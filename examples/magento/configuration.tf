# Terraform builds the stack; Ansible configures it.
#
# The inventory is discovered rather than written, because half this stack is an
# autoscaling group: those instances do not exist when Terraform plans, and any
# host list written here is wrong the first time the group scales.
module "ansible" {
  source = "../../modules/ansible-inventory"

  name       = local.prefix
  output_dir = "${path.module}/ansible"
  regions    = [var.region]

  # Ansible finds hosts by these tags. The context module puts them on
  # everything, so a node joins the inventory by existing.
  discovery_tags = {
    Project     = var.project
    Environment = var.environment
  }

  group_by_tag = "Role"
  ssh_user     = local.vm_user

  # Over Systems Manager: no bastion, no open port 22, no key to distribute,
  # and it reaches an instance that has no public address.
  connection = "ssm"

  kms_key_arn = module.kms.arn

  # Published once, to SSM, so every operator and every CI runner reads the
  # same values and a stale local copy cannot exist.
  facts = {
    environment = var.environment

    db_host        = module.database.endpoint
    db_reader_host = module.database.reader_endpoint
    db_name        = module.database.database_name
    db_secret_arn  = module.database.master_user_secret_arn

    redis_host = module.cache.primary_endpoint_address
    redis_port = tostring(module.cache.port)

    search_host = module.search.endpoint

    media_filesystem_id = module.media.id
    static_bucket       = module.static_assets.id

    cdn_domain    = module.cdn.domain_name
    origin_domain = aws_route53_record.origin.fqdn
    aws_region    = var.region
  }

  group_vars = {
    web = {
      run_cron    = "false"
      serves_http = "true"
    }

    cron = {
      # The one node that runs bin/magento cron:run.
      run_cron    = "true"
      serves_http = "false"
    }

    admin = {
      run_cron    = "false"
      serves_http = "true"
    }
  }

  tags = local.tags
}
