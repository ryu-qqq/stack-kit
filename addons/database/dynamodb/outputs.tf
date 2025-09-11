# DynamoDB Database Outputs

# Table Information
output "table_id" {
  description = "DynamoDB table ID"
  value       = aws_dynamodb_table.main.id
}

output "table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.main.name
}

output "table_arn" {
  description = "DynamoDB table ARN"
  value       = aws_dynamodb_table.main.arn
}

output "table_stream_arn" {
  description = "DynamoDB table stream ARN"
  value       = aws_dynamodb_table.main.stream_arn
}

output "table_stream_label" {
  description = "DynamoDB table stream label"
  value       = aws_dynamodb_table.main.stream_label
}

# Configuration Information
output "hash_key" {
  description = "Hash key (partition key) of the table"
  value       = aws_dynamodb_table.main.hash_key
}

output "range_key" {
  description = "Range key (sort key) of the table"
  value       = aws_dynamodb_table.main.range_key
}

output "billing_mode" {
  description = "Billing mode of the table"
  value       = aws_dynamodb_table.main.billing_mode
}

output "read_capacity" {
  description = "Read capacity of the table"
  value       = aws_dynamodb_table.main.read_capacity
}

output "write_capacity" {
  description = "Write capacity of the table"
  value       = aws_dynamodb_table.main.write_capacity
}

output "table_class" {
  description = "Storage class of the table"
  value       = aws_dynamodb_table.main.table_class
}

# Global Secondary Indexes
output "global_secondary_indexes" {
  description = "Global secondary indexes of the table"
  value = [for gsi in aws_dynamodb_table.main.global_secondary_index : {
    name               = gsi.name
    hash_key           = gsi.hash_key
    range_key          = gsi.range_key
    projection_type    = gsi.projection_type
    non_key_attributes = gsi.non_key_attributes
    read_capacity      = gsi.read_capacity
    write_capacity     = gsi.write_capacity
  }]
}

output "local_secondary_indexes" {
  description = "Local secondary indexes of the table"
  value = [for lsi in aws_dynamodb_table.main.local_secondary_index : {
    name               = lsi.name
    range_key          = lsi.range_key
    projection_type    = lsi.projection_type
    non_key_attributes = lsi.non_key_attributes
  }]
}

# Encryption Information
output "server_side_encryption_enabled" {
  description = "Server-side encryption status"
  value       = var.server_side_encryption_enabled
}

output "kms_key_id" {
  description = "KMS key ID used for encryption"
  value       = var.create_kms_key ? aws_kms_key.dynamodb[0].key_id : var.kms_key_id
}

output "kms_key_arn" {
  description = "KMS key ARN used for encryption"
  value       = var.create_kms_key ? aws_kms_key.dynamodb[0].arn : var.kms_key_id
}

# Time to Live
output "ttl_enabled" {
  description = "Time to Live status"
  value       = var.ttl_enabled
}

output "ttl_attribute_name" {
  description = "Time to Live attribute name"
  value       = var.ttl_enabled ? var.ttl_attribute_name : null
}

# Point-in-time Recovery
output "point_in_time_recovery_enabled" {
  description = "Point-in-time recovery status"
  value       = aws_dynamodb_table.main.point_in_time_recovery[0].enabled
}

# Stream Configuration
output "stream_enabled" {
  description = "DynamoDB stream status"
  value       = aws_dynamodb_table.main.stream_enabled
}

output "stream_view_type" {
  description = "DynamoDB stream view type"
  value       = aws_dynamodb_table.main.stream_view_type
}

# Global Tables
output "global_tables_enabled" {
  description = "Global tables status"
  value       = local.global_tables_enabled
}

output "replica_regions" {
  description = "Replica regions for global tables"
  value       = local.global_tables_enabled ? local.replica_regions : []
}

output "replicas" {
  description = "Table replicas information"
  value = [for replica in aws_dynamodb_table.main.replica : {
    region_name = replica.region_name
    kms_key_id  = replica.kms_key_id
  }]
}

# Auto Scaling Information
output "autoscaling_enabled" {
  description = "Auto scaling status"
  value       = local.config.billing_mode == "PROVISIONED" && var.enable_autoscaling
}

output "autoscaling_read_target_arn" {
  description = "Read capacity auto scaling target ARN"
  value       = local.config.billing_mode == "PROVISIONED" && var.enable_autoscaling ? aws_appautoscaling_target.read[0].arn : null
}

output "autoscaling_write_target_arn" {
  description = "Write capacity auto scaling target ARN"
  value       = local.config.billing_mode == "PROVISIONED" && var.enable_autoscaling ? aws_appautoscaling_target.write[0].arn : null
}

