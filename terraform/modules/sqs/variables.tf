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

variable "queue_name" {
  description = "SQS 큐 이름"
  type        = string
}

# Queue Configuration
variable "delay_seconds" {
  description = "메시지 지연 시간 (초)"
  type        = number
  default     = 0
  validation {
    condition     = var.delay_seconds >= 0 && var.delay_seconds <= 900
    error_message = "지연 시간은 0초 이상 900초 이하로 설정해주세요."
  }
}

variable "max_message_size" {
  description = "최대 메시지 크기 (바이트)"
  type        = number
  default     = 262144
  validation {
    condition     = var.max_message_size >= 1024 && var.max_message_size <= 262144
    error_message = "최대 메시지 크기는 1024바이트 이상 262144바이트 이하로 설정해주세요."
  }
}

variable "message_retention_seconds" {
  description = "메시지 보존 시간 (초)"
  type        = number
  default     = 1209600  # 14 days
  validation {
    condition     = var.message_retention_seconds >= 60 && var.message_retention_seconds <= 1209600
    error_message = "메시지 보존 시간은 60초 이상 1209600초 이하로 설정해주세요."
  }
}

variable "receive_wait_time_seconds" {
  description = "수신 대기 시간 (초) - Long Polling"
  type        = number
  default     = 0
  validation {
    condition     = var.receive_wait_time_seconds >= 0 && var.receive_wait_time_seconds <= 20
    error_message = "수신 대기 시간은 0초 이상 20초 이하로 설정해주세요."
  }
}

variable "visibility_timeout_seconds" {
  description = "가시성 타임아웃 (초)"
  type        = number
  default     = 30
  validation {
    condition     = var.visibility_timeout_seconds >= 0 && var.visibility_timeout_seconds <= 43200
    error_message = "가시성 타임아웃은 0초 이상 43200초 이하로 설정해주세요."
  }
}

# FIFO Configuration
variable "fifo_queue" {
  description = "FIFO 큐 여부"
  type        = bool
  default     = false
}

variable "content_based_deduplication" {
  description = "콘텐츠 기반 중복 제거 (FIFO 큐만 해당)"
  type        = bool
  default     = false
}

variable "deduplication_scope" {
  description = "중복 제거 범위 (FIFO 큐만 해당)"
  type        = string
  default     = null
  validation {
    condition = var.deduplication_scope == null || contains(["messageGroup", "queue"], var.deduplication_scope)
    error_message = "중복 제거 범위는 messageGroup 또는 queue 중 하나여야 합니다."
  }
}

variable "fifo_throughput_limit" {
  description = "FIFO 처리량 제한 (FIFO 큐만 해당)"
  type        = string
  default     = null
  validation {
    condition = var.fifo_throughput_limit == null || contains(["perQueue", "perMessageGroupId"], var.fifo_throughput_limit)
    error_message = "FIFO 처리량 제한은 perQueue 또는 perMessageGroupId 중 하나여야 합니다."
  }
}

# Dead Letter Queue
variable "create_dlq" {
  description = "데드 레터 큐 생성 여부"
  type        = bool
  default     = true
}

variable "max_receive_count" {
  description = "최대 수신 횟수 (DLQ로 이동하기 전)"
  type        = number
  default     = 3
  validation {
    condition     = var.max_receive_count >= 1 && var.max_receive_count <= 1000
    error_message = "최대 수신 횟수는 1회 이상 1000회 이하로 설정해주세요."
  }
}

variable "dlq_message_retention_seconds" {
  description = "DLQ 메시지 보존 시간 (초)"
  type        = number
  default     = 1209600  # 14 days
}

variable "redrive_policy" {
  description = "커스텀 재시도 정책 (JSON)"
  type        = string
  default     = null
}

variable "redrive_allow_policy" {
  description = "재시도 허용 정책 (JSON)"
  type        = string
  default     = null
}

# Encryption
variable "kms_master_key_id" {
  description = "KMS 마스터 키 ID"
  type        = string
  default     = null
}

variable "kms_data_key_reuse_period_seconds" {
  description = "KMS 데이터 키 재사용 기간 (초)"
  type        = number
  default     = 300
  validation {
    condition     = var.kms_data_key_reuse_period_seconds >= 60 && var.kms_data_key_reuse_period_seconds <= 86400
    error_message = "KMS 데이터 키 재사용 기간은 60초 이상 86400초 이하로 설정해주세요."
  }
}

variable "sqs_managed_sse_enabled" {
  description = "SQS 관리형 SSE 활성화"
  type        = bool
  default     = true
}

# Queue Policy
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

# Lambda Integration
variable "lambda_trigger" {
  description = "Lambda 트리거 설정"
  type = object({
    function_name = string
    batch_size   = number
    enabled      = bool
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

# IAM
variable "create_iam_policy" {
  description = "IAM 정책 생성 여부"
  type        = bool
  default     = false
}

# Monitoring & Alarms
variable "create_cloudwatch_alarms" {
  description = "CloudWatch 알람 생성 여부"
  type        = bool
  default     = true
}

variable "visible_messages_alarm_threshold" {
  description = "가시 메시지 수 알람 임계값"
  type        = number
  default     = 10
}

variable "oldest_message_age_alarm_threshold" {
  description = "가장 오래된 메시지 연령 알람 임계값 (초)"
  type        = number
  default     = 600  # 10 minutes
}

variable "dlq_messages_alarm_threshold" {
  description = "DLQ 메시지 수 알람 임계값"
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