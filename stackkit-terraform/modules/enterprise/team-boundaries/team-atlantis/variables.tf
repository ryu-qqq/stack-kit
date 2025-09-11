# Team Atlantis Module Variables

variable "team_name" {
  description = "Name of the team"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.team_name))
    error_message = "Team name must be lowercase alphanumeric with hyphens only."
  }
}

variable "team_id" {
  description = "Numeric ID of the team"
  type        = number
  
  validation {
    condition     = var.team_id >= 1 && var.team_id <= 254
    error_message = "Team ID must be between 1 and 254."
  }
}

variable "organization" {
  description = "Organization name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

# Network Configuration
variable "vpc_id" {
  description = "VPC ID where Atlantis will be deployed"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID for ALB"
  type        = string
}

variable "atlantis_security_group_id" {
  description = "Security group ID for Atlantis ECS tasks"
  type        = string
  default     = ""
}

# ECS Configuration
variable "atlantis_size" {
  description = "Size of the Atlantis deployment (small, medium, large)"
  type        = string
  default     = "small"
  
  validation {
    condition     = contains(["small", "medium", "large"], var.atlantis_size)
    error_message = "Atlantis size must be one of: small, medium, large."
  }
}

variable "cpu" {
  description = "CPU units for Atlantis task (overrides atlantis_size if specified)"
  type        = number
  default     = null
}

variable "memory" {
  description = "Memory MB for Atlantis task (overrides atlantis_size if specified)"
  type        = number
  default     = null
}

# Atlantis Configuration
variable "atlantis_version" {
  description = "Atlantis version to deploy"
  type        = string
  default     = "0.27.0"
}

variable "atlantis_image" {
  description = "Custom Atlantis image (overrides version if specified)"
  type        = string
  default     = ""
}

variable "terraform_version" {
  description = "Default Terraform version for Atlantis"
  type        = string
  default     = "1.7.5"
}

variable "log_level" {
  description = "Log level for Atlantis (debug, info, warn, error)"
  type        = string
  default     = "info"
  
  validation {
    condition     = contains(["debug", "info", "warn", "error"], var.log_level)
    error_message = "Log level must be one of: debug, info, warn, error."
  }
}

variable "log_retention_days" {
  description = "Number of days to retain Atlantis logs"
  type        = number
  default     = 30
}

# GitHub Configuration
variable "github_org" {
  description = "GitHub organization name"
  type        = string
}

variable "github_token" {
  description = "GitHub personal access token (will be stored in Secrets Manager)"
  type        = string
  default     = ""
  sensitive   = true
}

# Domain and SSL Configuration
variable "domain_name" {
  description = "Base domain name for team subdomains (e.g., atlantis.company.com)"
  type        = string
  default     = ""
}

variable "subdomain" {
  description = "Subdomain for this team (defaults to team_name)"
  type        = string
  default     = ""
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS (optional)"
  type        = string
  default     = ""
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for DNS records (optional)"
  type        = string
  default     = ""
}

# Integrations
variable "slack_webhook_url" {
  description = "Slack webhook URL for notifications"
  type        = string
  default     = ""
  sensitive   = true
}

variable "infracost_api_key" {
  description = "Infracost API key for cost analysis"
  type        = string
  default     = ""
  sensitive   = true
}

# Advanced Options
variable "enable_deletion_protection" {
  description = "Enable deletion protection for ALB in production"
  type        = bool
  default     = null # Will default to true if environment is prod
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights for ECS cluster"
  type        = bool
  default     = true
}

variable "health_check_path" {
  description = "Health check path for ALB target group"
  type        = string
  default     = "/healthz"
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 5
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

variable "deregistration_delay" {
  description = "ALB target group deregistration delay in seconds"
  type        = number
  default     = 30
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}