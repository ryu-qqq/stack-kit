# SNS Messaging Addon - Variables
# Version: v1.0.0

# Core Configuration
variable "project_name" {
  description = "프로젝트 이름"
  type        = string
  validation {
    condition     = length(var.project_name) > 0 && length(var.project_name) <= 50
    error_message = "프로젝트 이름은 1-50자 사이여야 합니다."
  }
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
  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.topic_name))
    error_message = "토픽 이름은 영문자, 숫자, 하이픈, 언더스코어만 포함할 수 있습니다."
  }
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
  description = "컨텐츠 기반 중복 제거 (FIFO만)"
  type        = bool
  default     = false
}

# Encryption Configuration
variable "kms_master_key_id" {
  description = "KMS 마스터 키 ID (암호화용)"
  type        = string
  default     = null
}

# Topic Policy
variable "topic_policy" {
  description = "토픽 정책 (JSON)"
  type        = string
  default     = null
}

variable "delivery_policy" {
  description = "전달 정책 (JSON)"
  type        = string
  default     = null
}

variable "data_protection_policy" {
  description = "데이터 보호 정책 (JSON)"
  type        = string
  default     = null
}

# Subscriptions Configuration
variable "subscriptions" {
  description = "SNS 구독 설정"
  type = list(object({
    protocol                        = string
    endpoint                        = string
    confirmation_timeout_in_minutes = optional(number, 1)
    endpoint_auto_confirms          = optional(bool, false)
    raw_message_delivery           = optional(bool, false)
    filter_policy                  = optional(string, null)
    filter_policy_scope            = optional(string, "MessageAttributes")
    delivery_policy                = optional(string, null)
    redrive_policy                 = optional(string, null)
  }))
  default = []

  validation {
    condition = alltrue([
      for sub in var.subscriptions : contains([
        "email", "email-json", "sms", "sqs", "lambda", "http", "https", "application", "firehose"
      ], sub.protocol)
    ])
    error_message = "지원되는 프로토콜: email, email-json, sms, sqs, lambda, http, https, application, firehose"
  }
}

# Delivery Status Logging
variable "create_delivery_status_role" {
  description = "전달 상태 로깅용 IAM 역할 생성 여부"
  type        = bool
  default     = true
}

variable "create_delivery_status_logs" {
  description = "전달 상태 로깅용 CloudWatch 로그 그룹 생성 여부"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch 로그 보존 기간 (일)"
  type        = number
  default     = 14
  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.log_retention_days)
    error_message = "유효한 로그 보존 기간을 선택해주세요."
  }
}

# Manual Delivery Status Role ARNs (if not creating automatically)
variable "application_success_feedback_role_arn" {
  description = "애플리케이션 성공 피드백 역할 ARN"
  type        = string
  default     = null
}

variable "application_success_feedback_sample_rate" {
  description = "애플리케이션 성공 피드백 샘플 비율"
  type        = number
  default     = 100
  validation {
    condition     = var.application_success_feedback_sample_rate >= 0 && var.application_success_feedback_sample_rate <= 100
    error_message = "샘플 비율은 0-100 사이여야 합니다."
  }
}

variable "application_failure_feedback_role_arn" {
  description = "애플리케이션 실패 피드백 역할 ARN"
  type        = string
  default     = null
}

variable "http_success_feedback_role_arn" {
  description = "HTTP 성공 피드백 역할 ARN"
  type        = string
  default     = null
}

variable "http_success_feedback_sample_rate" {
  description = "HTTP 성공 피드백 샘플 비율"
  type        = number
  default     = 100
  validation {
    condition     = var.http_success_feedback_sample_rate >= 0 && var.http_success_feedback_sample_rate <= 100
    error_message = "샘플 비율은 0-100 사이여야 합니다."
  }
}

variable "http_failure_feedback_role_arn" {
  description = "HTTP 실패 피드백 역할 ARN"
  type        = string
  default     = null
}

variable "lambda_success_feedback_role_arn" {
  description = "Lambda 성공 피드백 역할 ARN"
  type        = string
  default     = null
}

variable "lambda_success_feedback_sample_rate" {
  description = "Lambda 성공 피드백 샘플 비율"
  type        = number
  default     = 100
  validation {
    condition     = var.lambda_success_feedback_sample_rate >= 0 && var.lambda_success_feedback_sample_rate <= 100
    error_message = "샘플 비율은 0-100 사이여야 합니다."
  }
}

