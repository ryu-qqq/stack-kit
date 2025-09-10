# ==============================================================================
# ENVIRONMENT CONFIGURATION MODULE OUTPUTS - Enhanced Integration
# ==============================================================================

# Environment Configurations
output "environment_config" {
  description = "현재 환경 설정"
  value       = local.current_env_config
}

output "network_config" {
  description = "네트워크 설정"
  value       = local.current_network_config
}

output "service_config" {
  description = "서비스별 설정"
  value       = local.current_service_config
}

# Standard Tags
output "standard_tags" {
  description = "표준 태그"
  value       = local.standard_tags
}

output "final_tags" {
  description = "최종 태그 (사용자 정의 태그 포함)"
  value       = local.final_tags
}

# Shared Resources
output "shared_kms_key" {
  description = "공유 KMS 키 정보"
  value = var.create_shared_kms_key ? {
    id          = aws_kms_key.env_key[0].id
    arn         = aws_kms_key.env_key[0].arn
    alias_name  = aws_kms_alias.env_key_alias[0].name
    alias_arn   = aws_kms_alias.env_key_alias[0].arn
  } : null
}

output "shared_sns_topic" {
  description = "공유 SNS 토픽 정보"
  value = var.create_shared_sns_topic ? {
    arn          = aws_sns_topic.env_notifications[0].arn
    name         = aws_sns_topic.env_notifications[0].name
    display_name = aws_sns_topic.env_notifications[0].display_name
  } : null
}

# AWS Context
output "aws_context" {
  description = "AWS 컨텍스트 정보"
  value = {
    account_id         = data.aws_caller_identity.current.account_id
    region            = data.aws_region.current.name
    availability_zones = data.aws_availability_zones.available.names
  }
}

# ==============================================================================
# MODULE INTEGRATION HELPERS
# ==============================================================================

# For VPC Module Integration
output "vpc_integration" {
  description = "VPC 모듈 통합을 위한 설정"
  value = {
    # Network configuration
    vpc_cidr               = local.current_network_config.vpc_cidr
    availability_zones     = local.current_network_config.availability_zones
    public_subnet_cidrs    = local.current_network_config.public_subnet_cidrs
    private_subnet_cidrs   = local.current_network_config.private_subnet_cidrs
    database_subnet_cidrs  = local.current_network_config.database_subnet_cidrs
    enable_nat_gateway     = local.current_network_config.enable_nat_gateway
    single_nat_gateway     = local.current_network_config.single_nat_gateway
    
    # Security settings
    enable_dns_hostnames   = local.current_env_config.security.vpc_enable_dns_hostnames
    enable_dns_support     = local.current_env_config.security.vpc_enable_dns_support
    enable_flow_logs       = local.current_env_config.security.enable_flow_logs
    
    # Common settings
    project_name = var.project_name
    environment  = var.environment
    common_tags  = local.final_tags
  }
}

# For RDS Module Integration
output "rds_integration" {
  description = "RDS 모듈 통합을 위한 설정"
  value = {
    # Database configuration
    instance_class           = local.current_env_config.database.instance_class
    allocated_storage       = local.current_env_config.database.allocated_storage
    backup_retention_period = local.current_env_config.database.backup_retention_period
    multi_az               = local.current_env_config.database.multi_az
    deletion_protection    = local.current_env_config.database.deletion_protection
    skip_final_snapshot    = local.current_env_config.database.skip_final_snapshot
    
    # Security settings
    encryption_enabled = local.current_env_config.security.enable_encryption
    kms_key_id        = var.create_shared_kms_key ? aws_kms_key.env_key[0].arn : null
    
    # Monitoring
    monitoring_interval = local.current_env_config.monitoring.detailed_monitoring_enabled ? 60 : 0
    log_retention_days = local.current_env_config.monitoring.log_retention_days
    create_alarms     = local.current_env_config.monitoring.create_dashboards
    
    # Common settings
    project_name = var.project_name
    environment  = var.environment
    common_tags  = local.final_tags
  }
}

# For ECS Module Integration
output "ecs_integration" {
  description = "ECS 모듈 통합을 위한 설정"
  value = {
    # ECS configuration
    cpu                = local.current_service_config.ecs.cpu
    memory             = local.current_service_config.ecs.memory
    desired_count      = local.current_service_config.ecs.desired_count
    min_capacity       = local.current_service_config.ecs.min_capacity
    max_capacity       = local.current_service_config.ecs.max_capacity
    enable_auto_scaling = local.current_service_config.ecs.enable_auto_scaling
    
    # Instance configuration
    instance_types = local.current_env_config.instance_types
    
    # Monitoring
    detailed_monitoring = local.current_env_config.monitoring.detailed_monitoring_enabled
    log_retention_days = local.current_env_config.monitoring.log_retention_days
    
    # Security
    encryption_enabled = local.current_env_config.security.enable_encryption
    kms_key_id        = var.create_shared_kms_key ? aws_kms_key.env_key[0].arn : null
    
    # Common settings
    project_name = var.project_name
    environment  = var.environment
    common_tags  = local.final_tags
  }
}

