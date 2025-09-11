output "queue_id" {
  description = "SQS 큐 ID"
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

output "dlq_id" {
  description = "DLQ ID"
  value       = var.create_dlq ? aws_sqs_queue.dlq[0].id : null
}

output "dlq_arn" {
  description = "DLQ ARN"
  value       = var.create_dlq ? aws_sqs_queue.dlq[0].arn : null
}

output "dlq_name" {
  description = "DLQ 이름"
  value       = var.create_dlq ? aws_sqs_queue.dlq[0].name : null
}

output "dlq_url" {
  description = "DLQ URL"
  value       = var.create_dlq ? aws_sqs_queue.dlq[0].url : null
}

# Configuration outputs
output "fifo_queue" {
  description = "FIFO 큐 여부"
  value       = aws_sqs_queue.main.fifo_queue
}

output "content_based_deduplication" {
  description = "콘텐츠 기반 중복 제거 여부"
  value       = aws_sqs_queue.main.content_based_deduplication
}

output "visibility_timeout_seconds" {
  description = "가시성 타임아웃 (초)"
  value       = aws_sqs_queue.main.visibility_timeout_seconds
}

output "message_retention_seconds" {
  description = "메시지 보존 시간 (초)"
  value       = aws_sqs_queue.main.message_retention_seconds
}

output "delay_seconds" {
  description = "메시지 지연 시간 (초)"
  value       = aws_sqs_queue.main.delay_seconds
}

output "max_message_size" {
  description = "최대 메시지 크기 (바이트)"
  value       = aws_sqs_queue.main.max_message_size
}

output "receive_wait_time_seconds" {
  description = "수신 대기 시간 (초)"
  value       = aws_sqs_queue.main.receive_wait_time_seconds
}

output "kms_master_key_id" {
  description = "KMS 마스터 키 ID"
  value       = aws_sqs_queue.main.kms_master_key_id
}

output "kms_data_key_reuse_period_seconds" {
  description = "KMS 데이터 키 재사용 기간 (초)"
  value       = aws_sqs_queue.main.kms_data_key_reuse_period_seconds
}

output "sqs_managed_sse_enabled" {
  description = "SQS 관리형 SSE 활성화 여부"
  value       = aws_sqs_queue.main.sqs_managed_sse_enabled
}

# IAM outputs
output "iam_policy_arn" {
  description = "SQS 접근 IAM 정책 ARN"
  value       = var.create_iam_policy ? aws_iam_policy.sqs_access[0].arn : null
}

output "iam_policy_name" {
  description = "SQS 접근 IAM 정책 이름"
  value       = var.create_iam_policy ? aws_iam_policy.sqs_access[0].name : null
}

# Lambda integration outputs
output "lambda_event_source_mapping_uuid" {
  description = "Lambda 이벤트 소스 매핑 UUID"
  value       = var.lambda_trigger != null ? aws_lambda_event_source_mapping.sqs[0].uuid : null
}

output "lambda_event_source_mapping_function_arn" {
  description = "Lambda 이벤트 소스 매핑 함수 ARN"
  value       = var.lambda_trigger != null ? aws_lambda_event_source_mapping.sqs[0].function_arn : null
}

# Monitoring outputs
output "visible_messages_alarm_name" {
  description = "가시 메시지 수 알람 이름"
  value       = var.create_cloudwatch_alarms ? aws_cloudwatch_metric_alarm.queue_messages_visible[0].alarm_name : null
}

output "oldest_message_age_alarm_name" {
  description = "가장 오래된 메시지 연령 알람 이름"
  value       = var.create_cloudwatch_alarms ? aws_cloudwatch_metric_alarm.queue_age_of_oldest_message[0].alarm_name : null
}

output "dlq_messages_alarm_name" {
  description = "DLQ 메시지 수 알람 이름"
  value       = var.create_dlq && var.create_cloudwatch_alarms ? aws_cloudwatch_metric_alarm.dlq_messages_visible[0].alarm_name : null
}

# Useful for connecting to other AWS services
output "queue_attributes" {
  description = "큐 속성 정보"
  value = {
    name                          = aws_sqs_queue.main.name
    arn                          = aws_sqs_queue.main.arn
    url                          = aws_sqs_queue.main.url
    fifo_queue                   = aws_sqs_queue.main.fifo_queue
    visibility_timeout_seconds   = aws_sqs_queue.main.visibility_timeout_seconds
    message_retention_seconds    = aws_sqs_queue.main.message_retention_seconds
  }
}

output "dlq_attributes" {
  description = "DLQ 속성 정보"
  value = var.create_dlq ? {
    name                        = aws_sqs_queue.dlq[0].name
    arn                        = aws_sqs_queue.dlq[0].arn
    url                        = aws_sqs_queue.dlq[0].url
    fifo_queue                 = aws_sqs_queue.dlq[0].fifo_queue
    message_retention_seconds  = aws_sqs_queue.dlq[0].message_retention_seconds
  } : null
}