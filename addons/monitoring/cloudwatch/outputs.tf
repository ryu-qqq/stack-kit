# CloudWatch Enhanced Monitoring Addon Outputs
# Version: v1.0.0

# Log Groups Outputs
output "log_groups" {
  description = "Created CloudWatch log groups"
  value = {
    for key, log_group in aws_cloudwatch_log_group.addon : key => {
      name              = log_group.name
      arn               = log_group.arn
      retention_in_days = log_group.retention_in_days
      kms_key_id        = log_group.kms_key_id
    }
  }
}

output "log_group_names" {
  description = "List of log group names for easy reference"
  value       = [for log_group in aws_cloudwatch_log_group.addon : log_group.name]
}

output "log_group_arns" {
  description = "List of log group ARNs for IAM policies"
  value       = [for log_group in aws_cloudwatch_log_group.addon : log_group.arn]
}

# Log Streams Outputs
output "log_streams" {
  description = "Created CloudWatch log streams"
  value = {
    for key, stream in aws_cloudwatch_log_stream.addon : key => {
      name           = stream.name
      arn            = stream.arn
      log_group_name = stream.log_group_name
    }
  }
}

# Metric Filters Outputs
output "metric_filters" {
  description = "Created CloudWatch log metric filters"
  value = {
    for key, filter in aws_cloudwatch_log_metric_filter.addon : key => {
      name           = filter.name
      log_group_name = filter.log_group_name
      pattern        = filter.pattern
      metric_name    = filter.metric_transformation[0].name
      namespace      = filter.metric_transformation[0].namespace
    }
  }
}

# Metric Alarms Outputs
output "metric_alarms" {
  description = "Created CloudWatch metric alarms"
  value = {
    for key, alarm in aws_cloudwatch_metric_alarm.addon : key => {
      name                = alarm.alarm_name
      arn                 = alarm.arn
      comparison_operator = alarm.comparison_operator
      evaluation_periods  = alarm.evaluation_periods
      threshold           = alarm.threshold
      alarm_actions       = alarm.alarm_actions
    }
  }
}

output "metric_alarm_arns" {
  description = "List of metric alarm ARNs for references"
  value       = [for alarm in aws_cloudwatch_metric_alarm.addon : alarm.arn]
}

# Composite Alarms Outputs
output "composite_alarms" {
  description = "Created CloudWatch composite alarms"
  value = {
    for key, alarm in aws_cloudwatch_composite_alarm.addon : key => {
      name        = alarm.alarm_name
      arn         = alarm.arn
      alarm_rule  = alarm.alarm_rule
      actions_enabled = alarm.actions_enabled
    }
  }
}

# Anomaly Detectors Outputs
output "anomaly_detectors" {
  description = "Created CloudWatch anomaly detectors"
  value = {
    for key, detector in aws_cloudwatch_anomaly_detector.addon : key => {
      metric_name = detector.metric_name
      namespace   = detector.namespace
      stat        = detector.stat
      dimensions  = detector.dimensions
    }
  }
}

# Anomaly Alarms Outputs
output "anomaly_alarms" {
  description = "Created CloudWatch anomaly-based alarms"
  value = {
    for key, alarm in aws_cloudwatch_metric_alarm.anomaly : key => {
      name                = alarm.alarm_name
      arn                 = alarm.arn
      comparison_operator = alarm.comparison_operator
      evaluation_periods  = alarm.evaluation_periods
      alarm_actions       = alarm.alarm_actions
    }
  }
}

# Dashboard Outputs
output "dashboards" {
  description = "Created CloudWatch dashboards"
  value = {
    for key, dashboard in aws_cloudwatch_dashboard.addon : key => {
      name = dashboard.dashboard_name
      url  = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${dashboard.dashboard_name}"
    }
  }
}

# Custom Application Metrics Outputs
output "custom_application_metrics" {
  description = "Created custom application metrics"
  value = {
    for key, metric in aws_cloudwatch_log_metric_filter.custom_application_metrics : key => {
      name           = metric.name
      metric_name    = metric.metric_transformation[0].name
      namespace      = metric.metric_transformation[0].namespace
      log_group_name = metric.log_group_name
    }
  }
}

# Alert Channels Outputs
output "alert_channels" {
  description = "Created SNS alert channels"
  value = {
    for key, topic in aws_sns_topic.alerts : key => {
      name = topic.name
      arn  = topic.arn
      display_name = topic.display_name
    }
  }
}

output "sns_topic_arns" {
  description = "List of SNS topic ARNs for alarm actions"
  value       = [for topic in aws_sns_topic.alerts : topic.arn]
}

# Auto Scaling Policies Outputs
output "autoscaling_policies" {
  description = "Created application auto scaling policies"
  value = {
    for key, policy in aws_appautoscaling_policy.addon : key => {
      name               = policy.name
      arn                = policy.arn
      policy_type        = policy.policy_type
      resource_id        = policy.resource_id
      scalable_dimension = policy.scalable_dimension
      service_namespace  = policy.service_namespace
    }
  }
}

# EventBridge Rules Outputs
output "event_rules" {
  description = "Created EventBridge rules"
  value = {
    for key, rule in aws_cloudwatch_event_rule.addon : key => {
      name = rule.name
      arn  = rule.arn
      description = rule.description
      state = rule.state
    }
  }
}

# CloudWatch Insights Queries Outputs
output "insights_queries" {
  description = "Created CloudWatch Insights queries"
  value = {
    for key, query in aws_cloudwatch_query_definition.addon : key => {
      name            = query.name
      query_string    = query.query_string
      log_group_names = query.log_group_names
    }
  }
}

