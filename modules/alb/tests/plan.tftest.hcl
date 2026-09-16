# Plans the module on its own with real values. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

variables {
  vpc_id          = "vpc-0123456789abcdef0"
  subnet_ids      = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]
  certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  target_groups   = { web = { port = 80 } }
}

run "forwards_by_default" {
  command = plan

  variables {
    name                 = "plan-test"
    default_target_group = "web"
  }

  assert {
    condition     = aws_lb_listener.https[0].default_action[0].type == "forward"
    error_message = "With no fixed response the HTTPS listener must forward."
  }
}

run "refuses_requests_without_the_origin_header" {
  command = plan

  variables {
    name                   = "plan-test"
    default_fixed_response = { status_code = 403, message_body = "Forbidden" }

    listener_rules = {
      origin_verify = {
        priority     = 1
        target_group = "web"
        http_headers = { "X-Origin-Verify" = ["plan-test-placeholder-value"] }
      }
    }
  }

  assert {
    condition     = aws_lb_listener.https[0].default_action[0].type == "fixed-response"
    error_message = "The HTTPS listener must answer unmatched requests with the fixed response."
  }

  assert {
    condition     = aws_lb_listener.https[0].default_action[0].fixed_response[0].status_code == "403"
    error_message = "The fixed response must carry the status code asked for."
  }

  assert {
    condition     = [for condition in aws_lb_listener_rule.this["origin_verify"].condition : one(condition.http_header).http_header_name] == ["X-Origin-Verify"]
    error_message = "The rule must match on the origin header."
  }
}

run "accepts_a_fixed_response_with_no_body" {
  command = plan

  variables {
    name                   = "plan-test"
    default_fixed_response = {}
  }

  assert {
    condition     = aws_lb_listener.https[0].default_action[0].fixed_response[0].message_body == null
    error_message = "A fixed response with no body must plan."
  }
}

run "refuses_an_oversized_fixed_response_body" {
  command = plan

  variables {
    name                   = "plan-test"
    default_fixed_response = { message_body = format("%1025s", "x") }
  }

  expect_failures = [var.default_fixed_response]
}

run "names_target_groups_within_limits_and_apart" {
  command = plan

  variables {
    name                 = "a-load-balancer-name-of-32-chars"
    default_target_group = "web"
    target_groups = {
      web                   = { port = 80 }
      "admin-backend_group" = { port = 8080 }
    }
  }

  assert {
    condition = alltrue([
      for tg_name in values(local.target_group_names) :
      length(tg_name) <= 32 && can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]$", tg_name))
    ])
    error_message = "Every target group name must be at most 32 characters of alphanumerics and hyphens, with no hyphen at either end."
  }

  assert {
    condition     = local.target_group_names["web"] != local.target_group_names["admin-backend_group"]
    error_message = "Two target groups sharing a truncated prefix must still get different names."
  }
}

run "renames_a_target_group_that_must_be_replaced" {
  command = plan

  variables {
    name                 = "plan-test"
    default_target_group = "web"
    target_groups        = { web = { port = 8080 } }
  }

  assert {
    condition     = local.target_group_names["web"] != "plan-test-web-${substr(sha1(jsonencode(["web", "vpc-0123456789abcdef0", 80, "HTTP", "HTTP1", "instance"])), 0, 6)}"
    error_message = "A change to a replacement-forcing attribute must change the target group name."
  }
}

run "keys_additional_certificates_by_name" {
  command = plan

  variables {
    name                        = "plan-test"
    default_target_group        = "web"
    additional_certificate_arns = { shop = "arn:aws:acm:us-east-1:123456789012:certificate/11111111-1111-1111-1111-111111111111" }
  }

  assert {
    condition     = keys(aws_lb_listener_certificate.this) == ["shop"]
    error_message = "Extra certificates must be keyed by the caller's names."
  }
}

run "plans_http_only_when_asked" {
  command = plan

  variables {
    name                  = "plan-test"
    default_target_group  = "web"
    create_https_listener = false
    certificate_arn       = null
  }

  assert {
    condition     = length(aws_lb_listener.https) == 0 && aws_lb_listener.http[0].default_action[0].type == "forward"
    error_message = "With HTTPS off, only the HTTP listener exists and it forwards."
  }
}

