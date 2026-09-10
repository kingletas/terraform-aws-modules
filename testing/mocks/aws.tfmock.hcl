# Data source values apply during a plan; mock_resource defaults apply only when a
# test applies. A plan test that needs a computed value states it with an
# override_resource and override_during = plan.

mock_data "aws_availability_zones" {
  defaults = {
    names    = ["us-east-1a", "us-east-1b", "us-east-1c"]
    zone_ids = ["use1-az1", "use1-az2", "use1-az4"]
  }
}

mock_data "aws_caller_identity" {
  defaults = {
    account_id = "123456789012"
    arn        = "arn:aws:iam::123456789012:user/plan-test"
  }
}

mock_data "aws_region" {
  defaults = {
    name   = "us-east-1"
    region = "us-east-1"
  }
}

mock_data "aws_partition" {
  defaults = {
    partition  = "aws"
    dns_suffix = "amazonaws.com"
  }
}

mock_data "aws_route53_zone" {
  defaults = {
    zone_id = "Z0123456789ABCDEFGHIJ"
    name    = "example.com"
  }
}

mock_data "aws_ami" {
  defaults = {
    id = "ami-0123456789abcdef0"
  }
}

# A policy document is computed locally by the real provider. A mock would invent a
# random string, and anything that parses the JSON later would break on it.
mock_data "aws_iam_policy_document" {
  defaults = {
    json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
  }
}

# Resources whose ARNs or IDs are parsed downstream need a realistic shape.
mock_resource "aws_kms_key" {
  defaults = {
    arn    = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
    key_id = "00000000-0000-0000-0000-000000000000"
  }
}

mock_resource "aws_ecs_cluster" {
  defaults = {
    arn = "arn:aws:ecs:us-east-1:123456789012:cluster/plan-test"
  }
}

mock_resource "aws_acm_certificate" {
  defaults = {
    arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  }
}

mock_resource "aws_acm_certificate_validation" {
  defaults = {
    certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  }
}
