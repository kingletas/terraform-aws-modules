module "node_role" {
  source = "../../modules/iam-role"

  name             = format("%s-node", local.prefix)
  description      = "Web, cron and admin nodes, which read static assets but never publish them"
  trusted_services = ["ec2.amazonaws.com"]

  managed_policy_arns = {
    session_manager  = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    cloudwatch_agent = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  }

  inline_policies = {
    storefront = data.aws_iam_policy_document.node.json
  }

  create_instance_profile = true

  tags = local.tags
}

data "aws_iam_policy_document" "node" {
  statement {
    sid       = "ReadOwnSecrets"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [module.database.master_user_secret_arn]
  }

  # The facts Terraform published, read at boot rather than baked into the AMI.
  statement {
    sid       = "ReadFacts"
    effect    = "Allow"
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = [module.ansible.facts_parameter_arn]
  }

  # The Valkey auth token and the OpenSearch password, and no other parameter.
  statement {
    sid       = "ReadServiceCredentials"
    effect    = "Allow"
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = values(module.service_credentials.arns)
  }

  statement {
    sid       = "UseTheKey"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:DescribeKey", "kms:GenerateDataKey"]
    resources = [module.kms.arn]
  }

  statement {
    sid       = "ReadStaticAssets"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = [module.static_assets.arn, format("%s/*", module.static_assets.arn)]
  }
}

# Only the builder publishes what CloudFront serves to every shopper, so a compromised web node cannot plant a script there.
module "builder_role" {
  count  = var.include_builder ? 1 : 0
  source = "../../modules/iam-role"

  name             = format("%s-builder", local.prefix)
  description      = "The builder node, which also publishes static assets"
  trusted_services = ["ec2.amazonaws.com"]

  managed_policy_arns = {
    session_manager  = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    cloudwatch_agent = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  }

  inline_policies = {
    storefront     = data.aws_iam_policy_document.node.json
    publish_static = data.aws_iam_policy_document.publish_static.json
  }

  create_instance_profile = true

  tags = local.tags
}

data "aws_iam_policy_document" "publish_static" {
  statement {
    sid       = "PublishStaticAssets"
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = [format("%s/*", module.static_assets.arn)]
  }
}

locals {
  # Where to find everything, and where to fetch each secret from. No secret value is in here.
  node_environment = {
    MAGENTO_ENVIRONMENT               = var.environment
    MAGENTO_DB_HOST                   = module.database.endpoint
    MAGENTO_DB_READER_HOST            = module.database.reader_endpoint
    MAGENTO_DB_NAME                   = module.database.database_name
    MAGENTO_DB_SECRET_ARN             = module.database.master_user_secret_arn
    MAGENTO_REDIS_HOST                = module.cache.primary_endpoint_address
    MAGENTO_REDIS_PORT                = tostring(module.cache.port)
    MAGENTO_REDIS_AUTH_PARAMETER      = module.service_credentials.names["cache/auth-token"]
    MAGENTO_SEARCH_HOST               = module.search.endpoint
    MAGENTO_SEARCH_USER               = local.search_master_user
    MAGENTO_SEARCH_PASSWORD_PARAMETER = module.service_credentials.names["search/master-password"]
    MAGENTO_MEDIA_FS                  = module.media.id
    MAGENTO_STATIC_BUCKET             = module.static_assets.id
    MAGENTO_FACTS_PARAMETER           = module.ansible.facts_parameter_name
    AWS_REGION                        = var.region
  }

  node_cloud_init = <<-EOT
    #cloud-config
    write_files:
      - path: /etc/magento/environment
        permissions: "0644"
        content: |
          ${indent(6, join("\n", [for key, value in local.node_environment : format("%s=%s", key, value)]))}
    runcmd:
      - mkdir -p /var/www/html/pub/media
      - >-
        mount -t efs -o tls,accesspoint=${module.media.access_point_arns["media"]}
        ${module.media.id}:/ /var/www/html/pub/media
  EOT
}

# --- the web tier: cattle ---

module "web_template" {
  source = "../../modules/launch-template"

  name        = module.context.name["web"]
  description = "Magento web node"

  image_id      = var.ami_id
  instance_type = var.instance_types[var.environment]

  security_group_ids       = [module.app_sg.id]
  iam_instance_profile_arn = module.node_role.instance_profile_arn
  kms_key_id               = module.kms.arn

  user_data = local.node_cloud_init

  root_volume = {
    type       = "gp3"
    size       = 60
    throughput = 250
  }

  tags = merge(local.tags, { Role = "web" })
}

module "web" {
  source = "../../modules/autoscaling-group"

  name                    = module.context.name["web"]
  launch_template_id      = module.web_template.id
  launch_template_version = module.web_template.latest_version
  subnet_ids              = values(module.vpc.private_subnet_ids)

  min_size         = local.capacity.min
  max_size         = local.capacity.max
  desired_capacity = local.capacity.desired

  target_group_arns = [module.alb.target_group_arns["web"]]
  health_check_type = "ELB"

  # Magento's first request after a deploy compiles and warms a great deal.
  # Below this the group kills nodes that were about to become healthy.
  health_check_grace_period = 600

  target_tracking_policies = {
    cpu = {
      metric_type  = "ASGAverageCPUUtilization"
      target_value = 55
    }
  }

  instance_refresh = {
    min_healthy_percentage = 100
    instance_warmup        = 600
  }

  tags = merge(local.tags, { Role = "web" })
}

# --- the jobs exactly one machine may do: pets ---

# The AMI the singletons were built from. A new ami_id rolls only the web tier;
# replacing this resource rolls the singletons onto the current ami_id.
resource "terraform_data" "singleton_ami" {
  input = var.ami_id

  lifecycle {
    ignore_changes = [input]
  }
}

# Magento has work that cannot be replicated. Two nodes running
# bin/magento cron:run claim the same cron_schedule rows, and the result is
# duplicate order emails and indexers stuck in "working" forever.
module "singletons" {
  source = "../../modules/instance-fleet"

  name = local.prefix

  defaults = {
    ami_id        = terraform_data.singleton_ami.output
    instance_type = var.instance_types[var.environment]

    subnet_ids           = values(module.vpc.private_subnet_ids)
    security_group_ids   = [module.app_sg.id]
    iam_instance_profile = module.node_role.instance_profile_name
    kms_key_id           = module.kms.arn

    root_volume_type = "gp3"
    root_volume_size = 60
    user_data        = local.node_cloud_init
  }

  roles = merge(
    {
      # The indexers and the consumer queue.
      cron = {
        count            = 1
        root_volume_size = 100
        tags             = { Tier = "application" }
      }

      # The admin panel, off the shopper path so a slow report cannot take
      # capacity from checkout.
      admin = {
        count = 1
        tags  = { Tier = "application" }
      }
    },

    # Off by default: where CI builds the AMI, there is nothing for a builder
    # node to do, and an idle c7g.2xlarge is an expensive way to have nothing.
    var.include_builder ? {
      builder = {
        count                  = 1
        iam_instance_profile   = one(module.builder_role[*].instance_profile_name)
        instance_type          = "c7g.2xlarge"
        root_volume_size       = 200
        root_volume_throughput = 500

        extra_volumes = {
          workspace = {
            device_name = "/dev/sdf"
            size        = 200
            throughput  = 500
          }
        }

        tags = { Tier = "build" }
      }
    } : {},
  )

  tags = local.tags
}
