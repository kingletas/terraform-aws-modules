# Creates resources and hands their IDs to the module in the same plan, so those
# IDs are unknown exactly as they are on a real first apply. Never deployed.
terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }
}

resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_vpc" "other" {
  cidr_block = "10.1.0.0/16"
}

resource "aws_route_table" "this" {
  vpc_id = aws_vpc.this.id
}

resource "aws_route_table" "other" {
  vpc_id = aws_vpc.other.id
}

resource "aws_kms_key" "this" {
  description = "plan test"
}

module "under_test" {
  source = "../.."

  default_security_group_vpc_ids = { main = aws_vpc.this.id }
  ebs_default_kms_key            = { arn = aws_kms_key.this.arn }
}
