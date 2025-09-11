# SQS Messaging Addon - Variables
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

variable "queue_name" {
  description = "SQS 큐 이름"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.queue_name))
    error_message = "큐 이름은 영문자, 숫자, 하이픈, 언더스코어만 포함할 수 있습니다."
  }
}

# Queue Configuration
variable "delay_seconds" {
  description = "메시지 전달 지연 시간 (초)"
  type        = number
  default     = 0
  validation {
    condition     = var.delay_seconds >= 0 && var.delay_seconds <= 900
    error_message = "지연 시간은 0-900초 사이여야 합니다."
  }
}

variable "max_message_size" {
  description = "최대 메시지 크기 (바이트)"
  type        = number
  default     = 262144
  validation {
    condition     = var.max_message_size >= 1024 && var.max_message_size <= 262144
    error_message = "메시지 크기는 1024-262144 바이트 사이여야 합니다."
  }
}

variable "message_retention_seconds" {
  description = "메시지 보존 기간 (초)"
  type        = number
  default     = 1209600 # 14 days
  validation {
    condition     = var.message_retention_seconds >= 60 && var.message_retention_seconds <= 1209600
    error_message = "메시지 보존 기간은 60초-1209600초(14일) 사이여야 합니다."
  }
}

variable "receive_wait_time_seconds" {
  description = "롱 폴링 대기 시간 (초)"
  type        = number
  default     = 20
  validation {
    condition     = var.receive_wait_time_seconds >= 0 && var.receive_wait_time_seconds <= 20
    error_message = "대기 시간은 0-20초 사이여야 합니다."
  }
}

variable "visibility_timeout_seconds" {
  description = "가시성 타임아웃 (초)"
  type        = number
  default     = 30
  validation {
    condition     = var.visibility_timeout_seconds >= 0 && var.visibility_timeout_seconds <= 43200
    error_message = "가시성 타임아웃은 0-43200초 사이여야 합니다."
  }
}

# FIFO Configuration
variable "fifo_queue" {
  description = "FIFO 큐 여부"
  type        = bool
  default     = false
}

variable "content_based_deduplication" {
  description = "컨텐츠 기반 중복 제거 (FIFO만)"
  type        = bool
  default     = false
}

variable "deduplication_scope" {
  description = "중복 제거 범위 (messageGroup 또는 queue)"
  type        = string
  default     = null
  validation {
    condition = var.deduplication_scope == null || contains(["messageGroup", "queue"], var.deduplication_scope)
    error_message = "중복 제거 범위는 messageGroup 또는 queue여야 합니다."
  }
}

variable "fifo_throughput_limit" {
  description = "FIFO 처리량 제한 (perQueue 또는 perMessageGroupId)"
  type        = string
  default     = null
  validation {
    condition = var.fifo_throughput_limit == null || contains(["perQueue", "perMessageGroupId"], var.fifo_throughput_limit)
    error_message = "처리량 제한은 perQueue 또는 perMessageGroupId여야 합니다."
  }
}

# Dead Letter Queue Configuration
variable "enable_dlq" {
  description = "DLQ 활성화 여부"
  type        = bool
  default     = true
}

variable "max_receive_count" {
  description = "DLQ로 이동하기 전 최대 수신 횟수"
  type        = number
  default     = 3
  validation {
    condition     = var.max_receive_count >= 1 && var.max_receive_count <= 1000
    error_message = "최대 수신 횟수는 1-1000 사이여야 합니다."
  }
}

variable "dlq_message_retention_seconds" {
  description = "DLQ 메시지 보존 기간 (초)"
  type        = number
  default     = 1209600 # 14 days
  validation {
    condition     = var.dlq_message_retention_seconds >= 60 && var.dlq_message_retention_seconds <= 1209600
    error_message = "DLQ 메시지 보존 기간은 60초-1209600초(14일) 사이여야 합니다."
  }
}

variable "custom_redrive_policy" {
  description = "사용자 정의 redrive 정책 (JSON)"
  type        = string
  default     = null
}

variable "redrive_allow_policy" {
  description = "Redrive allow 정책 (JSON)"
  type        = string
  default     = null
}

# Encryption Configuration
variable "kms_master_key_id" {
  description = "KMS 마스터 키 ID (암호화용)"
  type        = string
  default     = null
}

variable "kms_data_key_reuse_period_seconds" {
  description = "KMS 데이터 키 재사용 기간 (초)"
  type        = number
  default     = 300
  validation {
    condition     = var.kms_data_key_reuse_period_seconds >= 60 && var.kms_data_key_reuse_period_seconds <= 86400
    error_message = "데이터 키 재사용 기간은 60-86400초 사이여야 합니다."
  }
}

variable "sqs_managed_sse_enabled" {
  description = "SQS 관리 서버 측 암호화 활성화"
  type        = bool
  default     = true
}

# Policy Configuration
variable "queue_policy" {
  description = "큐 정책 (JSON)"
  type        = string
  default     = null
}

variable "dlq_policy" {
  description = "DLQ 정책 (JSON)"
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
  description = "IAM 정책에 포함할 SQS 액션"
  type        = list(string)
  default = [
    "sqs:SendMessage",
    "sqs:ReceiveMessage",
    "sqs:DeleteMessage",
    "sqs:GetQueueAttributes",
    "sqs:GetQueueUrl",
    "sqs:ChangeMessageVisibility"
  ]
}

# Lambda Trigger Configuration
variable "lambda_trigger" {
  description = "Lambda 트리거 설정"
  type = object({
    function_name                      = string
    batch_size                         = optional(number, 10)
    maximum_batching_window_in_seconds = optional(number, 0)
    enabled                           = optional(bool, true)
    scaling_config = optional(object({
      maximum_concurrency = number
    }))
    filter_criteria = optional(object({
      filters = list(object({
        pattern = string
      }))
    }))
  })
  default = null
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
    evaluation_periods              = optional(number, 2)
    period                         = optional(number, 300)
    visible_messages_threshold     = optional(number, 100)
    oldest_message_age_threshold   = optional(number, 300)
    dlq_messages_threshold         = optional(number, 1)
    alarm_actions                  = optional(list(string), [])
    ok_actions                     = optional(list(string), [])
  })
  default = {}
}

variable "create_dashboard" {
  description = "CloudWatch 대시보드 생성 여부"
  type        = bool
  default     = false
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