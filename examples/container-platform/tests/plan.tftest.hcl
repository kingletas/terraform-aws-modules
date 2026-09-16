# Plans the example against mock providers: every expression is evaluated with
# real values, which is what terraform validate does not do. Nothing is created.

mock_provider "aws" {
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
        domain_name           = "app.example.com"
        resource_record_name  = "_0123456789abcdef.app.example.com."
        resource_record_type  = "CNAME"
        resource_record_value = "_fedcba9876543210.acm-validations.aws."
      }]
    }
  }

  variables {
    domain_name      = "app.example.com"
    hosted_zone_name = "example.com"
  }

  assert {
    condition = alltrue([
      for service in module.services : anytrue([
        for entry in service.capacity_provider_strategy : entry.capacity_provider == "FARGATE" && entry.base == 1
      ])
    ])
    error_message = "Every service should keep one task on on-demand Fargate."
  }

  assert {
    condition = alltrue([
      for service in module.services : anytrue([
        for entry in service.capacity_provider_strategy : entry.capacity_provider == "FARGATE_SPOT" && entry.weight == 3
      ])
    ])
    error_message = "Every service should place most of its other tasks on Fargate Spot."
  }
}
