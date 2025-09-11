# CloudWatch Enhanced Monitoring Addon
# Version: v1.0.0
# Purpose: Comprehensive CloudWatch monitoring with enhanced features, custom metrics, and intelligent alerting

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Data sources for existing resources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Enhanced CloudWatch Log Groups with retention and encryption
resource "aws_cloudwatch_log_group" "addon" {
  for_each = var.log_groups

  name              = each.value.name
  retention_in_days = each.value.retention_in_days
  kms_key_id        = each.value.kms_key_id
  skip_destroy      = lookup(each.value, "skip_destroy", false)

  tags = merge(var.common_tags, lookup(each.value, "tags", {}), {
    Name        = each.value.name
    Environment = var.environment
    Module      = "cloudwatch-addon"
    Version     = "v1.0.0"
    Purpose     = lookup(each.value, "purpose", "logging")
  })
}

# Log Streams with auto-creation support
resource "aws_cloudwatch_log_stream" "addon" {
  for_each = var.log_streams

  name           = each.value.name
  log_group_name = each.value.log_group_name

  depends_on = [aws_cloudwatch_log_group.addon]
}

# Enhanced Metric Filters with multiple transformations
resource "aws_cloudwatch_log_metric_filter" "addon" {
  for_each = var.metric_filters

  name           = each.value.name
  log_group_name = each.value.log_group_name
  pattern        = each.value.pattern

  metric_transformation {
    name          = each.value.metric_name
    namespace     = each.value.namespace
    value         = each.value.value
    default_value = lookup(each.value, "default_value", null)
    unit          = lookup(each.value, "unit", "None")
  }

  depends_on = [aws_cloudwatch_log_group.addon]
}

# Advanced Metric Alarms with comprehensive configuration
resource "aws_cloudwatch_metric_alarm" "addon" {
  for_each = var.metric_alarms

  alarm_name          = each.value.alarm_name
  comparison_operator = each.value.comparison_operator
  evaluation_periods  = each.value.evaluation_periods
  threshold           = each.value.threshold
  alarm_description   = each.value.alarm_description
  alarm_actions       = each.value.alarm_actions
  ok_actions          = lookup(each.value, "ok_actions", [])
  treat_missing_data  = lookup(each.value, "treat_missing_data", "missing")
  datapoints_to_alarm = lookup(each.value, "datapoints_to_alarm", null)
  unit                = lookup(each.value, "unit", null)
  actions_enabled     = lookup(each.value, "actions_enabled", true)

  # Simple metric configuration
  metric_name = lookup(each.value, "metric_name", null)
  namespace   = lookup(each.value, "namespace", null)
  period      = lookup(each.value, "period", null)
  statistic   = lookup(each.value, "statistic", null)

  # Dimensions for simple metrics
  dimensions = lookup(each.value, "dimensions", null)

  # Advanced metric queries for complex scenarios
  dynamic "metric_query" {
    for_each = lookup(each.value, "metric_queries", [])
    content {
      id          = metric_query.value.id
      return_data = lookup(metric_query.value, "return_data", false)
      label       = lookup(metric_query.value, "label", null)

      dynamic "metric" {
        for_each = lookup(metric_query.value, "metric", null) != null ? [metric_query.value.metric] : []
        content {
          metric_name = metric.value.metric_name
          namespace   = metric.value.namespace
          period      = metric.value.period
          stat        = metric.value.stat
          unit        = lookup(metric.value, "unit", null)
          dimensions  = lookup(metric.value, "dimensions", null)
        }
      }

      dynamic "expression" {
        for_each = lookup(metric_query.value, "expression", null) != null ? [metric_query.value.expression] : []
        content {
          expression = expression.value
        }
      }
    }
  }

  tags = merge(var.common_tags, lookup(each.value, "tags", {}), {
    Name         = each.value.alarm_name
    Environment  = var.environment
    Module       = "cloudwatch-addon"
    Severity     = lookup(each.value, "severity", "medium")
    AlertType    = lookup(each.value, "alert_type", "metric")
  })
}

