data "aws_region" "current" {}

data "aws_partition" "current" {}

locals {
  region = coalesce(var.default_region, data.aws_region.current.region)

  # The console has its own hostname in each partition, and none in a partition not listed here.
  console_hosts = {
    aws        = "console.aws.amazon.com"
    aws-cn     = "console.amazonaws.cn"
    aws-us-gov = "console.amazonaws-us-gov.com"
  }
  console_host = lookup(local.console_hosts, data.aws_partition.current.partition, null)

  # Each widget type has a differently shaped properties object, and any step that
  # makes them share a type fails to evaluate or coerces numbers to strings. So the
  # JSON is built from fragments, each encoded on its own, and absent keys are dropped.
  properties = [
    for widget in var.widgets : format("{%s}", join(",", compact(
      widget.type == "text" ? [
        format("\"markdown\":%s", jsonencode(widget.markdown == null ? "" : widget.markdown)),
      ]
      : widget.type == "log" ? [
        format("\"query\":%s", jsonencode(widget.log_query == null ? "" : widget.log_query)),
        format("\"region\":%s", jsonencode(coalesce(widget.region, local.region))),
        format("\"view\":%s", jsonencode("table")),
        widget.title == null ? "" : format("\"title\":%s", jsonencode(widget.title)),
      ]
      : [
        format("\"metrics\":%s", coalesce(widget.metrics_json, "[]")),
        format("\"view\":%s", jsonencode(widget.view)),
        format("\"stacked\":%s", jsonencode(widget.stacked)),
        format("\"stat\":%s", jsonencode(widget.stat)),
        format("\"period\":%s", jsonencode(coalesce(widget.period, var.default_period))),
        format("\"region\":%s", jsonencode(coalesce(widget.region, local.region))),
        widget.title == null ? "" : format("\"title\":%s", jsonencode(widget.title)),
        widget.yaxis_left_min == null && widget.yaxis_left_max == null ? "" : format("\"yAxis\":%s", jsonencode({
          left = { for bound, value in { min = widget.yaxis_left_min, max = widget.yaxis_left_max } : bound => value if value != null }
        })),
        widget.annotations_horizontal == null ? "" : format("\"annotations\":%s", jsonencode({
          horizontal = widget.annotations_horizontal
        })),
      ]
    )))
  ]

  widget_json = [
    for index, widget in var.widgets : format(
      "{\"type\":%s,\"width\":%d,\"height\":%d%s,\"properties\":%s}",
      jsonencode(widget.type),
      widget.width,
      widget.height,
      # An unplaced widget omits both coordinates, and CloudWatch flows it into the next free position, wrapping at 24 columns.
      widget.x == null ? "" : format(",\"x\":%d,\"y\":%d", widget.x, widget.y),
      local.properties[index],
    )
  ]

  dashboard_body = format("{\"widgets\":[%s]}", join(",", local.widget_json))
}

resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = var.name
  dashboard_body = local.dashboard_body
}
