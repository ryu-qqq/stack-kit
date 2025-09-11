# Log Groups Outputs
output "log_group_names" {
  description = "Names of the created log groups"
  value       = { for k, v in aws_cloudwatch_log_group.main : k => v.name }
}

output "log_group_arns" {
  description = "ARNs of the created log groups"
  value       = { for k, v in aws_cloudwatch_log_group.main : k => v.arn }
}

output "log_group_retention_in_days" {
  description = "Retention periods of the created log groups"
  value       = { for k, v in aws_cloudwatch_log_group.main : k => v.retention_in_days }
}

# Log Streams Outputs
output "log_stream_names" {
  description = "Names of the created log streams"
  value       = { for k, v in aws_cloudwatch_log_stream.main : k => v.name }
}

output "log_stream_arns" {
  description = "ARNs of the created log streams"
  value       = { for k, v in aws_cloudwatch_log_stream.main : k => v.arn }
}

# Metric Filter Outputs
output "metric_filter_names" {
  description = "Names of the created metric filters"
  value       = { for k, v in aws_cloudwatch_log_metric_filter.main : k => v.name }
}

output "metric_filter_ids" {
  description = "IDs of the created metric filters"
  value       = { for k, v in aws_cloudwatch_log_metric_filter.main : k => v.id }
}

# Metric Alarm Outputs
output "metric_alarm_names" {
  description = "Names of the created metric alarms"
  value       = { for k, v in aws_cloudwatch_metric_alarm.main : k => v.alarm_name }
}

output "metric_alarm_arns" {
  description = "ARNs of the created metric alarms"
  value       = { for k, v in aws_cloudwatch_metric_alarm.main : k => v.arn }
}

output "metric_alarm_ids" {
  description = "IDs of the created metric alarms"
  value       = { for k, v in aws_cloudwatch_metric_alarm.main : k => v.id }
}

# Composite Alarm Outputs
output "composite_alarm_names" {
  description = "Names of the created composite alarms"
  value       = { for k, v in aws_cloudwatch_composite_alarm.main : k => v.alarm_name }
}

output "composite_alarm_arns" {
  description = "ARNs of the created composite alarms"
  value       = { for k, v in aws_cloudwatch_composite_alarm.main : k => v.arn }
}

output "composite_alarm_ids" {
  description = "IDs of the created composite alarms"
  value       = { for k, v in aws_cloudwatch_composite_alarm.main : k => v.id }
}

# Anomaly Detector Outputs
output "anomaly_detector_ids" {
  description = "IDs of the created anomaly detectors"
  value       = { for k, v in aws_cloudwatch_anomaly_detector.main : k => v.id }
}

output "anomaly_detector_arns" {
  description = "ARNs of the created anomaly detectors"
  value       = { for k, v in aws_cloudwatch_anomaly_detector.main : k => v.arn }
}

# Anomaly Alarm Outputs
output "anomaly_alarm_names" {
  description = "Names of the created anomaly alarms"
  value       = { for k, v in aws_cloudwatch_metric_alarm.anomaly : k => v.alarm_name }
}

output "anomaly_alarm_arns" {
  description = "ARNs of the created anomaly alarms"
  value       = { for k, v in aws_cloudwatch_metric_alarm.anomaly : k => v.arn }
}

output "anomaly_alarm_ids" {
  description = "IDs of the created anomaly alarms"
  value       = { for k, v in aws_cloudwatch_metric_alarm.anomaly : k => v.id }
}

# Dashboard Outputs
output "dashboard_names" {
  description = "Names of the created dashboards"
  value       = { for k, v in aws_cloudwatch_dashboard.main : k => v.dashboard_name }
}

output "dashboard_arns" {
  description = "ARNs of the created dashboards"
  value       = { for k, v in aws_cloudwatch_dashboard.main : k => v.dashboard_arn }
}

output "dashboard_urls" {
  description = "URLs of the created dashboards"
  value = { 
    for k, v in aws_cloudwatch_dashboard.main : k => 
    "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${v.dashboard_name}"
  }
}

# SNS Topic Outputs
output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = var.create_sns_topic ? aws_sns_topic.alerts[0].arn : null
}

output "sns_topic_name" {
  description = "Name of the SNS topic for alerts"
  value       = var.create_sns_topic ? aws_sns_topic.alerts[0].name : null
}

output "sns_subscription_arns" {
  description = "ARNs of the SNS subscriptions"
  value       = var.create_sns_topic ? { for k, v in aws_sns_topic_subscription.alerts : k => v.arn } : {}
}

# Auto Scaling Policy Outputs
output "autoscaling_policy_arns" {
  description = "ARNs of the created auto scaling policies"
  value       = { for k, v in aws_appautoscaling_policy.scale_up : k => v.arn }
}

output "autoscaling_policy_names" {
  description = "Names of the created auto scaling policies"
  value       = { for k, v in aws_appautoscaling_policy.scale_up : k => v.name }
}

# Event Rule Outputs
output "event_rule_arns" {
  description = "ARNs of the created event rules"
  value       = { for k, v in aws_cloudwatch_event_rule.autoscaling : k => v.arn }
}

output "event_rule_names" {
  description = "Names of the created event rules"
  value       = { for k, v in aws_cloudwatch_event_rule.autoscaling : k => v.name }
}

# Comprehensive Outputs for Easy Reference
output "all_alarm_arns" {
  description = "All alarm ARNs (metric and composite alarms)"
  value = merge(
    { for k, v in aws_cloudwatch_metric_alarm.main : k => v.arn },
    { for k, v in aws_cloudwatch_composite_alarm.main : k => v.arn },
    { for k, v in aws_cloudwatch_metric_alarm.anomaly : k => v.arn }
  )
}

output "monitoring_summary" {
  description = "Summary of all monitoring resources created"
  value = {
    log_groups_count        = length(aws_cloudwatch_log_group.main)
    log_streams_count       = length(aws_cloudwatch_log_stream.main)
    metric_filters_count    = length(aws_cloudwatch_log_metric_filter.main)
    metric_alarms_count     = length(aws_cloudwatch_metric_alarm.main)
    composite_alarms_count  = length(aws_cloudwatch_composite_alarm.main)
    anomaly_detectors_count = length(aws_cloudwatch_anomaly_detector.main)
    anomaly_alarms_count    = length(aws_cloudwatch_metric_alarm.anomaly)
    dashboards_count        = length(aws_cloudwatch_dashboard.main)
    sns_topic_created       = var.create_sns_topic
    autoscaling_policies_count = length(aws_appautoscaling_policy.scale_up)
    event_rules_count       = length(aws_cloudwatch_event_rule.autoscaling)
  }
}

# Data source to get current AWS region
data "aws_region" "current" {}

# Output for Terraform state reference
output "terraform_state_info" {
  description = "Terraform state information for this module"
  value = {
    module_name = "cloudwatch-monitoring"
    region      = data.aws_region.current.name
    environment = var.environment
    project     = var.project_name
    created_at  = timestamp()
  }
}