# Composite Alarms for complex conditions
resource "aws_cloudwatch_composite_alarm" "addon" {
  for_each = var.composite_alarms

  alarm_name                = each.value.alarm_name
  alarm_description         = each.value.alarm_description
  alarm_rule                = each.value.alarm_rule
  actions_enabled           = lookup(each.value, "actions_enabled", true)
  alarm_actions             = lookup(each.value, "alarm_actions", [])
  ok_actions                = lookup(each.value, "ok_actions", [])
  insufficient_data_actions = lookup(each.value, "insufficient_data_actions", [])

  tags = merge(var.common_tags, lookup(each.value, "tags", {}), {
    Name        = each.value.alarm_name
    Environment = var.environment
    Module      = "cloudwatch-addon"
    AlarmType   = "composite"
  })
}

# Anomaly Detectors for intelligent monitoring
resource "aws_cloudwatch_anomaly_detector" "addon" {
  for_each = var.anomaly_detectors

  metric_name = each.value.metric_name
  namespace   = each.value.namespace
  stat        = each.value.stat
  dimensions  = lookup(each.value, "dimensions", null)

  tags = merge(var.common_tags, lookup(each.value, "tags", {}), {
    Name        = "${each.value.namespace}-${each.value.metric_name}-anomaly"
    Environment = var.environment
    Module      = "cloudwatch-addon"
    Type        = "anomaly-detector"
  })
}

# Anomaly Metric Alarms
resource "aws_cloudwatch_metric_alarm" "anomaly" {
  for_each = var.anomaly_alarms

  alarm_name          = each.value.alarm_name
  comparison_operator = "LessThanLowerOrGreaterThanUpperThreshold"
  evaluation_periods  = each.value.evaluation_periods
  threshold_metric_id = "ad1"
  alarm_description   = each.value.alarm_description
  alarm_actions       = each.value.alarm_actions
  ok_actions          = lookup(each.value, "ok_actions", [])
  treat_missing_data  = lookup(each.value, "treat_missing_data", "breaching")
  datapoints_to_alarm = lookup(each.value, "datapoints_to_alarm", null)

  metric_query {
    id          = "m1"
    return_data = true
    metric {
      metric_name = each.value.metric_name
      namespace   = each.value.namespace
      period      = each.value.period
      stat        = each.value.stat
      dimensions  = lookup(each.value, "dimensions", null)
    }
  }

  metric_query {
    id = "ad1"
    anomaly_detector {
      metric_math_anomaly_detector {
        metric_data_queries {
          id = "m1"
          metric_stat {
            metric {
              metric_name = each.value.metric_name
              namespace   = each.value.namespace
              dimensions  = lookup(each.value, "dimensions", null)
            }
            period = each.value.period
            stat   = each.value.stat
          }
          return_data = true
        }
      }
    }
  }

  tags = merge(var.common_tags, lookup(each.value, "tags", {}), {
    Name        = each.value.alarm_name
    Environment = var.environment
    Module      = "cloudwatch-addon"
    Type        = "anomaly-alarm"
  })

  depends_on = [aws_cloudwatch_anomaly_detector.addon]
}

# Enhanced CloudWatch Dashboards with multiple widgets
resource "aws_cloudwatch_dashboard" "addon" {
  for_each = var.dashboards

  dashboard_name = each.value.dashboard_name
  dashboard_body = jsonencode({
    widgets = each.value.widgets
  })
}

# Custom Metrics for application monitoring
resource "aws_cloudwatch_log_metric_filter" "custom_application_metrics" {
  for_each = var.custom_application_metrics

  name           = each.value.name
  log_group_name = each.value.log_group_name
  pattern        = each.value.pattern

  metric_transformation {
    name          = each.value.metric_name
    namespace     = each.value.namespace
    value         = each.value.value
    default_value = lookup(each.value, "default_value", 0)
    unit          = lookup(each.value, "unit", "Count")
  }
}

# Enhanced SNS Topics for alert routing
resource "aws_sns_topic" "alerts" {
  for_each = var.alert_channels

  name                        = "${var.project_name}-${var.environment}-${each.key}-alerts"
  display_name                = "CloudWatch Alerts - ${title(each.key)}"
  kms_master_key_id          = lookup(each.value, "kms_key_id", null)
  fifo_topic                 = lookup(each.value, "fifo_topic", false)
  content_based_deduplication = lookup(each.value, "content_based_deduplication", false)

  policy = lookup(each.value, "topic_policy", null)

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-${each.key}-alerts"
    Environment = var.environment
    Module      = "cloudwatch-addon"
    AlertType   = each.key
  })
}

