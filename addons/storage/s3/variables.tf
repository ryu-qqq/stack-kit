# S3 Enhanced Storage Addon Variables
# Version: v1.0.0

# Basic Configuration
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

variable "bucket_purpose" {
  description = "Purpose of the bucket (e.g., data, logs, backups, assets)"
  type        = string
}

variable "bucket_name_override" {
  description = "Override default bucket naming convention"
  type        = string
  default     = null
}

variable "force_destroy" {
  description = "Allow bucket deletion even when containing objects (use with caution)"
  type        = bool
  default     = false
}

# Enhanced Security Configuration
variable "enable_enhanced_security" {
  description = "Enable enhanced security features including strict bucket policies"
  type        = bool
  default     = true
}

variable "kms_key_alias" {
  description = "KMS key alias for bucket encryption (without 'alias/' prefix)"
  type        = string
  default     = null
}

variable "bucket_key_enabled" {
  description = "Whether to use S3 bucket keys for cost optimization"
  type        = bool
  default     = true
}

variable "mfa_delete_enabled" {
  description = "Enable MFA delete protection (requires bucket owner account)"
  type        = bool
  default     = false
}

variable "block_public_access" {
  description = "Block all public access to the bucket"
  type        = bool
  default     = true
}

# Environment-specific Access Controls
variable "environment_access_controls" {
  description = "Environment-specific IAM access controls"
  type = map(object({
    allowed_principals = list(string)
    allowed_actions    = list(string)
    apply_to_objects  = bool
    conditions = list(object({
      test     = string
      variable = string
      values   = list(string)
    }))
  }))
  default = {}
}

# Versioning Configuration
variable "versioning_enabled" {
  description = "Enable versioning on the S3 bucket"
  type        = bool
  default     = true
}

# Lifecycle Management
variable "lifecycle_rules" {
  description = "Advanced lifecycle rules for the S3 bucket"
  type = list(object({
    id     = string
    status = string
    filter = optional(object({
      prefix                   = optional(string)
      object_size_greater_than = optional(number)
      object_size_less_than    = optional(number)
      tags                     = optional(map(string))
    }))
    expiration = optional(object({
      days                         = optional(number)
      date                         = optional(string)
      expired_object_delete_marker = optional(bool)
    }))
    noncurrent_version_expiration = optional(object({
      days = number
    }))
    transitions = optional(list(object({
      days          = optional(number)
      date          = optional(string)
      storage_class = string
    })))
    noncurrent_version_transitions = optional(list(object({
      days          = number
      storage_class = string
    })))
    abort_incomplete_multipart_upload_days = optional(number)
  }))
  default = []
}

# Intelligent Tiering
variable "enable_intelligent_tiering" {
  description = "Enable S3 Intelligent Tiering for cost optimization"
  type        = bool
  default     = false
}

variable "intelligent_tiering_prefix" {
  description = "Prefix for objects to apply intelligent tiering"
  type        = string
  default     = ""
}

variable "intelligent_tiering_days" {
  description = "Days after creation to transition to intelligent tiering"
  type        = number
  default     = 1
}

# Cross-Region Replication
variable "replication_configuration" {
  description = "Cross-region replication configuration"
  type = object({
    rules = list(object({
      id                  = string
      status              = string
      priority            = optional(number)
      prefix              = optional(string)
      destination_bucket  = string
      storage_class       = optional(string)
      replica_kms_key_id  = optional(string)
      account_id          = optional(string)
      owner_override      = optional(bool)
      filter_tags         = optional(map(string))
      delete_marker_replication = optional(bool)
    }))
  })
  default = null
}

# Monitoring and Analytics
variable "enable_detailed_monitoring" {
  description = "Enable detailed S3 monitoring metrics"
  type        = bool
  default     = false
}

variable "enable_analytics" {
  description = "Enable S3 analytics configuration"
  type        = bool
  default     = false
}

variable "analytics_export_destination" {
  description = "S3 bucket ARN for analytics export"
  type        = string
  default     = null
}

variable "analytics_export_prefix" {
  description = "Prefix for analytics export files"
  type        = string
  default     = "analytics/"
}

# Inventory Configuration
variable "inventory_configuration" {
  description = "S3 inventory configuration for compliance and governance"
  type = object({
    name                     = string
    enabled                  = optional(bool)
    included_object_versions = optional(string)
    optional_fields          = optional(list(string))
    schedule = object({
      frequency = string
    })
    destination = object({
      bucket_arn = string
      format     = optional(string)
      prefix     = optional(string)
      encryption = optional(object({
        kms_key_id = optional(string)
      }))
    })
    filter = optional(object({
      prefix = string
    }))
  })
  default = null
}

# Notification Configuration
variable "notification_configuration" {
  description = "Enhanced S3 bucket notification configuration"
  type = object({
    lambda_notifications = optional(list(object({
      function_arn  = string
      events        = list(string)
      filter_prefix = optional(string)
      filter_suffix = optional(string)
    })))
    sqs_notifications = optional(list(object({
      queue_arn     = string
      events        = list(string)
      filter_prefix = optional(string)
      filter_suffix = optional(string)
    })))
    sns_notifications = optional(list(object({
      topic_arn     = string
      events        = list(string)
      filter_prefix = optional(string)
      filter_suffix = optional(string)
    })))
  })
  default = null
}

# CORS Configuration
variable "cors_configuration" {
  description = "CORS configuration for the S3 bucket"
  type = list(object({
    id              = optional(string)
    allowed_headers = optional(list(string))
    allowed_methods = list(string)
    allowed_origins = list(string)
    expose_headers  = optional(list(string))
    max_age_seconds = optional(number)
  }))
  default = null
}

# Website Configuration
variable "website_configuration" {
  description = "Website configuration for the S3 bucket"
  type = object({
    index_document = optional(object({
      suffix = string
    }))
    error_document = optional(object({
      key = string
    }))
    redirect_all_requests_to = optional(object({
      host_name = string
      protocol  = optional(string)
    }))
    routing_rules = optional(list(object({
      condition = optional(object({
        http_error_code_returned_equals = optional(string)
        key_prefix_equals               = optional(string)
      }))
      redirect = optional(object({
        host_name               = optional(string)
        http_redirect_code      = optional(string)
        protocol                = optional(string)
        replace_key_prefix_with = optional(string)
        replace_key_with        = optional(string)
      }))
    })))
  })
  default = null
}

# Common Tags
variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Environment-specific defaults for different use cases
variable "apply_environment_defaults" {
  description = "Apply environment-specific defaults for lifecycle and monitoring"
  type        = bool
  default     = true
}

# Compliance and Governance
variable "compliance_requirements" {
  description = "Compliance requirements affecting configuration"
  type = object({
    data_retention_years = optional(number)
    audit_logging       = optional(bool)
    encryption_required = optional(bool)
    backup_required     = optional(bool)
  })
  default = {}
}