# CloudWatch Monitoring Terraform Module

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "main" {
  for_each = var.log_groups

  name              = each.value.name
  retention_in_days = each.value.retention_in_days
  kms_key_id        = each.value.kms_key_id

  tags = merge(var.tags, each.value.tags, {
    Name        = each.value.name
    Environment = var.environment
    Module      = "cloudwatch-monitoring"
  })
}

# CloudWatch Log Streams
resource "aws_cloudwatch_log_stream" "main" {
  for_each = var.log_streams

  name           = each.value.name
  log_group_name = aws_cloudwatch_log_group.main[each.value.log_group_key].name

  depends_on = [aws_cloudwatch_log_group.main]
}

# CloudWatch Metric Filters
resource "aws_cloudwatch_log_metric_filter" "main" {
  for_each = var.metric_filters

  name           = each.value.name
  log_group_name = aws_cloudwatch_log_group.main[each.value.log_group_key].name
  pattern        = each.value.pattern

  metric_transformation {
    name          = each.value.metric_name
    namespace     = each.value.namespace
    value         = each.value.value
    default_value = each.value.default_value
    unit          = each.value.unit
  }

  depends_on = [aws_cloudwatch_log_group.main]
}

# CloudWatch Metric Alarms
resource "aws_cloudwatch_metric_alarm" "main" {
  for_each = var.metric_alarms

  alarm_name          = each.value.alarm_name
  comparison_operator = each.value.comparison_operator
  evaluation_periods  = each.value.evaluation_periods
  metric_name         = each.value.metric_name
  namespace           = each.value.namespace
  period              = each.value.period
  statistic           = each.value.statistic
  threshold           = each.value.threshold
  alarm_description   = each.value.alarm_description
  alarm_actions       = each.value.alarm_actions
  ok_actions         = each.value.ok_actions
  datapoints_to_alarm = each.value.datapoints_to_alarm
  treat_missing_data  = each.value.treat_missing_data
  unit               = each.value.unit

  dynamic "dimensions" {
    for_each = each.value.dimensions != null ? [1] : []
    content {
      for key, value in each.value.dimensions : key => value
    }
  }

  dynamic "metric_query" {
    for_each = each.value.metric_queries != null ? each.value.metric_queries : []
    content {
      id          = metric_query.value.id
      return_data = metric_query.value.return_data
      label       = metric_query.value.label

      dynamic "metric" {
        for_each = metric_query.value.metric != null ? [1] : []
        content {
          metric_name = metric_query.value.metric.metric_name
          namespace   = metric_query.value.metric.namespace
          period      = metric_query.value.metric.period
          stat        = metric_query.value.metric.stat
          unit        = metric_query.value.metric.unit

          dynamic "dimensions" {
            for_each = metric_query.value.metric.dimensions != null ? [1] : []
            content {
              for key, value in metric_query.value.metric.dimensions : key => value
            }
          }
        }
      }

      dynamic "expression" {
        for_each = metric_query.value.expression != null ? [1] : []
        content {
          expression = metric_query.value.expression
        }
      }
    }
  }

  tags = merge(var.tags, each.value.tags, {
    Name        = each.value.alarm_name
    Environment = var.environment
    Module      = "cloudwatch-monitoring"
  })
}

# CloudWatch Composite Alarms
resource "aws_cloudwatch_composite_alarm" "main" {
  for_each = var.composite_alarms

  alarm_name                = each.value.alarm_name
  alarm_description         = each.value.alarm_description
  alarm_rule                = each.value.alarm_rule
  actions_enabled           = each.value.actions_enabled
  alarm_actions            = each.value.alarm_actions
  ok_actions               = each.value.ok_actions
  insufficient_data_actions = each.value.insufficient_data_actions

  tags = merge(var.tags, each.value.tags, {
    Name        = each.value.alarm_name
    Environment = var.environment
    Module      = "cloudwatch-monitoring"
  })
}

# CloudWatch Anomaly Detectors
resource "aws_cloudwatch_anomaly_detector" "main" {
  for_each = var.anomaly_detectors

  metric_name = each.value.metric_name
  namespace   = each.value.namespace
  stat        = each.value.stat

  dynamic "dimensions" {
    for_each = each.value.dimensions != null ? [1] : []
    content {
      for key, value in each.value.dimensions : key => value
    }
  }

  tags = merge(var.tags, each.value.tags, {
    Name        = "${each.value.namespace}-${each.value.metric_name}-anomaly-detector"
    Environment = var.environment
    Module      = "cloudwatch-monitoring"
  })
}

