variable "name" {
  type        = string
  description = "Dashboard name."
}

variable "widgets" {
  type = list(object({
    type   = optional(string, "metric")
    title  = optional(string)
    width  = optional(number, 12)
    height = optional(number, 6)
    x      = optional(number)
    y      = optional(number)

    # A JSON-encoded CloudWatch metric array, from jsonencode in the caller.
    # The array is heterogeneous by design (dimension pairs as strings, then an
    # optional options object overriding stat or colour for that one line), and
    # no Terraform object type can hold that alongside the rest of a widget.
    metrics_json = optional(string)
    view         = optional(string, "timeSeries")
    stacked      = optional(bool, false)
    stat         = optional(string, "Average")
    period       = optional(number, 300)
    region       = optional(string)

    yaxis_left_min = optional(number)
    yaxis_left_max = optional(number)

    annotations_horizontal = optional(list(object({
      value = number
      label = optional(string)
      color = optional(string)
    })))

    markdown = optional(string)

    log_query = optional(string)
  }))
  description = "Widgets in reading order. Leave x and y unset and CloudWatch places them left to right, wrapping at 24 columns. Set both to place a widget yourself."

  validation {
    condition     = alltrue([for widget in var.widgets : widget.width >= 1 && widget.width <= 24])
    error_message = "A widget width must be between 1 and 24, which is the grid width."
  }

  validation {
    condition     = alltrue([for widget in var.widgets : (widget.x == null) == (widget.y == null)])
    error_message = "Set both x and y on a widget, or neither."
  }

  validation {
    condition     = alltrue([for widget in var.widgets : widget.x == null || (coalesce(widget.x, 0) >= 0 && coalesce(widget.x, 0) + widget.width <= 24)])
    error_message = "A placed widget must fit the grid: x is at least 0 and x plus width is at most 24."
  }
}

variable "default_region" {
  type        = string
  description = "Region a widget reads metrics from when it names none. Null uses the provider's region."
  default     = null
}

variable "default_period" {
  type        = number
  description = "Aggregation period in seconds for widgets that name none."
  default     = 300
}
