# SQS Messaging Addon - Outputs
# Version: v1.0.0

# Queue Information
output "queue_id" {
  description = "SQS 큐 ID (URL)"
  value       = aws_sqs_queue.main.id
}

output "queue_arn" {
  description = "SQS 큐 ARN"
  value       = aws_sqs_queue.main.arn
}

output "queue_name" {
  description = "SQS 큐 이름"
  value       = aws_sqs_queue.main.name
}

output "queue_url" {
  description = "SQS 큐 URL"
  value       = aws_sqs_queue.main.url
}

# Dead Letter Queue Information
output "dlq_id" {
  description = "DLQ ID (URL)"
  value       = var.enable_dlq ? aws_sqs_queue.dlq[0].id : null
}

output "dlq_arn" {
  description = "DLQ ARN"
  value       = var.enable_dlq ? aws_sqs_queue.dlq[0].arn : null
}

output "dlq_name" {
  description = "DLQ 이름"
  value       = var.enable_dlq ? aws_sqs_queue.dlq[0].name : null
}

output "dlq_url" {
  description = "DLQ URL"
  value       = var.enable_dlq ? aws_sqs_queue.dlq[0].url : null
}

# IAM Information
output "iam_role_arn" {
  description = "IAM 역할 ARN"
  value       = var.create_iam_role ? aws_iam_role.queue_access[0].arn : null
}

output "iam_role_name" {
  description = "IAM 역할 이름"
  value       = var.create_iam_role ? aws_iam_role.queue_access[0].name : null
}

output "iam_policy_arn" {
  description = "IAM 정책 ARN"
  value       = var.create_iam_role ? aws_iam_policy.queue_access[0].arn : null
}

# Lambda Event Source Mapping
output "lambda_event_source_mapping_uuid" {
  description = "Lambda 이벤트 소스 매핑 UUID"
  value       = var.lambda_trigger != null ? aws_lambda_event_source_mapping.queue_trigger[0].uuid : null
}

# Monitoring Information
output "cloudwatch_alarms" {
  description = "생성된 CloudWatch 알람 정보"
  value = var.enable_monitoring ? {
    messages_visible = {
      name = aws_cloudwatch_metric_alarm.messages_visible[0].alarm_name
      arn  = aws_cloudwatch_metric_alarm.messages_visible[0].arn
    }
    oldest_message_age = {
      name = aws_cloudwatch_metric_alarm.oldest_message_age[0].alarm_name
      arn  = aws_cloudwatch_metric_alarm.oldest_message_age[0].arn
    }
    dlq_messages = var.enable_dlq ? {
      name = aws_cloudwatch_metric_alarm.dlq_messages[0].alarm_name
      arn  = aws_cloudwatch_metric_alarm.dlq_messages[0].arn
    } : null
  } : null
}

output "dashboard_url" {
  description = "CloudWatch 대시보드 URL"
  value = var.create_dashboard ? "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.queue_metrics[0].dashboard_name}" : null
}

# Configuration Information
output "queue_configuration" {
  description = "큐 설정 정보"
  value = {
    fifo_queue                   = var.fifo_queue
    content_based_deduplication  = var.fifo_queue ? var.content_based_deduplication : null
    visibility_timeout_seconds   = var.visibility_timeout_seconds
    message_retention_seconds    = var.message_retention_seconds
    max_message_size            = var.max_message_size
    delay_seconds               = var.delay_seconds
    receive_wait_time_seconds   = var.receive_wait_time_seconds
    dlq_enabled                 = var.enable_dlq
    max_receive_count           = var.enable_dlq ? var.max_receive_count : null
    encryption_enabled          = var.kms_master_key_id != null || var.sqs_managed_sse_enabled
  }
}

# For Integration with Other Services
output "integration_config" {
  description = "다른 서비스와의 통합을 위한 설정"
  value = {
    sns_subscription_endpoint = aws_sqs_queue.main.arn
    lambda_event_source_arn   = aws_sqs_queue.main.arn
    cloudformation_stack_outputs = {
      QueueUrl = aws_sqs_queue.main.url
      QueueArn = aws_sqs_queue.main.arn
      DLQUrl   = var.enable_dlq ? aws_sqs_queue.dlq[0].url : null
      DLQArn   = var.enable_dlq ? aws_sqs_queue.dlq[0].arn : null
    }
  }
}

# Regional Information
output "region" {
  description = "리소스가 생성된 AWS 리전"
  value       = data.aws_region.current.name
}

output "account_id" {
  description = "AWS 계정 ID"
  value       = data.aws_caller_identity.current.account_id
  sensitive   = true
}