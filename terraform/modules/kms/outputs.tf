# ==============================================================================
# KMS MODULE OUTPUTS - Standardized Format
# ==============================================================================

# Core KMS Resources
output "key_id" {
  description = "KMS 키 ID"
  value       = aws_kms_key.main.key_id
}

output "key_arn" {
  description = "KMS 키 ARN"
  value       = aws_kms_key.main.arn
}

output "alias_name" {
  description = "KMS 키 별칭 이름"
  value       = aws_kms_alias.main.name
}

output "alias_arn" {
  description = "KMS 키 별칭 ARN"
  value       = aws_kms_alias.main.arn
}

# Configuration Information
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

# Policy Information
output "key_policy" {
  description = "KMS 키 정책 JSON"
  value       = aws_kms_key.main.policy
  sensitive   = true
}

# Grant Information
output "grants" {
  description = "생성된 KMS 권한 부여 정보"
  value = {
    for idx, grant in aws_kms_grant.main : idx => {
      name              = grant.name
      key_id           = grant.key_id
      grantee_principal = grant.grantee_principal
      operations       = grant.operations
      grant_id         = grant.grant_id
      grant_token      = grant.grant_token
    }
  }
  sensitive = true
}

# Monitoring Resources
output "cloudwatch_log_group" {
  description = "CloudWatch 로그 그룹 정보"
  value = var.enable_logging ? {
    name              = aws_cloudwatch_log_group.kms_usage[0].name
    arn              = aws_cloudwatch_log_group.kms_usage[0].arn
    retention_in_days = aws_cloudwatch_log_group.kms_usage[0].retention_in_days
  } : null
}

output "cloudwatch_alarms" {
  description = "생성된 CloudWatch 알람 정보"
  value = var.create_cloudwatch_alarms ? {
    usage_alarm = {
      name = aws_cloudwatch_metric_alarm.kms_key_usage[0].alarm_name
      arn  = aws_cloudwatch_metric_alarm.kms_key_usage[0].arn
    }
  } : {}
}

output "dashboard_name" {
  description = "CloudWatch 대시보드 이름"
  value       = var.create_dashboard ? aws_cloudwatch_dashboard.kms[0].dashboard_name : null
}

# Resource Summary for Integration
output "resource_summary" {
  description = "KMS 모듈 리소스 요약"
  value = {
    key_id           = aws_kms_key.main.key_id
    key_arn          = aws_kms_key.main.arn
    alias_name       = aws_kms_alias.main.name
    alias_arn        = aws_kms_alias.main.arn
    rotation_enabled = aws_kms_key.main.key_rotation_enabled
    multi_region     = aws_kms_key.main.multi_region
    grants_count     = length(aws_kms_grant.main)
    monitoring_enabled = var.create_cloudwatch_alarms
    logging_enabled    = var.enable_logging
    dashboard_enabled  = var.create_dashboard
    
    # Environment context
    project_name = var.project_name
    environment  = var.environment
    key_name     = var.key_name
  }
}

# Standard Module Metadata
output "module_metadata" {
  description = "모듈 메타데이터 (표준화된 형식)"
  value = {
    module_name    = "kms"
    module_version = "1.0.0"
    resource_count = 2 + length(var.grants) + (var.enable_logging ? 1 : 0) + (var.create_cloudwatch_alarms ? 1 : 0) + (var.create_dashboard ? 1 : 0)
    
    capabilities = [
      "key_management",
      "access_control",
      "policy_management",
      "grant_management",
      var.enable_logging ? "logging" : null,
      var.create_cloudwatch_alarms ? "monitoring" : null,
      var.create_dashboard ? "dashboard" : null,
      var.multi_region ? "multi_region" : null
    ]
    
    integration_points = {
      s3_encryption      = aws_kms_key.main.arn
      dynamodb_encryption = aws_kms_key.main.arn
      lambda_encryption   = aws_kms_key.main.arn
      sns_encryption     = aws_kms_key.main.arn
      sqs_encryption     = aws_kms_key.main.arn
      rds_encryption     = aws_kms_key.main.arn
    }
  }
}