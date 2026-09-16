# --- one repository per service ---

module "repositories" {
  source   = "../../modules/ecr-repository"
  for_each = var.services

  name        = format("%s/%s", var.name, each.key)
  kms_key_arn = module.kms.arn

  # A deployed tag names one image forever. A build cannot move it afterwards,
  # so what is running always matches what the tag meant when it shipped.
  image_tag_mutability = "IMMUTABLE"
  scan_on_push         = true

  untagged_image_expiry_days = var.untagged_image_expiry_days
  max_tagged_images          = var.max_tagged_images

  tags = merge(local.tags, { Service = each.key })
}

# --- database ---

module "database" {
  source = "../../modules/aurora-cluster"

  name           = local.prefix
  engine         = "aurora-postgresql"
  engine_version = "16.4"

  database_name = replace(var.name, "-", "_")

  subnet_ids         = values(module.vpc.private_subnet_ids)
  security_group_ids = [module.database_sg.id]
  kms_key_arn        = module.kms.arn

  instances = {
    writer = { promotion_tier = 0 }
    reader = { promotion_tier = 1 }
  }

  serverless_capacity = {
    min_capacity = 0.5
    max_capacity = var.database_max_capacity
  }

  enabled_cloudwatch_logs_exports = ["postgresql"]
  backup_retention_period         = 30

  tags = local.tags
}

# --- cluster ---

locals {
  # One task per service stays on on-demand Fargate whatever the spot market
  # does, and three in four of the rest run on Fargate Spot.
  capacity_provider_strategy = [
    { capacity_provider = "FARGATE", base = 1, weight = 1 },
    { capacity_provider = "FARGATE_SPOT", weight = 3 },
  ]
}

module "cluster" {
  source = "../../modules/ecs-cluster"

  name        = local.prefix
  kms_key_arn = module.kms.arn

  capacity_providers                 = ["FARGATE", "FARGATE_SPOT"]
  default_capacity_provider_strategy = local.capacity_provider_strategy

  tags = local.tags
}

# --- what a task is allowed to do ---

# ECS uses this one before your code runs, to pull the image and read secrets.
module "execution_role" {
  source = "../../modules/iam-role"

  name             = format("%s-execution", local.prefix)
  description      = "ECS pulling images and reading secrets"
  trusted_services = ["ecs-tasks.amazonaws.com"]

  managed_policy_arns = {
    ecs_execution = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  }

  inline_policies = {
    read_secrets = data.aws_iam_policy_document.execution.json
  }

  tags = local.tags
}

data "aws_iam_policy_document" "execution" {
  statement {
    sid       = "ReadDatabaseSecret"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [module.database.master_user_secret_arn]
  }

  statement {
    sid       = "DecryptWithTheKey"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [module.kms.arn]
  }
}

# The application assumes this one at runtime. Kept separate so a compromise of
# the code does not hand over the ability to read every secret at task start.
module "task_role" {
  source = "../../modules/iam-role"

  name             = format("%s-task", local.prefix)
  description      = "Application code at runtime"
  trusted_services = ["ecs-tasks.amazonaws.com"]

  inline_policies = {
    runtime = data.aws_iam_policy_document.task.json
  }

  tags = local.tags
}

data "aws_iam_policy_document" "task" {
  # ECS Exec talks to Systems Manager over the task's own role.
  statement {
    sid    = "ExecuteCommand"
    effect = "Allow"

    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]

    resources = ["*"]
  }
}

# --- the services themselves ---

module "services" {
  source   = "../../modules/ecs-service"
  for_each = var.services

  name        = format("%s-%s", local.prefix, each.key)
  cluster_arn = module.cluster.arn

  cpu    = each.value.cpu
  memory = each.value.memory

  capacity = {
    capacity_provider_strategy = local.capacity_provider_strategy
  }

  subnet_ids         = values(module.vpc.private_subnet_ids)
  security_group_ids = [module.task_sg.id]

  execution_role_arn = module.execution_role.arn
  task_role_arn      = module.task_role.arn
  kms_key_arn        = module.kms.arn

  containers = {
    (each.key) = {
      image = format("%s:%s", module.repositories[each.key].repository_url, each.value.image_tag)
      ports = [{ container_port = each.value.container_port }]

      environment = merge(each.value.environment, {
        DATABASE_HOST        = module.database.endpoint
        DATABASE_READER_HOST = module.database.reader_endpoint
        DATABASE_NAME        = module.database.database_name
        SERVICE_NAME         = each.key
      })

      # Fetched by ECS at task start and never written into the task definition.
      secrets = {
        DATABASE_CREDENTIALS = module.database.master_user_secret_arn
      }

      health_check_command = ["CMD-SHELL", format("curl -fsS localhost:%d%s || exit 1", each.value.container_port, each.value.health_path)]
    }
  }

  load_balancers = {
    public = {
      target_group_arn = module.alb.target_group_arns[each.key]
      container_name   = each.key
      container_port   = each.value.container_port
    }
  }

  health_check_grace_period_seconds = 120

  deployment = {
    # Stops a broken rollout rather than patiently replacing every healthy
    # task with one that cannot start.
    circuit_breaker     = true
    rollback_on_failure = true
  }

  autoscaling = {
    min_capacity = each.value.min_capacity
    max_capacity = each.value.max_capacity
    cpu_target   = each.value.cpu_target
  }

  tags = merge(local.tags, { Service = each.key })
}
