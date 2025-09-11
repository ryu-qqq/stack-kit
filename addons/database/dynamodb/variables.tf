# DynamoDB Database Variables

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

# Table Configuration
variable "table_name" {
  description = "Name of the DynamoDB table"
  type        = string
  default     = "main"
}

variable "hash_key" {
  description = "Hash key (partition key) for the table"
  type        = string
}

variable "range_key" {
  description = "Range key (sort key) for the table"
  type        = string
  default     = null
}

variable "attributes" {
  description = "List of table attributes"
  type = list(object({
    name = string
    type = string
  }))
}

# Billing Configuration
variable "billing_mode" {
  description = "Billing mode for the table (PAY_PER_REQUEST or PROVISIONED)"
  type        = string
  default     = ""
  validation {
    condition = var.billing_mode == "" || contains(["PAY_PER_REQUEST", "PROVISIONED"], var.billing_mode)
    error_message = "Billing mode must be either PAY_PER_REQUEST or PROVISIONED."
  }
}

variable "read_capacity" {
  description = "Read capacity units for provisioned mode"
  type        = number
  default     = 5
}

variable "write_capacity" {
  description = "Write capacity units for provisioned mode"
  type        = number
  default     = 5
}

# Global Secondary Indexes
variable "global_secondary_indexes" {
  description = "List of global secondary indexes"
  type = list(object({
    name               = string
    hash_key           = string
    range_key          = string
    projection_type    = string
    non_key_attributes = list(string)
    read_capacity      = number
    write_capacity     = number
  }))
  default = []
}

# Local Secondary Indexes
variable "local_secondary_indexes" {
  description = "List of local secondary indexes"
  type = list(object({
    name               = string
    range_key          = string
    projection_type    = string
    non_key_attributes = list(string)
  }))
  default = []
}

# Time to Live
variable "ttl_enabled" {
  description = "Enable Time to Live"
  type        = bool
  default     = false
}

variable "ttl_attribute_name" {
  description = "Name of the TTL attribute"
  type        = string
  default     = "expires_at"
}

# Point-in-time Recovery
variable "point_in_time_recovery_enabled" {
  description = "Enable point-in-time recovery (null to use environment defaults)"
  type        = bool
  default     = null
}

# Server-side Encryption
variable "server_side_encryption_enabled" {
  description = "Enable server-side encryption"
  type        = bool
  default     = true
}

variable "create_kms_key" {
  description = "Create a KMS key for DynamoDB encryption"
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

# Stream Configuration
variable "stream_enabled" {
  description = "Enable DynamoDB streams"
  type        = bool
  default     = false
}

variable "stream_view_type" {
  description = "Stream view type (KEYS_ONLY, NEW_IMAGE, OLD_IMAGE, NEW_AND_OLD_IMAGES)"
  type        = string
  default     = "NEW_AND_OLD_IMAGES"
  validation {
    condition = contains(["KEYS_ONLY", "NEW_IMAGE", "OLD_IMAGE", "NEW_AND_OLD_IMAGES"], var.stream_view_type)
    error_message = "Stream view type must be one of: KEYS_ONLY, NEW_IMAGE, OLD_IMAGE, NEW_AND_OLD_IMAGES."
  }
}

# Table Class
variable "table_class" {
  description = "Storage class of the table (STANDARD or STANDARD_INFREQUENT_ACCESS)"
  type        = string
  default     = "STANDARD"
  validation {
    condition = contains(["STANDARD", "STANDARD_INFREQUENT_ACCESS"], var.table_class)
    error_message = "Table class must be either STANDARD or STANDARD_INFREQUENT_ACCESS."
  }
}

# Global Tables
variable "enable_global_tables" {
  description = "Enable global tables (multi-region replication)"
  type        = bool
  default     = false
}

variable "replica_regions" {
  description = "List of regions for global table replicas"
  type        = list(string)
  default     = []
}

# Auto Scaling
variable "enable_autoscaling" {
  description = "Enable auto scaling for provisioned capacity"
  type        = bool
  default     = true
}

variable "autoscaling_read_min_capacity" {
  description = "Minimum read capacity for auto scaling"
  type        = number
  default     = 5
}

variable "autoscaling_read_max_capacity" {
  description = "Maximum read capacity for auto scaling"
  type        = number
  default     = 40000
}

variable "autoscaling_read_target_value" {
  description = "Target utilization for read capacity auto scaling"
  type        = number
  default     = 70.0
}

variable "autoscaling_write_min_capacity" {
  description = "Minimum write capacity for auto scaling"
  type        = number
  default     = 5
}

variable "autoscaling_write_max_capacity" {
  description = "Maximum write capacity for auto scaling"
  type        = number
  default     = 40000
}

variable "autoscaling_write_target_value" {
  description = "Target utilization for write capacity auto scaling"
  type        = number
  default     = 70.0
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

variable "read_throttle_alarm_threshold" {
  description = "Read throttle alarm threshold"
  type        = number
  default     = 0
}

variable "write_throttle_alarm_threshold" {
  description = "Write throttle alarm threshold"
  type        = number
  default     = 0
}

# Backup Configuration
variable "enable_backup" {
  description = "Enable AWS Backup for DynamoDB"
  type        = bool
  default     = false
}

variable "backup_schedule" {
  description = "Backup schedule expression"
  type        = string
  default     = "cron(0 2 ? * * *)" # Daily at 2 AM UTC
}

variable "backup_cold_storage_after" {
  description = "Days after which backup moves to cold storage"
  type        = number
  default     = 30
}

variable "backup_delete_after" {
  description = "Days after which backup is deleted"
  type        = number
  default     = 120
}

variable "backup_kms_key_id" {
  description = "KMS key ID for backup encryption (empty to use table's KMS key)"
  type        = string
  default     = ""
}

# Security Configuration
variable "deletion_protection_enabled" {
  description = "Enable deletion protection (null to use environment defaults)"
  type        = bool
  default     = null
}

# Performance Configuration
variable "enable_contributor_insights" {
  description = "Enable DynamoDB Contributor Insights"
  type        = bool
  default     = false
}