variable "lambda_failure_feedback_role_arn" {
  description = "Lambda 실패 피드백 역할 ARN"
  type        = string
  default     = null
}

variable "sqs_success_feedback_role_arn" {
  description = "SQS 성공 피드백 역할 ARN"
  type        = string
  default     = null
}

variable "sqs_success_feedback_sample_rate" {
  description = "SQS 성공 피드백 샘플 비율"
  type        = number
  default     = 100
  validation {
    condition     = var.sqs_success_feedback_sample_rate >= 0 && var.sqs_success_feedback_sample_rate <= 100
    error_message = "샘플 비율은 0-100 사이여야 합니다."
  }
}

variable "sqs_failure_feedback_role_arn" {
  description = "SQS 실패 피드백 역할 ARN"
  type        = string
  default     = null
}

variable "firehose_success_feedback_role_arn" {
  description = "Firehose 성공 피드백 역할 ARN"
  type        = string
  default     = null
}

variable "firehose_success_feedback_sample_rate" {
  description = "Firehose 성공 피드백 샘플 비율"
  type        = number
  default     = 100
  validation {
    condition     = var.firehose_success_feedback_sample_rate >= 0 && var.firehose_success_feedback_sample_rate <= 100
    error_message = "샘플 비율은 0-100 사이여야 합니다."
  }
}

variable "firehose_failure_feedback_role_arn" {
  description = "Firehose 실패 피드백 역할 ARN"
  type        = string
  default     = null
}

# IAM Configuration
variable "create_iam_role" {
  description = "IAM 역할 생성 여부"
  type        = bool
  default     = false
}

variable "iam_role_principals" {
  description = "IAM 역할이 신뢰할 서비스 주체"
  type        = list(string)
  default     = ["lambda.amazonaws.com", "ec2.amazonaws.com"]
}

variable "iam_actions" {
  description = "IAM 정책에 포함할 SNS 액션"
  type        = list(string)
  default = [
    "sns:Publish",
    "sns:GetTopicAttributes",
    "sns:SetTopicAttributes",
    "sns:Subscribe",
    "sns:Unsubscribe",
    "sns:ListSubscriptionsByTopic"
  ]
}

# Monitoring Configuration
variable "enable_monitoring" {
  description = "CloudWatch 모니터링 활성화"
  type        = bool
  default     = true
}

variable "monitoring_config" {
  description = "모니터링 설정"
  type = object({
    evaluation_periods                = optional(number, 2)
    period                           = optional(number, 300)
    failed_notifications_threshold   = optional(number, 1)
    messages_published_threshold     = optional(number, 1)
    high_publish_threshold          = optional(number, 1000)
    create_publish_alarm            = optional(bool, false)
    create_high_publish_alarm       = optional(bool, false)
    alarm_actions                   = optional(list(string), [])
    ok_actions                      = optional(list(string), [])
  })
  default = {}
}

variable "create_dashboard" {
  description = "CloudWatch 대시보드 생성 여부"
  type        = bool
  default     = false
}

# Email/SMS Configuration
variable "email_addresses" {
  description = "이메일 구독을 위한 이메일 주소 목록"
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for email in var.email_addresses : can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", email))
    ])
    error_message = "올바른 이메일 주소 형식이어야 합니다."
  }
}

variable "sms_numbers" {
  description = "SMS 구독을 위한 전화번호 목록 (E.164 형식)"
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for number in var.sms_numbers : can(regex("^\\+[1-9]\\d{1,14}$", number))
    ])
    error_message = "전화번호는 E.164 형식이어야 합니다 (예: +821012345678)."
  }
}

# HTTP/HTTPS Configuration
variable "http_endpoints" {
  description = "HTTP/HTTPS 엔드포인트 구독 설정"
  type = list(object({
    url                    = string
    confirmation_timeout  = optional(number, 1)
    raw_message_delivery  = optional(bool, false)
    filter_policy         = optional(string, null)
  }))
  default = []
}

# Tagging
variable "common_tags" {
  description = "모든 리소스에 적용할 공통 태그"
  type        = map(string)
  default     = {}
}

variable "additional_tags" {
  description = "추가 태그"
  type        = map(string)
  default     = {}
}