# For Lambda Module Integration
output "lambda_integration" {
  description = "Lambda 모듈 통합을 위한 설정"
  value = {
    # Lambda configuration
    timeout                = local.current_service_config.lambda.timeout
    memory_size           = local.current_service_config.lambda.memory_size
    reserved_concurrency  = local.current_service_config.lambda.reserved_concurrency
    dead_letter_queue    = local.current_service_config.lambda.dead_letter_queue
    enable_xray_tracing  = local.current_service_config.lambda.enable_xray_tracing
    
    # Monitoring
    log_retention_days = local.current_env_config.monitoring.log_retention_days
    
    # Security
    kms_key_id = var.create_shared_kms_key ? aws_kms_key.env_key[0].arn : null
    
    # Common settings
    project_name = var.project_name
    environment  = var.environment
    common_tags  = local.final_tags
  }
}

# For ElastiCache Module Integration
output "elasticache_integration" {
  description = "ElastiCache 모듈 통합을 위한 설정"
  value = {
    # Cache configuration
    node_type                 = local.current_service_config.cache.node_type
    num_cache_nodes          = local.current_service_config.cache.num_cache_nodes
    parameter_group_family   = local.current_service_config.cache.parameter_group_family
    at_rest_encryption_enabled = local.current_service_config.cache.at_rest_encryption_enabled
    transit_encryption_enabled = local.current_service_config.cache.transit_encryption_enabled
    
    # Security
    kms_key_id = var.create_shared_kms_key ? aws_kms_key.env_key[0].arn : null
    
    # Monitoring
    log_retention_days = local.current_env_config.monitoring.log_retention_days
    
    # Common settings
    project_name = var.project_name
    environment  = var.environment
    common_tags  = local.final_tags
  }
}

# For KMS Module Integration
output "kms_integration" {
  description = "KMS 모듈 통합을 위한 설정"
  value = {
    # Key configuration
    enable_key_rotation     = true
    deletion_window_in_days = var.environment == "prod" ? 30 : 7
    multi_region           = var.environment == "prod" ? true : false
    
    # Monitoring
    enable_logging         = local.current_env_config.monitoring.create_dashboards
    log_retention_in_days  = local.current_env_config.monitoring.log_retention_days
    create_cloudwatch_alarms = local.current_env_config.monitoring.create_dashboards
    alarm_actions          = var.create_shared_sns_topic ? [aws_sns_topic.env_notifications[0].arn] : []
    
    # Common settings
    project_name = var.project_name
    environment  = var.environment
    common_tags  = local.final_tags
  }
}

# For EventBridge Module Integration
output "eventbridge_integration" {
  description = "EventBridge 모듈 통합을 위한 설정"
  value = {
    # EventBridge configuration
    kms_key_id = var.create_shared_kms_key ? aws_kms_key.env_key[0].arn : null
    
    # Monitoring
    create_cloudwatch_alarms = local.current_env_config.monitoring.create_dashboards
    alarm_actions           = var.create_shared_sns_topic ? [aws_sns_topic.env_notifications[0].arn] : []
    
    # Common settings
    project_name = var.project_name
    environment  = var.environment
    common_tags  = local.final_tags
  }
}

# For Monitoring Integration
output "monitoring_integration" {
  description = "모니터링 통합을 위한 설정"
  value = {
    # Monitoring settings
    detailed_monitoring_enabled = local.current_env_config.monitoring.detailed_monitoring_enabled
    log_retention_days         = local.current_env_config.monitoring.log_retention_days
    create_dashboards          = local.current_env_config.monitoring.create_dashboards
    alarm_evaluation_periods   = local.current_env_config.monitoring.alarm_evaluation_periods
    alarm_threshold_multiplier = local.current_env_config.monitoring.alarm_threshold_multiplier
    
    # Notification settings
    notification_topic_arn = var.create_shared_sns_topic ? aws_sns_topic.env_notifications[0].arn : null
    
    # Security
    kms_key_id = var.create_shared_kms_key ? aws_kms_key.env_key[0].arn : null
    
    # Common settings
    project_name = var.project_name
    environment  = var.environment
    common_tags  = local.final_tags
  }
}

# ==============================================================================
# CROSS-MODULE RESOURCE REFERENCES
# ==============================================================================

# Resource ARNs for cross-module references
output "resource_references" {
  description = "다른 모듈에서 참조할 수 있는 리소스 ARN"
  value = {
    shared_kms_key_arn = var.create_shared_kms_key ? aws_kms_key.env_key[0].arn : null
    shared_kms_key_id  = var.create_shared_kms_key ? aws_kms_key.env_key[0].id : null
    shared_kms_alias   = var.create_shared_kms_key ? aws_kms_alias.env_key_alias[0].name : null
    
    notification_topic_arn = var.create_shared_sns_topic ? aws_sns_topic.env_notifications[0].arn : null
    
    # AWS context
    account_id = data.aws_caller_identity.current.account_id
    region     = data.aws_region.current.name
  }
}

# Environment Summary
output "environment_summary" {
  description = "환경 구성 요약 정보"
  value = {
    environment    = var.environment
    project_name   = var.project_name
    account_id     = data.aws_caller_identity.current.account_id
    region         = data.aws_region.current.name
    
    # Capabilities enabled
    shared_kms_enabled = var.create_shared_kms_key
    shared_sns_enabled = var.create_shared_sns_topic
    
    # Environment characteristics
    is_production       = var.environment == "prod"
    multi_az_enabled    = local.current_env_config.database.multi_az
    encryption_enabled  = local.current_env_config.security.enable_encryption
    monitoring_enabled  = local.current_env_config.monitoring.create_dashboards
    
    # Resource sizing tier
    size_tier = var.environment == "dev" ? "small" : var.environment == "staging" ? "medium" : "large"
  }
}