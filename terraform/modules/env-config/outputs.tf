# Environment Configuration Module Outputs

# ==============================================================================
# ENVIRONMENT CONFIGURATION
# ==============================================================================

output "environment" {
  description = "현재 환경 정보"
  value = {
    name         = var.environment
    project_name = var.project_name
    region       = data.aws_region.current.name
    account_id   = data.aws_caller_identity.current.account_id
  }
}

# ==============================================================================
# RESOURCE CONFIGURATIONS
# ==============================================================================

output "instance_types" {
  description = "환경별 인스턴스 타입 매핑"
  value = merge(
    local.current_env_config.instance_types,
    var.override_instance_types
  )
}

output "database_config" {
  description = "데이터베이스 설정"
  value = merge(
    local.current_env_config.database,
    var.override_database_config
  )
}

output "monitoring_config" {
  description = "모니터링 설정"
  value = merge(
    local.current_env_config.monitoring,
    var.override_monitoring_config
  )
}

output "security_config" {
  description = "보안 설정"
  value = merge(
    local.current_env_config.security,
    var.override_security_config
  )
}

output "cost_optimization_config" {
  description = "비용 최적화 설정"
  value = local.current_env_config.cost_optimization
}

# ==============================================================================
# NETWORK CONFIGURATIONS
# ==============================================================================

output "network_config" {
  description = "네트워크 설정"
  value = merge(
    local.current_network_config,
    var.override_network_config
  )
}

output "vpc_config" {
  description = "VPC 설정 (모듈에서 직접 사용 가능)"
  value = {
    cidr_block           = coalesce(var.override_network_config.vpc_cidr, local.current_network_config.vpc_cidr)
    enable_dns_hostnames = coalesce(var.override_security_config.vpc_enable_dns_hostnames, local.current_env_config.security.vpc_enable_dns_hostnames)
    enable_dns_support   = coalesce(var.override_security_config.vpc_enable_dns_support, local.current_env_config.security.vpc_enable_dns_support)
    availability_zones   = coalesce(var.override_network_config.availability_zones, local.current_network_config.availability_zones)
  }
}

output "subnet_config" {
  description = "서브넷 설정"
  value = {
    public_cidrs   = coalesce(var.override_network_config.public_subnet_cidrs, local.current_network_config.public_subnet_cidrs)
    private_cidrs  = coalesce(var.override_network_config.private_subnet_cidrs, local.current_network_config.private_subnet_cidrs)
    database_cidrs = coalesce(var.override_network_config.database_subnet_cidrs, local.current_network_config.database_subnet_cidrs)
  }
}

# ==============================================================================
# SERVICE CONFIGURATIONS
# ==============================================================================

output "service_config" {
  description = "서비스별 설정"
  value = merge(
    local.current_service_config,
    var.override_service_config
  )
}

output "ecs_config" {
  description = "ECS 서비스 설정"
  value = merge(
    local.current_service_config.ecs,
    coalesce(var.override_service_config.ecs, {})
  )
}

output "lambda_config" {
  description = "Lambda 함수 설정"
  value = merge(
    local.current_service_config.lambda,
    coalesce(var.override_service_config.lambda, {})
  )
}

output "cache_config" {
  description = "캐시 서비스 설정"
  value = merge(
    local.current_service_config.cache,
    coalesce(var.override_service_config.cache, {})
  )
}

# ==============================================================================
# SHARED RESOURCES
# ==============================================================================

output "shared_kms_key" {
  description = "공유 KMS 키 정보"
  value = var.create_shared_kms_key ? {
    key_id    = aws_kms_key.env_key[0].key_id
    key_arn   = aws_kms_key.env_key[0].arn
    alias_name = aws_kms_alias.env_key_alias[0].name
    alias_arn  = aws_kms_alias.env_key_alias[0].arn
  } : null
}

output "shared_sns_topic" {
  description = "공유 SNS 토픽 정보"
  value = var.create_shared_sns_topic ? {
    topic_arn  = aws_sns_topic.env_notifications[0].arn
    topic_name = aws_sns_topic.env_notifications[0].name
  } : null
}

# ==============================================================================
# TAGGING
# ==============================================================================

output "standard_tags" {
  description = "표준 태그 (모든 리소스에 적용)"
  value       = local.final_tags
}

output "common_tags" {
  description = "공통 태그 (표준 태그의 별칭, 기존 호환성용)"
  value       = local.final_tags
}

