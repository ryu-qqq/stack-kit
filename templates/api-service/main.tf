# API Service Template - StackKit v2
# This template creates a complete REST API service infrastructure

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend configuration - customize for your organization
  backend "s3" {
    bucket         = "ORG_NAME_PLACEHOLDER-terraform-state"
    key            = "PROJECT_NAME_PLACEHOLDER/terraform.tfstate"
    region         = "REGION_PLACEHOLDER"
    encrypt        = true
    dynamodb_table = "ORG_NAME_PLACEHOLDER-terraform-locks"
  }
}

# Provider configuration
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# Local values for consistent naming and tagging
locals {
  project_name = var.project_name
  environment  = var.environment
  
  # Standard tags applied to all resources
  common_tags = {
    Project     = local.project_name
    Environment = local.environment
    Team        = var.team
    ManagedBy   = "terraform"
    Template    = "api-service"
    CreatedBy   = "stackkit-v2"
  }

  # Naming conventions
  name_prefix = "${local.project_name}-${local.environment}"
}

# Data sources for existing resources (when using existing VPC)
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC Module - Choose between new VPC or existing VPC
module "vpc" {
  count = var.use_existing_vpc ? 0 : 1
  
  source = "git::https://github.com/company/stackkit-terraform-modules.git//foundation/networking/vpc?ref=v1.0.0"
  
  project_name = local.project_name
  environment  = local.environment
  
  # VPC Configuration
  vpc_cidr                = var.vpc_cidr
  availability_zones      = data.aws_availability_zones.available.names
  enable_nat_gateway      = var.enable_nat_gateway
  single_nat_gateway      = var.single_nat_gateway
  enable_dns_hostnames    = true
  enable_dns_support      = true
  
  # Subnet Configuration
  public_subnet_cidrs     = var.public_subnet_cidrs
  private_subnet_cidrs    = var.private_subnet_cidrs
  database_subnet_cidrs   = var.database_subnet_cidrs
  
  tags = local.common_tags
}

# Data source for existing VPC (when reusing existing infrastructure)
data "aws_vpc" "existing" {
  count = var.use_existing_vpc ? 1 : 0
  
  filter {
    name   = "tag:Environment"
    values = [local.environment]
  }
  
  filter {
    name   = "tag:Project"
    values = [var.existing_vpc_project_name != "" ? var.existing_vpc_project_name : local.project_name]
  }
}

data "aws_subnets" "existing_private" {
  count = var.use_existing_vpc ? 1 : 0
  
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing[0].id]
  }
  
  filter {
    name   = "tag:Type"
    values = ["private"]
  }
}

data "aws_subnets" "existing_public" {
  count = var.use_existing_vpc ? 1 : 0
  
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing[0].id]
  }
  
  filter {
    name   = "tag:Type"
    values = ["public"]
  }
}

# Application Load Balancer
module "alb" {
  source = "git::https://github.com/company/stackkit-terraform-modules.git//foundation/networking/alb?ref=v1.0.0"
  
  project_name = local.project_name
  environment  = local.environment
  
  # Network Configuration
  vpc_id             = var.use_existing_vpc ? data.aws_vpc.existing[0].id : module.vpc[0].vpc_id
  public_subnet_ids  = var.use_existing_vpc ? data.aws_subnets.existing_public[0].ids : module.vpc[0].public_subnet_ids
  
  # ALB Configuration
  enable_deletion_protection = var.environment == "prod" ? true : false
  enable_cross_zone_load_balancing = true
  idle_timeout = 60
  
  # Health Check Configuration
  health_check_enabled         = true
  health_check_healthy_threshold = 2
  health_check_interval        = 30
  health_check_matcher         = "200"
  health_check_path            = var.health_check_path
  health_check_port            = "traffic-port"
  health_check_protocol        = "HTTP"
  health_check_timeout         = 5
  health_check_unhealthy_threshold = 2
  
  # SSL Configuration
  certificate_arn = var.ssl_certificate_arn
  
  tags = local.common_tags
}

# ECS Cluster and Service
module "ecs_service" {
  source = "git::https://github.com/company/stackkit-terraform-modules.git//foundation/compute/ecs?ref=v1.0.0"
  
  project_name = local.project_name
  environment  = local.environment
  
  # Network Configuration
  vpc_id            = var.use_existing_vpc ? data.aws_vpc.existing[0].id : module.vpc[0].vpc_id
  private_subnet_ids = var.use_existing_vpc ? data.aws_subnets.existing_private[0].ids : module.vpc[0].private_subnet_ids
  
