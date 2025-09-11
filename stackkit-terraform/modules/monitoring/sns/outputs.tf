output "topic_id" {
  description = "SNS 토픽 ID"
  value       = aws_sns_topic.main.id
}

output "topic_arn" {
  description = "SNS 토픽 ARN"
  value       = aws_sns_topic.main.arn
}

output "topic_name" {
  description = "SNS 토픽 이름"
  value       = aws_sns_topic.main.name
}

output "topic_display_name" {
  description = "SNS 토픽 표시 이름"
  value       = aws_sns_topic.main.display_name
}

output "topic_owner" {
  description = "SNS 토픽 소유자 계정 ID"
  value       = aws_sns_topic.main.owner
}

# FIFO Configuration outputs
output "fifo_topic" {
  description = "FIFO 토픽 여부"
  value       = aws_sns_topic.main.fifo_topic
}

output "content_based_deduplication" {
  description = "콘텐츠 기반 중복 제거 여부"
  value       = aws_sns_topic.main.content_based_deduplication
}

# Policy outputs
output "topic_policy" {
  description = "SNS 토픽 정책"
  value       = aws_sns_topic.main.policy
}

output "delivery_policy" {
  description = "배달 정책"
  value       = aws_sns_topic.main.delivery_policy
}

# Encryption outputs
output "kms_master_key_id" {
  description = "KMS 마스터 키 ID"
  value       = aws_sns_topic.main.kms_master_key_id
}

# Subscription outputs
output "subscription_arns" {
  description = "구독 ARN 리스트"
  value       = aws_sns_topic_subscription.subscriptions[*].arn
}

output "subscription_ids" {
  description = "구독 ID 리스트"
  value       = aws_sns_topic_subscription.subscriptions[*].id
}

output "subscription_details" {
  description = "구독 상세 정보"
  value = [
    for i, sub in aws_sns_topic_subscription.subscriptions : {
      arn                     = sub.arn
      id                      = sub.id
      protocol               = sub.protocol
      endpoint               = sub.endpoint
      confirmation_was_authenticated = sub.confirmation_was_authenticated
      owner_id               = sub.owner_id
      pending_confirmation   = sub.pending_confirmation
    }
  ]
}

# Feedback Configuration outputs
output "application_success_feedback_role_arn" {
  description = "애플리케이션 성공 피드백 IAM 역할 ARN"
  value       = aws_sns_topic.main.application_success_feedback_role_arn
}

output "application_failure_feedback_role_arn" {
  description = "애플리케이션 실패 피드백 IAM 역할 ARN"
  value       = aws_sns_topic.main.application_failure_feedback_role_arn
}

output "http_success_feedback_role_arn" {
  description = "HTTP 성공 피드백 IAM 역할 ARN"
  value       = aws_sns_topic.main.http_success_feedback_role_arn
}

output "http_failure_feedback_role_arn" {
  description = "HTTP 실패 피드백 IAM 역할 ARN"
  value       = aws_sns_topic.main.http_failure_feedback_role_arn
}

output "lambda_success_feedback_role_arn" {
  description = "Lambda 성공 피드백 IAM 역할 ARN"
  value       = aws_sns_topic.main.lambda_success_feedback_role_arn
}

output "lambda_failure_feedback_role_arn" {
  description = "Lambda 실패 피드백 IAM 역할 ARN"
  value       = aws_sns_topic.main.lambda_failure_feedback_role_arn
}

output "sqs_success_feedback_role_arn" {
  description = "SQS 성공 피드백 IAM 역할 ARN"
  value       = aws_sns_topic.main.sqs_success_feedback_role_arn
}

output "sqs_failure_feedback_role_arn" {
  description = "SQS 실패 피드백 IAM 역할 ARN"
  value       = aws_sns_topic.main.sqs_failure_feedback_role_arn
}

output "firehose_success_feedback_role_arn" {
  description = "Firehose 성공 피드백 IAM 역할 ARN"
  value       = aws_sns_topic.main.firehose_success_feedback_role_arn
}

output "firehose_failure_feedback_role_arn" {
  description = "Firehose 실패 피드백 IAM 역할 ARN"
  value       = aws_sns_topic.main.firehose_failure_feedback_role_arn
}

# IAM and Logging outputs
output "delivery_status_role_arn" {
  description = "배달 상태 IAM 역할 ARN"
  value       = var.create_delivery_status_role ? aws_iam_role.sns_delivery_status[0].arn : null
}

output "delivery_status_role_name" {
  description = "배달 상태 IAM 역할 이름"
  value       = var.create_delivery_status_role ? aws_iam_role.sns_delivery_status[0].name : null
}

output "log_group_name" {
  description = "CloudWatch 로그 그룹 이름"
  value       = var.create_delivery_status_logs ? aws_cloudwatch_log_group.sns_delivery_status[0].name : null
}

output "log_group_arn" {
  description = "CloudWatch 로그 그룹 ARN"
  value       = var.create_delivery_status_logs ? aws_cloudwatch_log_group.sns_delivery_status[0].arn : null
}

# Monitoring outputs
output "failed_notifications_alarm_name" {
  description = "실패한 알림 수 알람 이름"
  value       = var.create_cloudwatch_alarms ? aws_cloudwatch_metric_alarm.sns_failed_notifications[0].alarm_name : null
}

output "messages_published_alarm_name" {
  description = "게시된 메시지 수 알람 이름"
  value       = var.create_cloudwatch_alarms && var.create_publish_alarm ? aws_cloudwatch_metric_alarm.sns_messages_published[0].alarm_name : null
}

# Lambda permission outputs
output "lambda_permission_statement_ids" {
  description = "Lambda 권한 문장 ID 리스트"
  value       = aws_lambda_permission.sns_invoke[*].statement_id
}

# Cross-account access
output "cross_account_policy_applied" {
  description = "교차 계정 정책 적용 여부"
  value       = var.cross_account_policy != null
}

# Data protection
output "data_protection_policy_applied" {
  description = "데이터 보호 정책 적용 여부"
  value       = var.data_protection_policy != null
}

# Useful for connecting to other AWS services
output "topic_attributes" {
  description = "토픽 속성 정보"
  value = {
    name         = aws_sns_topic.main.name
    arn          = aws_sns_topic.main.arn
    display_name = aws_sns_topic.main.display_name
    fifo_topic   = aws_sns_topic.main.fifo_topic
    owner        = aws_sns_topic.main.owner
  }
}