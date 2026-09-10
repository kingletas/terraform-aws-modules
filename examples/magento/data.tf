module "database" {
  source = "../../modules/aurora-cluster"

  name           = local.prefix
  engine         = "aurora-mysql"
  engine_version = "8.0.mysql_aurora.3.08.0"
  database_name  = "magento"
  username       = "magento"

  subnet_ids         = values(module.vpc.private_subnet_ids)
  security_group_ids = [module.datastore_sg.id]
  kms_key_arn        = module.kms.arn

  instances = merge(
    { writer = { promotion_tier = 0 } },
    local.defaults.multi_az ? { reader = { promotion_tier = 1 } } : {},
  )

  serverless_capacity = {
    min_capacity = module.context.is_production ? 2 : 0.5
    max_capacity = module.context.is_production ? 32 : 8
  }

  parameter_group_family = "aurora-mysql8.0"

  cluster_parameters = {
    max_allowed_packet              = "134217728"
    log_bin_trust_function_creators = "1"
  }

  enabled_cloudwatch_logs_exports = ["error", "slowquery"]

  backup_retention_period = local.defaults.backup_retention_days
  deletion_protection     = local.defaults.deletion_protection
  skip_final_snapshot     = local.defaults.skip_final_snapshot

  tags = local.tags
}

module "cache" {
  source = "../../modules/elasticache-redis"

  name      = module.context.name["cache"]
  engine    = "valkey"
  node_type = module.context.is_production ? "cache.r7g.large" : "cache.t4g.micro"

  subnet_ids         = values(module.vpc.private_subnet_ids)
  security_group_ids = [module.datastore_sg.id]
  kms_key_arn        = module.kms.arn

  replicas_per_node_group = local.defaults.multi_az ? 1 : 0

  parameter_group_family = "valkey8"

  # Sessions live here alongside the cache. An evicted session key is a shopper
  # logged out mid-checkout, so the policy must not discard live keys.
  parameters = {
    maxmemory-policy = "volatile-lru"
  }

  # On, which means env.php needs scheme => tls and this token on both the
  # cache and the session handler.
  transit_encryption_enabled = true
  auth_token                 = random_password.cache.result

  snapshot_retention_limit = min(local.defaults.backup_retention_days, 5)

  tags = local.tags
}

resource "random_password" "cache" {
  length           = 64
  special          = true
  override_special = "!&#$^<>-"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
}

module "search" {
  source = "../../modules/opensearch-domain"

  name           = module.context.short_prefix
  engine_version = "OpenSearch_2.17"

  instance_type  = module.context.is_production ? "r7g.large.search" : "t3.small.search"
  instance_count = local.defaults.multi_az ? 2 : 1

  zone_awareness_count = local.defaults.multi_az ? 2 : 1
  volume_size          = module.context.is_production ? 100 : 20

  subnet_ids         = local.defaults.multi_az ? values(module.vpc.private_subnet_ids) : [values(module.vpc.private_subnet_ids)[0]]
  security_group_ids = [module.datastore_sg.id]
  kms_key_arn        = module.kms.arn

  master_user = {
    name     = "opensearch"
    password = random_password.search.result
  }

  tags = local.tags
}

resource "random_password" "search" {
  length           = 32
  special          = true
  override_special = "!#$%^&*()-_=+"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
}

# pub/media must be one directory across every node, or an image uploaded
# through the admin is a 404 on every other node — and with an autoscaling
# tier, the node holding it is also the one that gets terminated.
module "media" {
  source = "../../modules/efs-filesystem"

  name = format("%s-media", local.prefix)

  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.datastore_sg.id]
  kms_key_arn        = module.kms.arn

  throughput_mode = "elastic"
  enable_backup   = module.context.is_production

  access_points = {
    media = {
      path        = "/media"
      owner_uid   = 33
      owner_gid   = 33
      posix_uid   = 33
      posix_gid   = 33
      permissions = "0775"
    }
  }

  tags = local.tags
}

module "static_assets" {
  source = "../../modules/s3-bucket"

  name        = format("%s-static-%s", local.prefix, data.aws_caller_identity.current.account_id)
  kms_key_arn = module.kms.arn

  lifecycle_rules = {
    expire_old_deploys = {
      prefix                             = "static/"
      noncurrent_version_expiration_days = 30
    }
  }

  tags = local.tags
}

module "cdn_logs" {
  source = "../../modules/s3-bucket"

  name = format("%s-cdn-logs-%s", local.prefix, data.aws_caller_identity.current.account_id)

  # CloudFront access logging writes with an ACL, which BucketOwnerEnforced
  # forbids. The looser setting is confined to a bucket holding only logs.
  object_ownership = "BucketOwnerPreferred"

  lifecycle_rules = {
    expire = {
      expiration_days = local.defaults.log_retention_days
    }
  }

  tags = local.tags
}
