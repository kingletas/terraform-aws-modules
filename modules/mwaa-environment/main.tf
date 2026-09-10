locals {
  tags = merge(var.tags, { Name = var.name })
}

resource "aws_mwaa_environment" "this" {
  # checkov:skip=CKV_AWS_242: scheduler logs enabled by the logging variable default
  # checkov:skip=CKV_AWS_243: worker logs enabled by the logging variable default
  # checkov:skip=CKV_AWS_244: webserver logs enabled by the logging variable default
  name              = var.name
  airflow_version   = var.airflow_version
  environment_class = var.environment_class

  source_bucket_arn = var.source_bucket_arn
  dag_s3_path       = var.dag_s3_path

  requirements_s3_path           = var.requirements_s3_path
  requirements_s3_object_version = var.requirements_s3_object_version
  plugins_s3_path                = var.plugins_s3_path
  plugins_s3_object_version      = var.plugins_s3_object_version
  startup_script_s3_path         = var.startup_script_s3_path

  execution_role_arn = var.execution_role_arn
  kms_key            = var.kms_key_arn

  max_workers = var.max_workers
  min_workers = var.min_workers
  schedulers  = var.schedulers

  webserver_access_mode = var.webserver_access_mode
  endpoint_management   = var.endpoint_management

  airflow_configuration_options   = var.airflow_configuration_options
  weekly_maintenance_window_start = var.weekly_maintenance_window_start

  network_configuration {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  logging_configuration {
    dynamic "dag_processing_logs" {
      for_each = contains(keys(var.logging), "dag_processing") ? [var.logging["dag_processing"]] : []

      content {
        enabled   = dag_processing_logs.value.enabled
        log_level = dag_processing_logs.value.log_level
      }
    }

    dynamic "scheduler_logs" {
      for_each = contains(keys(var.logging), "scheduler") ? [var.logging["scheduler"]] : []

      content {
        enabled   = scheduler_logs.value.enabled
        log_level = scheduler_logs.value.log_level
      }
    }

    dynamic "task_logs" {
      for_each = contains(keys(var.logging), "task") ? [var.logging["task"]] : []

      content {
        enabled   = task_logs.value.enabled
        log_level = task_logs.value.log_level
      }
    }

    dynamic "webserver_logs" {
      for_each = contains(keys(var.logging), "webserver") ? [var.logging["webserver"]] : []

      content {
        enabled   = webserver_logs.value.enabled
        log_level = webserver_logs.value.log_level
      }
    }

    dynamic "worker_logs" {
      for_each = contains(keys(var.logging), "worker") ? [var.logging["worker"]] : []

      content {
        enabled   = worker_logs.value.enabled
        log_level = worker_logs.value.log_level
      }
    }
  }

  tags = local.tags
}
