locals {
  # production is the environment that gets guards; everything else is disposable.
  is_production = var.environment == "production"

  parts  = compact([var.project, var.environment, var.component])
  prefix = join("-", local.parts)

  # Several AWS resources cap names well below what a prefix can reach, and a
  # few reject hyphens entirely. Both forms are exported rather than left for
  # each caller to work out again.
  short        = substr(local.prefix, 0, 24)
  compact_name = replace(local.prefix, "-", "")

  tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      Owner       = var.owner
      ManagedBy   = "terraform"
    },
    var.component == null ? {} : { Component = var.component },
    var.cost_centre == null ? {} : { CostCentre = var.cost_centre },
    local.is_production ? { Backup = "true" } : {},
    var.extra_tags,
  )

  # Sizing that scales with how much the environment matters. A caller reads
  # these rather than writing another environment-to-instance-type map.
  defaults = {
    dev = {
      multi_az              = false
      deletion_protection   = false
      skip_final_snapshot   = true
      backup_retention_days = 1
      log_retention_days    = 30
      single_nat_gateway    = true
      min_capacity          = 1
      desired_capacity      = 1
      max_capacity          = 2
    }
    staging = {
      multi_az              = false
      deletion_protection   = false
      skip_final_snapshot   = true
      backup_retention_days = 7
      log_retention_days    = 90
      single_nat_gateway    = true
      min_capacity          = 1
      desired_capacity      = 2
      max_capacity          = 4
    }
    uat = {
      multi_az              = false
      deletion_protection   = true
      skip_final_snapshot   = false
      backup_retention_days = 14
      log_retention_days    = 90
      single_nat_gateway    = true
      min_capacity          = 2
      desired_capacity      = 2
      max_capacity          = 4
    }
    production = {
      multi_az              = true
      deletion_protection   = true
      skip_final_snapshot   = false
      backup_retention_days = 30
      log_retention_days    = 365
      single_nat_gateway    = false
      min_capacity          = 2
      desired_capacity      = 3
      max_capacity          = 12
    }
  }
}
