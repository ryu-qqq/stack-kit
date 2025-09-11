# Basic MySQL RDS Example
# This example shows how to deploy a basic MySQL database for development

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

module "mysql_database" {
  source = "../../"

  # Remote state configuration
  shared_state_bucket = "my-terraform-state-bucket"
  shared_state_key    = "shared/connectly-shared-infrastructure.tfstate"
  aws_region         = "ap-northeast-2"

  # Project configuration
  project_name = "example-app"
  environment  = "dev"

  # Database configuration
  database_name   = "appdb"
  master_username = "admin"

  # Security
  allowed_cidr_blocks = ["10.0.0.0/8"]

  common_tags = {
    Owner   = "development-team"
    Purpose = "example"
    Cost    = "development"
  }
}

# Example outputs
output "database_endpoint" {
  description = "MySQL database endpoint"
  value       = module.mysql_database.db_instance_endpoint
  sensitive   = true
}

output "database_name" {
  description = "Database name"
  value       = module.mysql_database.database_name
}

output "credentials_secret_arn" {
  description = "Secrets Manager ARN for database credentials"
  value       = module.mysql_database.credentials_secret_arn
}