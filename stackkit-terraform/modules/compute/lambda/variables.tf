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

variable "function_name" {
  description = "Lambda 함수 이름"
  type        = string
}

variable "handler" {
  description = "Lambda 함수 핸들러"
  type        = string
  default     = "index.handler"
}

variable "runtime" {
  description = "Lambda 런타임"
  type        = string
  default     = "python3.9"
  validation {
    condition = contains([
      "nodejs18.x", "nodejs16.x", "nodejs14.x",
      "python3.11", "python3.10", "python3.9", "python3.8",
      "java17", "java11", "java8.al2",
      "dotnet6", "dotnet7",
      "go1.x",
      "ruby3.2", "ruby2.7",
      "provided.al2", "provided"
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
  default     = 128
  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 10240
    error_message = "메모리 크기는 128MB 이상 10240MB 이하로 설정해주세요."
  }
}

variable "timeout" {
  description = "Lambda 함수 타임아웃 (초)"
  type        = number
  default     = 3
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
  default     = null
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

# Tracing
variable "tracing_mode" {
  description = "X-Ray 추적 모드"
  type        = string
  default     = "PassThrough"
  validation {
    condition     = contains(["Active", "PassThrough"], var.tracing_mode)
    error_message = "추적 모드는 Active 또는 PassThrough 중 하나여야 합니다."
  }
}

# File System
variable "file_system_config" {
  description = "EFS 파일 시스템 설정"
  type = list(object({
    arn              = string
    local_mount_path = string
  }))
  default = []
}

# Image Configuration (for container images)
variable "image_config" {
  description = "컨테이너 이미지 설정"
  type = object({
    entry_point       = list(string)
    command          = list(string)
    working_directory = string
  })
  default = null
}

# Layers
variable "layers" {
  description = "Lambda 레이어 ARN 리스트"
  type        = list(string)
  default     = []
}

# IAM Configuration
variable "additional_iam_policy" {
  description = "추가 IAM 정책 (JSON)"
  type        = string
  default     = null
}

# Lambda Permissions
variable "lambda_permissions" {
  description = "Lambda 함수 권한 설정"
  type = list(object({
    statement_id   = string
    action        = string
    principal     = string
    source_arn    = string
    source_account = string
  }))
  default = []
}

# Function URL
variable "create_function_url" {
  description = "Lambda 함수 URL 생성 여부"
  type        = bool
  default     = false
}

variable "function_url_auth_type" {
  description = "함수 URL 인증 타입"
  type        = string
  default     = "AWS_IAM"
  validation {
    condition     = contains(["AWS_IAM", "NONE"], var.function_url_auth_type)
    error_message = "인증 타입은 AWS_IAM 또는 NONE 중 하나여야 합니다."
  }
}

variable "function_url_cors" {
  description = "함수 URL CORS 설정"
  type = object({
    allow_credentials = bool
    allow_headers     = list(string)
    allow_methods     = list(string)
    allow_origins     = list(string)
    expose_headers    = list(string)
    max_age          = number
  })
  default = null
}

# Alias Configuration
variable "create_alias" {
  description = "Lambda 별칭 생성 여부"
  type        = bool
  default     = false
}

variable "alias_name" {
  description = "Lambda 별칭 이름"
  type        = string
  default     = "live"
}

variable "alias_function_version" {
  description = "별칭이 가리킬 함수 버전"
  type        = string
  default     = null
}

variable "alias_routing_config" {
  description = "별칭 라우팅 설정 (가중치 기반 트래픽 분산)"
  type = object({
    additional_version_weights = map(number)
  })
  default = null
}

# Logging
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

# Monitoring & Alarms
variable "create_cloudwatch_alarms" {
  description = "CloudWatch 알람 생성 여부"
  type        = bool
  default     = true
}

variable "error_alarm_threshold" {
  description = "에러 알람 임계값"
  type        = number
  default     = 1
}

variable "duration_alarm_threshold" {
  description = "실행 시간 알람 임계값 (밀리초)"
  type        = number
  default     = 5000
}

variable "throttle_alarm_threshold" {
  description = "스로틀 알람 임계값"
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