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
    condition     = module.alb.https_listener_default_action == { type = "fixed-response", status_code = 403 }
    error_message = "A request that matches no listener rule must get a 403, not reach the web tier."
  }

  assert {
    condition = (
      [for name, rule in module.alb.listener_rules : name if rule.action == "forward"] == ["from_cloudfront"]
      && module.alb.listener_rules["from_cloudfront"].target_group == "web"
      && module.alb.listener_rules["from_cloudfront"].http_headers == toset(["X-Origin-Verify"])
    )
    error_message = "The web tier may be reached only through a rule requiring the X-Origin-Verify header."
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
    condition     = toset(values(module.service_credentials.names)) == toset(["/storefront-staging/cache/auth-token", "/storefront-staging/search/master-password"])
    error_message = "The Valkey token and the OpenSearch master password must each be stored in a parameter."
  }

  # The keys are what a moved block has to name, so they must not carry the environment.
  assert {
    condition     = toset(keys(module.service_credentials.names)) == toset(["cache/auth-token", "search/master-password"])
    error_message = "Each credential parameter must be addressed by a short name that does not change with the environment."
  }

  assert {
    condition     = local.static_assets_kms_key_arn == null
    error_message = "The public static bucket must use SSE-S3, or CloudFront cannot decrypt what it serves and every /static/* request is a 403."
  }

  assert {
    condition     = toset(flatten([for statement in data.aws_iam_policy_document.node.statement : statement.actions if statement.sid == "ReadStaticAssets"])) == toset(["s3:GetObject", "s3:ListBucket"])
    error_message = "Web, cron and admin nodes may only read the static bucket."
  }

  assert {
    condition     = alltrue([for statement in data.aws_iam_policy_document.node.statement : length(setintersection(toset(statement.actions), toset(["s3:PutObject", "s3:DeleteObject"]))) == 0])
    error_message = "The shared node role may write and delete in no bucket: Ansible's transfers use presigned URLs from the controller."
  }

  assert {
    condition     = length(module.builder_role) == 0
    error_message = "Without a builder node there is no role that publishes static assets."
  }

  assert {
    condition     = length(data.aws_elb_service_account.current) == 1 && toset([for statement in data.aws_iam_policy_document.alb_logs.statement : statement.sid]) == toset(["AllowLoadBalancerLogDelivery", "AllowRegionalLoadBalancerAccountLogDelivery"])
    error_message = "In us-east-1 the log bucket must admit both the regional ELB account and the log delivery service principal."
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

  assert {
    condition     = length(module.builder_role) == 1 && toset(one([for statement in data.aws_iam_policy_document.publish_static.statement : statement.actions if statement.sid == "PublishStaticAssets"])) == toset(["s3:PutObject", "s3:DeleteObject"])
    error_message = "The builder node's role must be the one that publishes static assets."
  }
}

# A region opened after August 2022 has no ELB account, so log delivery rests on the service principal alone.
run "plans_in_a_region_without_an_elb_account" {
  command = plan

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

  override_resource {
    override_during = plan
    target          = module.origin_certificate.aws_acm_certificate.this
    values = {
      arn = "arn:aws:acm:eu-central-2:123456789012:certificate/00000000-0000-0000-0000-000000000000"
      domain_validation_options = [{
        domain_name           = "origin.shop.example.com"
        resource_record_name  = "_0123456789abcdef.origin.shop.example.com."
        resource_record_type  = "CNAME"
        resource_record_value = "_fedcba9876543210.acm-validations.aws."
      }]
    }
  }

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
    region           = "eu-central-2"
  }

  assert {
    condition     = length(data.aws_elb_service_account.current) == 0 && [for statement in data.aws_iam_policy_document.alb_logs.statement : statement.sid] == ["AllowLoadBalancerLogDelivery"]
    error_message = "Where no ELB account exists, log delivery must be granted to the service principal only."
  }
}
