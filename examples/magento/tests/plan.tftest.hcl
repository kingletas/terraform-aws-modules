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

  variables {
    domain_name      = "shop.example.com"
    hosted_zone_name = "example.com"
    ami_id           = "ami-0123456789abcdef0"
  }
}
