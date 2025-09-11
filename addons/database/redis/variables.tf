# Redis ElastiCache Variables

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

# Engine Configuration
variable "engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.0"
}

variable "parameter_group_family" {
  description = "ElastiCache parameter group family"
  type        = string
  default     = "redis7.x"
}

# Node Configuration
variable "node_type" {
  description = "Cache node type (leave empty to use environment defaults)"
  type        = string
  default     = ""
}

# Standard Mode Configuration
variable "num_cache_nodes" {
  description = "Number of cache nodes for standard mode (null to use environment defaults)"
  type        = number
  default     = null
}

variable "automatic_failover_enabled" {
  description = "Enable automatic failover (null to use environment defaults)"
  type        = bool
  default     = null
}

variable "multi_az_enabled" {
  description = "Enable Multi-AZ deployment (null to use environment defaults)"
  type        = bool
  default     = null
}

# Cluster Mode Configuration
variable "cluster_mode_enabled" {
  description = "Enable Redis cluster mode (null to use environment defaults)"
  type        = bool
  default     = null
}

variable "num_node_groups" {
  description = "Number of node groups (shards) for cluster mode (null to use environment defaults)"
  type        = number
  default     = null
}

variable "replicas_per_node_group" {
  description = "Number of replica nodes per node group (null to use environment defaults)"
  type        = number
  default     = null
}

# Security Configuration
variable "auth_token_enabled" {
  description = "Enable auth token for Redis authentication"
  type        = bool
  default     = true
}

variable "encryption_at_rest_enabled" {
  description = "Enable encryption at rest"
  type        = bool
  default     = true
}

variable "encryption_in_transit_enabled" {
  description = "Enable encryption in transit"
  type        = bool
  default     = true
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access Redis"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

# KMS Configuration
variable "create_kms_key" {
  description = "Create a KMS key for Redis encryption"
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

# Backup Configuration
variable "snapshot_retention_limit" {
  description = "Number of days to retain snapshots"
  type        = number
  default     = 5
}

variable "snapshot_window" {
  description = "Daily time range for snapshots (UTC)"
  type        = string
  default     = "03:00-05:00"
}

# Maintenance Configuration
variable "maintenance_window" {
  description = "Weekly maintenance window"
  type        = string
  default     = "sun:05:00-sun:06:00"
}

# Notification Configuration
variable "notification_topic_arn" {
  description = "SNS topic ARN for notifications"
  type        = string
  default     = ""
}

# Log Delivery Configuration
variable "log_delivery_configuration" {
  description = "Log delivery configuration for Redis"
  type = list(object({
    destination      = string
    destination_type = string
    log_format       = string
    log_type         = string
  }))
  default = []
}

# Parameter Group Customization
variable "custom_parameters" {
  description = "Custom Redis parameters"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "maxmemory_policy" {
  description = "Memory eviction policy"
  type        = string
  default     = "allkeys-lru"
  validation {
    condition = contains([
      "volatile-lru", "allkeys-lru", "volatile-lfu", "allkeys-lfu",
      "volatile-random", "allkeys-random", "volatile-ttl", "noeviction"
    ], var.maxmemory_policy)
    error_message = "Invalid maxmemory policy."
  }
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

variable "memory_alarm_threshold" {
  description = "Memory utilization alarm threshold"
  type        = number
  default     = 80
}

variable "connection_alarm_threshold" {
  description = "Connection count alarm threshold"
  type        = number
  default     = 100
}

variable "eviction_alarm_threshold" {
  description = "Eviction count alarm threshold"
  type        = number
  default     = 100
}