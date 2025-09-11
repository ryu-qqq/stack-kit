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

variable "table_name" {
  description = "DynamoDB 테이블 이름"
  type        = string
}

variable "billing_mode" {
  description = "청구 모드 (PROVISIONED 또는 PAY_PER_REQUEST)"
  type        = string
  default     = "PAY_PER_REQUEST"
  validation {
    condition     = contains(["PROVISIONED", "PAY_PER_REQUEST"], var.billing_mode)
    error_message = "청구 모드는 PROVISIONED 또는 PAY_PER_REQUEST 중 하나여야 합니다."
  }
}

variable "hash_key" {
  description = "해시 키 (파티션 키)"
  type        = string
}

variable "range_key" {
  description = "레인지 키 (정렬 키)"
  type        = string
  default     = null
}

variable "attributes" {
  description = "테이블 속성 정의"
  type = list(object({
    name = string
    type = string
  }))
  validation {
    condition = alltrue([
      for attr in var.attributes : contains(["S", "N", "B"], attr.type)
    ])
    error_message = "속성 타입은 S(String), N(Number), B(Binary) 중 하나여야 합니다."
  }
}

# Capacity Configuration
variable "read_capacity" {
  description = "읽기 용량 단위 (PROVISIONED 모드에서만 사용)"
  type        = number
  default     = 5
}

variable "write_capacity" {
  description = "쓰기 용량 단위 (PROVISIONED 모드에서만 사용)"
  type        = number
  default     = 5
}

# Global Secondary Indexes
variable "global_secondary_indexes" {
  description = "글로벌 보조 인덱스 설정"
  type = list(object({
    name               = string
    hash_key           = string
    range_key          = string
    projection_type    = string
    non_key_attributes = list(string)
    read_capacity      = number
    write_capacity     = number
  }))
  default = []
}

# Local Secondary Indexes
variable "local_secondary_indexes" {
  description = "로컬 보조 인덱스 설정"
  type = list(object({
    name               = string
    range_key          = string
    projection_type    = string
    non_key_attributes = list(string)
  }))
  default = []
}

# TTL Configuration
variable "ttl_enabled" {
  description = "TTL(Time To Live) 활성화"
  type        = bool
  default     = false
}

variable "ttl_attribute_name" {
  description = "TTL 속성 이름"
  type        = string
  default     = null
}

# Backup & Recovery
variable "point_in_time_recovery_enabled" {
  description = "특정 시점 복구 활성화"
  type        = bool
  default     = true
}

variable "deletion_protection_enabled" {
  description = "삭제 보호 활성화"
  type        = bool
  default     = true
}

# Encryption
variable "server_side_encryption_enabled" {
  description = "서버측 암호화 활성화"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS 키 ID (지정하지 않으면 AWS 관리형 키 사용)"
  type        = string
  default     = null
}

# Streams
variable "stream_enabled" {
  description = "DynamoDB Streams 활성화"
  type        = bool
  default     = false
}

variable "stream_view_type" {
  description = "스트림 뷰 타입"
  type        = string
  default     = "NEW_AND_OLD_IMAGES"
  validation {
    condition = contains([
      "KEYS_ONLY",
      "NEW_IMAGE", 
      "OLD_IMAGE",
      "NEW_AND_OLD_IMAGES"
    ], var.stream_view_type)
    error_message = "유효한 스트림 뷰 타입을 선택해주세요."
  }
}

# Table Class
variable "table_class" {
  description = "테이블 클래스"
  type        = string
  default     = "STANDARD"
  validation {
    condition     = contains(["STANDARD", "STANDARD_INFREQUENT_ACCESS"], var.table_class)
    error_message = "테이블 클래스는 STANDARD 또는 STANDARD_INFREQUENT_ACCESS 중 하나여야 합니다."
  }
}

# Auto Scaling
variable "enable_autoscaling" {
  description = "Auto Scaling 활성화 (PROVISIONED 모드에서만)"
  type        = bool
  default     = true
}

variable "autoscaling_read_min_capacity" {
  description = "Auto Scaling 읽기 최소 용량"
  type        = number
  default     = 5
}

variable "autoscaling_read_max_capacity" {
  description = "Auto Scaling 읽기 최대 용량"
  type        = number
  default     = 100
}

variable "autoscaling_write_min_capacity" {
  description = "Auto Scaling 쓰기 최소 용량"
  type        = number
  default     = 5
}

variable "autoscaling_write_max_capacity" {
  description = "Auto Scaling 쓰기 최대 용량"
  type        = number
  default     = 100
}

variable "autoscaling_read_target_value" {
  description = "Auto Scaling 읽기 목표 사용률 (%)"
  type        = number
  default     = 70
}

variable "autoscaling_write_target_value" {
  description = "Auto Scaling 쓰기 목표 사용률 (%)"
  type        = number
  default     = 70
}

# Backup Configuration
variable "enable_backup" {
  description = "AWS Backup 활성화"
  type        = bool
  default     = false
}

variable "backup_schedule" {
  description = "백업 스케줄 (cron 표현식)"
  type        = string
  default     = "cron(0 5 ? * * *)"  # Daily at 5 AM UTC
}

variable "backup_kms_key_id" {
  description = "백업용 KMS 키 ID"
  type        = string
  default     = null
}

variable "backup_cold_storage_after" {
  description = "콜드 스토리지 이전 일수"
  type        = number
  default     = 30
}

variable "backup_delete_after" {
  description = "백업 삭제까지의 일수"
  type        = number
  default     = 120
}

# Monitoring & Alarms
variable "create_cloudwatch_alarms" {
  description = "CloudWatch 알람 생성 여부"
  type        = bool
  default     = true
}

variable "alarm_actions" {
  description = "알람 액션 ARN 리스트"
  type        = list(string)
  default     = []
}

variable "read_throttle_alarm_threshold" {
  description = "읽기 스로틀 알람 임계값"
  type        = number
  default     = 0
}

variable "write_throttle_alarm_threshold" {
  description = "쓰기 스로틀 알람 임계값"
  type        = number
  default     = 0
}

variable "common_tags" {
  description = "모든 리소스에 적용할 공통 태그"
  type        = map(string)
  default     = {}
}