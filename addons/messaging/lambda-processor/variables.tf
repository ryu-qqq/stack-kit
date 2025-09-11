# Lambda Processor Messaging Addon - Variables
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

variable "function_name" {
  description = "Lambda 함수 이름"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.function_name))
    error_message = "함수 이름은 영문자, 숫자, 하이픈, 언더스코어만 포함할 수 있습니다."
  }
}

# Lambda Function Configuration
variable "handler" {
  description = "Lambda 함수 핸들러"
  type        = string
  default     = "index.handler"
}

variable "runtime" {
  description = "Lambda 런타임"
  type        = string
  default     = "python3.11"
  validation {
    condition = contains([
      "nodejs18.x", "nodejs16.x", "nodejs20.x",
      "python3.11", "python3.10", "python3.9", "python3.8",
      "java17", "java11", "java21",
      "dotnet6", "dotnet8",
      "go1.x",
      "ruby3.2", "ruby3.3",
      "provided.al2", "provided.al2023"
    ], var.runtime)
    error_message = "지원되는 런타임을 선택해주세요."
  }
}

variable "architectures" {
  description = "Lambda 함수 아키텍처"
  type        = list(string)
  default     = ["x86_64"]
  validation {
    condition = alltrue([
      for arch in var.architectures : contains(["x86_64", "arm64"], arch)
    ])
    error_message = "아키텍처는 x86_64 또는 arm64 중 하나여야 합니다."
  }
}

variable "memory_size" {
  description = "Lambda 함수 메모리 크기 (MB)"
  type        = number
  default     = 512
  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 10240
    error_message = "메모리 크기는 128MB 이상 10240MB 이하로 설정해주세요."
  }
}

variable "timeout" {
  description = "Lambda 함수 타임아웃 (초)"
  type        = number
  default     = 60
  validation {
    condition     = var.timeout >= 1 && var.timeout <= 900
    error_message = "타임아웃은 1초 이상 900초 이하로 설정해주세요."
  }
}

variable "reserved_concurrent_executions" {
  description = "예약된 동시 실행 수"
  type        = number
  default     = null
}

variable "publish" {
  description = "함수 버전 게시 여부"
  type        = bool
  default     = false
}

# Package Configuration
variable "package_type" {
  description = "패키지 타입 (Zip 또는 Image)"
  type        = string
  default     = "Zip"
  validation {
    condition     = contains(["Zip", "Image"], var.package_type)
    error_message = "패키지 타입은 Zip 또는 Image 중 하나여야 합니다."
  }
}

variable "filename" {
  description = "배포 패키지 파일 경로 (Zip 패키지용)"
  type        = string
  default     = null
}

variable "s3_bucket" {
  description = "배포 패키지 S3 버킷 (Zip 패키지용)"
  type        = string
  default     = null
}

variable "s3_key" {
  description = "배포 패키지 S3 키 (Zip 패키지용)"
  type        = string
  default     = null
}

variable "s3_object_version" {
  description = "배포 패키지 S3 객체 버전 (Zip 패키지용)"
  type        = string
  default     = null
}

variable "image_uri" {
  description = "컨테이너 이미지 URI (Image 패키지용)"
  type        = string
  default     = null
}

variable "source_code_hash" {
  description = "소스 코드 해시"
  type        = string
  default     = null
}

# Environment Configuration
variable "environment_variables" {
  description = "환경 변수"
  type        = map(string)
  default     = {}
}

variable "kms_key_arn" {
  description = "환경 변수 암호화용 KMS 키 ARN"
  type        = string
  default     = null
}

# VPC Configuration
variable "vpc_config" {
  description = "VPC 설정"
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}

# Dead Letter Queue
variable "dead_letter_queue_arn" {
  description = "데드 레터 큐 ARN"
  type        = string
  default     = null
}

# X-Ray Tracing
variable "tracing_mode" {
  description = "X-Ray 추적 모드"
  type        = string
  default     = "PassThrough"
  validation {
    condition     = contains(["Active", "PassThrough"], var.tracing_mode)
    error_message = "추적 모드는 Active 또는 PassThrough 중 하나여야 합니다."
  }
}

# Lambda Layers
variable "layers" {
  description = "Lambda 레이어 ARN 리스트"
  type        = list(string)
  default     = []
}

# Message Processing Configuration
variable "sqs_config" {
  description = "SQS 이벤트 소스 설정"
  type = object({
    queue_arn                          = string
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

variable "sns_config" {
  description = "SNS 구독 설정"
  type = object({
    topic_arns = list(string)
  })
  default = null
}

variable "eventbridge_config" {
  description = "EventBridge 규칙 설정"
  type = object({
    rule_arns = list(string)
  })
  default = null
}

# AWS Service Integration
variable "dynamodb_config" {
  description = "DynamoDB 액세스 설정"
  type = object({
    table_arns = list(string)
  })
  default = null
}

variable "s3_config" {
  description = "S3 액세스 설정"
  type = object({
    bucket_arns = list(string)
  })
  default = null
}

# IAM Configuration
variable "additional_iam_policies" {
  description = "추가 IAM 정책 스테이트먼트"
  type = list(object({
    Effect   = string
    Action   = list(string)
    Resource = list(string)
    Condition = optional(map(any))
  }))
  default = []
}

# Logging Configuration
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

# Monitoring Configuration
variable "enable_monitoring" {
  description = "CloudWatch 모니터링 활성화"
  type        = bool
  default     = true
}

variable "monitoring_config" {
  description = "모니터링 설정"
  type = object({
    evaluation_periods                  = optional(number, 2)
    period                             = optional(number, 300)
    error_threshold                    = optional(number, 1)
    duration_threshold                 = optional(number, 30000)  # 30 seconds in ms
    throttle_threshold                 = optional(number, 1)
    concurrent_executions_threshold    = optional(number, 100)
    create_concurrency_alarm          = optional(bool, false)
    alarm_actions                      = optional(list(string), [])
    ok_actions                         = optional(list(string), [])
  })
  default = {}
}

variable "create_dashboard" {
  description = "CloudWatch 대시보드 생성 여부"
  type        = bool
  default     = false
}

# Processing Configuration
variable "processing_config" {
  description = "메시지 처리 설정"
  type = object({
    max_retry_attempts     = optional(number, 3)
    retry_delay_seconds   = optional(number, 60)
    batch_processing      = optional(bool, true)
    parallel_processing   = optional(bool, false)
    enable_dlq_processing = optional(bool, true)
  })
  default = {}
}

# Performance Configuration
variable "performance_config" {
  description = "성능 최적화 설정"
  type = object({
    provisioned_concurrency = optional(number, null)
    enable_snapstart       = optional(bool, false)  # Java only
    optimize_cold_start     = optional(bool, true)
  })
  default = {}
}

# Security Configuration
variable "security_config" {
  description = "보안 설정"
  type = object({
    enable_function_url   = optional(bool, false)
    function_url_auth     = optional(string, "AWS_IAM")
    enable_code_signing   = optional(bool, false)
    code_signing_config_arn = optional(string, null)
  })
  default = {}
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