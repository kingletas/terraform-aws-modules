data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

locals {
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Example     = "ec2-in-vpc"
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name               = var.name
  cidr_block         = var.vpc_cidr
  availability_zones = local.availability_zones
  enable_nat_gateway = true
  single_nat_gateway = true
  tags               = local.tags
}

module "app_security_group" {
  source = "../../modules/security-group"

  name        = format("%s-app", var.name)
  description = "Application instances"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    http_from_vpc = {
      description = "HTTP from inside the VPC"
      ip_protocol = "tcp"
      from_port   = 80
      to_port     = 80
      cidr_ipv4   = module.vpc.cidr_block
    }

    peers = {
      description = "Instances in this group reaching each other"
      ip_protocol = "-1"
      self        = true
    }
  }

  tags = local.tags
}

# Session Manager replaces SSH, so the instances need no key pair and no inbound port 22.
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name_prefix        = format("%s-app-", var.name)
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "session_manager" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "app" {
  name_prefix = format("%s-app-", var.name)
  role        = aws_iam_role.app.name

  tags = local.tags
}

module "app" {
  source = "../../modules/ec2-instance"

  name           = var.name
  instance_count = var.instance_count
  instance_type  = var.instance_type
  ami_id         = data.aws_ami.amazon_linux.id
  subnet_ids     = values(module.vpc.private_subnet_ids)

  security_group_ids   = [module.app_security_group.id]
  iam_instance_profile = aws_iam_instance_profile.app.name

  user_data = <<-EOT
    #cloud-config
    package_update: true
    packages:
      - nginx
    runcmd:
      - systemctl enable --now nginx
  EOT

  root_volume = {
    type = "gp3"
    size = 30
  }

  tags = local.tags
}
