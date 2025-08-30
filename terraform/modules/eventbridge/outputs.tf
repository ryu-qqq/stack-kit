output "event_bus_name" {
  description = "EventBridge 버스 이름"
  value       = var.create_custom_bus ? aws_cloudwatch_event_bus.main[0].name : "default"
}

output "event_bus_arn" {
  description = "EventBridge 버스 ARN"
  value       = var.create_custom_bus ? aws_cloudwatch_event_bus.main[0].arn : "arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:event-bus/default"
}

# Rules outputs
output "rule_names" {
  description = "EventBridge 규칙 이름 리스트"
  value       = aws_cloudwatch_event_rule.rules[*].name
}

output "rule_arns" {
  description = "EventBridge 규칙 ARN 리스트"
  value       = aws_cloudwatch_event_rule.rules[*].arn
}

output "rule_details" {
  description = "EventBridge 규칙 상세 정보"
  value = [
    for i, rule in aws_cloudwatch_event_rule.rules : {
      name              = rule.name
      arn              = rule.arn
      description      = rule.description
      event_pattern    = rule.event_pattern
      schedule_expression = rule.schedule_expression
      is_enabled       = rule.is_enabled
    }
  ]
}

# Targets outputs
output "target_ids" {
  description = "EventBridge 대상 ID 리스트"
  value       = aws_cloudwatch_event_target.targets[*].target_id
}

output "target_arns" {
  description = "EventBridge 대상 ARN 리스트"
  value       = aws_cloudwatch_event_target.targets[*].arn
}

# Connections outputs
output "connection_names" {
  description = "EventBridge 연결 이름 리스트"
  value       = aws_cloudwatch_event_connection.connections[*].name
}

output "connection_arns" {
  description = "EventBridge 연결 ARN 리스트"
  value       = aws_cloudwatch_event_connection.connections[*].arn
}

output "connection_secrets" {
  description = "EventBridge 연결 시크릿 ARN 리스트"
  value       = aws_cloudwatch_event_connection.connections[*].secret_arn
  sensitive   = true
}

# API Destinations outputs
output "api_destination_names" {
  description = "EventBridge API 대상 이름 리스트"
  value       = aws_cloudwatch_event_api_destination.destinations[*].name
}

output "api_destination_arns" {
  description = "EventBridge API 대상 ARN 리스트"
  value       = aws_cloudwatch_event_api_destination.destinations[*].arn
}

output "api_destination_details" {
  description = "EventBridge API 대상 상세 정보"
  value = [
    for i, dest in aws_cloudwatch_event_api_destination.destinations : {
      name                             = dest.name
      arn                             = dest.arn
      invocation_endpoint             = dest.invocation_endpoint
      http_method                     = dest.http_method
      invocation_rate_limit_per_second = dest.invocation_rate_limit_per_second
    }
  ]
}

# Archives outputs
output "archive_names" {
  description = "EventBridge 아카이브 이름 리스트"
  value       = aws_cloudwatch_event_archive.archives[*].name
}

output "archive_arns" {
  description = "EventBridge 아카이브 ARN 리스트"
  value       = aws_cloudwatch_event_archive.archives[*].arn
}

# Replays outputs
output "replay_names" {
  description = "EventBridge 재생 이름 리스트"
  value       = aws_cloudwatch_event_replay.replays[*].name
}

output "replay_arns" {
  description = "EventBridge 재생 ARN 리스트"
  value       = aws_cloudwatch_event_replay.replays[*].arn
}

output "replay_states" {
  description = "EventBridge 재생 상태 리스트"
  value       = aws_cloudwatch_event_replay.replays[*].state
}

# Monitoring outputs
output "invocation_alarm_names" {
  description = "호출 알람 이름 리스트"
  value       = var.create_cloudwatch_alarms ? aws_cloudwatch_metric_alarm.rule_invocations[*].alarm_name : []
}

output "failure_alarm_names" {
  description = "실패 알람 이름 리스트"
  value       = var.create_cloudwatch_alarms ? aws_cloudwatch_metric_alarm.rule_failures[*].alarm_name : []
}

# Configuration outputs
output "kms_key_id" {
  description = "EventBridge 암호화 KMS 키 ID"
  value       = var.create_custom_bus ? aws_cloudwatch_event_bus.main[0].kms_key_id : null
}

output "event_source_name" {
  description = "이벤트 소스 이름"
  value       = var.create_custom_bus ? aws_cloudwatch_event_bus.main[0].event_source_name : null
}

# Summary information for integration with other services
output "eventbridge_configuration" {
  description = "EventBridge 설정 요약"
  value = {
    bus_name      = var.create_custom_bus ? aws_cloudwatch_event_bus.main[0].name : "default"
    bus_arn       = var.create_custom_bus ? aws_cloudwatch_event_bus.main[0].arn : "arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:event-bus/default"
    custom_bus    = var.create_custom_bus
    rule_count    = length(aws_cloudwatch_event_rule.rules)
    target_count  = length(aws_cloudwatch_event_target.targets)
    connection_count = length(aws_cloudwatch_event_connection.connections)
    destination_count = length(aws_cloudwatch_event_api_destination.destinations)
    archive_count = length(aws_cloudwatch_event_archive.archives)
    replay_count  = length(aws_cloudwatch_event_replay.replays)
  }
}

# Rule and target mapping for reference
output "rule_target_mapping" {
  description = "규칙과 대상 매핑 정보"
  value = {
    for i, rule in aws_cloudwatch_event_rule.rules : rule.name => [
      for j, target in aws_cloudwatch_event_target.targets : target.arn
      if target.rule == rule.name
    ]
  }
}