variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "environment" {
  description = "환경 (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "환경은 dev, staging, prod 중 하나여야 합니다."
  }
}

variable "key_name" {
  description = "KMS 키 이름"
  type        = string
}

variable "description" {
  description = "KMS 키 설명"
  type        = string
  default     = null
}

variable "key_usage" {
  description = "키 사용 목적"
  type        = string
  default     = "ENCRYPT_DECRYPT"
  validation {
    condition     = contains(["ENCRYPT_DECRYPT", "SIGN_VERIFY"], var.key_usage)
    error_message = "키 사용 목적은 ENCRYPT_DECRYPT 또는 SIGN_VERIFY 중 하나여야 합니다."
  }
}

variable "key_spec" {
  description = "키 스펙"
  type        = string
  default     = "SYMMETRIC_DEFAULT"
  validation {
    condition = contains([
      "SYMMETRIC_DEFAULT",
      "RSA_2048",
      "RSA_3072", 
      "RSA_4096",
      "ECC_NIST_P256",
      "ECC_NIST_P384",
      "ECC_NIST_P521",
      "ECC_SECG_P256K1"
    ], var.key_spec)
    error_message = "유효한 키 스펙을 선택해주세요."
  }
}

variable "customer_master_key_spec" {
  description = "고객 관리형 키 스펙 (deprecated, use key_spec)"
  type        = string
  default     = null
}

variable "enable_key_rotation" {
  description = "키 로테이션 활성화"
  type        = bool
  default     = true
}

variable "deletion_window_in_days" {
  description = "키 삭제 대기 기간 (일)"
  type        = number
  default     = 7
  validation {
    condition     = var.deletion_window_in_days >= 7 && var.deletion_window_in_days <= 30
    error_message = "삭제 대기 기간은 7일 이상 30일 이하로 설정해주세요."
  }
}

variable "multi_region" {
  description = "다중 리전 키 여부"
  type        = bool
  default     = false
}

variable "policy" {
  description = "커스텀 키 정책 (JSON 문자열)"
  type        = string
  default     = null
}

# IAM Principal Configuration
variable "key_administrators" {
  description = "키 관리자 ARN 리스트"
  type        = list(string)
  default     = []
}

variable "key_users" {
  description = "키 사용자 ARN 리스트"
  type        = list(string)
  default     = []
}

variable "service_principals" {
  description = "서비스 주체 리스트"
  type        = list(string)
  default     = []
}

variable "service_principal_conditions" {
  description = "서비스 주체 조건"
  type = list(object({
    test     = string
    variable = string
    values   = list(string)
  }))
  default = []
}

variable "cross_account_principals" {
  description = "교차 계정 주체 ARN 리스트"
  type        = list(string)
  default     = []
}

# Grant Configuration
variable "grants" {
  description = "KMS 권한 부여 설정"
  type = list(object({
    name              = string
    grantee_principal = string
    operations        = list(string)
    constraints = optional(object({
      encryption_context_equals = optional(map(string))
      encryption_context_subset = optional(map(string))
    }))
    grant_tokens = optional(list(string))
  }))
  default = []
}

# Logging Configuration
variable "enable_logging" {
  description = "CloudWatch 로깅 활성화"
  type        = bool
  default     = false
}

variable "log_retention_in_days" {
  description = "로그 보존 기간 (일)"
  type        = number
  default     = 7
  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.log_retention_in_days)
    error_message = "유효한 로그 보존 기간을 선택해주세요."
  }
}

# Monitoring Configuration
variable "create_cloudwatch_alarms" {
  description = "CloudWatch 알람 생성 여부"
  type        = bool
  default     = true
}

variable "usage_alarm_threshold" {
  description = "사용량 알람 임계값"
  type        = number
  default     = 100
}

variable "alarm_actions" {
  description = "알람 액션 ARN 리스트"
  type        = list(string)
  default     = []
}

variable "create_dashboard" {
  description = "CloudWatch 대시보드 생성 여부"
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "모든 리소스에 적용할 공통 태그"
  type        = map(string)
  default     = {}
}