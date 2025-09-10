# Terraform State Management Module Outputs

# ==============================================================================
# STATE STORAGE OUTPUTS
# ==============================================================================

output "state_bucket_name" {
  description = "Terraform 상태 파일 저장용 S3 버킷 이름"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "state_bucket_arn" {
  description = "Terraform 상태 파일 저장용 S3 버킷 ARN"
  value       = aws_s3_bucket.terraform_state.arn
}

output "state_bucket_region" {
  description = "상태 버킷이 위치한 리전"
  value       = data.aws_region.current.name
}

output "backup_bucket_name" {
  description = "백업용 S3 버킷 이름"
  value       = var.enable_cross_region_backup ? aws_s3_bucket.terraform_state_backup[0].bucket : null
}

output "backup_bucket_arn" {
  description = "백업용 S3 버킷 ARN"
  value       = var.enable_cross_region_backup ? aws_s3_bucket.terraform_state_backup[0].arn : null
}

output "backup_bucket_region" {
  description = "백업 버킷이 위치한 리전"
  value       = var.enable_cross_region_backup ? data.aws_region.backup[0].name : null
}

# ==============================================================================
# LOCKING OUTPUTS
# ==============================================================================

output "lock_table_name" {
  description = "Terraform 상태 잠금용 DynamoDB 테이블 이름"
  value       = aws_dynamodb_table.terraform_lock.name
}

output "lock_table_arn" {
  description = "Terraform 상태 잠금용 DynamoDB 테이블 ARN"
  value       = aws_dynamodb_table.terraform_lock.arn
}

# ==============================================================================
# TERRAFORM BACKEND CONFIGURATION
# ==============================================================================

output "backend_config" {
  description = "Terraform backend 설정 (terraform block에서 사용)"
  value = {
    bucket         = aws_s3_bucket.terraform_state.bucket
    key            = "terraform.tfstate"  # 기본값, 각 스택에서 override 필요
    region         = data.aws_region.current.name
    dynamodb_table = aws_dynamodb_table.terraform_lock.name
    encrypt        = true
    
    # KMS 키가 있으면 추가
    kms_key_id = var.kms_key_id
  }
}

output "backend_config_hcl" {
  description = "HCL 형식의 backend 설정 (파일로 저장하여 사용)"
  value = templatefile("${path.module}/templates/backend.hcl.tpl", {
    bucket         = aws_s3_bucket.terraform_state.bucket
    region         = data.aws_region.current.name
    dynamodb_table = aws_dynamodb_table.terraform_lock.name
    kms_key_id     = var.kms_key_id
  })
}

# ==============================================================================
# SECURITY OUTPUTS
# ==============================================================================

output "state_encryption_key" {
  description = "상태 파일 암호화에 사용된 KMS 키 정보"
  value = var.kms_key_id != null ? {
    key_id     = var.kms_key_id
    encryption = "KMS"
  } : {
    key_id     = null
    encryption = "AES256"
  }
}

output "access_policy_arn" {
  description = "상태 파일 접근 정책 ARN (생성된 경우)"
  value       = var.enable_cross_region_backup ? aws_iam_role.replication_role[0].arn : null
}

# ==============================================================================
# MONITORING OUTPUTS
# ==============================================================================

output "monitoring_alarms" {
  description = "생성된 CloudWatch 알람 정보"
  value = var.create_monitoring_alarms ? {
    state_errors = {
      name = aws_cloudwatch_metric_alarm.state_operation_errors[0].alarm_name
      arn  = aws_cloudwatch_metric_alarm.state_operation_errors[0].arn
    }
    lock_throttling = {
      name = aws_cloudwatch_metric_alarm.lock_table_throttling[0].alarm_name
      arn  = aws_cloudwatch_metric_alarm.lock_table_throttling[0].arn
    }
  } : null
}

output "backup_function" {
  description = "백업 Lambda 함수 정보"
  value = var.enable_automated_backups ? {
    function_name = aws_lambda_function.state_backup[0].function_name
    function_arn  = aws_lambda_function.state_backup[0].arn
    schedule      = var.backup_schedule_expression
  } : null
}

# ==============================================================================
# ACCESS CONFIGURATION
# ==============================================================================

output "terraform_user_policy" {
  description = "Terraform 사용자를 위한 최소 권한 정책 (JSON 형태)"
  value = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TerraformStateAccess"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.terraform_state.arn,
          "${aws_s3_bucket.terraform_state.arn}/*"
        ]
        Condition = {
          StringEquals = {
            "s3:x-amz-server-side-encryption" = var.kms_key_id != null ? "aws:kms" : "AES256"
          }
        }
      },
      {
        Sid    = "TerraformLockAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = aws_dynamodb_table.terraform_lock.arn
      }
    ]
  })
}

