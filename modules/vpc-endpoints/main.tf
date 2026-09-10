data "aws_region" "current" {}

locals {
  region = data.aws_region.current.region
}

resource "aws_vpc_endpoint" "interface" {
  for_each = toset(var.interface_services)

  vpc_id            = var.vpc_id
  service_name      = format("com.amazonaws.%s.%s", local.region, each.value)
  vpc_endpoint_type = "Interface"

  subnet_ids          = var.subnet_ids
  security_group_ids  = var.security_group_ids
  private_dns_enabled = var.private_dns_enabled
  policy              = var.policy_json

  tags = merge(var.tags, { Name = format("%s-%s", var.name, replace(each.value, ".", "-")) })

  lifecycle {
    precondition {
      condition     = length(var.subnet_ids) > 0
      error_message = "Interface endpoints need at least one subnet to place a network interface in."
    }
  }
}

resource "aws_vpc_endpoint" "gateway" {
  for_each = toset(var.gateway_services)

  vpc_id            = var.vpc_id
  service_name      = format("com.amazonaws.%s.%s", local.region, each.value)
  vpc_endpoint_type = "Gateway"

  route_table_ids = var.route_table_ids
  policy          = var.policy_json

  tags = merge(var.tags, { Name = format("%s-%s", var.name, each.value) })

  lifecycle {
    precondition {
      condition     = length(var.route_table_ids) > 0
      error_message = "Gateway endpoints need at least one route table, or nothing routes to them."
    }
  }
}
