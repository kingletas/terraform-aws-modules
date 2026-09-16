locals {
  import_server_certificate  = var.server_certificate_arn == null
  certificate_authentication = var.authentication_type == "certificate-authentication"
  import_client_certificate  = local.certificate_authentication && var.client_root_certificate_chain_arn == null

  server_certificate_arn = local.import_server_certificate ? aws_acm_certificate.server[0].arn : var.server_certificate_arn

  client_root_certificate_chain_arn = (
    local.certificate_authentication
    ? (local.import_client_certificate ? aws_acm_certificate.client_root[0].arn : var.client_root_certificate_chain_arn)
    : null
  )

  logging_enabled = var.connection_log_retention_days > 0

  tags = merge(var.tags, { Name = var.name })
}

# Fails at plan time rather than leaving an endpoint nobody can authenticate against.
resource "terraform_data" "authentication_preconditions" {
  lifecycle {
    precondition {
      condition     = var.server_certificate_arn != null || var.server_certificate != null
      error_message = "Set either server_certificate_arn or server_certificate."
    }

    precondition {
      condition = !local.certificate_authentication || (
        var.client_root_certificate_chain_arn != null || var.client_root_certificate != null
      )
      error_message = "Certificate authentication needs client_root_certificate_chain_arn or client_root_certificate."
    }

    precondition {
      condition     = var.authentication_type != "directory-service-authentication" || var.directory_id != null
      error_message = "Directory authentication needs directory_id."
    }

    precondition {
      condition     = var.authentication_type != "federated-authentication" || var.saml_provider_arn != null
      error_message = "Federated authentication needs saml_provider_arn."
    }

    precondition {
      condition     = !var.self_service_portal_enabled || var.authentication_type == "federated-authentication"
      error_message = "The self-service portal is only available with federated authentication."
    }
  }
}

# --- certificates ---

resource "aws_acm_certificate" "server" {
  count = local.import_server_certificate ? 1 : 0

  certificate_body  = try(var.server_certificate.certificate_body, null)
  private_key       = try(var.server_certificate.private_key, null)
  certificate_chain = try(var.server_certificate.certificate_chain, null)

  tags = merge(var.tags, { Name = format("%s-server", var.name) })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate" "client_root" {
  count = local.import_client_certificate ? 1 : 0

  certificate_body  = try(var.client_root_certificate.certificate_body, null)
  private_key       = try(var.client_root_certificate.private_key, null)
  certificate_chain = try(var.client_root_certificate.certificate_chain, null)

  tags = merge(var.tags, { Name = format("%s-client-root", var.name) })

  lifecycle {
    create_before_destroy = true
  }
}

# --- connection logging ---

resource "aws_cloudwatch_log_group" "this" {
  count = local.logging_enabled ? 1 : 0

  name              = format("/aws/client-vpn/%s", var.name)
  retention_in_days = var.connection_log_retention_days
  kms_key_id        = var.connection_log_kms_key_arn

  tags = local.tags
}

resource "aws_cloudwatch_log_stream" "this" {
  count = local.logging_enabled ? 1 : 0

  name           = "connections"
  log_group_name = aws_cloudwatch_log_group.this[0].name
}

# --- endpoint ---

resource "aws_ec2_client_vpn_endpoint" "this" {
  description = format("%s client VPN", var.name)

  vpc_id = var.vpc_id
  # An empty list is refused by the API, so none given means the VPC default security group.
  security_group_ids     = length(var.security_group_ids) > 0 ? var.security_group_ids : null
  server_certificate_arn = local.server_certificate_arn
  client_cidr_block      = var.client_cidr_block
  dns_servers            = var.dns_servers
  split_tunnel           = var.split_tunnel
  transport_protocol     = var.transport_protocol
  vpn_port               = var.vpn_port
  session_timeout_hours  = var.session_timeout_hours

  self_service_portal = var.self_service_portal_enabled ? "enabled" : "disabled"

  authentication_options {
    type                           = var.authentication_type
    root_certificate_chain_arn     = local.client_root_certificate_chain_arn
    active_directory_id            = var.directory_id
    saml_provider_arn              = var.saml_provider_arn
    self_service_saml_provider_arn = var.self_service_saml_provider_arn
  }

  connection_log_options {
    enabled               = local.logging_enabled
    cloudwatch_log_group  = local.logging_enabled ? aws_cloudwatch_log_group.this[0].name : null
    cloudwatch_log_stream = local.logging_enabled ? aws_cloudwatch_log_stream.this[0].name : null
  }

  tags = local.tags

  depends_on = [terraform_data.authentication_preconditions]
}

# --- network wiring ---

resource "aws_ec2_client_vpn_network_association" "this" {
  for_each = var.subnet_ids

  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  subnet_id              = each.value
}

resource "aws_ec2_client_vpn_authorization_rule" "this" {
  for_each = var.authorization_rules

  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  target_network_cidr    = each.value.target_network_cidr
  description            = coalesce(each.value.description, each.key)
  access_group_id        = each.value.access_group_id
  authorize_all_groups   = each.value.authorize_all_groups

  depends_on = [aws_ec2_client_vpn_network_association.this]
}

resource "aws_ec2_client_vpn_route" "this" {
  for_each = var.routes

  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  destination_cidr_block = each.value.destination_cidr_block
  target_vpc_subnet_id   = each.value.target_subnet_id
  description            = coalesce(each.value.description, each.key)

  depends_on = [aws_ec2_client_vpn_network_association.this]
}