# ==============================================================================
# NAMING CONVENTIONS
# ==============================================================================

output "naming_convention" {
  description = "표준 명명 규칙"
  value = {
    prefix              = "${var.project_name}-${var.environment}"
    project_environment = "${var.project_name}-${var.environment}"
    
    # 자주 사용되는 이름 패턴
    patterns = {
      resource_name = "${var.project_name}-${var.environment}-{resource_type}-{specific_name}"
      iam_role     = "${var.project_name}-${var.environment}-{service}-role"
      policy_name  = "${var.project_name}-${var.environment}-{service}-policy"
      sg_name      = "${var.project_name}-${var.environment}-{service}-sg"
      log_group    = "/aws/{service}/${var.project_name}-${var.environment}-{specific_name}"
    }
  }
}

# ==============================================================================
# COMPUTED VALUES
# ==============================================================================

output "computed_values" {
  description = "환경별 계산된 값들"
  value = {
    # 인스턴스 타입 추천
    recommended_instance_type = local.current_env_config.instance_types.medium
    
    # 가용성 영역 목록 (실제 AZ 기준)
    available_azs = slice(data.aws_availability_zones.available.names, 0, 
                         coalesce(var.override_network_config.availability_zones, 
                                local.current_network_config.availability_zones))
    
    # 환경별 특성
    environment_characteristics = {
      is_production     = var.environment == "prod"
      is_development    = var.environment == "dev"
      is_staging       = var.environment == "staging"
      requires_ha      = contains(["staging", "prod"], var.environment)
      cost_sensitive   = var.environment == "dev"
      security_strict  = contains(["staging", "prod"], var.environment)
    }
    
    # 리소스 제한
    resource_limits = {
      max_instances    = local.current_env_config.cost_optimization.auto_scaling_max_size
      min_instances    = local.current_env_config.cost_optimization.auto_scaling_min_size
      backup_retention = local.current_env_config.database.backup_retention_period
      log_retention    = local.current_env_config.monitoring.log_retention_days
    }
  }
}

# ==============================================================================
# INTEGRATION HELPERS
# ==============================================================================

output "integration_config" {
  description = "다른 모듈과의 통합을 위한 설정"
  value = {
    # 모듈 호출 시 자주 사용되는 변수 조합
    module_common_vars = {
      project_name    = var.project_name
      environment     = var.environment
      common_tags     = local.final_tags
      kms_key_id      = var.create_shared_kms_key ? aws_kms_key.env_key[0].arn : null
      sns_topic_arn   = var.create_shared_sns_topic ? aws_sns_topic.env_notifications[0].arn : null
    }
    
    # 모니터링 통합
    monitoring_integration = {
      enable_detailed_monitoring = local.current_env_config.monitoring.detailed_monitoring_enabled
      log_retention_days         = local.current_env_config.monitoring.log_retention_days
      create_dashboards          = local.current_env_config.monitoring.create_dashboards
      alarm_actions             = var.create_shared_sns_topic ? [aws_sns_topic.env_notifications[0].arn] : []
    }
    
    # 보안 통합
    security_integration = {
      enable_encryption = local.current_env_config.security.enable_encryption
      force_ssl        = local.current_env_config.security.force_ssl
      kms_key_arn      = var.create_shared_kms_key ? aws_kms_key.env_key[0].arn : null
    }
  }
}

# ==============================================================================
# VALIDATION OUTPUTS
# ==============================================================================

output "configuration_summary" {
  description = "설정 요약 (검증 및 디버깅용)"
  value = {
    environment_type = var.environment
    total_azs       = length(slice(data.aws_availability_zones.available.names, 0, 
                                  coalesce(var.override_network_config.availability_zones, 
                                          local.current_network_config.availability_zones)))
    
    overrides_applied = {
      instance_types = length(var.override_instance_types) > 0
      database      = length(var.override_database_config) > 0
      monitoring    = length(var.override_monitoring_config) > 0
      security      = length(var.override_security_config) > 0
      network       = length(var.override_network_config) > 0
      services      = length(var.override_service_config) > 0
    }
    
    shared_resources = {
      kms_key_created   = var.create_shared_kms_key
      sns_topic_created = var.create_shared_sns_topic
    }
    
    compliance_requirements = var.compliance_requirements
    feature_flags = {
      cost_optimization    = var.enable_cost_optimization
      advanced_monitoring  = var.enable_advanced_monitoring
      disaster_recovery    = var.enable_disaster_recovery
    }
  }
}