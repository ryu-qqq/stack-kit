# =======================================
# StackKit Standard Variables for GitOps Atlantis
# =======================================
# Following StackKit variable naming conventions

# =====================================
# 1. PROJECT METADATA (Required)
# =====================================

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "PROJECT_NAME_PLACEHOLDER"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "team" {
  description = "Team name"
  type        = string
  default     = "TEAM_NAME_PLACEHOLDER"
}

variable "organization" {
  description = "Organization name"
  type        = string
  default     = "ORG_NAME_PLACEHOLDER"
}

variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "TEAM_NAME_PLACEHOLDER"
}

variable "owner_email" {
  description = "Owner email for notifications"
  type        = string
  default     = "TEAM_NAME_PLACEHOLDER@ORG_NAME_PLACEHOLDER.com"
}

# =====================================
# 2. AWS BASIC CONFIGURATION
# =====================================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "REGION_PLACEHOLDER"
}

# =====================================
# 3. NETWORKING CONFIGURATION
# =====================================

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.100.0.0/16"
  
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid CIDR block."
  }
}

variable "use_existing_vpc" {
  description = "Whether to use an existing VPC"
  type        = bool
  default     = false
}

variable "existing_vpc_id" {
  description = "ID of existing VPC (if use_existing_vpc is true)"
  type        = string
  default     = ""
}

variable "existing_public_subnet_ids" {
  description = "IDs of existing public subnets"
  type        = list(string)
  default     = []
}

variable "existing_private_subnet_ids" {
  description = "IDs of existing private subnets"
  type        = list(string)
  default     = []
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access Atlantis"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Should be restricted in production
}

# =====================================
# 4. ECS CONFIGURATION
# =====================================

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights for ECS cluster"
  type        = bool
  default     = true
}

variable "ecs_task_cpu" {
  description = "CPU units for ECS task (256, 512, 1024, 2048, 4096)"
  type        = string
  default     = "512"
  
  validation {
    condition     = contains(["256", "512", "1024", "2048", "4096"], var.ecs_task_cpu)
    error_message = "ECS task CPU must be one of: 256, 512, 1024, 2048, 4096."
  }
}

variable "ecs_task_memory" {
  description = "Memory for ECS task (MB)"
  type        = string
  default     = "1024"
}

variable "ecs_min_capacity" {
  description = "Minimum number of ECS tasks"
  type        = number
  default     = 1
}

variable "ecs_max_capacity" {
  description = "Maximum number of ECS tasks"
  type        = number
  default     = 3
}

variable "desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 1
}

variable "enable_autoscaling" {
  description = "Enable ECS auto scaling"
  type        = bool
  default     = true
}

variable "target_cpu_utilization" {
  description = "Target CPU utilization for auto-scaling (%)"
  type        = number
  default     = 70
  
  validation {
    condition     = var.target_cpu_utilization >= 10 && var.target_cpu_utilization <= 90
    error_message = "CPU utilization must be between 10 and 90."
  }
}

variable "target_memory_utilization" {
  description = "Target memory utilization for auto-scaling (%)"
  type        = number
  default     = 80
}

# =====================================
# 5. LOAD BALANCER CONFIGURATION
# =====================================

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

variable "enable_deletion_protection" {
  description = "Enable deletion protection for ALB"
  type        = bool
  default     = false
}

variable "health_check_path" {
  description = "Health check path for target group"
  type        = string
  default     = "/healthz"
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

# =====================================
# 6. STORAGE CONFIGURATION
# =====================================

variable "enable_efs" {
  description = "Enable EFS for persistent storage"
  type        = bool
  default     = true
}

variable "efs_performance_mode" {
  description = "EFS performance mode"
  type        = string
  default     = "generalPurpose"
  
  validation {
    condition     = contains(["generalPurpose", "maxIO"], var.efs_performance_mode)
    error_message = "EFS performance mode must be 'generalPurpose' or 'maxIO'."
  }
}

variable "efs_throughput_mode" {
  description = "EFS throughput mode"
  type        = string
  default     = "bursting"
  
  validation {
    condition     = contains(["bursting", "provisioned"], var.efs_throughput_mode)
    error_message = "EFS throughput mode must be 'bursting' or 'provisioned'."
  }
}

variable "efs_lifecycle_policy" {
  description = "EFS lifecycle policy"
  type        = string
  default     = "AFTER_30_DAYS"
  
  validation {
    condition = contains([
      "AFTER_7_DAYS", "AFTER_14_DAYS", "AFTER_30_DAYS", 
      "AFTER_60_DAYS", "AFTER_90_DAYS"
    ], var.efs_lifecycle_policy)
    error_message = "EFS lifecycle policy must be a valid option."
  }
}

variable "create_terraform_state_bucket" {
  description = "Create S3 bucket for Terraform state"
  type        = bool
  default     = false
}

variable "create_terraform_lock_table" {
  description = "Create DynamoDB table for Terraform locking"
  type        = bool
  default     = false
}

# =====================================
# 7. SECURITY CONFIGURATION
# =====================================

variable "secret_recovery_window_days" {
  description = "Recovery window for secrets in days"
  type        = number
  default     = 7
}

# =====================================
# 8. LOGGING CONFIGURATION
# =====================================

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
  
  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.log_retention_days)
    error_message = "Log retention must be a valid CloudWatch retention period."
  }
}

# =====================================
# 9. ATLANTIS SPECIFIC CONFIGURATION
# =====================================

variable "atlantis_host" {
  description = "Hostname for Atlantis"
  type        = string
  default     = "atlantis.ORG_NAME_PLACEHOLDER.com"
}

variable "atlantis_port" {
  description = "Port for Atlantis service"
  type        = number
  default     = 4141
}

variable "atlantis_image" {
  description = "Atlantis Docker image"
  type        = string
  default     = "runatlantis/atlantis:latest"
}

variable "atlantis_repo_allowlist" {
  description = "Repositories that Atlantis can manage"
  type        = string
  default     = "github.com/ORG_NAME_PLACEHOLDER/*"
}

variable "atlantis_repo_config" {
  description = "Path to Atlantis config file"
  type        = string
  default     = "atlantis.yaml"
}

variable "atlantis_github_user" {
  description = "GitHub username for Atlantis"
  type        = string
  default     = "atlantis-bot"
}

variable "hide_prev_plan_comments" {
  description = "Hide previous plan comments in PRs"
  type        = bool
  default     = true
}

variable "terraform_version" {
  description = "Terraform version for Atlantis"
  type        = string
  default     = "1.5.0"
}