# Example: API Service with ALB Integration
# This example shows how to deploy a REST API service with load balancer integration

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "ap-northeast-2"
}

# Backend configuration for state storage
terraform {
  backend "s3" {
    bucket = "my-terraform-state-bucket"
    key    = "services/my-api/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# API Service Module
module "api_service" {
  source = "../"

  # Core Configuration
  project_name = "connectly"
  environment  = "dev"
  service_name = "api"
  service_type = "api"

  # Container Configuration
  container_image = "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/connectly-api:latest"
  container_port  = 8080

  # Shared Infrastructure Integration
  use_shared_infrastructure = true
  shared_state_bucket       = "connectly-terraform-state"
  shared_state_key          = "shared/terraform.tfstate"

  # ALB Integration - Route /api/* to this service
  enable_alb                 = true
  alb_listener_rule_priority = 100
  alb_listener_rule_conditions = [
    {
      path_pattern = {
        values = ["/api/*"]
      }
    }
  ]

  # Health Check Configuration
  health_check_command     = "curl -f http://localhost:8080/api/health || exit 1"
  alb_health_check_path    = "/api/health"
  alb_health_check_matcher = "200"

  # Environment Variables
  environment_variables = {
    NODE_ENV  = "development"
    PORT      = "8080"
    LOG_LEVEL = "debug"
  }

  # Secrets from Parameter Store
  secrets = {
    DATABASE_URL = "arn:aws:ssm:ap-northeast-2:123456789012:parameter/connectly/dev/database-url"
    JWT_SECRET   = "arn:aws:ssm:ap-northeast-2:123456789012:parameter/connectly/dev/jwt-secret"
  }

  # Custom IAM permissions for S3 access
  s3_bucket_arns = [
    "arn:aws:s3:::connectly-dev-uploads",
    "arn:aws:s3:::connectly-dev-assets"
  ]

  # Auto Scaling Configuration
  enable_autoscaling        = true
  autoscaling_cpu_target    = 60
  autoscaling_memory_target = 70

  # Enable debugging in dev environment
  enable_execute_command = true

  # Common tags
  common_tags = {
    Project     = "connectly"
    Environment = "dev"
    Team        = "backend"
    Service     = "api"
    Version     = "v1.0.0"
  }
}

# Outputs
output "api_service_url" {
  description = "URL of the API service"
  value       = module.api_service.service_url
}

output "api_service_name" {
  description = "Name of the API service"
  value       = module.api_service.service_name
}

output "api_target_group_arn" {
  description = "ARN of the API target group"
  value       = module.api_service.target_group_arn
}