# CloudWatch Anomaly Metric Alarms
resource "aws_cloudwatch_metric_alarm" "anomaly" {
  for_each = var.anomaly_alarms

  alarm_name          = each.value.alarm_name
  comparison_operator = "LessThanLowerOrGreaterThanUpperThreshold"
  evaluation_periods  = each.value.evaluation_periods
  threshold_metric_id = "ad1"
  alarm_description   = each.value.alarm_description
  alarm_actions       = each.value.alarm_actions
  ok_actions         = each.value.ok_actions
  treat_missing_data  = each.value.treat_missing_data

  metric_query {
    id          = "m1"
    return_data = true
    metric {
      metric_name = each.value.metric_name
      namespace   = each.value.namespace
      period      = each.value.period
      stat        = each.value.stat

      dynamic "dimensions" {
        for_each = each.value.dimensions != null ? [1] : []
        content {
          for key, value in each.value.dimensions : key => value
        }
      }
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
              dimensions  = each.value.dimensions
            }
            period = each.value.period
            stat   = each.value.stat
          }
          return_data = true
        }
      }
    }
  }

  tags = merge(var.tags, each.value.tags, {
    Name        = each.value.alarm_name
    Environment = var.environment
    Module      = "cloudwatch-monitoring"
  })

  depends_on = [aws_cloudwatch_anomaly_detector.main]
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  for_each = var.dashboards

  dashboard_name = each.value.dashboard_name
  dashboard_body = jsonencode({
    widgets = each.value.widgets
  })
}

# SNS Topics for Notifications (Optional)
resource "aws_sns_topic" "alerts" {
  count = var.create_sns_topic ? 1 : 0

  name         = "${var.project_name}-${var.environment}-cloudwatch-alerts"
  display_name = "CloudWatch Alerts for ${var.project_name}"

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-cloudwatch-alerts"
    Environment = var.environment
    Module      = "cloudwatch-monitoring"
  })
}

# SNS Topic Subscriptions
resource "aws_sns_topic_subscription" "alerts" {
  for_each = var.create_sns_topic ? var.sns_subscriptions : {}

  topic_arn = aws_sns_topic.alerts[0].arn
  protocol  = each.value.protocol
  endpoint  = each.value.endpoint

  depends_on = [aws_sns_topic.alerts]
}

# Application Auto Scaling Policy Integration
resource "aws_appautoscaling_policy" "scale_up" {
  for_each = var.autoscaling_policies

  name               = each.value.name
  policy_type        = each.value.policy_type
  resource_id        = each.value.resource_id
  scalable_dimension = each.value.scalable_dimension
  service_namespace  = each.value.service_namespace

  dynamic "step_scaling_policy_configuration" {
    for_each = each.value.policy_type == "StepScaling" ? [1] : []
    content {
      adjustment_type         = each.value.step_scaling_config.adjustment_type
      cooldown               = each.value.step_scaling_config.cooldown
      metric_aggregation_type = each.value.step_scaling_config.metric_aggregation_type

      dynamic "step_adjustment" {
        for_each = each.value.step_scaling_config.step_adjustments
        content {
          metric_interval_lower_bound = step_adjustment.value.metric_interval_lower_bound
          metric_interval_upper_bound = step_adjustment.value.metric_interval_upper_bound
          scaling_adjustment          = step_adjustment.value.scaling_adjustment
        }
      }
    }
  }

  dynamic "target_tracking_scaling_policy_configuration" {
    for_each = each.value.policy_type == "TargetTrackingScaling" ? [1] : []
    content {
      target_value       = each.value.target_tracking_config.target_value
      scale_in_cooldown  = each.value.target_tracking_config.scale_in_cooldown
      scale_out_cooldown = each.value.target_tracking_config.scale_out_cooldown

      dynamic "predefined_metric_specification" {
        for_each = each.value.target_tracking_config.predefined_metric_type != null ? [1] : []
        content {
          predefined_metric_type = each.value.target_tracking_config.predefined_metric_type
          resource_label         = each.value.target_tracking_config.resource_label
        }
      }

      dynamic "customized_metric_specification" {
        for_each = each.value.target_tracking_config.custom_metric != null ? [1] : []
        content {
          metric_name = each.value.target_tracking_config.custom_metric.metric_name
          namespace   = each.value.target_tracking_config.custom_metric.namespace
          statistic   = each.value.target_tracking_config.custom_metric.statistic
          unit        = each.value.target_tracking_config.custom_metric.unit

          dynamic "dimensions" {
            for_each = each.value.target_tracking_config.custom_metric.dimensions != null ? [1] : []
            content {
              for key, value in each.value.target_tracking_config.custom_metric.dimensions : key => value
            }
          }
        }
      }
    }
  }
}

# CloudWatch Event Rules for Auto Scaling
resource "aws_cloudwatch_event_rule" "autoscaling" {
  for_each = var.autoscaling_event_rules

  name        = each.value.name
  description = each.value.description

  event_pattern = jsonencode({
    source      = each.value.source
    detail-type = each.value.detail_type
    detail      = each.value.detail
  })

  tags = merge(var.tags, each.value.tags, {
    Name        = each.value.name
    Environment = var.environment
    Module      = "cloudwatch-monitoring"
  })
}

# CloudWatch Event Targets
resource "aws_cloudwatch_event_target" "autoscaling" {
  for_each = var.autoscaling_event_rules

  rule      = aws_cloudwatch_event_rule.autoscaling[each.key].name
  target_id = each.value.target_id
  arn       = each.value.target_arn
  role_arn  = each.value.role_arn

  dynamic "input_transformer" {
    for_each = each.value.input_transformer != null ? [1] : []
    content {
      input_paths    = each.value.input_transformer.input_paths
      input_template = each.value.input_transformer.input_template
    }
  }
}