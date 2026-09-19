locals {
  tags = merge(var.tags, { Name = var.name })

  propagations = merge([
    for attachment_key, attachment in var.vpc_attachments : {
      for table_key in attachment.propagate_to_tables :
      format("%s-%s", attachment_key, table_key) => {
        attachment_key = attachment_key
        table_key      = table_key
      }
    }
  ]...)

  associations = {
    for key, attachment in var.vpc_attachments : key => attachment
    if attachment.route_table_key != null
  }
}

resource "aws_ec2_transit_gateway" "this" {
  description     = coalesce(var.description, format("%s transit gateway", var.name))
  amazon_side_asn = var.amazon_side_asn

  auto_accept_shared_attachments  = var.auto_accept_shared_attachments ? "enable" : "disable"
  default_route_table_association = var.default_route_table_association ? "enable" : "disable"
  default_route_table_propagation = var.default_route_table_propagation ? "enable" : "disable"
  dns_support                     = var.dns_support ? "enable" : "disable"
  multicast_support               = var.multicast_support ? "enable" : "disable"

  tags = local.tags
}

resource "aws_ec2_transit_gateway_route_table" "this" {
  for_each = var.route_tables

  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(var.tags, {
    Name    = format("%s-%s", var.name, each.key)
    Purpose = each.value
  })
}

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  for_each = var.vpc_attachments

  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = each.value.vpc_id
  subnet_ids         = each.value.subnet_ids

  appliance_mode_support = each.value.appliance_mode ? "enable" : "disable"
  dns_support            = each.value.dns_support ? "enable" : "disable"

  transit_gateway_default_route_table_association = var.default_route_table_association
  transit_gateway_default_route_table_propagation = var.default_route_table_propagation

  tags = merge(var.tags, { Name = format("%s-%s", var.name, each.key) })
}

resource "aws_ec2_transit_gateway_route_table_association" "this" {
  for_each = local.associations

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this[each.value.route_table_key].id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "this" {
  for_each = local.propagations

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this[each.value.attachment_key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this[each.value.table_key].id
}

resource "aws_ec2_transit_gateway_route" "this" {
  for_each = var.static_routes

  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this[each.value.route_table_key].id
  destination_cidr_block         = each.value.destination_cidr_block
  blackhole                      = each.value.blackhole

  transit_gateway_attachment_id = each.value.blackhole ? null : aws_ec2_transit_gateway_vpc_attachment.this[each.value.attachment_key].id
}

resource "aws_ram_resource_share" "this" {
  count = length(var.share_with_principals) > 0 ? 1 : 0

  name                      = format("%s-share", var.name)
  allow_external_principals = false

  tags = local.tags
}

resource "aws_ram_resource_association" "this" {
  count = length(var.share_with_principals) > 0 ? 1 : 0

  resource_arn       = aws_ec2_transit_gateway.this.arn
  resource_share_arn = aws_ram_resource_share.this[0].arn
}

resource "aws_ram_principal_association" "this" {
  for_each = var.share_with_principals

  principal          = each.value
  resource_share_arn = aws_ram_resource_share.this[0].arn
}
