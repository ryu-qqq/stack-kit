output "function_name" {
  description = "Lambda 함수 이름"
  value       = aws_lambda_function.main.function_name
}

output "function_arn" {
  description = "Lambda 함수 ARN"
  value       = aws_lambda_function.main.arn
}

output "function_invoke_arn" {
  description = "Lambda 함수 호출 ARN"
  value       = aws_lambda_function.main.invoke_arn
}

output "function_version" {
  description = "Lambda 함수 버전"
  value       = aws_lambda_function.main.version
}

output "function_last_modified" {
  description = "Lambda 함수 최종 수정 시간"
  value       = aws_lambda_function.main.last_modified
}

output "function_source_code_hash" {
  description = "Lambda 함수 소스 코드 해시"
  value       = aws_lambda_function.main.source_code_hash
}

output "function_source_code_size" {
  description = "Lambda 함수 소스 코드 크기"
  value       = aws_lambda_function.main.source_code_size
}

output "function_qualified_arn" {
  description = "Lambda 함수 정규화된 ARN (버전 포함)"
  value       = aws_lambda_function.main.qualified_arn
}

output "function_qualified_invoke_arn" {
  description = "Lambda 함수 정규화된 호출 ARN (버전 포함)"
  value       = aws_lambda_function.main.qualified_invoke_arn
}

output "role_arn" {
  description = "Lambda 함수 실행 역할 ARN"
  value       = aws_iam_role.lambda.arn
}

output "role_name" {
  description = "Lambda 함수 실행 역할 이름"
  value       = aws_iam_role.lambda.name
}

output "log_group_name" {
  description = "CloudWatch 로그 그룹 이름"
  value       = aws_cloudwatch_log_group.lambda.name
}

output "log_group_arn" {
  description = "CloudWatch 로그 그룹 ARN"
  value       = aws_cloudwatch_log_group.lambda.arn
}

output "function_url" {
  description = "Lambda 함수 URL"
  value       = var.create_function_url ? aws_lambda_function_url.main[0].function_url : null
}

output "function_url_creation_time" {
  description = "Lambda 함수 URL 생성 시간"
  value       = var.create_function_url ? aws_lambda_function_url.main[0].url_id : null
}

output "alias_arn" {
  description = "Lambda 별칭 ARN"
  value       = var.create_alias ? aws_lambda_alias.main[0].arn : null
}

output "alias_invoke_arn" {
  description = "Lambda 별칭 호출 ARN"
  value       = var.create_alias ? aws_lambda_alias.main[0].invoke_arn : null
}

output "alias_name" {
  description = "Lambda 별칭 이름"
  value       = var.create_alias ? aws_lambda_alias.main[0].name : null
}

# Configuration outputs
output "runtime" {
  description = "Lambda 런타임"
  value       = aws_lambda_function.main.runtime
}

output "handler" {
  description = "Lambda 핸들러"
  value       = aws_lambda_function.main.handler
}

output "memory_size" {
  description = "Lambda 메모리 크기 (MB)"
  value       = aws_lambda_function.main.memory_size
}

output "timeout" {
  description = "Lambda 타임아웃 (초)"
  value       = aws_lambda_function.main.timeout
}

output "architectures" {
  description = "Lambda 아키텍처"
  value       = aws_lambda_function.main.architectures
}

output "package_type" {
  description = "패키지 타입"
  value       = aws_lambda_function.main.package_type
}

output "reserved_concurrent_executions" {
  description = "예약된 동시 실행 수"
  value       = aws_lambda_function.main.reserved_concurrent_executions
}

output "vpc_config" {
  description = "VPC 설정"
  value = length(aws_lambda_function.main.vpc_config) > 0 ? {
    subnet_ids         = aws_lambda_function.main.vpc_config[0].subnet_ids
    security_group_ids = aws_lambda_function.main.vpc_config[0].security_group_ids
    vpc_id            = aws_lambda_function.main.vpc_config[0].vpc_id
  } : null
}

output "dead_letter_config_target_arn" {
  description = "데드 레터 큐 ARN"
  value       = length(aws_lambda_function.main.dead_letter_config) > 0 ? aws_lambda_function.main.dead_letter_config[0].target_arn : null
}

output "tracing_config_mode" {
  description = "X-Ray 추적 모드"
  value       = aws_lambda_function.main.tracing_config[0].mode
}

output "layers" {
  description = "Lambda 레이어"
  value       = aws_lambda_function.main.layers
}

# Monitoring outputs
output "error_alarm_name" {
  description = "에러 알람 이름"
  value       = var.create_cloudwatch_alarms ? aws_cloudwatch_metric_alarm.lambda_errors[0].alarm_name : null
}

output "duration_alarm_name" {
  description = "실행 시간 알람 이름"
  value       = var.create_cloudwatch_alarms ? aws_cloudwatch_metric_alarm.lambda_duration[0].alarm_name : null
}

output "throttle_alarm_name" {
  description = "스로틀 알람 이름"
  value       = var.create_cloudwatch_alarms ? aws_cloudwatch_metric_alarm.lambda_throttles[0].alarm_name : null
}