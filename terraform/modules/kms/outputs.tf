output "key_id" {
  description = "KMS 키 ID"
  value       = aws_kms_key.main.key_id
}

output "key_arn" {
  description = "KMS 키 ARN"
  value       = aws_kms_key.main.arn
}

output "alias_name" {
  description = "KMS 키 별칭"
  value       = aws_kms_alias.main.name
}

output "alias_arn" {
  description = "KMS 키 별칭 ARN"
  value       = aws_kms_alias.main.arn
}

output "key_usage" {
  description = "키 사용 목적"
  value       = aws_kms_key.main.key_usage
}

output "key_spec" {
  description = "키 스펙"
  value       = aws_kms_key.main.key_spec
}

output "key_rotation_enabled" {
  description = "키 로테이션 활성화 여부"
  value       = aws_kms_key.main.key_rotation_enabled
}

output "multi_region" {
  description = "다중 리전 키 여부"
  value       = aws_kms_key.main.multi_region
}

output "deletion_window_in_days" {
  description = "키 삭제 대기 기간"
  value       = aws_kms_key.main.deletion_window_in_days
}

output "policy" {
  description = "키 정책"
  value       = aws_kms_key.main.policy
}

output "grant_ids" {
  description = "KMS 권한 부여 ID 리스트"
  value       = aws_kms_grant.main[*].grant_id
}

output "grant_tokens" {
  description = "KMS 권한 부여 토큰 리스트"
  value       = aws_kms_grant.main[*].grant_token
  sensitive   = true
}

output "log_group_name" {
  description = "CloudWatch 로그 그룹 이름"
  value       = var.enable_logging ? aws_cloudwatch_log_group.kms_usage[0].name : null
}

output "log_group_arn" {
  description = "CloudWatch 로그 그룹 ARN"
  value       = var.enable_logging ? aws_cloudwatch_log_group.kms_usage[0].arn : null
}

output "dashboard_url" {
  description = "CloudWatch 대시보드 URL"
  value = var.create_dashboard ? "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.kms[0].dashboard_name}" : null
}

# Frequently used outputs for other modules
output "key_id_for_encryption" {
  description = "암호화에 사용할 KMS 키 ID (별칭 형태)"
  value       = aws_kms_alias.main.name
}

output "key_arn_for_iam" {
  description = "IAM 정책에서 사용할 KMS 키 ARN"
  value       = aws_kms_key.main.arn
}

# Data source already defined in main.tf