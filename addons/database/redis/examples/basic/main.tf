# Basic Redis ElastiCache Example
# This example shows how to deploy a basic Redis cache for development

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

module "redis_cache" {
  source = "../../"

  # Remote state configuration
  shared_state_bucket = "my-terraform-state-bucket"
  shared_state_key    = "shared/connectly-shared-infrastructure.tfstate"
  aws_region         = "ap-northeast-2"

  # Project configuration
  project_name = "example-app"
  environment  = "dev"

  # Security
  auth_token_enabled = true
  allowed_cidr_blocks = ["10.0.0.0/8"]

  common_tags = {
    Owner   = "development-team"
    Purpose = "example"
    Cost    = "development"
  }
}

# Example outputs
output "redis_endpoint" {
  description = "Redis primary endpoint"
  value       = module.redis_cache.primary_endpoint_address
}

output "auth_token_secret_arn" {
  description = "Secrets Manager ARN for Redis auth token"
  value       = module.redis_cache.auth_token_secret_arn
}

output "connection_info" {
  description = "Redis connection information"
  value       = module.redis_cache.connection_info
  sensitive   = true
}