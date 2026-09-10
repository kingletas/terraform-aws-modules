# --- buckets ---

# MWAA refuses to create an environment whose DAG bucket is not versioned,
# which the s3-bucket module already does.
module "dags" {
  source = "../../modules/s3-bucket"

  name = format("%s-dags-%s", local.prefix, data.aws_caller_identity.current.account_id)

  # No customer key. MWAA reads this bucket as a service, and a customer key
  # means adding the airflow principal to the key policy for no real gain on
  # a bucket holding code rather than data.
  versioning_enabled = true

  tags = merge(local.tags, { Purpose = "airflow-dags" })
}

module "warehouse_logs" {
  source = "../../modules/s3-bucket"

  name = format("%s-logs-%s", local.prefix, data.aws_caller_identity.current.account_id)

  # Redshift audit logging writes with an ACL, which BucketOwnerEnforced forbids.
  object_ownership = "BucketOwnerPreferred"

  lifecycle_rules = {
    expire = {
      expiration_days = 365
    }
  }

  tags = merge(local.tags, { Purpose = "redshift-audit" })
}

# --- source credentials, created empty ---

module "source_secrets" {
  source   = "../../modules/secrets-manager-secret"
  for_each = var.sources

  name        = format("%s/%s/source/%s", var.name, var.environment, each.key)
  description = coalesce(each.value.description, format("DMS source credentials for %s", each.key))
  kms_key_arn = module.kms.arn

  tags = merge(local.tags, { Source = each.key })
}

module "warehouse_secret" {
  source = "../../modules/secrets-manager-secret"

  name        = format("%s/%s/target/redshift", var.name, var.environment)
  description = "DMS target credentials for the Redshift cluster"
  kms_key_arn = module.kms.arn

  tags = local.tags
}

# --- what Redshift is allowed to do ---

module "redshift_role" {
  source = "../../modules/iam-role"

  name             = format("%s-redshift", local.prefix)
  description      = "Redshift COPY and UNLOAD against the warehouse buckets"
  trusted_services = ["redshift.amazonaws.com"]

  inline_policies = {
    warehouse = data.aws_iam_policy_document.redshift.json
  }

  tags = local.tags
}

data "aws_iam_policy_document" "redshift" {
  statement {
    sid       = "ReadWriteStaging"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket", "s3:DeleteObject"]
    resources = [module.warehouse_logs.arn, format("%s/*", module.warehouse_logs.arn)]
  }

  statement {
    sid       = "UseTheKey"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [module.kms.arn]
  }
}

module "warehouse" {
  source = "../../modules/redshift-cluster"

  name            = local.prefix
  database_name   = replace(var.name, "-", "_")
  node_type       = var.redshift_node_type
  number_of_nodes = var.redshift_nodes

  subnet_ids         = values(module.vpc.private_subnet_ids)
  security_group_ids = [module.warehouse_sg.id]
  kms_key_arn        = module.kms.arn

  iam_role_arns        = [module.redshift_role.arn]
  default_iam_role_arn = module.redshift_role.arn

  logging = { bucket = module.warehouse_logs.id }

  # COPY and UNLOAD stay inside the VPC, where the security groups and the S3
  # gateway endpoint apply to them. Off, that traffic leaves over the internet.
  enhanced_vpc_routing = true

  tags = local.tags
}

# --- replication ---

module "dms_secrets_role" {
  source = "../../modules/iam-role"

  name             = format("%s-dms-secrets", local.prefix)
  description      = "DMS reading endpoint credentials from Secrets Manager"
  trusted_services = [format("dms.%s.amazonaws.com", var.region)]

  inline_policies = {
    read_secrets = data.aws_iam_policy_document.dms_secrets.json
  }

  tags = local.tags
}

data "aws_iam_policy_document" "dms_secrets" {
  statement {
    sid     = "ReadEndpointSecrets"
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = concat(
      [for name, secret in module.source_secrets : secret.arn],
      [module.warehouse_secret.arn],
    )
  }

  statement {
    sid       = "DecryptThem"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [module.kms.arn]
  }
}

locals {
  # Every table in every schema, which is the sensible default for a warehouse
  # load and the thing you narrow once you know what you actually need.
  default_table_mappings = jsonencode({
    rules = [{
      "rule-type" = "selection"
      "rule-id"   = "1"
      "rule-name" = "all-tables"
      "object-locator" = {
        "schema-name" = "%"
        "table-name"  = "%"
      }
      "rule-action" = "include"
    }]
  })
}

module "replication" {
  source = "../../modules/dms-replication"

  name           = local.prefix
  instance_class = var.dms_instance_class

  subnet_ids         = values(module.vpc.private_subnet_ids)
  security_group_ids = [module.dms_sg.id]
  kms_key_arn        = module.kms.arn

  secrets_access_role_arn = module.dms_secrets_role.arn

  # The line that decides whether a private DMS task connects at all.
  secrets_manager_endpoint_dns = module.endpoints.interface_dns_names["secretsmanager"][0].dns_name

  endpoints = merge(
    {
      for name, source in var.sources : name => {
        endpoint_type = "source"
        engine_name   = source.engine
        database_name = source.database_name
        secret_arn    = module.source_secrets[name].arn
      }
    },
    {
      warehouse = {
        endpoint_type = "target"
        engine_name   = "redshift"
        database_name = module.warehouse.database_name
        secret_arn    = module.warehouse_secret.arn
      }
    }
  )

  tasks = {
    for name, source in var.sources : name => {
      source_endpoint     = name
      target_endpoint     = "warehouse"
      migration_type      = source.migration_type
      table_mappings_json = coalesce(source.table_mappings_json, local.default_table_mappings)

      # Started by Airflow, not by Terraform. A task that begins the moment it
      # is created will hammer a production source before anyone is watching.
      start_on_create = false
    }
  }

  tags = local.tags
}
