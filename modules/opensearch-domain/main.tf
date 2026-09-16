locals {
  in_vpc               = !var.public
  zone_aware           = var.zone_awareness_count > 1
  fine_grained_enabled = var.master_user != null || var.master_user_arn != null

  # Auto-Tune is not available on T2 and T3 instance types.
  auto_tune_supported = !can(regex("^t[23]\\.", var.instance_type))

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_opensearch_domain" "this" {
  domain_name    = var.name
  engine_version = var.engine_version

  cluster_config {
    instance_type  = var.instance_type
    instance_count = var.instance_count

    dedicated_master_enabled = var.dedicated_master.enabled
    dedicated_master_type    = var.dedicated_master.enabled ? var.dedicated_master.instance_type : null
    dedicated_master_count   = var.dedicated_master.enabled ? var.dedicated_master.instance_count : null

    zone_awareness_enabled = local.zone_aware

    dynamic "zone_awareness_config" {
      for_each = local.zone_aware ? [var.zone_awareness_count] : []

      content {
        availability_zone_count = zone_awareness_config.value
      }
    }
  }

  ebs_options {
    ebs_enabled = true
    volume_size = var.volume_size
    volume_type = var.volume_type
  }

  dynamic "vpc_options" {
    for_each = local.in_vpc ? [1] : []

    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = var.security_group_ids
    }
  }

  encrypt_at_rest {
    enabled    = true
    kms_key_id = var.kms_key_arn
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-PFS-2023-10"
  }

  advanced_security_options {
    enabled                        = local.fine_grained_enabled
    internal_user_database_enabled = var.master_user != null

    dynamic "master_user_options" {
      for_each = local.fine_grained_enabled ? [1] : []

      content {
        master_user_arn      = var.master_user_arn
        master_user_name     = try(var.master_user.name, null)
        master_user_password = try(var.master_user.password, null)
      }
    }
  }

  # Omitted on instance types without Auto-Tune, which refuse any Auto-Tune setting.
  dynamic "auto_tune_options" {
    for_each = local.auto_tune_supported ? [1] : []

    content {
      desired_state = var.auto_tune_enabled ? "ENABLED" : "DISABLED"
    }
  }

  off_peak_window_options {
    enabled = true

    off_peak_window {
      window_start_time {
        hours   = var.off_peak_window_start_hour
        minutes = 0
      }
    }
  }

  software_update_options {
    auto_software_update_enabled = true
  }

  access_policies = var.access_policy_json

  dynamic "log_publishing_options" {
    for_each = var.log_publishing

    content {
      log_type                 = log_publishing_options.key
      cloudwatch_log_group_arn = log_publishing_options.value.cloudwatch_log_group_arn
      enabled                  = log_publishing_options.value.enabled
    }
  }

  tags = local.tags

  lifecycle {
    precondition {
      condition     = var.master_user == null || var.master_user_arn == null
      error_message = "Set master_user or master_user_arn, not both."
    }

    precondition {
      condition     = !local.zone_aware || var.instance_count % var.zone_awareness_count == 0
      error_message = "The instance_count must divide evenly by zone_awareness_count, or shards will not spread evenly."
    }
  }
}
