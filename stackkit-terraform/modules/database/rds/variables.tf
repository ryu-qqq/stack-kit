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
  description = "DB 서브넷 그룹에 사용할 서브넷 ID 리스트"
  type        = list(string)
  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "RDS를 위해서는 최소 2개의 서브넷이 필요합니다."
  }
}

# Database Configuration
variable "engine" {
  description = "데이터베이스 엔진"
  type        = string
  default     = "mysql"
  validation {
    condition     = contains(["mysql", "postgres", "mariadb", "oracle-ee", "oracle-se2", "sqlserver-ex", "sqlserver-web", "sqlserver-se", "sqlserver-ee"], var.engine)
    error_message = "지원하는 데이터베이스 엔진을 선택해주세요."
  }
}

variable "engine_version" {
  description = "데이터베이스 엔진 버전"
  type        = string
  default     = "8.0"
}

variable "instance_class" {
  description = "RDS 인스턴스 클래스"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "데이터베이스 이름"
  type        = string
}

variable "username" {
  description = "마스터 사용자 이름"
  type        = string
  default     = "admin"
}

variable "password" {
  description = "마스터 사용자 비밀번호"
  type        = string
  sensitive   = true
}

# Storage Configuration
variable "allocated_storage" {
  description = "초기 할당 스토리지 (GB)"
  type        = number
  default     = 20
  validation {
    condition     = var.allocated_storage >= 20 && var.allocated_storage <= 65536
    error_message = "할당 스토리지는 20GB 이상 65536GB 이하로 설정해주세요."
  }
}

variable "max_allocated_storage" {
  description = "최대 할당 스토리지 (GB) - 자동 스케일링"
  type        = number
  default     = 100
}

variable "storage_type" {
  description = "스토리지 타입"
  type        = string
  default     = "gp2"
  validation {
    condition     = contains(["standard", "gp2", "gp3", "io1", "io2"], var.storage_type)
    error_message = "스토리지 타입은 standard, gp2, gp3, io1, io2 중 하나여야 합니다."
  }
}

variable "storage_encrypted" {
  description = "스토리지 암호화 여부"
  type        = bool
  default     = true
}

# Network & Security
variable "port" {
  description = "데이터베이스 포트"
  type        = number
  default     = 3306
}

variable "publicly_accessible" {
  description = "퍼블릭 액세스 허용 여부"
  type        = bool
  default     = false
}

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
  default     = "mysql8.0"
}

variable "parameter_group_name" {
  description = "기존 Parameter Group 이름 (create_parameter_group가 false일 때 사용)"
  type        = string
  default     = null
}

variable "parameters" {
  description = "DB Parameter 설정 리스트"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

# Backup Configuration
variable "backup_retention_period" {
  description = "백업 보존 기간 (일)"
  type        = number
  default     = 7
  validation {
    condition     = var.backup_retention_period >= 0 && var.backup_retention_period <= 35
    error_message = "백업 보존 기간은 0일 이상 35일 이하로 설정해주세요."
  }
}

variable "backup_window" {
  description = "백업 시간대 (UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "유지보수 시간대 (UTC)"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

# Monitoring
variable "monitoring_interval" {
  description = "Enhanced Monitoring 간격 (초, 0이면 비활성화)"
  type        = number
  default     = 60
  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "모니터링 간격은 0, 1, 5, 10, 15, 30, 60 중 하나여야 합니다."
  }
}

variable "performance_insights_enabled" {
  description = "Performance Insights 활성화"
  type        = bool
  default     = false
}

variable "performance_insights_retention_period" {
  description = "Performance Insights 데이터 보존 기간 (일)"
  type        = number
  default     = 7
  validation {
    condition     = contains([7, 731], var.performance_insights_retention_period)
    error_message = "Performance Insights 보존 기간은 7일 또는 731일이어야 합니다."
  }
}

# Advanced Settings
variable "auto_minor_version_upgrade" {
  description = "자동 마이너 버전 업그레이드"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "삭제 보호"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "최종 스냅샷 생성 건너뛰기"
  type        = bool
  default     = false
}

# Read Replica
variable "create_read_replica" {
  description = "읽기 전용 복제본 생성 여부"
  type        = bool
  default     = false
}

variable "replica_instance_class" {
  description = "읽기 전용 복제본 인스턴스 클래스"
  type        = string
  default     = "db.t3.micro"
}

variable "common_tags" {
  description = "모든 리소스에 적용할 공통 태그"
  type        = map(string)
  default     = {}
}