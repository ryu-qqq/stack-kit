# =======================================
# Variables for Atlantis GitOps
# =======================================

# Basic Configuration
variable "environment" {
  description = "Environment name (shared for Atlantis)"
  type        = string
  default     = "shared"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "atlantis"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "owner" {
  description = "Owner of the infrastructure"
  type        = string
  default     = "DevOps"
}

# Shared Infrastructure Reference
variable "use_shared_infrastructure" {
  description = "Use REPO_NAME_PLACEHOLDERstructure instead of creating new resources"
  type        = bool
  default     = false
}

variable "shared_state_bucket" {
  description = "S3 bucket for shared infrastructure state"
  type        = string
  default     = ""
}

variable "shared_state_key" {
  description = "S3 key for shared infrastructure state"
  type        = string
  default     = "REPO_NAME_PLACEHOLDERstructure/terraform.tfstate"
}

# Networking Configuration
variable "use_existing_vpc" {
  description = "Use an existing VPC instead of creating a new one"
  type        = bool
  default     = false
}

variable "existing_vpc_id" {
  description = "ID of existing VPC to use"
  type        = string
  default     = ""
}

variable "existing_public_subnet_ids" {
  description = "List of existing public subnet IDs"
  type        = list(string)
  default     = []
}

variable "existing_private_subnet_ids" {
  description = "List of existing private subnet IDs"
  type        = list(string)
  default     = []
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

# Atlantis Configuration
variable "atlantis_image" {
  description = "Docker image for Atlantis"
  type        = string
  default     = "ghcr.io/runatlantis/atlantis:latest"
}

variable "atlantis_port" {
  description = "Port for Atlantis server"
  type        = number
  default     = 4141
}

variable "atlantis_url" {
  description = "External URL for Atlantis"
  type        = string
}

variable "github_user" {
  description = "GitHub username for Atlantis"
  type        = string
}

variable "github_token" {
  description = "GitHub token for Atlantis (stored in Secrets Manager)"
  type        = string
  sensitive   = true
}

variable "github_webhook_secret" {
  description = "GitHub webhook secret"
  type        = string
  sensitive   = true
}

variable "github_repo_allowlist" {
  description = "Comma-separated list of allowed GitHub repos"
  type        = string
  default     = "github.com/myorg/*"
}

variable "hide_prev_plan_comments" {
  description = "Hide previous plan comments"
  type        = string
  default     = "true"
}

variable "atlantis_repo_config" {
  description = "Atlantis repository configuration"
  type        = any
  default     = {}
}

variable "terraform_version" {
  description = "Default Terraform version for Atlantis"
  type        = string
  default     = "1.7.5"
}

variable "tfe_token" {
  description = "Terraform Enterprise/Cloud token"
  type        = string
  default     = ""
  sensitive   = true
}

# ECS Configuration
variable "task_cpu" {
  description = "CPU units for the task"
  type        = string
  default     = "512"
}

variable "task_memory" {
  description = "Memory for the task (MB)"
  type        = string
  default     = "1024"
}

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 1
}

variable "fargate_platform_version" {
  description = "Fargate platform version"
  type        = string
  default     = "LATEST"
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

# Auto Scaling
variable "enable_autoscaling" {
  description = "Enable auto scaling for ECS service"
  type        = bool
  default     = false
}

variable "min_capacity" {
  description = "Minimum number of tasks"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum number of tasks"
  type        = number
  default     = 3
}

variable "cpu_threshold" {
  description = "CPU utilization threshold for scaling"
  type        = number
  default     = 70
}

variable "memory_threshold" {
  description = "Memory utilization threshold for scaling"
  type        = number
  default     = 70
}

# Load Balancer Configuration
variable "enable_deletion_protection" {
  description = "Enable deletion protection for ALB"
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
  default     = ""
}

variable "additional_certificate_arns" {
  description = "Additional ACM certificate ARNs"
  type        = list(string)
  default     = []
}

variable "ssl_policy" {
  description = "SSL policy for HTTPS listener"
  type        = string
  default     = "ELBSecurityPolicy-TLS-1-2-2017-01"
}

# Storage Configuration
variable "enable_efs" {
  description = "Enable EFS for persistent storage"
  type        = bool
  default     = true
}

variable "efs_performance_mode" {
  description = "EFS performance mode"
  type        = string
  default     = "generalPurpose"
}

variable "efs_throughput_mode" {
  description = "EFS throughput mode"
  type        = string
  default     = "bursting"
}

variable "enable_efs_lifecycle_policy" {
  description = "Enable EFS lifecycle policy"
  type        = bool
  default     = true
}

variable "secret_recovery_window_days" {
  description = "Recovery window for deleted secrets"
  type        = number
  default     = 7
}

# Terraform State Configuration
variable "create_terraform_state_bucket" {
  description = "Create new S3 bucket for Terraform state"
  type        = bool
  default     = false
}

variable "existing_terraform_state_bucket" {
  description = "Name of existing S3 bucket for Terraform state"
  type        = string
  default     = ""
}

variable "create_terraform_lock_table" {
  description = "Create new DynamoDB table for state locking"
  type        = bool
  default     = false
}

variable "existing_terraform_lock_table" {
  description = "Name of existing DynamoDB table for state locking"
  type        = string
  default     = ""
}

# Route53 Configuration
variable "create_route53_record" {
  description = "Create Route53 record for Atlantis"
  type        = bool
  default     = false
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
  default     = ""
}

variable "atlantis_hostname" {
  description = "Hostname for Atlantis"
  type        = string
  default     = "atlantis"
}
