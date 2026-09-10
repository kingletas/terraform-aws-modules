locals {
  same_account_and_region = var.peer_owner_id == null && var.peer_region == null
  tags                    = merge(var.tags, { Name = var.name })
}

resource "aws_vpc_peering_connection" "this" {
  vpc_id        = var.requester_vpc_id
  peer_vpc_id   = var.accepter_vpc_id
  peer_owner_id = var.peer_owner_id
  peer_region   = var.peer_region

  auto_accept = local.same_account_and_region && var.auto_accept

  dynamic "requester" {
    for_each = local.same_account_and_region ? [1] : []

    content {
      allow_remote_vpc_dns_resolution = var.allow_remote_dns_resolution
    }
  }

  dynamic "accepter" {
    for_each = local.same_account_and_region ? [1] : []

    content {
      allow_remote_vpc_dns_resolution = var.allow_remote_dns_resolution
    }
  }

  tags = local.tags

  lifecycle {
    precondition {
      condition     = length(var.requester_route_table_ids) == 0 || var.requester_destination_cidr != null
      error_message = "Routes on the requester side need requester_destination_cidr."
    }

    precondition {
      condition     = length(var.accepter_route_table_ids) == 0 || var.accepter_destination_cidr != null
      error_message = "Routes on the accepter side need accepter_destination_cidr."
    }

    precondition {
      condition     = length(var.accepter_route_table_ids) == 0 || local.same_account_and_region
      error_message = "The accepter's route tables can only be managed when both VPCs are in this account and region."
    }
  }
}

resource "aws_route" "requester" {
  for_each = var.requester_route_table_ids

  route_table_id            = each.value
  destination_cidr_block    = var.requester_destination_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
}

resource "aws_route" "accepter" {
  for_each = var.accepter_route_table_ids

  route_table_id            = each.value
  destination_cidr_block    = var.accepter_destination_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
}
