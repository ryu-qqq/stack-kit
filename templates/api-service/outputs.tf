# Outputs for API Service Template - StackKit v2

# =============================================================================
# Network Outputs
# =============================================================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = var.use_existing_vpc ? data.aws_vpc.existing[0].id : module.vpc[0].vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = var.use_existing_vpc ? data.aws_subnets.existing_public[0].ids : module.vpc[0].public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = var.use_existing_vpc ? data.aws_subnets.existing_private[0].ids : module.vpc[0].private_subnet_ids
}

output "database_subnet_ids" {
  description = "IDs of the database subnets"
  value       = var.use_existing_vpc ? [] : module.vpc[0].database_subnet_ids
}

# =============================================================================
# Load Balancer Outputs
# =============================================================================

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = module.alb.alb_zone_id
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.alb.alb_arn
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = module.alb.target_group_arn
}

# =============================================================================
# ECS Outputs
# =============================================================================

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs_service.cluster_name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = module.ecs_service.cluster_arn
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = module.ecs_service.service_name
}

output "ecs_service_arn" {
  description = "ARN of the ECS service"
  value       = module.ecs_service.service_arn
}

output "ecs_task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = module.ecs_service.task_definition_arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role"
  value       = module.ecs_service.task_role_arn
}

output "ecs_execution_role_arn" {
  description = "ARN of the ECS execution role"
  value       = module.ecs_service.execution_role_arn
}

# =============================================================================
# Database Outputs (Conditional)
# =============================================================================

output "database_endpoint" {
  description = "RDS instance endpoint"
  value       = var.enable_database ? module.database[0].db_instance_endpoint : null
  sensitive   = true
}

output "database_port" {
  description = "RDS instance port"
  value       = var.enable_database ? module.database[0].db_instance_port : null
}

output "database_id" {
  description = "RDS instance ID"
  value       = var.enable_database ? module.database[0].db_instance_id : null
}

output "database_arn" {
  description = "RDS instance ARN"
  value       = var.enable_database ? module.database[0].db_instance_arn : null
}

output "database_name" {
  description = "Database name"
  value       = var.enable_database ? var.db_name : null
}

# =============================================================================
# Redis Outputs (Conditional)
# =============================================================================

output "redis_endpoint" {
  description = "Redis cluster endpoint"
  value       = var.enable_redis ? module.redis[0].cache_cluster_address : null
  sensitive   = true
}

output "redis_port" {
  description = "Redis port"
  value       = var.enable_redis ? module.redis[0].cache_cluster_port : null
}

output "redis_cluster_id" {
  description = "Redis cluster ID"
  value       = var.enable_redis ? module.redis[0].cache_cluster_id : null
}

# =============================================================================
# S3 Outputs (Conditional)
# =============================================================================

output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = var.enable_s3_bucket ? module.s3_bucket[0].bucket_name : null
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = var.enable_s3_bucket ? module.s3_bucket[0].bucket_arn : null
}

output "s3_bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = var.enable_s3_bucket ? module.s3_bucket[0].bucket_domain_name : null
}

# =============================================================================
# Monitoring Outputs
# =============================================================================

output "cloudwatch_dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = var.create_cloudwatch_dashboard ? module.monitoring.dashboard_url : null
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = module.ecs_service.log_group_name
}

# =============================================================================
# Application Access Information
# =============================================================================

output "application_url" {
  description = "URL to access the application"
  value       = var.ssl_certificate_arn != "" ? "https://${module.alb.alb_dns_name}" : "http://${module.alb.alb_dns_name}"
}

output "health_check_url" {
  description = "Health check URL"
  value       = var.ssl_certificate_arn != "" ? "https://${module.alb.alb_dns_name}${var.health_check_path}" : "http://${module.alb.alb_dns_name}${var.health_check_path}"
}

# =============================================================================
# Security Information
# =============================================================================

output "ecs_security_group_id" {
  description = "ID of the ECS security group"
  value       = module.ecs_service.ecs_security_group_id
}

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = module.alb.alb_security_group_id
}

# =============================================================================
# Project Information
# =============================================================================

output "project_info" {
  description = "Project information summary"
  value = {
    project_name = var.project_name
    environment  = var.environment
    team         = var.team
    region       = var.aws_region
    template     = "api-service"
    created_by   = "stackkit-v2"
  }
}

# =============================================================================
# Connection Information for Applications
# =============================================================================

output "connection_info" {
  description = "Connection information for applications"
  value = {
    # Load Balancer
    load_balancer = {
      dns_name = module.alb.alb_dns_name
      zone_id  = module.alb.alb_zone_id
    }
    
    # Database (if enabled)
    database = var.enable_database ? {
      endpoint = module.database[0].db_instance_endpoint
      port     = module.database[0].db_instance_port
      name     = var.db_name
      username = var.db_username
    } : null
    
    # Redis (if enabled)
    redis = var.enable_redis ? {
      endpoint = module.redis[0].cache_cluster_address
      port     = module.redis[0].cache_cluster_port
    } : null
    
    # S3 (if enabled)
    s3 = var.enable_s3_bucket ? {
      bucket_name = module.s3_bucket[0].bucket_name
      region      = var.aws_region
    } : null
  }
  sensitive = true
}