# SNS Topic Subscriptions with filtering
resource "aws_sns_topic_subscription" "alerts" {
  for_each = merge([
    for channel_key, channel in var.alert_channels : {
      for sub_key, subscription in lookup(channel, "subscriptions", {}) : 
      "${channel_key}-${sub_key}" => merge(subscription, {
        topic_arn = aws_sns_topic.alerts[channel_key].arn
      })
    }
  ]...)

  topic_arn              = each.value.topic_arn
  protocol               = each.value.protocol
  endpoint               = each.value.endpoint
  filter_policy          = lookup(each.value, "filter_policy", null)
  filter_policy_scope    = lookup(each.value, "filter_policy_scope", "MessageAttributes")
  confirmation_timeout   = lookup(each.value, "confirmation_timeout", 1)
  endpoint_auto_confirms = lookup(each.value, "endpoint_auto_confirms", false)

  depends_on = [aws_sns_topic.alerts]
}

# Application Auto Scaling Integration
resource "aws_appautoscaling_policy" "addon" {
  for_each = var.autoscaling_policies

  name               = each.value.name
  policy_type        = each.value.policy_type
  resource_id        = each.value.resource_id
  scalable_dimension = each.value.scalable_dimension
  service_namespace  = each.value.service_namespace

  # Step Scaling Configuration
  dynamic "step_scaling_policy_configuration" {
    for_each = each.value.policy_type == "StepScaling" ? [each.value.step_scaling_config] : []
    content {
      adjustment_type         = step_scaling_policy_configuration.value.adjustment_type
      cooldown               = lookup(step_scaling_policy_configuration.value, "cooldown", 300)
      metric_aggregation_type = lookup(step_scaling_policy_configuration.value, "metric_aggregation_type", "Average")

      dynamic "step_adjustment" {
        for_each = step_scaling_policy_configuration.value.step_adjustments
        content {
          metric_interval_lower_bound = lookup(step_adjustment.value, "metric_interval_lower_bound", null)
          metric_interval_upper_bound = lookup(step_adjustment.value, "metric_interval_upper_bound", null)
          scaling_adjustment          = step_adjustment.value.scaling_adjustment
        }
      }
    }
  }

  # Target Tracking Configuration
  dynamic "target_tracking_scaling_policy_configuration" {
    for_each = each.value.policy_type == "TargetTrackingScaling" ? [each.value.target_tracking_config] : []
    content {
      target_value       = target_tracking_scaling_policy_configuration.value.target_value
      scale_in_cooldown  = lookup(target_tracking_scaling_policy_configuration.value, "scale_in_cooldown", 300)
      scale_out_cooldown = lookup(target_tracking_scaling_policy_configuration.value, "scale_out_cooldown", 300)

      dynamic "predefined_metric_specification" {
        for_each = lookup(target_tracking_scaling_policy_configuration.value, "predefined_metric_type", null) != null ? [1] : []
        content {
          predefined_metric_type = target_tracking_scaling_policy_configuration.value.predefined_metric_type
          resource_label         = lookup(target_tracking_scaling_policy_configuration.value, "resource_label", null)
        }
      }

      dynamic "customized_metric_specification" {
        for_each = lookup(target_tracking_scaling_policy_configuration.value, "custom_metric", null) != null ? [target_tracking_scaling_policy_configuration.value.custom_metric] : []
        content {
          metric_name = customized_metric_specification.value.metric_name
          namespace   = customized_metric_specification.value.namespace
          statistic   = customized_metric_specification.value.statistic
          unit        = lookup(customized_metric_specification.value, "unit", null)
          dimensions  = lookup(customized_metric_specification.value, "dimensions", null)
        }
      }
    }
  }
}

# EventBridge Rules for advanced event handling
resource "aws_cloudwatch_event_rule" "addon" {
  for_each = var.event_rules

  name           = each.value.name
  description    = each.value.description
  event_pattern  = lookup(each.value, "event_pattern", null)
  schedule_expression = lookup(each.value, "schedule_expression", null)
  state          = lookup(each.value, "state", "ENABLED")

  tags = merge(var.common_tags, lookup(each.value, "tags", {}), {
    Name        = each.value.name
    Environment = var.environment
    Module      = "cloudwatch-addon"
    Type        = "event-rule"
  })
}

