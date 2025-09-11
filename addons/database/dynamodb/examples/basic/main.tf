# Basic DynamoDB Example
# This example shows how to deploy a basic DynamoDB table for development

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

module "user_table" {
  source = "../../"

  # Remote state configuration
  shared_state_bucket = "my-terraform-state-bucket"
  shared_state_key    = "shared/connectly-shared-infrastructure.tfstate"
  aws_region         = "ap-northeast-2"

  # Project configuration
  project_name = "example-app"
  environment  = "dev"
  table_name   = "users"

  # Table schema
  hash_key = "user_id"
  
  attributes = [
    {
      name = "user_id"
      type = "S"
    }
  ]

  common_tags = {
    Owner   = "development-team"
    Purpose = "example"
    Cost    = "development"
  }
}

# Example outputs
output "table_name" {
  description = "DynamoDB table name"
  value       = module.user_table.table_name
}

output "table_arn" {
  description = "DynamoDB table ARN"
  value       = module.user_table.table_arn
}

output "access_patterns" {
  description = "Table access patterns"
  value       = module.user_table.access_patterns
}