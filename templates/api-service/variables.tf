# Variables for API Service Template - StackKit v2

# =============================================================================
# Project Configuration
# =============================================================================

variable "project_name" {
  description = "Name of the project"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod", "test"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod, test."
  }
}

variable "team" {
  description = "Team responsible for this project"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

# =============================================================================
# Network Configuration
# =============================================================================

variable "use_existing_vpc" {
  description = "Whether to use an existing VPC instead of creating a new one"
  type        = bool
  default     = false
}

variable "existing_vpc_project_name" {
  description = "Project name of existing VPC (if different from current project)"
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
  
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "database_subnet_cidrs" {
  description = "List of database subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.110.0/24", "10.0.120.0/24"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT Gateway for all private subnets (cost optimization)"
  type        = bool
  default     = true
}

# =============================================================================
# Application Load Balancer Configuration
# =============================================================================

variable "ssl_certificate_arn" {
  description = "ARN of SSL certificate for HTTPS listener (optional)"
  type        = string
  default     = ""
}

variable "health_check_path" {
  description = "Health check path for target group"
  type        = string
  default     = "/health"
}

# =============================================================================
# ECS Configuration
# =============================================================================

variable "ecs_launch_type" {
  description = "ECS launch type"
  type        = string
  default     = "FARGATE"
  
  validation {
    condition     = contains(["FARGATE", "EC2"], var.ecs_launch_type)
    error_message = "Launch type must be either FARGATE or EC2."
  }
}

variable "container_image" {
  description = "Docker image URI for the application"
  type        = string
  default     = "nginx:latest"
}

variable "container_port" {
  description = "Port exposed by the container"
  type        = number
  default     = 80
  
  validation {
    condition     = var.container_port > 0 && var.container_port <= 65535
    error_message = "Container port must be between 1 and 65535."
  }
}

variable "container_cpu" {
  description = "CPU units for the container (1024 = 1 vCPU for Fargate)"
  type        = number
  default     = 256
  
  validation {
    condition = contains([
      256, 512, 1024, 2048, 4096, 8192, 16384
    ], var.container_cpu)
    error_message = "CPU must be one of: 256, 512, 1024, 2048, 4096, 8192, 16384."
  }
}

variable "container_memory" {
  description = "Memory (MB) for the container"
  type        = number
  default     = 512
  
  validation {
    condition     = var.container_memory >= 128
    error_message = "Memory must be at least 128 MB."
  }
}

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 2
  
  validation {
    condition     = var.desired_count >= 1
    error_message = "Desired count must be at least 1."
  }
}

variable "environment_variables" {
  description = "Environment variables for the container"
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Secrets to pass to the container (ARN-based)"
  type        = map(string)
  default     = {}
}

# =============================================================================
# Auto Scaling Configuration
# =============================================================================

variable "enable_autoscaling" {
  description = "Enable auto scaling for ECS service"
  type        = bool
  default     = true
}

variable "min_capacity" {
  description = "Minimum number of tasks"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum number of tasks"
  type        = number
  default     = 10
}

variable "target_cpu_utilization" {
  description = "Target CPU utilization percentage for auto scaling"
  type        = number
  default     = 70
  
  validation {
    condition     = var.target_cpu_utilization > 0 && var.target_cpu_utilization <= 100
    error_message = "Target CPU utilization must be between 1 and 100."
  }
}

variable "target_memory_utilization" {
  description = "Target memory utilization percentage for auto scaling"
  type        = number
  default     = 80
  
  validation {
    condition     = var.target_memory_utilization > 0 && var.target_memory_utilization <= 100
    error_message = "Target memory utilization must be between 1 and 100."
  }
}

# =============================================================================
# Database Configuration (Optional)
# =============================================================================

variable "enable_database" {
  description = "Enable RDS database"
  type        = bool
  default     = false
}

variable "db_engine" {
  description = "Database engine"
  type        = string
  default     = "postgres"
  
  validation {
    condition = contains([
      "postgres", "mysql", "mariadb", "oracle-ee", "oracle-se2", "sqlserver-ee", "sqlserver-se", "sqlserver-ex", "sqlserver-web"
    ], var.db_engine)
    error_message = "Database engine must be supported by RDS."
  }
}

variable "db_engine_version" {
  description = "Database engine version"
  type        = string
  default     = "15.4"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Initial storage allocation (GB)"
  type        = number
  default     = 20
  
  validation {
    condition     = var.db_allocated_storage >= 20
    error_message = "Allocated storage must be at least 20 GB."
  }
}

variable "db_max_allocated_storage" {
  description = "Maximum storage allocation (GB) for auto scaling"
  type        = number
  default     = 100
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "dbadmin"
}

# =============================================================================
# Redis Configuration (Optional)
# =============================================================================

variable "enable_redis" {
  description = "Enable Redis cache"
  type        = bool
  default     = false
}

variable "redis_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.0"
}

variable "redis_node_type" {
  description = "Redis node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_num_nodes" {
  description = "Number of Redis nodes"
  type        = number
  default     = 1
}

variable "redis_parameter_group" {
  description = "Redis parameter group name"
  type        = string
  default     = "default.redis7"
}

# =============================================================================
# S3 Configuration (Optional)
# =============================================================================

variable "enable_s3_bucket" {
  description = "Enable S3 bucket for application assets"
  type        = bool
  default     = false
}

variable "s3_enable_versioning" {
  description = "Enable versioning for S3 bucket"
  type        = bool
  default     = true
}

variable "s3_lifecycle_rules" {
  description = "S3 lifecycle rules"
  type = list(object({
    id     = string
    status = string
    expiration = object({
      days = number
    })
  }))
  default = [
    {
      id     = "old_versions"
      status = "Enabled"
      expiration = {
        days = 90
      }
    }
  ]
}

# =============================================================================
# Monitoring Configuration
# =============================================================================

variable "alert_topic_arn" {
  description = "SNS topic ARN for alerts (optional)"
  type        = string
  default     = ""
}

variable "create_cloudwatch_dashboard" {
  description = "Create CloudWatch dashboard"
  type        = bool
  default     = true
}