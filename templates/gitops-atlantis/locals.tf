locals {
  # Common tags following StackKit standards
  common_tags = {
    Project     = var.project_name
    Team        = var.team
    Environment = var.environment
    CostCenter  = var.cost_center
    Owner       = var.owner_email
    ManagedBy   = "terraform"
    StackKit    = "v2.0.0"
  }

  # Computed values for consistent naming
  name_prefix = "${var.environment}-${var.project_name}"

  # VPC and Subnet IDs (computed based on existing vs new)
  vpc_id             = var.use_existing_vpc ? var.existing_vpc_id : aws_vpc.main[0].id
  public_subnet_ids  = var.use_existing_vpc ? var.existing_public_subnet_ids : aws_subnet.public[*].id
  private_subnet_ids = var.use_existing_vpc ? var.existing_private_subnet_ids : aws_subnet.private[*].id

  # Availability zones
  availability_zones = data.aws_availability_zones.available.names

  # Security group IDs (will be defined by resources)
  alb_security_group_id = aws_security_group.alb.id
  ecs_security_group_id = aws_security_group.ecs.id
  efs_security_group_id = var.enable_efs ? aws_security_group.efs[0].id : null

  # ECS Configuration
  task_cpu    = var.ecs_task_cpu
  task_memory = var.ecs_task_memory

  # Atlantis Configuration
  atlantis_url = "https://${var.atlantis_host}"

  # Environment-specific deployment configuration
  deployment_max_percent = var.environment == "prod" ? 100 : 200
  deployment_min_percent = var.environment == "prod" ? 0 : 50 # VaultDB constraint: must allow 0% for single instance

  # Health check configuration based on environment
  health_check_grace_period = var.environment == "prod" ? 300 : 180 # Longer grace period in prod

  # Deployment strategy configuration
  is_production = var.environment == "prod"

  # VaultDB-specific configuration
  vaultdb_deployment_config = {
    prod = {
      strategy              = "blue_green"
      enable_staging_checks = true
      rollback_enabled      = true
      circuit_breaker       = true
    }
    dev = {
      strategy              = "direct"
      enable_staging_checks = false
      rollback_enabled      = false
      circuit_breaker       = false
    }
    staging = {
      strategy              = "blue_green"
      enable_staging_checks = true
      rollback_enabled      = true
      circuit_breaker       = false
    }
  }

  # Current environment deployment config
  current_deployment_config = local.vaultdb_deployment_config[var.environment]
}
