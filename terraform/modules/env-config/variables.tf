# Environment Configuration Module Variables

# ==============================================================================
# REQUIRED VARIABLES
# ==============================================================================

variable "project_name" {
  description = "프로젝트 이름"
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

# ==============================================================================
# ORGANIZATION VARIABLES
# ==============================================================================

variable "cost_center" {
  description = "비용 센터 (태깅용)"
  type        = string
  default     = "engineering"
}

variable "owner_team" {
  description = "소유 팀 (태깅용)"
  type        = string
  default     = "platform"
}

variable "additional_tags" {
  description = "추가 태그 (환경별 표준 태그와 병합됨)"
  type        = map(string)
  default     = {}
}

# ==============================================================================
# SHARED RESOURCES CONFIGURATION
# ==============================================================================

variable "create_shared_kms_key" {
  description = "환경 공유 KMS 키 생성 여부"
  type        = bool
  default     = true
}

variable "create_shared_sns_topic" {
  description = "환경 공유 SNS 토픽 생성 여부"
  type        = bool
  default     = true
}

# ==============================================================================
# CONFIGURATION OVERRIDES
# ==============================================================================

variable "override_instance_types" {
  description = "인스턴스 타입 오버라이드 (환경 기본값을 덮어씀)"
  type = object({
    small  = optional(string)
    medium = optional(string)
    large  = optional(string)
    xlarge = optional(string)
  })
  default = {}
}

variable "override_database_config" {
  description = "데이터베이스 설정 오버라이드"
  type = object({
    instance_class           = optional(string)
    allocated_storage       = optional(number)
    backup_retention_period = optional(number)
    multi_az               = optional(bool)
    deletion_protection    = optional(bool)
    skip_final_snapshot    = optional(bool)
  })
  default = {}
}

variable "override_monitoring_config" {
  description = "모니터링 설정 오버라이드"
  type = object({
    detailed_monitoring_enabled = optional(bool)
    log_retention_days         = optional(number)
    create_dashboards          = optional(bool)
    alarm_evaluation_periods   = optional(number)
    alarm_threshold_multiplier = optional(number)
  })
  default = {}
}

variable "override_security_config" {
  description = "보안 설정 오버라이드"
  type = object({
    enable_encryption        = optional(bool)
    force_ssl               = optional(bool)
    enable_cloudtrail       = optional(bool)
    vpc_enable_dns_hostnames = optional(bool)
    vpc_enable_dns_support   = optional(bool)
    enable_flow_logs        = optional(bool)
  })
  default = {}
}

variable "override_network_config" {
  description = "네트워크 설정 오버라이드"
  type = object({
    vpc_cidr             = optional(string)
    availability_zones   = optional(number)
    public_subnet_cidrs  = optional(list(string))
    private_subnet_cidrs = optional(list(string))
    database_subnet_cidrs = optional(list(string))
    enable_nat_gateway   = optional(bool)
    single_nat_gateway   = optional(bool)
  })
  default = {}
}

variable "override_service_config" {
  description = "서비스 설정 오버라이드"
  type = object({
    ecs = optional(object({
      cpu                = optional(number)
      memory             = optional(number)
      desired_count      = optional(number)
      min_capacity       = optional(number)
      max_capacity       = optional(number)
      enable_auto_scaling = optional(bool)
    }))
    lambda = optional(object({
      timeout                = optional(number)
      memory_size           = optional(number)
      reserved_concurrency  = optional(number)
      dead_letter_queue    = optional(bool)
      enable_xray_tracing  = optional(bool)
    }))
    cache = optional(object({
      node_type                 = optional(string)
      num_cache_nodes          = optional(number)
      parameter_group_family   = optional(string)
      at_rest_encryption_enabled = optional(bool)
      transit_encryption_enabled = optional(bool)
    }))
  })
  default = {}
}

# ==============================================================================
# FEATURE FLAGS
# ==============================================================================

variable "enable_cost_optimization" {
  description = "비용 최적화 기능 활성화"
  type        = bool
  default     = true
}

variable "enable_advanced_monitoring" {
  description = "고급 모니터링 기능 활성화"
  type        = bool
  default     = null # Will use environment default
}

variable "enable_disaster_recovery" {
  description = "재해복구 기능 활성화"
  type        = bool
  default     = null # Will use environment default
}

variable "compliance_requirements" {
  description = "준수해야 할 컴플라이언스 요구사항"
  type        = list(string)
  default     = []
  
  validation {
    condition = alltrue([
      for req in var.compliance_requirements : contains(["SOC2", "HIPAA", "PCI-DSS", "GDPR", "ISO27001"], req)
    ])
    error_message = "유효한 컴플라이언스 요구사항을 선택해주세요: SOC2, HIPAA, PCI-DSS, GDPR, ISO27001"
  }
}

# ==============================================================================
# REGIONAL SETTINGS
# ==============================================================================

variable "region_preferences" {
  description = "리전별 선호도 설정"
  type = object({
    primary_region   = optional(string)
    secondary_region = optional(string)
    multi_region     = optional(bool, false)
  })
  default = {}
}

# ==============================================================================
# INTEGRATION SETTINGS
# ==============================================================================

variable "external_integrations" {
  description = "외부 시스템 통합 설정"
  type = object({
    enable_datadog    = optional(bool, false)
    enable_newrelic   = optional(bool, false)
    enable_splunk     = optional(bool, false)
    enable_elasticsearch = optional(bool, false)
  })
  default = {}
}