locals {
  metric_name = replace(var.name, "-", "")
  tags        = merge(var.tags, { Name = var.name })
}

resource "aws_wafv2_web_acl" "this" {
  name        = var.name
  description = var.description
  scope       = var.scope

  default_action {
    dynamic "allow" {
      for_each = var.default_action == "allow" ? [1] : []
      content {}
    }

    dynamic "block" {
      for_each = var.default_action == "block" ? [1] : []
      content {}
    }
  }

  dynamic "rule" {
    for_each = var.ip_allow_lists

    content {
      name     = format("allow-%s", rule.key)
      priority = rule.value.priority

      action {
        allow {}
      }

      statement {
        ip_set_reference_statement {
          arn = rule.value.arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = format("%sAllow%s", local.metric_name, title(replace(rule.key, "-", "")))
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = var.ip_block_lists

    content {
      name     = format("block-%s", rule.key)
      priority = rule.value.priority

      action {
        block {}
      }

      statement {
        ip_set_reference_statement {
          arn = rule.value.arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = format("%sBlock%s", local.metric_name, title(replace(rule.key, "-", "")))
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = var.managed_rule_groups

    content {
      name     = rule.key
      priority = rule.value.priority

      # A managed group carries its own actions, so the rule either defers to them or counts everything.
      dynamic "override_action" {
        for_each = rule.value.count_only ? [1] : []

        content {
          count {}
        }
      }

      dynamic "override_action" {
        for_each = rule.value.count_only ? [] : [1]

        content {
          none {}
        }
      }

      statement {
        managed_rule_group_statement {
          name        = rule.key
          vendor_name = rule.value.vendor_name

          dynamic "rule_action_override" {
            for_each = rule.value.excluded_rules

            content {
              name = rule_action_override.value

              action_to_use {
                count {}
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = replace(rule.key, "-", "")
        sampled_requests_enabled   = true
      }
    }
  }

  dynamic "rule" {
    for_each = var.rate_limits

    content {
      name     = format("rate-%s", rule.key)
      priority = rule.value.priority

      action {
        dynamic "block" {
          for_each = rule.value.action == "block" ? [1] : []
          content {}
        }

        dynamic "count" {
          for_each = rule.value.action == "count" ? [1] : []
          content {}
        }
      }

      statement {
        rate_based_statement {
          limit              = rule.value.limit
          aggregate_key_type = rule.value.aggregate_key_type

          dynamic "scope_down_statement" {
            for_each = rule.value.scope_down_uri_prefix == null ? [] : [rule.value.scope_down_uri_prefix]

            content {
              byte_match_statement {
                positional_constraint = "STARTS_WITH"
                search_string         = scope_down_statement.value

                field_to_match {
                  uri_path {}
                }

                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = format("%sRate%s", local.metric_name, title(replace(rule.key, "-", "")))
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = local.metric_name
    sampled_requests_enabled   = true
  }

  tags = local.tags
}

resource "aws_wafv2_web_acl_logging_configuration" "this" {
  count = length(var.log_destination_arns) > 0 ? 1 : 0

  resource_arn            = aws_wafv2_web_acl.this.arn
  log_destination_configs = var.log_destination_arns

  dynamic "redacted_fields" {
    for_each = var.redacted_header_names

    content {
      single_header {
        name = redacted_fields.value
      }
    }
  }
}

resource "aws_wafv2_web_acl_association" "this" {
  for_each = var.associations

  resource_arn = each.value
  web_acl_arn  = aws_wafv2_web_acl.this.arn
}
