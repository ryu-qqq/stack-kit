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

variable "topic_name" {
  description = "SNS 토픽 이름"
  type        = string
}

variable "display_name" {
  description = "SNS 토픽 표시 이름"
  type        = string
  default     = null
}

# FIFO Configuration
variable "fifo_topic" {
  description = "FIFO 토픽 여부"
  type        = bool
  default     = false
}

variable "content_based_deduplication" {
  description = "콘텐츠 기반 중복 제거 (FIFO 토픽만 해당)"
  type        = bool
  default     = false
}

# Policies
variable "topic_policy" {
  description = "SNS 토픽 정책 (JSON)"
  type        = string
  default     = null
}

variable "delivery_policy" {
  description = "배달 정책 (JSON)"
  type        = string
  default     = null
}

variable "cross_account_policy" {
  description = "교차 계정 접근 정책 (JSON)"
  type        = string
  default     = null
}

variable "data_protection_policy" {
  description = "데이터 보호 정책 (JSON)"
  type        = string
  default     = null
}

# Encryption
variable "kms_master_key_id" {
  description = "KMS 마스터 키 ID"
  type        = string
  default     = null
}

# Feedback Configuration
variable "application_success_feedback_role_arn" {
  description = "애플리케이션 성공 피드백 IAM 역할 ARN"
  type        = string
  default     = null
}

variable "application_success_feedback_sample_rate" {
  description = "애플리케이션 성공 피드백 샘플 비율 (%)"
  type        = number
  default     = null
  validation {
    condition     = var.application_success_feedback_sample_rate == null || (var.application_success_feedback_sample_rate >= 0 && var.application_success_feedback_sample_rate <= 100)
    error_message = "샘플 비율은 0-100 범위여야 합니다."
  }
}

variable "application_failure_feedback_role_arn" {
  description = "애플리케이션 실패 피드백 IAM 역할 ARN"
  type        = string
  default     = null
}

variable "http_success_feedback_role_arn" {
  description = "HTTP 성공 피드백 IAM 역할 ARN"
  type        = string
  default     = null
}

variable "http_success_feedback_sample_rate" {
  description = "HTTP 성공 피드백 샘플 비율 (%)"
  type        = number
  default     = null
  validation {
    condition     = var.http_success_feedback_sample_rate == null || (var.http_success_feedback_sample_rate >= 0 && var.http_success_feedback_sample_rate <= 100)
    error_message = "샘플 비율은 0-100 범위여야 합니다."
  }
}

variable "http_failure_feedback_role_arn" {
  description = "HTTP 실패 피드백 IAM 역할 ARN"
  type        = string
  default     = null
}

variable "lambda_success_feedback_role_arn" {
  description = "Lambda 성공 피드백 IAM 역할 ARN"
  type        = string
  default     = null
}

variable "lambda_success_feedback_sample_rate" {
  description = "Lambda 성공 피드백 샘플 비율 (%)"
  type        = number
  default     = null
  validation {
    condition     = var.lambda_success_feedback_sample_rate == null || (var.lambda_success_feedback_sample_rate >= 0 && var.lambda_success_feedback_sample_rate <= 100)
    error_message = "샘플 비율은 0-100 범위여야 합니다."
  }
}

variable "lambda_failure_feedback_role_arn" {
  description = "Lambda 실패 피드백 IAM 역할 ARN"
  type        = string
  default     = null
}

variable "sqs_success_feedback_role_arn" {
  description = "SQS 성공 피드백 IAM 역할 ARN"
  type        = string
  default     = null
}

variable "sqs_success_feedback_sample_rate" {
  description = "SQS 성공 피드백 샘플 비율 (%)"
  type        = number
  default     = null
  validation {
    condition     = var.sqs_success_feedback_sample_rate == null || (var.sqs_success_feedback_sample_rate >= 0 && var.sqs_success_feedback_sample_rate <= 100)
    error_message = "샘플 비율은 0-100 범위여야 합니다."
  }
}

variable "sqs_failure_feedback_role_arn" {
  description = "SQS 실패 피드백 IAM 역할 ARN"
  type        = string
  default     = null
}

variable "firehose_success_feedback_role_arn" {
  description = "Firehose 성공 피드백 IAM 역할 ARN"
  type        = string
  default     = null
}

variable "firehose_success_feedback_sample_rate" {
  description = "Firehose 성공 피드백 샘플 비율 (%)"
  type        = number
  default     = null
  validation {
    condition     = var.firehose_success_feedback_sample_rate == null || (var.firehose_success_feedback_sample_rate >= 0 && var.firehose_success_feedback_sample_rate <= 100)
    error_message = "샘플 비율은 0-100 범위여야 합니다."
  }
}

variable "firehose_failure_feedback_role_arn" {
  description = "Firehose 실패 피드백 IAM 역할 ARN"
  type        = string
  default     = null
}

# Subscriptions
variable "subscriptions" {
  description = "SNS 구독 설정 리스트"
  type = list(object({
    protocol                        = string
    endpoint                        = string
    confirmation_timeout_in_minutes = optional(number, 1)
    endpoint_auto_confirms          = optional(bool, false)
    raw_message_delivery           = optional(bool, false)
    filter_policy                  = optional(string, null)
    filter_policy_scope            = optional(string, null)
    delivery_policy                = optional(string, null)
    redrive_policy                 = optional(string, null)
  }))
  default = []

  validation {
    condition = alltrue([
      for sub in var.subscriptions : contains([
        "http", "https", "email", "email-json", "sms", "sqs", "application", "lambda", "firehose"
      ], sub.protocol)
    ])
    error_message = "지원되는 프로토콜을 선택해주세요."
  }
}

# IAM and Logging
variable "create_delivery_status_role" {
  description = "배달 상태 로깅용 IAM 역할 생성 여부"
  type        = bool
  default     = false
}

variable "create_delivery_status_logs" {
  description = "배달 상태 로그 그룹 생성 여부"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "로그 보존 기간 (일)"
  type        = number
  default     = 14
  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.log_retention_days)
    error_message = "유효한 로그 보존 기간을 선택해주세요."
  }
}

# Monitoring & Alarms
variable "create_cloudwatch_alarms" {
  description = "CloudWatch 알람 생성 여부"
  type        = bool
  default     = true
}

variable "failed_notifications_alarm_threshold" {
  description = "실패한 알림 수 알람 임계값"
  type        = number
  default     = 1
}

variable "create_publish_alarm" {
  description = "메시지 게시 알람 생성 여부"
  type        = bool
  default     = false
}

variable "messages_published_alarm_threshold" {
  description = "게시된 메시지 수 알람 임계값 (낮은 임계값)"
  type        = number
  default     = 1
}

variable "alarm_actions" {
  description = "알람 액션 ARN 리스트"
  type        = list(string)
  default     = []
}

variable "common_tags" {
  description = "모든 리소스에 적용할 공통 태그"
  type        = map(string)
  default     = {}
}