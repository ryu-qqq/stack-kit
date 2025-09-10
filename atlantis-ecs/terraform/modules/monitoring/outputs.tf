# StackKit Monitoring Module Outputs

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.stackkit_alerts.arn
}

output "dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.stackkit_dashboard.dashboard_name}"
}

output "log_groups" {
  description = "CloudWatch log groups created"
  value = {
    deployment = aws_cloudwatch_log_group.deployment_logs.name
    terraform  = aws_cloudwatch_log_group.terraform_logs.name
    atlantis   = aws_cloudwatch_log_group.atlantis_logs.name
  }
}

output "alarms" {
  description = "CloudWatch alarms created"
  value = {
    deployment_failure = aws_cloudwatch_metric_alarm.deployment_failure_rate.alarm_name
    cost_increase     = aws_cloudwatch_metric_alarm.cost_increase.alarm_name
    deployment_duration = aws_cloudwatch_metric_alarm.deployment_duration.alarm_name
  }
}

output "lambda_function_name" {
  description = "Name of the Slack notifier Lambda function"
  value       = var.slack_webhook_url != "" ? aws_lambda_function.slack_notifier[0].function_name : null
}