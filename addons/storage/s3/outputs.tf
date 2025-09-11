# S3 Enhanced Storage Addon Outputs
# Version: v1.0.0

# Basic Bucket Information
output "bucket_id" {
  description = "The ID of the S3 bucket"
  value       = aws_s3_bucket.addon.id
}

output "bucket_arn" {
  description = "The ARN of the S3 bucket"
  value       = aws_s3_bucket.addon.arn
}

output "bucket_domain_name" {
  description = "The bucket domain name"
  value       = aws_s3_bucket.addon.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "The bucket regional domain name"
  value       = aws_s3_bucket.addon.bucket_regional_domain_name
}

output "bucket_hosted_zone_id" {
  description = "The Route 53 Hosted Zone ID for this bucket's region"
  value       = aws_s3_bucket.addon.hosted_zone_id
}

output "bucket_region" {
  description = "The AWS region this bucket resides in"
  value       = aws_s3_bucket.addon.region
}

# Website Configuration Outputs
output "website_endpoint" {
  description = "The website endpoint of the bucket (if configured)"
  value       = var.website_configuration != null ? aws_s3_bucket_website_configuration.addon[0].website_endpoint : null
}

output "website_domain" {
  description = "The domain of the website endpoint (if configured)"
  value       = var.website_configuration != null ? aws_s3_bucket_website_configuration.addon[0].website_domain : null
}

# Security Configuration Outputs
output "encryption_configuration" {
  description = "The encryption configuration of the bucket"
  value = {
    algorithm = var.kms_key_alias != null ? "aws:kms" : "AES256"
    kms_key   = var.kms_key_alias != null ? data.aws_kms_key.s3[0].arn : null
  }
}

output "versioning_status" {
  description = "The versioning status of the bucket"
  value       = aws_s3_bucket_versioning.addon.versioning_configuration[0].status
}

output "public_access_block_configuration" {
  description = "The public access block configuration"
  value = {
    block_public_acls       = aws_s3_bucket_public_access_block.addon.block_public_acls
    block_public_policy     = aws_s3_bucket_public_access_block.addon.block_public_policy
    ignore_public_acls      = aws_s3_bucket_public_access_block.addon.ignore_public_acls
    restrict_public_buckets = aws_s3_bucket_public_access_block.addon.restrict_public_buckets
  }
}

# Replication Configuration Outputs
output "replication_role_arn" {
  description = "The ARN of the IAM role used for replication (if configured)"
  value       = var.replication_configuration != null ? aws_iam_role.replication[0].arn : null
}

output "replication_status" {
  description = "The replication configuration status"
  value       = var.replication_configuration != null ? "Enabled" : "Disabled"
}

# Monitoring and Analytics Outputs
output "metrics_configuration_name" {
  description = "The name of the metrics configuration (if enabled)"
  value       = var.enable_detailed_monitoring ? aws_s3_bucket_metric.addon[0].name : null
}

output "analytics_configuration_name" {
  description = "The name of the analytics configuration (if enabled)"
  value       = var.enable_analytics ? aws_s3_bucket_analytics_configuration.addon[0].name : null
}

output "inventory_configuration_id" {
  description = "The ID of the inventory configuration (if enabled)"
  value       = var.inventory_configuration != null ? aws_s3_bucket_inventory.addon[0].id : null
}

# Lifecycle Configuration Outputs
output "lifecycle_rules_count" {
  description = "Number of lifecycle rules applied"
  value       = length(var.lifecycle_rules)
}

output "intelligent_tiering_enabled" {
  description = "Whether intelligent tiering is enabled"
  value       = var.enable_intelligent_tiering
}

# Notification Configuration Outputs
output "notification_configuration_summary" {
  description = "Summary of notification configurations"
  value = var.notification_configuration != null ? {
    lambda_notifications = length(lookup(var.notification_configuration, "lambda_notifications", []))
    sqs_notifications    = length(lookup(var.notification_configuration, "sqs_notifications", []))
    sns_notifications    = length(lookup(var.notification_configuration, "sns_notifications", []))
  } : null
}

# CORS Configuration Outputs
output "cors_rules_count" {
  description = "Number of CORS rules configured"
  value       = var.cors_configuration != null ? length(var.cors_configuration) : 0
}

# Environment and Compliance Information
output "environment" {
  description = "The environment this bucket is deployed in"
  value       = var.environment
}

output "bucket_purpose" {
  description = "The purpose of this bucket"
  value       = var.bucket_purpose
}

output "compliance_features" {
  description = "Summary of enabled compliance features"
  value = {
    versioning               = var.versioning_enabled
    encryption              = true
    public_access_blocked   = var.block_public_access
    enhanced_security       = var.enable_enhanced_security
    mfa_delete             = var.mfa_delete_enabled
    detailed_monitoring    = var.enable_detailed_monitoring
    analytics_enabled      = var.enable_analytics
    inventory_enabled      = var.inventory_configuration != null
    replication_enabled    = var.replication_configuration != null
    intelligent_tiering    = var.enable_intelligent_tiering
  }
}

# Cost Optimization Information
output "cost_optimization_features" {
  description = "Summary of cost optimization features enabled"
  value = {
    intelligent_tiering         = var.enable_intelligent_tiering
    lifecycle_rules_count      = length(var.lifecycle_rules)
    bucket_key_enabled         = var.bucket_key_enabled
    storage_class_transitions  = length(flatten([for rule in var.lifecycle_rules : lookup(rule, "transitions", [])]))
  }
}

# Access and Security Summary
output "access_control_summary" {
  description = "Summary of access control configurations"
  value = {
    enhanced_security_enabled    = var.enable_enhanced_security
    environment_controls_count   = length(var.environment_access_controls)
    bucket_policy_applied       = var.enable_enhanced_security
    kms_encryption             = var.kms_key_alias != null
    cors_enabled               = var.cors_configuration != null
    notification_enabled       = var.notification_configuration != null
  }
}

# Integration Information for Other Modules
output "integration_endpoints" {
  description = "Key endpoints and identifiers for integration with other modules"
  value = {
    bucket_name = aws_s3_bucket.addon.id
    bucket_arn  = aws_s3_bucket.addon.arn
    kms_key_arn = var.kms_key_alias != null ? data.aws_kms_key.s3[0].arn : null
    region      = aws_s3_bucket.addon.region
  }
}

# Addon Metadata
output "addon_metadata" {
  description = "Metadata about this addon module"
  value = {
    name        = "s3-enhanced-storage"
    version     = "v1.0.0"
    provider    = "aws"
    category    = "storage"
    features    = [
      "enhanced-security",
      "intelligent-tiering", 
      "cross-region-replication",
      "advanced-lifecycle",
      "compliance-monitoring",
      "cost-optimization"
    ]
  }
}