# EventBridge Targets
resource "aws_cloudwatch_event_target" "addon" {
  for_each = var.event_rules

  rule      = aws_cloudwatch_event_rule.addon[each.key].name
  target_id = each.value.target_id
  arn       = each.value.target_arn
  role_arn  = lookup(each.value, "role_arn", null)

  dynamic "input_transformer" {
    for_each = lookup(each.value, "input_transformer", null) != null ? [each.value.input_transformer] : []
    content {
      input_paths    = lookup(input_transformer.value, "input_paths", null)
      input_template = input_transformer.value.input_template
    }
  }

  dynamic "retry_policy" {
    for_each = lookup(each.value, "retry_policy", null) != null ? [each.value.retry_policy] : []
    content {
      maximum_event_age       = lookup(retry_policy.value, "maximum_event_age", 86400)
      maximum_retry_attempts  = lookup(retry_policy.value, "maximum_retry_attempts", 185)
    }
  }

  dynamic "dead_letter_config" {
    for_each = lookup(each.value, "dead_letter_config", null) != null ? [each.value.dead_letter_config] : []
    content {
      arn = dead_letter_config.value.arn
    }
  }
}

# CloudWatch Insights Queries for log analysis
resource "aws_cloudwatch_query_definition" "addon" {
  for_each = var.insights_queries

  name            = each.value.name
  log_group_names = each.value.log_group_names
  query_string    = each.value.query_string
}

# Synthetics Canaries for endpoint monitoring
resource "aws_synthetics_canary" "addon" {
  for_each = var.synthetics_canaries

  name                 = each.value.name
  artifact_s3_location = each.value.artifact_s3_location
  execution_role_arn   = each.value.execution_role_arn
  handler              = each.value.handler
  zip_file             = each.value.zip_file
  runtime_version      = each.value.runtime_version
  start_canary         = lookup(each.value, "start_canary", true)
  success_retention_period = lookup(each.value, "success_retention_period", 2)
  failure_retention_period = lookup(each.value, "failure_retention_period", 14)

  schedule {
    expression                = each.value.schedule_expression
    duration_in_seconds       = lookup(each.value, "duration_in_seconds", 0)
  }

  dynamic "run_config" {
    for_each = lookup(each.value, "run_config", null) != null ? [each.value.run_config] : []
    content {
      timeout_in_seconds    = lookup(run_config.value, "timeout_in_seconds", 60)
      memory_in_mb         = lookup(run_config.value, "memory_in_mb", 960)
      active_tracing       = lookup(run_config.value, "active_tracing", false)
      environment_variables = lookup(run_config.value, "environment_variables", null)
    }
  }

  dynamic "vpc_config" {
    for_each = lookup(each.value, "vpc_config", null) != null ? [each.value.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  tags = merge(var.common_tags, lookup(each.value, "tags", {}), {
    Name        = each.value.name
    Environment = var.environment
    Module      = "cloudwatch-addon"
    Type        = "synthetics-canary"
  })
}

# Container Insights for ECS/EKS monitoring
resource "aws_ecs_cluster_capacity_providers" "insights" {
  for_each = var.enable_container_insights ? var.container_insights_clusters : {}

  cluster_name = each.value.cluster_name
  capacity_providers = each.value.capacity_providers

  default_capacity_provider_strategy {
    base              = lookup(each.value, "base", 0)
    weight            = lookup(each.value, "weight", 1)
    capacity_provider = each.value.default_capacity_provider
  }
}

# X-Ray Tracing Integration
resource "aws_xray_sampling_rule" "addon" {
  for_each = var.xray_sampling_rules

  rule_name      = each.value.rule_name
  priority       = each.value.priority
  version        = lookup(each.value, "version", 1)
  reservoir_size = each.value.reservoir_size
  fixed_rate     = each.value.fixed_rate
  url_path       = each.value.url_path
  host           = each.value.host
  http_method    = each.value.http_method
  service_name   = each.value.service_name
  service_type   = each.value.service_type
  resource_arn   = each.value.resource_arn
  attributes     = lookup(each.value, "attributes", {})

  tags = merge(var.common_tags, {
    Name        = each.value.rule_name
    Environment = var.environment
    Module      = "cloudwatch-addon"
    Type        = "xray-sampling"
  })
}