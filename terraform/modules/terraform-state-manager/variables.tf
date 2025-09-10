# Terraform State Management Module Variables

# ==============================================================================
# REQUIRED VARIABLES
# ==============================================================================

variable "project_name" {
  description = "프로젝트 이름"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name)) && length(var.project_name) <= 20
    error_message = "프로젝트 이름은 소문자, 숫자, 하이픈만 포함하고 20자 이하여야 합니다."
  }
}

variable "environment" {
  description = "환경 구분 (dev, staging, prod)"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "환경은 dev, staging, prod 중 하나여야 합니다."
  }
}

# ==============================================================================
# STORAGE CONFIGURATION
# ==============================================================================

variable "state_retention_days" {
  description = "상태 파일 보존 기간 (일)"
  type        = number
  default     = 90
  
  validation {
    condition     = var.state_retention_days >= 30 && var.state_retention_days <= 2557
    error_message = "상태 파일 보존 기간은 30일 이상 2557일(7년) 이하여야 합니다."
  }
}

variable "old_version_retention_days" {
  description = "이전 버전 상태 파일 보존 기간 (일)"
  type        = number
  default     = 30
  
  validation {
    condition     = var.old_version_retention_days >= 7 && var.old_version_retention_days <= 365
    error_message = "이전 버전 보존 기간은 7일 이상 365일 이하여야 합니다."
  }
}

# ==============================================================================
# SECURITY CONFIGURATION
# ==============================================================================

variable "kms_key_id" {
  description = "상태 파일 암호화용 KMS 키 ID (null이면 S3 기본 암호화 사용)"
  type        = string
  default     = null
}

variable "backup_kms_key_id" {
  description = "백업 버킷 암호화용 KMS 키 ID"
  type        = string
  default     = null
}

variable "enable_dynamodb_encryption" {
  description = "DynamoDB 잠금 테이블 암호화 활성화"
  type        = bool
  default     = true
}

variable "dynamodb_kms_key_id" {
  description = "DynamoDB 암호화용 KMS 키 ARN"
  type        = string
  default     = null
}

variable "enable_dynamodb_pitr" {
  description = "DynamoDB Point-in-Time Recovery 활성화"
  type        = bool
  default     = true
}

# ==============================================================================
# BACKUP CONFIGURATION
# ==============================================================================

variable "enable_cross_region_backup" {
  description = "교차 리전 백업 활성화"
  type        = bool
  default     = false
}

variable "backup_region" {
  description = "백업 리전 (교차 리전 백업 시)"
  type        = string
  default     = "us-west-2"
  
  validation {
    condition = can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.backup_region))
    error_message = "올바른 AWS 리전 형식을 입력해주세요 (예: us-west-2)"
  }
}

variable "enable_automated_backups" {
  description = "자동화된 백업 기능 활성화"
  type        = bool
  default     = true
}

variable "backup_schedule_expression" {
  description = "백업 스케줄 표현식 (CloudWatch Events 형식)"
  type        = string
  default     = "cron(0 2 * * ? *)"  # Daily at 2 AM UTC
  
  validation {
    condition = can(regex("^(rate\\([0-9]+ (minute|minutes|hour|hours|day|days)\\)|cron\\(.+\\))$", var.backup_schedule_expression))
    error_message = "올바른 스케줄 표현식을 입력해주세요. 예: cron(0 2 * * ? *) 또는 rate(1 hour)"
  }
}

# ==============================================================================
# MONITORING CONFIGURATION
# ==============================================================================

variable "create_monitoring_alarms" {
  description = "모니터링 알람 생성 여부"
  type        = bool
  default     = true
}

variable "alarm_actions" {
  description = "알람 발생 시 실행할 액션 ARN 목록"
  type        = list(string)
  default     = []
}

variable "notification_endpoints" {
  description = "알림을 받을 이메일 주소 또는 SNS 엔드포인트"
  type        = list(string)
  default     = []
}

# ==============================================================================
# ACCESS CONTROL
# ==============================================================================

variable "allowed_aws_accounts" {
  description = "상태 파일에 접근 가능한 AWS 계정 ID 목록"
  type        = list(string)
  default     = []
}

variable "allowed_principals" {
  description = "상태 파일에 접근 가능한 IAM 주체 ARN 목록"
  type        = list(string)
  default     = []
}

variable "terraform_users" {
  description = "Terraform 실행 권한이 있는 IAM 사용자/역할 ARN 목록"
  type        = list(string)
  default     = []
}