  # ECS Configuration
  launch_type                = var.ecs_launch_type
  cpu                       = var.container_cpu
  memory                    = var.container_memory
  desired_count             = var.desired_count
  
  # Container Configuration
  container_image           = var.container_image
  container_port            = var.container_port
  
  # Environment Variables
  environment_variables     = var.environment_variables
  secrets                  = var.secrets
  
  # Target Group Integration
  target_group_arn         = module.alb.target_group_arn
  
  # Auto Scaling Configuration
  enable_autoscaling       = var.enable_autoscaling
  min_capacity            = var.min_capacity
  max_capacity            = var.max_capacity
  target_cpu_utilization  = var.target_cpu_utilization
  target_memory_utilization = var.target_memory_utilization
  
  tags = local.common_tags
}

# RDS Database (optional)
module "database" {
  count = var.enable_database ? 1 : 0
  
  source = "git::https://github.com/company/stackkit-terraform-modules.git//foundation/database/rds?ref=v1.0.0"
  
  project_name = local.project_name
  environment  = local.environment
  
  # Network Configuration
  vpc_id                = var.use_existing_vpc ? data.aws_vpc.existing[0].id : module.vpc[0].vpc_id
  database_subnet_ids   = var.use_existing_vpc ? data.aws_subnets.existing_private[0].ids : module.vpc[0].database_subnet_ids
  
  # Database Configuration
  engine                = var.db_engine
  engine_version        = var.db_engine_version
  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  
  # Database Settings
  database_name         = var.db_name
  username             = var.db_username
  manage_master_user_password = true
  
  # Security Configuration
  vpc_security_group_ids = [module.ecs_service.ecs_security_group_id]
  
  # Backup Configuration
  backup_retention_period = var.environment == "prod" ? 30 : 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  # Monitoring
  monitoring_interval    = var.environment == "prod" ? 60 : 0
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]
  
  tags = local.common_tags
}

# Redis Cache (optional)
module "redis" {
  count = var.enable_redis ? 1 : 0
  
  source = "git::https://github.com/company/stackkit-terraform-modules.git//foundation/database/elasticache?ref=v1.0.0"
  
  project_name = local.project_name
  environment  = local.environment
  
  # Network Configuration
  vpc_id        = var.use_existing_vpc ? data.aws_vpc.existing[0].id : module.vpc[0].vpc_id
  subnet_ids    = var.use_existing_vpc ? data.aws_subnets.existing_private[0].ids : module.vpc[0].private_subnet_ids
  
  # Redis Configuration
  engine_version       = var.redis_engine_version
  node_type           = var.redis_node_type
  num_cache_nodes     = var.redis_num_nodes
  parameter_group_name = var.redis_parameter_group
  port                = 6379
  
  # Security
  security_group_ids  = [module.ecs_service.ecs_security_group_id]
  
  tags = local.common_tags
}

# CloudWatch Monitoring
module "monitoring" {
  source = "git::https://github.com/company/stackkit-terraform-modules.git//foundation/monitoring/cloudwatch?ref=v1.0.0"
  
  project_name = local.project_name
  environment  = local.environment
  
  # ECS Monitoring
  ecs_cluster_name = module.ecs_service.cluster_name
  ecs_service_name = module.ecs_service.service_name
  
  # ALB Monitoring
  alb_arn_suffix = module.alb.alb_arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffix
  
  # Database Monitoring (if enabled)
  rds_instance_id = var.enable_database ? module.database[0].db_instance_id : null
  
  # Alerting Configuration
  sns_topic_arn = var.alert_topic_arn
  
  # Dashboard Configuration
  create_dashboard = var.create_cloudwatch_dashboard
  
  tags = local.common_tags
}

# S3 Bucket for application assets (optional)
module "s3_bucket" {
  count = var.enable_s3_bucket ? 1 : 0
  
  source = "git::https://github.com/company/stackkit-terraform-modules.git//foundation/storage/s3?ref=v1.0.0"
  
  project_name = local.project_name
  environment  = local.environment
  
  # Bucket Configuration
  bucket_name           = "${local.name_prefix}-assets"
  enable_versioning     = var.s3_enable_versioning
  enable_encryption     = true
  
  # Lifecycle Configuration
  lifecycle_rules = var.s3_lifecycle_rules
  
  # Public Access Configuration
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  
  tags = local.common_tags
}