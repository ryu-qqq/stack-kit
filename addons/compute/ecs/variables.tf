# Core Variables
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "service_name" {
  description = "Name of the ECS service"
  type        = string
}

variable "service_type" {
  description = "Type of service (api or worker)"
  type        = string
  default     = "api"
  validation {
    condition     = contains(["api", "worker"], var.service_type)
    error_message = "Service type must be either 'api' or 'worker'."
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

# Container Configuration
variable "container_image" {
  description = "Docker image for the container"
  type        = string
}

variable "container_port" {
  description = "Port exposed by the container"
  type        = number
  default     = 8080
}

# Environment-specific configuration
variable "environment_config" {
  description = "Environment-specific configuration for resources"
  type = map(object({
    cpu              = string
    memory           = string
    container_cpu    = number
    container_memory = number
    desired_count    = number
    min_capacity     = number
    max_capacity     = number
  }))
  default = {
    dev = {
      cpu              = "256"
      memory           = "512"
      container_cpu    = 256
      container_memory = 512
      desired_count    = 1
      min_capacity     = 1
      max_capacity     = 2
    }
    staging = {
      cpu              = "512"
      memory           = "1024"
      container_cpu    = 512
      container_memory = 1024
      desired_count    = 2
      min_capacity     = 1
      max_capacity     = 4
    }
    prod = {
      cpu              = "1024"
      memory           = "2048"
      container_cpu    = 1024
      container_memory = 2048
      desired_count    = 3
      min_capacity     = 2
      max_capacity     = 10
    }
  }
}

# Shared Infrastructure Configuration
variable "use_shared_infrastructure" {
  description = "Whether to use shared infrastructure from remote state"
  type        = bool
  default     = true
}

variable "shared_state_bucket" {
  description = "S3 bucket for shared infrastructure state"
  type        = string
  default     = ""
}

variable "shared_state_key" {
  description = "S3 key for shared infrastructure state"
  type        = string
  default     = "shared/terraform.tfstate"
}

variable "use_shared_cluster" {
  description = "Whether to use shared ECS cluster"
  type        = bool
  default     = true
}

variable "shared_cluster_name" {
  description = "Name of shared ECS cluster (if different from remote state output)"
  type        = string
  default     = null
}

# Network Configuration (used when not using shared infrastructure)
variable "vpc_id" {
  description = "VPC ID (used when not using shared infrastructure)"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "List of subnet IDs (used when not using shared infrastructure)"
  type        = list(string)
  default     = []
}

variable "cluster_id" {
  description = "ECS cluster ID (used when not using shared cluster)"
  type        = string
  default     = ""
}

variable "cluster_name" {
  description = "ECS cluster name (used when not using shared cluster)"
  type        = string
  default     = ""
}

# Environment Variables and Secrets
variable "environment_variables" {
  description = "Environment variables for the container"
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Secrets for the container (key = env var name, value = ARN)"
  type        = map(string)
  default     = {}
}

# Health Check Configuration
variable "health_check_command" {
  description = "Health check command for the container"
  type        = string
  default     = "curl -f http://localhost:8080/health || exit 1"
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 5
}

variable "health_check_retries" {
  description = "Number of health check retries"
  type        = number
  default     = 3
}

variable "health_check_start_period" {
  description = "Health check start period in seconds"
  type        = number
  default     = 60
}

# Logging Configuration
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

# Volumes Configuration
variable "volumes" {
  description = "Volume configurations for the task"
  type = list(object({
    name = string
    efs_volume_configuration = optional(object({
      file_system_id     = string
      root_directory     = optional(string, "/")
      transit_encryption = optional(string, "ENABLED")
    }))
  }))
  default = []
}

# Security Configuration
variable "additional_security_group_rules" {
  description = "Additional security group rules"
  type = list(object({
    description     = string
    from_port       = number
    to_port         = number
    protocol        = string
    cidr_blocks     = optional(list(string))
    security_groups = optional(list(string))
  }))
  default = []
}

# ALB Configuration
variable "enable_alb" {
  description = "Enable ALB integration (only for API services)"
  type        = bool
  default     = true
}

variable "alb_listener_arn" {
  description = "ALB listener ARN (used when not using shared infrastructure)"
  type        = string
  default     = ""
}

variable "alb_security_group_ids" {
  description = "ALB security group IDs (used when not using shared infrastructure)"
  type        = list(string)
  default     = []
}

variable "alb_listener_rule_priority" {
  description = "Priority for ALB listener rule"
  type        = number
  default     = 100
}

variable "alb_listener_rule_conditions" {
  description = "Conditions for ALB listener rule"
  type = list(object({
    path_pattern = optional(object({
      values = list(string)
    }))
    host_header = optional(object({
      values = list(string)
    }))
  }))
  default = []
}

# ALB Health Check Configuration
variable "alb_health_check_path" {
  description = "Health check path for ALB target group"
  type        = string
  default     = "/health"
}

variable "alb_health_check_healthy_threshold" {
  description = "Number of consecutive health check successes"
  type        = number
  default     = 2
}

variable "alb_health_check_unhealthy_threshold" {
  description = "Number of consecutive health check failures"
  type        = number
  default     = 2
}

variable "alb_health_check_timeout" {
  description = "Health check timeout"
  type        = number
  default     = 5
}

variable "alb_health_check_interval" {
  description = "Health check interval"
  type        = number
  default     = 30
}

variable "alb_health_check_matcher" {
  description = "HTTP status codes to consider healthy"
  type        = string
  default     = "200"
}

# Deployment Configuration
variable "deployment_maximum_percent" {
  description = "Maximum percentage of tasks allowed during deployment"
  type        = number
  default     = 200
}

variable "deployment_minimum_healthy_percent" {
  description = "Minimum percentage of healthy tasks during deployment"
  type        = number
  default     = 100
}

# Service Discovery
variable "enable_service_discovery" {
  description = "Enable service discovery"
  type        = bool
  default     = false
}

variable "service_discovery_namespace_id" {
  description = "Service discovery namespace ID (used when not using shared infrastructure)"
  type        = string
  default     = ""
}

# Auto Scaling Configuration
variable "enable_autoscaling" {
  description = "Enable auto scaling"
  type        = bool
  default     = true
}

variable "autoscaling_cpu_target" {
  description = "Target CPU utilization for auto scaling"
  type        = number
  default     = 70
}

variable "autoscaling_memory_target" {
  description = "Target memory utilization for auto scaling"
  type        = number
  default     = 80
}

variable "autoscaling_scale_in_cooldown" {
  description = "Scale in cooldown period in seconds"
  type        = number
  default     = 300
}

variable "autoscaling_scale_out_cooldown" {
  description = "Scale out cooldown period in seconds"
  type        = number
  default     = 300
}

# IAM Configuration
variable "task_role_policies" {
  description = "Custom policies for the task role"
  type        = map(any)
  default     = {}
}

variable "task_role_managed_policies" {
  description = "Managed policies for the task role"
  type        = list(string)
  default     = []
}

variable "s3_bucket_arns" {
  description = "S3 bucket ARNs for task role permissions"
  type        = list(string)
  default     = []
}

variable "enable_cloudwatch_metrics" {
  description = "Enable CloudWatch metrics permissions"
  type        = bool
  default     = true
}

# Advanced Configuration
variable "enable_execute_command" {
  description = "Enable ECS Exec for debugging"
  type        = bool
  default     = false
}

# Tags
variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}