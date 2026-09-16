# Plans the module on its own with real values, including values from other
# resources that do not exist until apply. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

run "plans_with_real_values" {
  command = plan

  variables {
    name          = "example.com"
    records       = { www = { name = "www.example.com", type = "A", alias_name = "d111111abcdef8.cloudfront.net", alias_zone_id = "Z2FDTNDATAQYW2" } }
    health_checks = { web = { fqdn = "www.example.com" } }
  }

  assert {
    condition     = length(aws_route53_zone.this.vpc) == 0 && length(aws_route53_query_log.this) == 0
    error_message = "A zone with no VPCs should be public, with query logging off unless asked."
  }

  assert {
    condition     = aws_route53_record.this["www"].alias[0].name == "d111111abcdef8.cloudfront.net" && aws_route53_record.this["www"].ttl == null && aws_route53_record.this["www"].records == null
    error_message = "An alias record should carry the alias target and no TTL or values."
  }

  assert {
    condition     = aws_route53_health_check.this["web"].fqdn == "www.example.com"
    error_message = "Each health check should probe the name it was given."
  }
}

run "plans_a_private_zone_with_plain_records" {
  command = plan

  variables {
    name            = "internal.example.com"
    private_vpc_ids = ["vpc-0aaaaaaaaaaaaaaa1"]
    records         = { db = { name = "db.internal.example.com", type = "CNAME", records = ["db.example-cluster.us-east-1.rds.amazonaws.com"] } }
  }

  assert {
    condition     = [for vpc in aws_route53_zone.this.vpc : vpc.vpc_id] == ["vpc-0aaaaaaaaaaaaaaa1"]
    error_message = "A zone given VPCs should be private to them."
  }

  assert {
    condition     = aws_route53_record.this["db"].ttl == 300 && aws_route53_record.this["db"].records == toset(["db.example-cluster.us-east-1.rds.amazonaws.com"]) && length(aws_route53_record.this["db"].alias) == 0
    error_message = "A plain record should carry its values and the default TTL, with no alias."
  }
}

run "refuses_query_logging_on_a_private_zone" {
  command = plan

  variables {
    name                 = "internal.example.com"
    private_vpc_ids      = ["vpc-0aaaaaaaaaaaaaaa1"]
    enable_query_logging = true
    query_log_group_arn  = "arn:aws:logs:us-east-1:123456789012:log-group:/aws/route53/internal.example.com"
  }

  expect_failures = [aws_route53_zone.this]
}