output "readonly_user_policy" {
  description = "읽기 전용 사용자를 위한 정책 (JSON 형태)"
  value = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TerraformStateReadOnly"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject"
        ]
        Resource = [
          aws_s3_bucket.terraform_state.arn,
          "${aws_s3_bucket.terraform_state.arn}/*"
        ]
      },
      {
        Sid    = "TerraformLockReadOnly"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem"
        ]
        Resource = aws_dynamodb_table.terraform_lock.arn
      }
    ]
  })
}

# ==============================================================================
# OPERATIONAL OUTPUTS
# ==============================================================================

output "state_management_endpoints" {
  description = "상태 관리를 위한 엔드포인트 정보"
  value = {
    s3_console_url = "https://s3.console.aws.amazon.com/s3/buckets/${aws_s3_bucket.terraform_state.bucket}?region=${data.aws_region.current.name}"
    dynamodb_console_url = "https://${data.aws_region.current.name}.console.aws.amazon.com/dynamodbv2/home?region=${data.aws_region.current.name}#item-explorer?table=${aws_dynamodb_table.terraform_lock.name}"
    
    cloudwatch_dashboard_url = var.create_monitoring_alarms ? 
      "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#alarmsV2:?" : null
  }
}

output "backup_information" {
  description = "백업 관련 정보"
  value = {
    enabled                    = var.enable_automated_backups
    schedule                  = var.backup_schedule_expression
    cross_region_enabled      = var.enable_cross_region_backup
    backup_region             = var.enable_cross_region_backup ? var.backup_region : null
    state_retention_days      = var.state_retention_days
    old_version_retention_days = var.old_version_retention_days
  }
}

# ==============================================================================
# DISASTER RECOVERY OUTPUTS
# ==============================================================================

output "disaster_recovery_config" {
  description = "재해복구 설정 정보"
  value = {
    rto_hours                    = var.recovery_time_objective_hours
    rpo_hours                    = var.recovery_point_objective_hours
    cross_region_backup_enabled = var.enable_cross_region_backup
    versioning_enabled          = true
    point_in_time_recovery      = var.enable_dynamodb_pitr
    
    recovery_procedures = {
      state_restore = "Use S3 versioning or cross-region backup to restore state files"
      lock_recovery = "DynamoDB PITR can restore lock table to specific point in time"
      full_recovery_steps = [
        "1. Identify last known good state version",
        "2. Restore state file from backup or version",
        "3. Clear any stale locks in DynamoDB",
        "4. Validate state integrity",
        "5. Resume Terraform operations"
      ]
    }
  }
}

# ==============================================================================
# INTEGRATION HELPERS
# ==============================================================================

output "integration_config" {
  description = "다른 모듈과의 통합을 위한 설정"
  value = {
    # 환경별 backend 설정 생성을 위한 템플릿
    backend_template = {
      bucket         = aws_s3_bucket.terraform_state.bucket
      region         = data.aws_region.current.name
      dynamodb_table = aws_dynamodb_table.terraform_lock.name
      encrypt        = true
      kms_key_id     = var.kms_key_id
    }
    
    # 모니터링 통합
    monitoring_integration = {
      sns_topic_arn = var.enable_automated_backups && length(var.alarm_actions) > 0 ? var.alarm_actions[0] : null
      log_group     = var.enable_automated_backups ? "/aws/lambda/${aws_lambda_function.state_backup[0].function_name}" : null
    }
    
    # 태깅 정보
    resource_tags = merge(
      var.common_tags,
      var.additional_tags,
      {
        Component = "TerraformStateManagement"
        ManagedBy = "Terraform"
      }
    )
  }
}

# ==============================================================================
# VALIDATION OUTPUTS
# ==============================================================================

output "configuration_summary" {
  description = "설정 요약 (검증 및 디버깅용)"
  value = {
    project_environment = "${var.project_name}-${var.environment}"
    primary_region     = data.aws_region.current.name
    backup_region      = var.enable_cross_region_backup ? var.backup_region : "none"
    
    security_features = {
      encryption_enabled     = var.kms_key_id != null
      versioning_enabled    = true
      access_logging_enabled = var.enable_access_logging
      public_access_blocked = true
    }
    
    backup_features = {
      automated_backups    = var.enable_automated_backups
      cross_region_backup  = var.enable_cross_region_backup
      schedule            = var.backup_schedule_expression
    }
    
    monitoring_features = {
      cloudwatch_alarms   = var.create_monitoring_alarms
      access_logging      = var.enable_access_logging
      drift_detection     = var.enable_state_drift_detection
    }
    
    compliance_info = {
      requirements        = var.compliance_requirements
      data_residency     = var.data_residency_requirements
      mfa_delete_enabled = var.enable_versioning_mfa_delete
    }
  }
}