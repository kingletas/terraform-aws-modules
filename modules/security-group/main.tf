locals {
  # An explicit egress rule set replaces the allow-all default rather than adding to it.
  default_egress = var.allow_all_egress && length(var.egress_rules) == 0 ? {
    all = {
      description                  = "Allow all outbound IPv4 traffic"
      ip_protocol                  = "-1"
      cidr_ipv4                    = "0.0.0.0/0"
      from_port                    = null
      to_port                      = null
      cidr_ipv6                    = null
      referenced_security_group_id = null
      prefix_list_id               = null
      self                         = false
    }
  } : {}

  egress_rules = length(var.egress_rules) > 0 ? var.egress_rules : local.default_egress
}

resource "aws_security_group" "this" {
  name_prefix = format("%s-", var.name)
  description = var.description
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = var.name })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = var.ingress_rules

  security_group_id = aws_security_group.this.id
  description       = each.value.description
  ip_protocol       = each.value.ip_protocol
  from_port         = each.value.ip_protocol == "-1" ? null : each.value.from_port
  to_port           = each.value.ip_protocol == "-1" ? null : each.value.to_port

  cidr_ipv4                    = each.value.cidr_ipv4
  cidr_ipv6                    = each.value.cidr_ipv6
  prefix_list_id               = each.value.prefix_list_id
  referenced_security_group_id = each.value.self ? aws_security_group.this.id : each.value.referenced_security_group_id

  tags = merge(var.tags, { Name = format("%s-in-%s", var.name, each.key) })
}

# All outbound is the default AWS itself applies; set allow_all_egress = false or egress_rules to narrow it.
#trivy:ignore:AWS-0104
resource "aws_vpc_security_group_egress_rule" "this" {
  for_each = local.egress_rules

  security_group_id = aws_security_group.this.id
  description       = each.value.description
  ip_protocol       = each.value.ip_protocol
  from_port         = each.value.ip_protocol == "-1" ? null : each.value.from_port
  to_port           = each.value.ip_protocol == "-1" ? null : each.value.to_port

  cidr_ipv4                    = each.value.cidr_ipv4
  cidr_ipv6                    = each.value.cidr_ipv6
  prefix_list_id               = each.value.prefix_list_id
  referenced_security_group_id = each.value.self ? aws_security_group.this.id : each.value.referenced_security_group_id

  tags = merge(var.tags, { Name = format("%s-out-%s", var.name, each.key) })
}
