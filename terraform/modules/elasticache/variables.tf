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

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "캐시 서브넷 그룹에 사용할 서브넷 ID 리스트"
  type        = list(string)
  validation {
    condition     = length(var.subnet_ids) >= 1
    error_message = "최소 1개의 서브넷이 필요합니다."
  }
}

# Engine Configuration
variable "engine" {
  description = "캐시 엔진 (redis 또는 memcached)"
  type        = string
  default     = "redis"
  validation {
    condition     = contains(["redis", "memcached"], var.engine)
    error_message = "엔진은 redis 또는 memcached 중 하나여야 합니다."
  }
}

variable "engine_version" {
  description = "엔진 버전"
  type        = string
  default     = "7.0"
}

variable "node_type" {
  description = "노드 타입"
  type        = string
  default     = "cache.t3.micro"
}

variable "num_cache_nodes" {
  description = "캐시 노드 개수"
  type        = number
  default     = 1
  validation {
    condition     = var.num_cache_nodes >= 1 && var.num_cache_nodes <= 20
    error_message = "캐시 노드는 1개 이상 20개 이하로 설정해주세요."
  }
}

variable "port" {
  description = "포트 번호"
  type        = number
  default     = 6379
}

# Network & Security
variable "allowed_security_groups" {
  description = "접근을 허용할 Security Group ID 리스트"
  type        = list(string)
  default     = []
}

variable "allowed_cidr_blocks" {
  description = "접근을 허용할 CIDR 블록 리스트"
  type        = list(string)
  default     = []
}

# Parameter Group
variable "create_parameter_group" {
  description = "Parameter Group 생성 여부"
  type        = bool
  default     = true
}

variable "parameter_group_family" {
  description = "Parameter Group 패밀리"
  type        = string
  default     = "redis7.x"
}

variable "parameter_group_name" {
  description = "기존 Parameter Group 이름 (create_parameter_group가 false일 때 사용)"
  type        = string
  default     = null
}

variable "parameters" {
  description = "캐시 Parameter 설정 리스트"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

# Backup & Maintenance
variable "snapshot_retention_limit" {
  description = "스냅샷 보존 기간 (일) - Redis만 해당"
  type        = number
  default     = 5
  validation {
    condition     = var.snapshot_retention_limit >= 0 && var.snapshot_retention_limit <= 35
    error_message = "스냅샷 보존 기간은 0일 이상 35일 이하로 설정해주세요."
  }
}

variable "snapshot_window" {
  description = "스냅샷 시간대 (UTC) - Redis만 해당"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "유지보수 시간대 (UTC)"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

# Security
variable "at_rest_encryption_enabled" {
  description = "저장 시 암호화 활성화 - Redis만 해당"
  type        = bool
  default     = true
}

variable "transit_encryption_enabled" {
  description = "전송 시 암호화 활성화 - Redis만 해당"
  type        = bool
  default     = true
}

variable "auth_token_enabled" {
  description = "AUTH 토큰 활성화 - Redis만 해당"
  type        = bool
  default     = false
}

variable "auth_token" {
  description = "AUTH 토큰 - Redis만 해당"
  type        = string
  default     = null
  sensitive   = true
}

# High Availability
variable "automatic_failover_enabled" {
  description = "자동 장애 조치 활성화 - Redis만 해당"
  type        = bool
  default     = true
}

variable "multi_az_enabled" {
  description = "Multi-AZ 활성화 - Redis만 해당"
  type        = bool
  default     = false
}

# Monitoring & Alarms
variable "notification_topic_arn" {
  description = "알림 SNS 토픽 ARN"
  type        = string
  default     = null
}

variable "create_cloudwatch_alarms" {
  description = "CloudWatch 알람 생성 여부"
  type        = bool
  default     = true
}

variable "cpu_alarm_threshold" {
  description = "CPU 사용률 알람 임계값 (%)"
  type        = number
  default     = 80
  validation {
    condition     = var.cpu_alarm_threshold > 0 && var.cpu_alarm_threshold <= 100
    error_message = "CPU 알람 임계값은 0-100 범위여야 합니다."
  }
}

variable "memory_alarm_threshold" {
  description = "메모리 사용률 알람 임계값 (%) - Redis만 해당"
  type        = number
  default     = 80
  validation {
    condition     = var.memory_alarm_threshold > 0 && var.memory_alarm_threshold <= 100
    error_message = "메모리 알람 임계값은 0-100 범위여야 합니다."
  }
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