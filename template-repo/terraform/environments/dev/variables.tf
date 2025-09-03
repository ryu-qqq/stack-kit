# Variables for StackKit Atlantis Template
# These variables are automatically populated by GitHub Actions

variable "aws_region" {
  description = "AWS region for infrastructure deployment"
  type        = string
  default     = "ap-northeast-2"
}

variable "org_name" {
  description = "Organization name (used for resource naming)"
  type        = string
  default     = ""
  
  validation {
    condition     = length(var.org_name) > 0 && length(var.org_name) <= 20
    error_message = "Organization name must be between 1 and 20 characters."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "github_token" {
  description = "GitHub Personal Access Token for Atlantis"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.github_token) > 0
    error_message = "GitHub token is required."
  }
}

variable "openai_api_key" {
  description = "OpenAI API key for AI reviews"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.openai_api_key) > 0 && startswith(var.openai_api_key, "sk-")
    error_message = "OpenAI API key must be provided and start with 'sk-'."
  }
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for notifications"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.slack_webhook_url) > 0 && startswith(var.slack_webhook_url, "https://hooks.slack.com/")
    error_message = "Slack webhook URL must be provided and be a valid Slack webhook."
  }
}

# 기존 리소스 사용을 위한 변수들
variable "vpc_id" {
  description = "Existing VPC ID to use (required)"
  type        = string
  
  validation {
    condition     = length(var.vpc_id) > 0 && startswith(var.vpc_id, "vpc-")
    error_message = "VPC ID must be provided and start with 'vpc-'."
  }
}

variable "public_subnet_ids" {
  description = "List of existing public subnet IDs for ALB"
  type        = list(string)
  
  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "At least 2 public subnets are required for ALB."
  }
}

variable "private_subnet_ids" {
  description = "List of existing private subnet IDs for ECS"
  type        = list(string)
  
  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "At least 2 private subnets are required for ECS."
  }
}

variable "s3_bucket_name" {
  description = "Existing S3 bucket name for Atlantis artifacts"
  type        = string
  
  validation {
    condition     = length(var.s3_bucket_name) > 0
    error_message = "S3 bucket name is required."
  }
}

variable "github_user" {
  description = "GitHub username for Atlantis"
  type        = string
  
  validation {
    condition     = length(var.github_user) > 0
    error_message = "GitHub username is required."
  }
}

variable "repo_allowlist" {
  description = "List of GitHub repositories that Atlantis can access"
  type        = list(string)
  default     = []
  
  validation {
    condition     = length(var.repo_allowlist) > 0
    error_message = "At least one repository must be allowed."
  }
}

variable "infracost_api_key" {
  description = "Infracost API key for cost estimation (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "atlantis_image_tag" {
  description = "Atlantis Docker image tag"
  type        = string
  default     = "v0.28.5"
}