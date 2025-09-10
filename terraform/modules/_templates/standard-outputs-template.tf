# Standard Outputs Template for StackKit Infrastructure Modules
# This template provides the standardized output structure for all Terraform modules

# ==============================================================================
# PRIMARY RESOURCE OUTPUTS
# ==============================================================================

output "id" {
  description = "[리소스타입] ID"
  value       = aws_[SERVICE]_[RESOURCE].main.id
}

output "arn" {
  description = "[리소스타입] ARN"
  value       = aws_[SERVICE]_[RESOURCE].main.arn
}

output "name" {
  description = "[리소스타입] 이름"
  value       = aws_[SERVICE]_[RESOURCE].main.name
}

# ==============================================================================
# RESOURCE-SPECIFIC OUTPUTS
# ==============================================================================

# Add resource-specific outputs here following this pattern:
# output "specific_attribute" {
#   description = "구체적인 속성에 대한 설명"
#   value       = aws_[SERVICE]_[RESOURCE].main.specific_attribute
#   sensitive   = false  # true if sensitive data
# }

# ==============================================================================
# MONITORING OUTPUTS
# ==============================================================================

output "cloudwatch_log_group_name" {
  description = "CloudWatch 로그 그룹 이름"
  value       = var.enable_logging ? aws_cloudwatch_log_group.main[0].name : null
}

output "cloudwatch_log_group_arn" {
  description = "CloudWatch 로그 그룹 ARN"
  value       = var.enable_logging ? aws_cloudwatch_log_group.main[0].arn : null
}

output "alarm_names" {
  description = "생성된 CloudWatch 알람 이름 목록"
  value       = var.create_cloudwatch_alarms ? aws_cloudwatch_metric_alarm.main[*].alarm_name : []
}

output "alarm_arns" {
  description = "생성된 CloudWatch 알람 ARN 목록"  
  value       = var.create_cloudwatch_alarms ? aws_cloudwatch_metric_alarm.main[*].arn : []
}

output "dashboard_url" {
  description = "CloudWatch 대시보드 URL"
  value = var.create_dashboard ? "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.main[0].dashboard_name}" : null
}

# ==============================================================================
# SECURITY OUTPUTS
# ==============================================================================

output "iam_role_arn" {
  description = "생성된 IAM 역할 ARN"
  value       = var.create_iam_role ? aws_iam_role.main[0].arn : null
}

output "iam_role_name" {
  description = "생성된 IAM 역할 이름"
  value       = var.create_iam_role ? aws_iam_role.main[0].name : null
}

output "kms_key_id" {
  description = "사용된 KMS 키 ID"
  value       = var.kms_key_id
}

# ==============================================================================
# INTEGRATION OUTPUTS (다른 모듈에서 자주 사용되는 값들)
# ==============================================================================

output "[RESOURCE]_for_integration" {
  description = "다른 모듈 통합용 [리소스] 정보"
  value = {
    id               = aws_[SERVICE]_[RESOURCE].main.id
    arn              = aws_[SERVICE]_[RESOURCE].main.arn
    name             = aws_[SERVICE]_[RESOURCE].main.name
    # Add other frequently needed attributes
  }
}

# For use in IAM policies
output "[RESOURCE]_arn_for_iam" {
  description = "IAM 정책에서 사용할 [리소스] ARN"
  value       = aws_[SERVICE]_[RESOURCE].main.arn
}

# For use in other resource references
output "[RESOURCE]_reference" {
  description = "다른 리소스에서 참조용 [리소스] ID"
  value       = aws_[SERVICE]_[RESOURCE].main.id
}

# ==============================================================================
# CONFIGURATION SUMMARY
# ==============================================================================

output "[RESOURCE]_configuration" {
  description = "[리소스] 설정 요약 정보"
  value = {
    project_name    = var.project_name
    environment     = var.environment
    resource_name   = var.[RESOURCE]_name
    full_name       = aws_[SERVICE]_[RESOURCE].main.name
    
    # Feature flags
    encryption_enabled = var.enable_encryption
    logging_enabled    = var.enable_logging
    monitoring_enabled = var.create_cloudwatch_alarms
    dashboard_enabled  = var.create_dashboard
    
    # Operational info
    created_by     = "Terraform"
    module_version = "1.0"
    region         = data.aws_region.current.name
    account_id     = data.aws_caller_identity.current.account_id
  }
}

# ==============================================================================
# DEBUGGING & TROUBLESHOOTING OUTPUTS
# ==============================================================================

output "debug_info" {
  description = "디버깅용 정보 (개발 환경에서만 사용)"
  value = var.environment == "dev" ? {
    # Only show in dev environment
    resource_tags     = aws_[SERVICE]_[RESOURCE].main.tags
    computed_name     = "${var.project_name}-${var.environment}-${var.[RESOURCE]_name}"
    availability_zones = data.aws_availability_zones.available.names
  } : null
}

# ==============================================================================
# SENSITIVE OUTPUTS
# ==============================================================================

# Example for sensitive data
# output "sensitive_data" {
#   description = "민감한 정보 (예: 암호, 키 등)"
#   value       = aws_[SERVICE]_[RESOURCE].main.sensitive_attribute
#   sensitive   = true
# }