output "autoscaling_read_policy_arn" {
  description = "Read capacity auto scaling policy ARN"
  value       = local.config.billing_mode == "PROVISIONED" && var.enable_autoscaling ? aws_appautoscaling_policy.read[0].arn : null
}

output "autoscaling_write_policy_arn" {
  description = "Write capacity auto scaling policy ARN"
  value       = local.config.billing_mode == "PROVISIONED" && var.enable_autoscaling ? aws_appautoscaling_policy.write[0].arn : null
}

# CloudWatch Alarms
output "cloudwatch_alarm_read_throttle_id" {
  description = "CloudWatch read throttle alarm ID"
  value       = var.create_cloudwatch_alarms ? aws_cloudwatch_metric_alarm.read_throttled_requests[0].id : null
}

output "cloudwatch_alarm_write_throttle_id" {
  description = "CloudWatch write throttle alarm ID"
  value       = var.create_cloudwatch_alarms ? aws_cloudwatch_metric_alarm.write_throttled_requests[0].id : null
}

output "cloudwatch_alarm_read_capacity_id" {
  description = "CloudWatch read capacity alarm ID"
  value       = local.config.billing_mode == "PROVISIONED" && var.create_cloudwatch_alarms ? aws_cloudwatch_metric_alarm.consumed_read_capacity[0].id : null
}

output "cloudwatch_alarm_write_capacity_id" {
  description = "CloudWatch write capacity alarm ID"
  value       = local.config.billing_mode == "PROVISIONED" && var.create_cloudwatch_alarms ? aws_cloudwatch_metric_alarm.consumed_write_capacity[0].id : null
}

# Backup Information
output "backup_enabled" {
  description = "Backup status"
  value       = var.enable_backup
}

output "backup_vault_arn" {
  description = "Backup vault ARN"
  value       = var.enable_backup ? aws_backup_vault.dynamodb[0].arn : null
}

output "backup_plan_arn" {
  description = "Backup plan ARN"
  value       = var.enable_backup ? aws_backup_plan.dynamodb[0].arn : null
}

output "backup_selection_arn" {
  description = "Backup selection ARN"
  value       = var.enable_backup ? aws_backup_selection.dynamodb[0].selection_id : null
}

output "backup_role_arn" {
  description = "Backup IAM role ARN"
  value       = var.enable_backup ? aws_iam_role.backup[0].arn : null
}

# Security Information
output "deletion_protection_enabled" {
  description = "Deletion protection status"
  value       = aws_dynamodb_table.main.deletion_protection_enabled
}

# Performance Insights
output "contributor_insights_enabled" {
  description = "Contributor Insights status"
  value       = var.enable_contributor_insights
}

# Environment Information
output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "project_name" {
  description = "Project name"
  value       = var.project_name
}

# Connection Information for Applications
output "table_endpoints" {
  description = "DynamoDB table endpoints by region"
  value = {
    primary = "https://dynamodb.${data.aws_region.current.name}.amazonaws.com"
    replicas = local.global_tables_enabled ? {
      for region in local.replica_regions : region => "https://dynamodb.${region}.amazonaws.com"
    } : {}
  }
}

output "access_patterns" {
  description = "Common access patterns for the table"
  value = {
    table_name = aws_dynamodb_table.main.name
    hash_key   = aws_dynamodb_table.main.hash_key
    range_key  = aws_dynamodb_table.main.range_key
    gsi_names  = [for gsi in aws_dynamodb_table.main.global_secondary_index : gsi.name]
    lsi_names  = [for lsi in aws_dynamodb_table.main.local_secondary_index : lsi.name]
  }
}

# Resource Tags
output "tags" {
  description = "Tags applied to the DynamoDB table"
  value       = aws_dynamodb_table.main.tags_all
}

# Cost Information
output "cost_optimization_info" {
  description = "Cost optimization information"
  value = {
    billing_mode = aws_dynamodb_table.main.billing_mode
    table_class  = aws_dynamodb_table.main.table_class
    backup_enabled = var.enable_backup
    point_in_time_recovery = aws_dynamodb_table.main.point_in_time_recovery[0].enabled
    global_tables = local.global_tables_enabled
    stream_enabled = aws_dynamodb_table.main.stream_enabled
  }
}

# Table Status
output "table_status" {
  description = "Current table status information"
  value = {
    table_name = aws_dynamodb_table.main.name
    table_arn  = aws_dynamodb_table.main.arn
    hash_key   = aws_dynamodb_table.main.hash_key
    range_key  = aws_dynamodb_table.main.range_key
    billing_mode = aws_dynamodb_table.main.billing_mode
    table_class = aws_dynamodb_table.main.table_class
    stream_arn = aws_dynamodb_table.main.stream_arn
    encryption_enabled = var.server_side_encryption_enabled
    global_tables = local.global_tables_enabled
  }
}