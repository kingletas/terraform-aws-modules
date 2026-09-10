locals {
  zones = { for index, zone in var.availability_zones : zone => index }

  # Public subnets take the low half of the address space, private subnets the high half.
  private_offset = length(var.availability_zones)

  nat_zones = var.enable_nat_gateway ? (
    var.single_nat_gateway ? slice(var.availability_zones, 0, 1) : var.availability_zones
  ) : []

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = local.tags
}

# The default security group is left in place but permits nothing.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = format("%s-default", var.name) })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = local.tags
}

# --- subnets ---

resource "aws_subnet" "public" {
  for_each = local.zones

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = cidrsubnet(var.cidr_block, var.subnet_newbits, each.value)
  map_public_ip_on_launch = var.map_public_ip_on_launch

  tags = merge(var.tags, {
    Name = format("%s-public-%s", var.name, each.key)
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  for_each = local.zones

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = cidrsubnet(var.cidr_block, var.subnet_newbits, each.value + local.private_offset)

  tags = merge(var.tags, {
    Name = format("%s-private-%s", var.name, each.key)
    Tier = "private"
  })
}

# --- outbound routing ---

resource "aws_eip" "nat" {
  for_each = toset(local.nat_zones)

  domain = "vpc"

  tags = merge(var.tags, { Name = format("%s-nat-%s", var.name, each.key) })
}

resource "aws_nat_gateway" "this" {
  for_each = toset(local.nat_zones)

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = merge(var.tags, { Name = format("%s-nat-%s", var.name, each.key) })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = format("%s-public", var.name) })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Each private subnet gets its own table so a per-zone NAT gateway can be routed independently.
resource "aws_route_table" "private" {
  for_each = local.zones

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = format("%s-private-%s", var.name, each.key) })
}

resource "aws_route" "private_nat" {
  for_each = var.enable_nat_gateway ? local.zones : {}

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[var.single_nat_gateway ? local.nat_zones[0] : each.key].id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}
