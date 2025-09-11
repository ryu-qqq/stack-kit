# =======================================
# Atlantis GitOps Infrastructure - Shared Environment
# =======================================
# Single Atlantis instance for entire organization

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # Backend configuration will be provided via backend.hcl
    # terraform init -backend-config=backend.hcl
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# =======================================
# Data Sources
# =======================================

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

# Reference to shared infrastructure (if using connectly-shared-infrastructure)
data "terraform_remote_state" "shared" {
  count = var.use_shared_infrastructure ? 1 : 0

  backend = "s3"
  config = {
    bucket = var.shared_state_bucket
    key    = var.shared_state_key
    region = var.aws_region
  }
}

# =======================================
# Local Variables
# =======================================

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Component   = "gitops-atlantis"
    Owner       = var.owner
  }

  # Use shared infrastructure or create new
  vpc_id             = var.use_shared_infrastructure ? data.terraform_remote_state.shared[0].outputs.vpc_id : module.networking.vpc_id
  public_subnet_ids  = var.use_shared_infrastructure ? data.terraform_remote_state.shared[0].outputs.public_subnet_ids : module.networking.public_subnet_ids
  private_subnet_ids = var.use_shared_infrastructure ? data.terraform_remote_state.shared[0].outputs.private_subnet_ids : module.networking.private_subnet_ids
}

# =======================================
# Networking Module
# =======================================

module "networking" {
  source = "../../modules/networking.tf"
  count  = var.use_shared_infrastructure ? 0 : 1

  environment        = var.environment
  project_name       = var.project_name
  vpc_cidr           = var.vpc_cidr
  availability_zones = data.aws_availability_zones.available.names
  enable_nat_gateway = var.enable_nat_gateway
  tags               = local.common_tags

  # For existing VPC
  use_existing_vpc            = var.use_existing_vpc
  existing_vpc_id             = var.existing_vpc_id
  existing_public_subnet_ids  = var.existing_public_subnet_ids
  existing_private_subnet_ids = var.existing_private_subnet_ids
}

# =======================================
# Security Module
# =======================================

module "security" {
  source = "../../modules/security.tf"

  environment                = var.environment
  project_name               = var.project_name
  vpc_id                     = local.vpc_id
  atlantis_port              = var.atlantis_port
  enable_efs                 = var.enable_efs
  secrets_manager_arn        = module.storage.secrets_manager_arn
  terraform_state_bucket_arn = module.storage.terraform_state_bucket_arn
  terraform_lock_table_arn   = module.storage.terraform_lock_table_arn
  tags                       = local.common_tags
}

# =======================================
# Storage Module
# =======================================

module "storage" {
  source = "../../modules/storage.tf"

  environment                     = var.environment
  project_name                    = var.project_name
  enable_efs                      = var.enable_efs
  efs_performance_mode            = var.efs_performance_mode
  efs_throughput_mode             = var.efs_throughput_mode
  enable_efs_lifecycle_policy     = var.enable_efs_lifecycle_policy
  private_subnet_ids              = local.private_subnet_ids
  efs_security_group_id           = module.security.efs_security_group_id
  secret_recovery_window_days     = var.secret_recovery_window_days
  github_token                    = var.github_token
  github_webhook_secret           = var.github_webhook_secret
  tfe_token                       = var.tfe_token
  create_terraform_state_bucket   = var.create_terraform_state_bucket
  create_terraform_lock_table     = var.create_terraform_lock_table
  existing_terraform_state_bucket = var.existing_terraform_state_bucket
  existing_terraform_lock_table   = var.existing_terraform_lock_table
  aws_region                      = var.aws_region
  tags                            = local.common_tags
}

# =======================================
# Load Balancer Module
# =======================================

module "load_balancer" {
  source = "../../modules/load_balancer.tf"

  environment                 = var.environment
  project_name                = var.project_name
  vpc_id                      = local.vpc_id
  public_subnet_ids           = local.public_subnet_ids
  alb_security_group_id       = module.security.alb_security_group_id
  atlantis_port               = var.atlantis_port
  enable_deletion_protection  = var.enable_deletion_protection
  certificate_arn             = var.certificate_arn
  additional_certificate_arns = var.additional_certificate_arns
  ssl_policy                  = var.ssl_policy
  tags                        = local.common_tags
}

# =======================================
# Compute Module
# =======================================

module "compute" {
  source = "../../modules/compute.tf"

  environment               = var.environment
  project_name              = var.project_name
  enable_container_insights = var.enable_container_insights
  log_retention_days        = var.log_retention_days
  task_cpu                  = var.task_cpu
  task_memory               = var.task_memory
  ecs_execution_role_arn    = module.security.ecs_execution_role_arn
  ecs_task_role_arn         = module.security.ecs_task_role_arn
  atlantis_image            = var.atlantis_image
  atlantis_port             = var.atlantis_port
  atlantis_url              = var.atlantis_url
  github_repo_allowlist     = var.github_repo_allowlist
  github_user               = var.github_user
  github_webhook_secret     = var.github_webhook_secret
  hide_prev_plan_comments   = var.hide_prev_plan_comments
  atlantis_repo_config      = var.atlantis_repo_config
  terraform_version         = var.terraform_version
  tfe_token                 = var.tfe_token
  secrets_manager_arn       = module.storage.secrets_manager_arn
  aws_region                = var.aws_region
  enable_efs                = var.enable_efs
  efs_file_system_id        = module.storage.efs_file_system_id
  efs_access_point_id       = module.storage.efs_access_point_id
  desired_count             = var.desired_count
  fargate_platform_version  = var.fargate_platform_version
  private_subnet_ids        = local.private_subnet_ids
  ecs_security_group_id     = module.security.ecs_security_group_id
  target_group_arn          = module.load_balancer.target_group_arn
  alb_listener_arn          = module.load_balancer.https_listener_arn != null ? module.load_balancer.https_listener_arn : module.load_balancer.http_listener_arn
  enable_autoscaling        = var.enable_autoscaling
  min_capacity              = var.min_capacity
  max_capacity              = var.max_capacity
  cpu_threshold             = var.cpu_threshold
  memory_threshold          = var.memory_threshold
  tags                      = local.common_tags
}

# =======================================
# Route53 (Optional)
# =======================================

resource "aws_route53_record" "atlantis" {
  count = var.create_route53_record ? 1 : 0

  zone_id = var.route53_zone_id
  name    = var.atlantis_hostname
  type    = "A"

  alias {
    name                   = module.load_balancer.alb_dns_name
    zone_id                = module.load_balancer.alb_zone_id
    evaluate_target_health = true
  }
}