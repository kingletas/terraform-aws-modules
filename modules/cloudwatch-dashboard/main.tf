data "aws_region" "current" {}

locals {
  region = coalesce(var.default_region, data.aws_region.current.region)

  # Lay widgets out left to right, wrapping at the 24-column grid, unless the caller placed them.
  positions = { for index, widget in var.widgets : index => {
    x = widget.x != null ? widget.x : sum(concat([0], [
      for earlier_index, earlier in var.widgets :
      earlier.width if earlier_index < index
    ])) % 24
  } }

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
      "{\"type\":%s,\"width\":%d,\"height\":%d,\"x\":%d%s,\"properties\":%s}",
      jsonencode(widget.type),
      widget.width,
      widget.height,
      local.positions[index].x,
      widget.y == null ? "" : format(",\"y\":%d", widget.y),
      local.properties[index],
    )
  ]

  dashboard_body = format("{\"widgets\":[%s]}", join(",", local.widget_json))
}

resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = var.name
  dashboard_body = local.dashboard_body
}
