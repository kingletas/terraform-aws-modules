# Plans the example against mock providers: every expression is evaluated with
# real values, which is what terraform validate does not do. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

mock_provider "aws" {
  alias  = "us_east_1"
  source = "../../testing/mocks"
}

mock_provider "local" {}
mock_provider "random" {}

run "plans_with_real_values" {
  command = plan

  # The real provider derives these from the domain during plan; a mock cannot.
  override_resource {
    override_during = plan
    target          = module.certificate.aws_acm_certificate.this
    values = {
      arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
      domain_validation_options = [{
        domain_name           = "shop.example.com"
        resource_record_name  = "_0123456789abcdef.shop.example.com."
        resource_record_type  = "CNAME"
        resource_record_value = "_fedcba9876543210.acm-validations.aws."
      }]
    }
  }

  # The real provider derives these from the domain during plan; a mock cannot.
  override_resource {
    override_during = plan
    target          = module.origin_certificate.aws_acm_certificate.this
    values = {
      arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
      domain_validation_options = [{
        domain_name           = "origin.shop.example.com"
        resource_record_name  = "_0123456789abcdef.origin.shop.example.com."
        resource_record_type  = "CNAME"
        resource_record_value = "_fedcba9876543210.acm-validations.aws."
      }]
    }
  }

  # A mock invents a random string where a prefix list ID belongs.
  override_data {
    target = data.aws_ec2_managed_prefix_list.cloudfront_origin
    values = {
      id = "pl-3b927c52"
    }
  }

  variables {
    domain_name      = "shop.example.com"
    hosted_zone_name = "example.com"
    ami_id           = "ami-0123456789abcdef0"
  }

  assert {
    condition     = local.origin_default_response.status_code == 403
    error_message = "A request that matches no listener rule must get a 403, not reach the web tier."
  }

  assert {
    condition     = keys(local.origin_listener_rules["from_cloudfront"].http_headers) == [local.origin_verify_header] && local.origin_listener_rules["from_cloudfront"].target_group == "web"
    error_message = "The web tier may be reached only through a rule requiring the origin verify header."
  }

  assert {
    condition     = local.alb_ingress_rules["https"].prefix_list_id == "pl-3b927c52" && lookup(local.alb_ingress_rules["https"], "cidr_ipv4", null) == null
    error_message = "HTTPS to the load balancer must be limited to CloudFront's origin-facing prefix list."
  }

  assert {
    condition     = alltrue([for rule in values(local.alb_ingress_rules) : lookup(rule, "cidr_ipv4", null) == null && rule.from_port != 80])
    error_message = "Nothing may reach the load balancer from the whole internet, and port 80 must stay closed."
  }

  assert {
    condition     = module.alb.http_listener_arn == null
    error_message = "The load balancer must have no port 80 listener, since nothing can reach port 80."
  }

  assert {
    condition     = toset(local.alert_publishers) == toset(["cloudwatch.amazonaws.com", "backup.amazonaws.com"])
    error_message = "The alert topic must let CloudWatch alarms and AWS Backup publish."
  }

  assert {
    condition = alltrue([
      for key in ["MAGENTO_DB_SECRET_ARN", "MAGENTO_REDIS_AUTH_PARAMETER", "MAGENTO_SEARCH_PASSWORD_PARAMETER"] : contains(keys(local.node_environment), key)
    ])
    error_message = "The node environment file must name every credential a node reads."
  }

  assert {
    condition     = toset(keys(module.service_credentials.names)) == toset(["/storefront-staging/cache/auth-token", "/storefront-staging/search/master-password"])
    error_message = "The Valkey token and the OpenSearch master password must each be stored in a parameter."
  }

}

# Production turns on multi-AZ, replicas and the builder node, which staging never plans.
run "plans_production_defaults" {
  command = plan

  # The real provider derives these from the domain during plan; a mock cannot.
  override_resource {
    override_during = plan
    target          = module.certificate.aws_acm_certificate.this
    values = {
      arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
      domain_validation_options = [{
        domain_name           = "shop.example.com"
        resource_record_name  = "_0123456789abcdef.shop.example.com."
        resource_record_type  = "CNAME"
        resource_record_value = "_fedcba9876543210.acm-validations.aws."
      }]
    }
  }

  # The real provider derives these from the domain during plan; a mock cannot.
  override_resource {
    override_during = plan
    target          = module.origin_certificate.aws_acm_certificate.this
    values = {
      arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
      domain_validation_options = [{
        domain_name           = "origin.shop.example.com"
        resource_record_name  = "_0123456789abcdef.origin.shop.example.com."
        resource_record_type  = "CNAME"
        resource_record_value = "_fedcba9876543210.acm-validations.aws."
      }]
    }
  }

  # A mock invents a random string where a prefix list ID belongs.
  override_data {
    target = data.aws_ec2_managed_prefix_list.cloudfront_origin
    values = {
      id = "pl-3b927c52"
    }
  }

  variables {
    domain_name      = "shop.example.com"
    hosted_zone_name = "example.com"
    ami_id           = "ami-0123456789abcdef0"
    environment      = "production"
    include_builder  = true
  }
}