variable "readonly_users" {
  description = "상태 파일 읽기 전용 권한이 있는 IAM 사용자/역할 ARN 목록"
  type        = list(string)
  default     = []
}

# ==============================================================================
# STATE VALIDATION
# ==============================================================================

variable "enable_state_validation" {
  description = "상태 파일 유효성 검증 활성화"
  type        = bool
  default     = true
}

variable "validation_rules" {
  description = "상태 파일 검증 규칙"
  type = object({
    min_terraform_version = optional(string, "1.0.0")
    max_file_size_mb     = optional(number, 10)
    require_encryption   = optional(bool, true)
    check_sensitive_data = optional(bool, true)
  })
  default = {}
}

# ==============================================================================
# PERFORMANCE TUNING
# ==============================================================================

variable "dynamodb_read_capacity" {
  description = "DynamoDB 읽기 용량 단위 (온디맨드 모드가 아닐 때)"
  type        = number
  default     = 5
}

variable "dynamodb_write_capacity" {
  description = "DynamoDB 쓰기 용량 단위 (온디맨드 모드가 아닐 때)"
  type        = number
  default     = 5
}

variable "use_dynamodb_on_demand" {
  description = "DynamoDB 온디맨드 요금제 사용 여부"
  type        = bool
  default     = true
}

# ==============================================================================
# COMPLIANCE & GOVERNANCE
# ==============================================================================

variable "enable_access_logging" {
  description = "S3 액세스 로깅 활성화"
  type        = bool
  default     = true
}

variable "access_log_bucket" {
  description = "액세스 로그를 저장할 S3 버킷 (null이면 자동 생성)"
  type        = string
  default     = null
}

variable "compliance_requirements" {
  description = "준수해야 할 컴플라이언스 요구사항"
  type        = list(string)
  default     = []
  
  validation {
    condition = alltrue([
      for req in var.compliance_requirements : contains(["SOC2", "HIPAA", "PCI-DSS", "GDPR", "ISO27001"], req)
    ])
    error_message = "유효한 컴플라이언스 요구사항을 선택해주세요: SOC2, HIPAA, PCI-DSS, GDPR, ISO27001"
  }
}

variable "data_residency_requirements" {
  description = "데이터 거주 요구사항 (데이터가 저장될 수 있는 리전)"
  type        = list(string)
  default     = []
}

# ==============================================================================
# DISASTER RECOVERY
# ==============================================================================

variable "enable_versioning_mfa_delete" {
  description = "MFA 삭제 보호 활성화 (루트 계정에서만 설정 가능)"
  type        = bool
  default     = false
}

variable "recovery_time_objective_hours" {
  description = "목표 복구 시간 (시간 단위)"
  type        = number
  default     = 4
  
  validation {
    condition     = var.recovery_time_objective_hours >= 1 && var.recovery_time_objective_hours <= 72
    error_message = "목표 복구 시간은 1시간 이상 72시간 이하여야 합니다."
  }
}

variable "recovery_point_objective_hours" {
  description = "목표 복구 시점 (시간 단위)"
  type        = number
  default     = 1
  
  validation {
    condition     = var.recovery_point_objective_hours >= 0.25 && var.recovery_point_objective_hours <= 24
    error_message = "목표 복구 시점은 15분(0.25시간) 이상 24시간 이하여야 합니다."
  }
}

# ==============================================================================
# TAGGING
# ==============================================================================

variable "common_tags" {
  description = "모든 리소스에 적용할 공통 태그"
  type        = map(string)
  default     = {}
}

variable "additional_tags" {
  description = "상태 관리 리소스에만 적용할 추가 태그"
  type        = map(string)
  default     = {}
}

# ==============================================================================
# ADVANCED CONFIGURATION
# ==============================================================================

variable "enable_state_drift_detection" {
  description = "상태 드리프트 감지 활성화"
  type        = bool
  default     = false
}

variable "drift_detection_schedule" {
  description = "드리프트 감지 스케줄 표현식"
  type        = string
  default     = "cron(0 6 * * ? *)"  # Daily at 6 AM UTC
}

variable "enable_state_analytics" {
  description = "상태 파일 분석 기능 활성화"
  type        = bool
  default     = false
}

variable "custom_lambda_layers" {
  description = "백업 Lambda에 추가할 사용자 정의 레이어 ARN 목록"
  type        = list(string)
  default     = []
}