run "refuses_a_listener_rule_with_no_condition" {
  command = plan

  variables {
    name                 = "plan-test"
    default_target_group = "web"
    listener_rules       = { empty = { priority = 1, target_group = "web" } }
  }

  expect_failures = [var.listener_rules]
}

run "refuses_https_without_a_certificate" {
  command = plan

  variables {
    name                 = "plan-test"
    default_target_group = "web"
    certificate_arn      = null
  }

  expect_failures = [aws_lb.this]
}

run "refuses_no_default_at_all" {
  command = plan

  variables {
    name = "plan-test"
  }

  expect_failures = [aws_lb.this]
}

run "omits_the_http_listener_when_asked" {
  command = plan

  variables {
    name                 = "plan-test"
    default_target_group = "web"
    create_http_listener = false
  }

  assert {
    condition     = length(aws_lb_listener.http) == 0 && length(aws_lb_listener.https) == 1
    error_message = "With create_http_listener off, only the HTTPS listener exists."
  }
}

run "redirects_http_by_default" {
  command = plan

  variables {
    name                 = "plan-test"
    default_target_group = "web"
  }

  assert {
    condition     = aws_lb_listener.http[0].default_action[0].type == "redirect"
    error_message = "By default port 80 must redirect to HTTPS."
  }
}

run "refuses_a_load_balancer_with_no_listener" {
  command = plan

  variables {
    name                  = "plan-test"
    default_target_group  = "web"
    create_https_listener = false
    create_http_listener  = false
    certificate_arn       = null
  }

  expect_failures = [aws_lb.this]
}

run "describes_listener_behaviour_in_outputs" {
  command = plan

  variables {
    name                   = "plan-test"
    default_fixed_response = { status_code = 403 }
    target_groups = {
      web   = { port = 80 }
      admin = { port = 8080 }
    }

    listener_rules = {
      admin = {
        priority      = 10
        target_group  = "admin"
        host_headers  = ["admin.example.com"]
        path_patterns = ["/admin/*"]
      }
      origin_verify = {
        priority     = 20
        target_group = "web"
        http_headers = { "X-Origin-Verify" = ["plan-test-placeholder-value"] }
      }
    }
  }

  assert {
    condition     = output.https_listener_default_action == { type = "fixed-response", status_code = 403 }
    error_message = "The default action output must report the fixed response and its status."
  }

  assert {
    condition     = keys(output.listener_rules) == ["admin", "origin_verify"] && alltrue([for rule in values(output.listener_rules) : rule.action == "forward"])
    error_message = "Every listener rule must be reported by name with its action."
  }

  assert {
    condition = (
      output.listener_rules["admin"].target_group == "admin"
      && output.listener_rules["admin"].host_headers == toset(["admin.example.com"])
      && output.listener_rules["admin"].path_patterns == toset(["/admin/*"])
      && length(output.listener_rules["admin"].http_headers) == 0
    )
    error_message = "A host and path rule must report its target group and both conditions."
  }

  assert {
    condition = (
      output.listener_rules["origin_verify"].target_group == "web"
      && output.listener_rules["origin_verify"].http_headers == toset(["X-Origin-Verify"])
      && length(output.listener_rules["origin_verify"].host_headers) == 0
    )
    error_message = "A header rule must report the header name it requires."
  }
}

run "reports_a_forwarding_default_action_with_no_status" {
  command = plan

  variables {
    name                 = "plan-test"
    default_target_group = "web"
  }

  assert {
    condition     = output.https_listener_default_action == { type = "forward", status_code = null } && length(output.listener_rules) == 0
    error_message = "A forwarding default must report no status code, and no rules must mean an empty map."
  }
}

run "reports_no_default_action_without_https" {
  command = plan

  variables {
    name                  = "plan-test"
    default_target_group  = "web"
    create_https_listener = false
    certificate_arn       = null
  }

  assert {
    condition     = output.https_listener_default_action == null
    error_message = "With HTTPS off the default action output must be null."
  }
}