# Synthetics Canaries Outputs
output "synthetics_canaries" {
  description = "Created CloudWatch Synthetics canaries"
  value = {
    for key, canary in aws_synthetics_canary.addon : key => {
      name               = canary.name
      id                 = canary.id
      arn                = canary.arn
      source_location_arn = canary.source_location_arn
      status             = canary.status
      engine_arn         = canary.engine_arn
      runtime_version    = canary.runtime_version
    }
  }
}

# X-Ray Sampling Rules Outputs
output "xray_sampling_rules" {
  description = "Created X-Ray sampling rules"
  value = {
    for key, rule in aws_xray_sampling_rule.addon : key => {
      rule_name      = rule.rule_name
      arn            = rule.arn
      priority       = rule.priority
      reservoir_size = rule.reservoir_size
      fixed_rate     = rule.fixed_rate
    }
  }
}

# Environment and Configuration Outputs
output "environment" {
  description = "Environment this monitoring is deployed in"
  value       = var.environment
}

output "monitoring_level" {
  description = "Monitoring level configured"
  value       = var.monitoring_level
}

# Monitoring Summary
output "monitoring_summary" {
  description = "Summary of monitoring resources created"
  value = {
    log_groups_count         = length(aws_cloudwatch_log_group.addon)
    log_streams_count        = length(aws_cloudwatch_log_stream.addon)
    metric_filters_count     = length(aws_cloudwatch_log_metric_filter.addon)
    metric_alarms_count      = length(aws_cloudwatch_metric_alarm.addon)
    composite_alarms_count   = length(aws_cloudwatch_composite_alarm.addon)
    anomaly_detectors_count  = length(aws_cloudwatch_anomaly_detector.addon)
    anomaly_alarms_count     = length(aws_cloudwatch_metric_alarm.anomaly)
    dashboards_count         = length(aws_cloudwatch_dashboard.addon)
    alert_channels_count     = length(aws_sns_topic.alerts)
    autoscaling_policies_count = length(aws_appautoscaling_policy.addon)
    event_rules_count        = length(aws_cloudwatch_event_rule.addon)
    insights_queries_count   = length(aws_cloudwatch_query_definition.addon)
    synthetics_canaries_count = length(aws_synthetics_canary.addon)
    xray_sampling_rules_count = length(aws_xray_sampling_rule.addon)
  }
}

# Cost Optimization Features
output "cost_optimization_features" {
  description = "Summary of cost optimization features enabled"
  value = {
    cost_optimization_enabled = var.enable_cost_optimization
    log_retention_policies   = var.log_retention_policies
    anomaly_detection_enabled = length(aws_cloudwatch_anomaly_detector.addon) > 0
    intelligent_alerting     = length(aws_cloudwatch_composite_alarm.addon) > 0
  }
}

# Integration Information
output "integration_endpoints" {
  description = "Key endpoints and identifiers for integration with other modules"
  value = {
    primary_log_group    = length(aws_cloudwatch_log_group.addon) > 0 ? values(aws_cloudwatch_log_group.addon)[0].name : null
    alert_topic_arn      = length(aws_sns_topic.alerts) > 0 ? values(aws_sns_topic.alerts)[0].arn : null
    dashboard_urls       = [for dashboard in aws_cloudwatch_dashboard.addon : "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${dashboard.dashboard_name}"]
    region              = data.aws_region.current.name
    account_id          = data.aws_caller_identity.current.account_id
  }
}

# Alert Configuration
output "alert_configuration" {
  description = "Alert configuration summary"
  value = {
    severity_levels      = var.alert_severity_levels
    alert_channels       = keys(var.alert_channels)
    total_alarms        = length(aws_cloudwatch_metric_alarm.addon) + length(aws_cloudwatch_composite_alarm.addon) + length(aws_cloudwatch_metric_alarm.anomaly)
    anomaly_detection   = length(aws_cloudwatch_anomaly_detector.addon) > 0
  }
}

# Monitoring Capabilities
output "monitoring_capabilities" {
  description = "Summary of monitoring capabilities enabled"
  value = {
    log_monitoring          = length(aws_cloudwatch_log_group.addon) > 0
    metric_monitoring       = length(aws_cloudwatch_metric_alarm.addon) > 0
    anomaly_detection       = length(aws_cloudwatch_anomaly_detector.addon) > 0
    composite_alerting      = length(aws_cloudwatch_composite_alarm.addon) > 0
    dashboard_visualization = length(aws_cloudwatch_dashboard.addon) > 0
    synthetics_monitoring   = length(aws_synthetics_canary.addon) > 0
    distributed_tracing     = length(aws_xray_sampling_rule.addon) > 0
    auto_scaling_integration = length(aws_appautoscaling_policy.addon) > 0
    event_driven_monitoring = length(aws_cloudwatch_event_rule.addon) > 0
    log_insights_queries    = length(aws_cloudwatch_query_definition.addon) > 0
  }
}

# Addon Metadata
output "addon_metadata" {
  description = "Metadata about this addon module"
  value = {
    name        = "cloudwatch-enhanced-monitoring"
    version     = "v1.0.0"
    provider    = "aws"
    category    = "monitoring"
    features    = [
      "enhanced-logging",
      "intelligent-alerting",
      "anomaly-detection",
      "custom-dashboards",
      "synthetics-monitoring",
      "distributed-tracing",
      "auto-scaling-integration",
      "cost-optimization"
    ]
  }
}