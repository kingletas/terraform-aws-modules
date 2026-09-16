locals {
  use_custom_domain = var.custom_domain != null
  domain_name       = local.use_custom_domain ? var.custom_domain : var.domain_prefix
  create_domain     = local.domain_name != null
}

resource "aws_cognito_user_pool" "this" {
  name = var.name

  username_attributes      = var.username_attributes
  auto_verified_attributes = var.auto_verified_attributes
  mfa_configuration        = var.mfa_configuration
  user_pool_tier           = var.user_pool_tier
  deletion_protection      = var.deletion_protection ? "ACTIVE" : "INACTIVE"

  password_policy {
    minimum_length                   = var.password_policy.minimum_length
    require_lowercase                = var.password_policy.require_lowercase
    require_uppercase                = var.password_policy.require_uppercase
    require_numbers                  = var.password_policy.require_numbers
    require_symbols                  = var.password_policy.require_symbols
    temporary_password_validity_days = var.password_policy.temporary_password_validity_days
  }

  dynamic "software_token_mfa_configuration" {
    for_each = var.mfa_configuration != "OFF" && var.software_token_mfa ? [1] : []

    content {
      enabled = true
    }
  }

  user_pool_add_ons {
    advanced_security_mode = var.advanced_security_mode
  }

  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  dynamic "schema" {
    for_each = var.custom_attributes

    content {
      name                     = schema.key
      attribute_data_type      = schema.value.type
      mutable                  = schema.value.mutable
      developer_only_attribute = false

      dynamic "string_attribute_constraints" {
        for_each = schema.value.type == "String" ? [schema.value] : []

        content {
          min_length = string_attribute_constraints.value.min_length
          max_length = string_attribute_constraints.value.max_length
        }
      }
    }
  }

  tags = merge(var.tags, { Name = var.name })

  lifecycle {
    precondition {
      condition     = var.advanced_security_mode == "OFF" || var.user_pool_tier == "PLUS"
      error_message = "Threat protection, advanced_security_mode AUDIT or ENFORCED, is only available on the PLUS feature plan. Set user_pool_tier to PLUS or advanced_security_mode to OFF."
    }

    precondition {
      condition     = !local.use_custom_domain || var.custom_domain_certificate_arn != null
      error_message = "A custom domain needs custom_domain_certificate_arn, and the certificate must be in us-east-1."
    }
  }
}

resource "aws_cognito_user_pool_domain" "this" {
  count = local.create_domain ? 1 : 0

  domain          = local.domain_name
  user_pool_id    = aws_cognito_user_pool.this.id
  certificate_arn = local.use_custom_domain ? var.custom_domain_certificate_arn : null
}

resource "aws_cognito_user_pool_client" "this" {
  for_each = var.clients

  name         = each.key
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret = each.value.generate_secret
  callback_urls   = each.value.callback_urls
  logout_urls     = each.value.logout_urls

  allowed_oauth_flows                  = length(each.value.callback_urls) > 0 ? each.value.allowed_oauth_flows : null
  allowed_oauth_scopes                 = length(each.value.callback_urls) > 0 ? each.value.allowed_oauth_scopes : null
  allowed_oauth_flows_user_pool_client = length(each.value.callback_urls) > 0
  supported_identity_providers         = each.value.supported_identity_providers
  explicit_auth_flows                  = each.value.explicit_auth_flows

  access_token_validity  = each.value.access_token_validity_minutes
  id_token_validity      = each.value.id_token_validity_minutes
  refresh_token_validity = each.value.refresh_token_validity_days

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  # Without this, a failed login says whether the account exists.
  prevent_user_existence_errors = each.value.prevent_user_existence_errors ? "ENABLED" : "LEGACY"
}
