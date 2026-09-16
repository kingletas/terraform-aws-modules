# Plans the example against mock providers: every expression is evaluated with
# real values, which is what terraform validate does not do. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

mock_provider "aws" {
  alias  = "us_east_1"
  source = "../../testing/mocks"
}

run "plans_with_real_values" {
  command = plan

  # The real provider derives these from the domain during plan; a mock cannot.
  override_resource {
    override_during = plan
    target          = module.certificate.aws_acm_certificate.this
    values = {
      arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
      domain_validation_options = [{
        domain_name           = "www.example.com"
        resource_record_name  = "_0123456789abcdef.www.example.com."
        resource_record_type  = "CNAME"
        resource_record_value = "_fedcba9876543210.acm-validations.aws."
      }]
    }
  }

  variables {
    domain_name        = "www.example.com"
    hosted_zone_name   = "example.com"
    additional_domains = ["example.com"]
  }

  assert {
    condition     = toset(keys(aws_route53_record.site)) == toset(["www.example.com", "example.com"])
    error_message = "Every domain the distribution answers for must get an alias record."
  }

  assert {
    condition     = toset(flatten([for principal in data.aws_iam_policy_document.content.statement[0].principals : principal.identifiers])) == toset(["cloudfront.amazonaws.com"]) && data.aws_iam_policy_document.content.statement[0].actions == toset(["s3:GetObject"])
    error_message = "The content bucket must let CloudFront read objects and do nothing else."
  }

  assert {
    condition     = one([for condition in data.aws_iam_policy_document.content.statement[0].condition : condition.variable]) == "AWS:SourceArn"
    error_message = "CloudFront's read must be limited to this distribution by AWS:SourceArn, or any distribution could serve the bucket."
  }
}
