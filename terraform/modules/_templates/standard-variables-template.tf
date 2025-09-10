# Standard Variables Template for StackKit Infrastructure Modules
# This template provides the standardized variable structure for all Terraform modules

# ==============================================================================
# REQUIRED VARIABLES
# ==============================================================================

variable "project_name" {
  description = "프로젝트 이름 (리소스 이름에 사용됨)"
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

variable "[RESOURCE]_name" {
  description = "[리소스 타입] 이름 (구체적 설명)"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.[RESOURCE]_name)) && length(var.[RESOURCE]_name) <= 30
    error_message = "[리소스] 이름은 소문자, 숫자, 하이픈만 포함하고 30자 이하여야 합니다."
  }
}

# ==============================================================================
# RESOURCE-SPECIFIC CONFIGURATION
# ==============================================================================

# Add resource-specific variables here following this pattern:
# variable "example_config" {
#   description = "구체적인 설명과 용도"
#   type        = string|number|bool|list()|map()|object({})
#   default     = null|value (optional일 경우)
#   
#   validation {
#     condition     = # validation logic
#     error_message = "한글로된 명확한 에러 메시지"
#   }
# }

# ==============================================================================
# LIFECYCLE MANAGEMENT
# ==============================================================================

variable "prevent_destroy" {
  description = "리소스 삭제 방지 (프로덕션 환경 권장)"
  type        = bool
  default     = false
}

variable "ignore_changes" {
  description = "Terraform이 무시할 변경사항 목록"
  type        = list(string)
  default     = []
}

# ==============================================================================
# SECURITY & ENCRYPTION
# ==============================================================================

variable "kms_key_id" {
  description = "암호화용 KMS 키 ID (선택사항)"
  type        = string
  default     = null
}

variable "enable_encryption" {
  description = "암호화 활성화 여부"
  type        = bool
  default     = true
}

variable "create_iam_role" {
  description = "IAM 역할 생성 여부"
  type        = bool
  default     = false
}

variable "service_principals" {
  description = "IAM 역할에 대한 서비스 주체 목록"
  type        = list(string)
  default     = []
}

variable "iam_policy_document" {
  description = "커스텀 IAM 정책 문서 (JSON)"
  type        = string
  default     = null
}

# ==============================================================================
# MONITORING & LOGGING
# ==============================================================================

variable "enable_logging" {
  description = "CloudWatch 로깅 활성화 여부"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "로그 보존 기간 (일)"
  type        = number
  default     = 30
  
  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.log_retention_days)
    error_message = "유효한 로그 보존 기간을 선택해주세요."
  }
}

variable "log_kms_key_id" {
  description = "로그 암호화용 KMS 키 ID"
  type        = string
  default     = null
}

# ==============================================================================
# CLOUDWATCH ALARMS
# ==============================================================================

variable "create_cloudwatch_alarms" {
  description = "CloudWatch 알람 생성 여부"
  type        = bool
  default     = true
}

variable "alarm_comparison_operator" {
  description = "알람 비교 연산자"
  type        = string
  default     = "GreaterThanThreshold"
  
  validation {
    condition = contains([
      "GreaterThanOrEqualToThreshold",
      "GreaterThanThreshold",
      "LessThanThreshold",
      "LessThanOrEqualToThreshold",
      "LessThanLowerOrGreaterThanUpperThreshold",
      "LessThanLowerThreshold",
      "GreaterThanUpperThreshold"
    ], var.alarm_comparison_operator)
    error_message = "유효한 비교 연산자를 선택해주세요."
  }
}

variable "alarm_evaluation_periods" {
  description = "알람 평가 기간 수"
  type        = number
  default     = 2
  
  validation {
    condition     = var.alarm_evaluation_periods >= 1 && var.alarm_evaluation_periods <= 5
    error_message = "평가 기간은 1-5 사이의 값이어야 합니다."
  }
}

variable "alarm_metric_name" {
  description = "모니터링할 메트릭 이름"
  type        = string
  default     = null
}

variable "alarm_namespace" {
  description = "메트릭 네임스페이스"
  type        = string
  default     = null
}

variable "alarm_period" {
  description = "알람 평가 주기 (초)"
  type        = number
  default     = 300
}

variable "alarm_statistic" {
  description = "통계 방법"
  type        = string
  default     = "Average"
  
  validation {
    condition     = contains(["SampleCount", "Average", "Sum", "Minimum", "Maximum"], var.alarm_statistic)
    error_message = "유효한 통계 방법을 선택해주세요."
  }
}

variable "alarm_threshold" {
  description = "알람 임계값"
  type        = number
  default     = 80
}

variable "alarm_description" {
  description = "알람 설명"
  type        = string
  default     = null
}

variable "alarm_actions" {
  description = "알람 발생 시 실행할 액션 ARN 목록"
  type        = list(string)
  default     = []
}

variable "ok_actions" {
  description = "알람 해제 시 실행할 액션 ARN 목록"
  type        = list(string)
  default     = []
}

variable "treat_missing_data" {
  description = "누락 데이터 처리 방법"
  type        = string
  default     = "notBreaching"
  
  validation {
    condition     = contains(["breaching", "notBreaching", "ignore", "missing"], var.treat_missing_data)
    error_message = "유효한 누락 데이터 처리 방법을 선택해주세요."
  }
}

variable "alarm_dimensions" {
  description = "알람 메트릭 차원"
  type        = map(string)
  default     = {}
}

# ==============================================================================
# DASHBOARD
# ==============================================================================

variable "create_dashboard" {
  description = "CloudWatch 대시보드 생성 여부"
  type        = bool
  default     = false
}

variable "dashboard_metrics" {
  description = "대시보드에 표시할 메트릭"
  type        = list(list(string))
  default     = []
}

variable "dashboard_period" {
  description = "대시보드 메트릭 집계 주기 (초)"
  type        = number
  default     = 300
}

variable "dashboard_statistic" {
  description = "대시보드 통계 방법"
  type        = string
  default     = "Average"
}

# ==============================================================================
# TAGGING
# ==============================================================================

variable "common_tags" {
  description = "모든 리소스에 적용할 공통 태그"
  type        = map(string)
  default     = {}
}

variable "resource_tags" {
  description = "이 리소스에만 적용할 추가 태그"
  type        = map(string)
  default     = {}
}

# ==============================================================================
# VALIDATION HELPERS
# ==============================================================================

# Common validation patterns (as locals in main.tf):
# locals {
#   # Email validation
#   is_valid_email = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.email))
#   
#   # ARN validation  
#   is_valid_arn = can(regex("^arn:aws:.*", var.arn))
#   
#   # CIDR validation
#   is_valid_cidr = can(cidrhost(var.cidr_block, 0))
# }