# MySQL RDS Variables

# Remote State Configuration
variable "shared_state_bucket" {
  description = "S3 bucket name where shared infrastructure state is stored"
  type        = string
}

variable "shared_state_key" {
  description = "S3 key path for shared infrastructure state"
  type        = string
  default     = "shared/terraform.tfstate"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

# Project Configuration
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Database Configuration
variable "database_name" {
  description = "Name of the database to create"
  type        = string
  default     = "main"
}

variable "master_username" {
  description = "Master username for the database"
  type        = string
  default     = "admin"
}

variable "port" {
  description = "Database port"
  type        = number
  default     = 3306
}

# Engine Configuration
variable "engine_version" {
  description = "MySQL engine version"
  type        = string
  default     = "8.0.35"
}

variable "major_engine_version" {
  description = "MySQL major engine version for option group"
  type        = string
  default     = "8.0"
}

variable "parameter_group_family" {
  description = "DB parameter group family"
  type        = string
  default     = "mysql8.0"
}

# Instance Configuration
variable "instance_class" {
  description = "RDS instance class (leave empty to use environment defaults)"
  type        = string
  default     = ""
}

variable "allocated_storage" {
  description = "Initial allocated storage in GB (0 to use environment defaults)"
  type        = number
  default     = 0
}

variable "max_allocated_storage" {
  description = "Maximum allocated storage for auto-scaling"
  type        = number
  default     = 1000
}

variable "storage_type" {
  description = "Storage type (gp2, gp3, io1, io2)"
  type        = string
  default     = "gp3"
}

variable "storage_encrypted" {
  description = "Enable storage encryption"
  type        = bool
  default     = true
}

# High Availability
variable "multi_az" {
  description = "Enable Multi-AZ deployment (null to use environment defaults)"
  type        = bool
  default     = null
}

# Backup Configuration
variable "backup_retention_period" {
  description = "Backup retention period in days (null to use environment defaults)"
  type        = number
  default     = null
}

variable "backup_window" {
  description = "Backup window (empty to use environment defaults)"
  type        = string
  default     = ""
}

variable "maintenance_window" {
  description = "Maintenance window (empty to use environment defaults)"
  type        = string
  default     = ""
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on deletion"
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Enable deletion protection (automatically enabled for prod)"
  type        = bool
  default     = false
}

# Security Configuration
variable "publicly_accessible" {
  description = "Make RDS instance publicly accessible"
  type        = bool
  default     = false
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the database"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

# KMS Configuration
variable "create_kms_key" {
  description = "Create a KMS key for RDS encryption"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for encryption (used when create_kms_key is false)"
  type        = string
  default     = ""
}

variable "kms_deletion_window" {
  description = "KMS key deletion window in days"
  type        = number
  default     = 7
}

# Secrets Manager
variable "secret_recovery_window" {
  description = "Recovery window for secrets in days"
  type        = number
  default     = 7
}

# Monitoring Configuration
variable "monitoring_interval" {
  description = "Enhanced monitoring interval in seconds (0, 1, 5, 10, 15, 30, 60)"
  type        = number
  default     = 60
  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "Monitoring interval must be one of: 0, 1, 5, 10, 15, 30, 60."
  }
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights"
  type        = bool
  default     = true
}

variable "performance_insights_retention_period" {
  description = "Performance Insights retention period in days"
  type        = number
  default     = 7
}

# CloudWatch Alarms
variable "create_cloudwatch_alarms" {
  description = "Create CloudWatch alarms"
  type        = bool
  default     = true
}

variable "alarm_actions" {
  description = "List of alarm actions (SNS topic ARNs)"
  type        = list(string)
  default     = []
}

variable "cpu_alarm_threshold" {
  description = "CPU utilization alarm threshold"
  type        = number
  default     = 80
}

variable "connection_alarm_threshold" {
  description = "Database connection count alarm threshold"
  type        = number
  default     = 50
}

variable "free_storage_alarm_threshold" {
  description = "Free storage space alarm threshold in bytes"
  type        = number
  default     = 2147483648 # 2GB
}

# Read Replica Configuration
variable "create_read_replica" {
  description = "Create read replica (only for production)"
  type        = bool
  default     = false
}

variable "read_replica_instance_class" {
  description = "Instance class for read replica (empty to use same as primary)"
  type        = string
  default     = ""
}

# Parameter Group Customization
variable "custom_parameters" {
  description = "Custom DB parameters"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

# Operational Configuration
variable "auto_minor_version_upgrade" {
  description = "Enable auto minor version upgrade"
  type        = bool
  default     = true
}

variable "apply_immediately" {
  description = "Apply changes immediately"
  type        = bool
  default     = false
}