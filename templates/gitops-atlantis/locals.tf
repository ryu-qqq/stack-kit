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
  vpc_id = var.use_existing_vpc ? var.existing_vpc_id : aws_vpc.main[0].id
  public_subnet_ids = var.use_existing_vpc ? var.existing_public_subnet_ids : aws_subnet.public[*].id
  private_subnet_ids = var.use_existing_vpc ? var.existing_private_subnet_ids : aws_subnet.private[*].id
  
  # Availability zones
  availability_zones = data.aws_availability_zones.available.names
  
  # Security group IDs (will be defined by resources)
  alb_security_group_id = aws_security_group.alb.id
  ecs_security_group_id = aws_security_group.ecs.id
  efs_security_group_id = var.enable_efs ? aws_security_group.efs[0].id : null
  
  # ECS Configuration
  task_cpu = var.ecs_task_cpu
  task_memory = var.ecs_task_memory
  
  # Atlantis Configuration
  atlantis_url = "https://${var.atlantis_host}"
}