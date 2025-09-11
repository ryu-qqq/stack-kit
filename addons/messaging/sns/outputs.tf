# SNS Messaging Addon - Outputs
# Version: v1.0.0

# Topic Information
output "topic_arn" {
  description = "SNS 토픽 ARN"
  value       = aws_sns_topic.main.arn
}

output "topic_name" {
  description = "SNS 토픽 이름"
  value       = aws_sns_topic.main.name
}

output "topic_id" {
  description = "SNS 토픽 ID"
  value       = aws_sns_topic.main.id
}

output "topic_display_name" {
  description = "SNS 토픽 표시 이름"
  value       = aws_sns_topic.main.display_name
}

output "topic_owner" {
  description = "SNS 토픽 소유자"
  value       = aws_sns_topic.main.owner
}

# Subscription Information
output "subscriptions" {
  description = "생성된 구독 정보"
  value = {
    for idx, subscription in aws_sns_topic_subscription.subscriptions : idx => {
      arn                   = subscription.arn
      protocol              = subscription.protocol
      endpoint              = subscription.endpoint
      confirmation_was_authenticated = subscription.confirmation_was_authenticated
      owner_id              = subscription.owner_id
      pending_confirmation  = subscription.pending_confirmation
    }
  }
}

output "subscription_arns" {
  description = "구독 ARN 목록"
  value       = [for sub in aws_sns_topic_subscription.subscriptions : sub.arn]
}

# IAM Information
output "iam_role_arn" {
  description = "IAM 역할 ARN"
  value       = var.create_iam_role ? aws_iam_role.topic_access[0].arn : null
}

output "iam_role_name" {
  description = "IAM 역할 이름"
  value       = var.create_iam_role ? aws_iam_role.topic_access[0].name : null
}

output "iam_policy_arn" {
  description = "IAM 정책 ARN"
  value       = var.create_iam_role ? aws_iam_policy.topic_access[0].arn : null
}

output "delivery_status_role_arn" {
  description = "전달 상태 로깅 역할 ARN"
  value       = var.create_delivery_status_role ? aws_iam_role.sns_delivery_status[0].arn : null
}

# Monitoring Information
output "cloudwatch_alarms" {
  description = "생성된 CloudWatch 알람 정보"
  value = var.enable_monitoring ? {
    failed_notifications = {
      name = aws_cloudwatch_metric_alarm.failed_notifications[0].alarm_name
      arn  = aws_cloudwatch_metric_alarm.failed_notifications[0].arn
    }
    messages_published = var.monitoring_config.create_publish_alarm ? {
      name = aws_cloudwatch_metric_alarm.messages_published[0].alarm_name
      arn  = aws_cloudwatch_metric_alarm.messages_published[0].arn
    } : null
    high_publish_rate = var.monitoring_config.create_high_publish_alarm ? {
      name = aws_cloudwatch_metric_alarm.high_publish_rate[0].alarm_name
      arn  = aws_cloudwatch_metric_alarm.high_publish_rate[0].arn
    } : null
  } : null
}

output "dashboard_url" {
  description = "CloudWatch 대시보드 URL"
  value = var.create_dashboard ? "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.topic_metrics[0].dashboard_name}" : null
}

output "delivery_status_log_group" {
  description = "전달 상태 로그 그룹 정보"
  value = var.create_delivery_status_logs ? {
    name = aws_cloudwatch_log_group.sns_delivery_status[0].name
    arn  = aws_cloudwatch_log_group.sns_delivery_status[0].arn
  } : null
}

# Lambda Permissions
output "lambda_permissions" {
  description = "생성된 Lambda 권한 정보"
  value = {
    for idx, permission in aws_lambda_permission.sns_invoke : idx => {
      statement_id = permission.statement_id
      function_name = permission.function_name
      source_arn   = permission.source_arn
    }
  }
}

# Configuration Information
output "topic_configuration" {
  description = "토픽 설정 정보"
  value = {
    fifo_topic                  = var.fifo_topic
    content_based_deduplication = var.fifo_topic ? var.content_based_deduplication : null
    encryption_enabled          = var.kms_master_key_id != null
    kms_master_key_id          = var.kms_master_key_id
    subscription_count         = length(var.subscriptions)
    protocols_used             = distinct([for sub in var.subscriptions : sub.protocol])
    delivery_status_logging    = var.create_delivery_status_role
  }
}

# Integration Configuration
output "integration_config" {
  description = "다른 서비스와의 통합을 위한 설정"
  value = {
    # For SQS integration
    topic_arn_for_sqs_policy = aws_sns_topic.main.arn
    
    # For Lambda integration
    topic_arn_for_lambda_permission = aws_sns_topic.main.arn
    
    # For EventBridge integration
    topic_arn_for_eventbridge = aws_sns_topic.main.arn
    
    # CloudFormation stack outputs
    cloudformation_stack_outputs = {
      TopicArn          = aws_sns_topic.main.arn
      TopicName         = aws_sns_topic.main.name
      SubscriptionArns  = [for sub in aws_sns_topic_subscription.subscriptions : sub.arn]
    }
  }
}

# Subscription Templates
output "subscription_templates" {
  description = "추가 구독을 위한 템플릿"
  value = {
    email_subscription = {
      topic_arn = aws_sns_topic.main.arn
      protocol  = "email"
      endpoint  = "user@example.com"
    }
    
    sms_subscription = {
      topic_arn = aws_sns_topic.main.arn
      protocol  = "sms"
      endpoint  = "+821012345678"
    }
    
    sqs_subscription = {
      topic_arn = aws_sns_topic.main.arn
      protocol  = "sqs"
      endpoint  = "arn:aws:sqs:region:account:queue-name"
    }
    
    lambda_subscription = {
      topic_arn = aws_sns_topic.main.arn
      protocol  = "lambda"
      endpoint  = "arn:aws:lambda:region:account:function:function-name"
    }
    
    http_subscription = {
      topic_arn = aws_sns_topic.main.arn
      protocol  = "https"
      endpoint  = "https://example.com/webhook"
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

# For terraform-aws-modules compatibility
output "sns_topic_arn" {
  description = "SNS 토픽 ARN (terraform-aws-modules 호환)"
  value       = aws_sns_topic.main.arn
}

output "sns_topic_name" {
  description = "SNS 토픽 이름 (terraform-aws-modules 호환)"
  value       = aws_sns_topic.main.name
}