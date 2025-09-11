# Redis ElastiCache Outputs

# Replication Group Information
output "replication_group_id" {
  description = "Redis replication group ID"
  value       = local.cluster_mode_enabled ? aws_elasticache_replication_group.cluster[0].replication_group_id : aws_elasticache_replication_group.main[0].replication_group_id
}

output "replication_group_arn" {
  description = "Redis replication group ARN"
  value       = local.cluster_mode_enabled ? aws_elasticache_replication_group.cluster[0].arn : aws_elasticache_replication_group.main[0].arn
}

# Connection Information
output "primary_endpoint_address" {
  description = "Primary endpoint address"
  value       = local.cluster_mode_enabled ? null : aws_elasticache_replication_group.main[0].primary_endpoint_address
}

output "reader_endpoint_address" {
  description = "Reader endpoint address"
  value       = local.cluster_mode_enabled ? null : aws_elasticache_replication_group.main[0].reader_endpoint_address
}

output "configuration_endpoint_address" {
  description = "Configuration endpoint address (cluster mode only)"
  value       = local.cluster_mode_enabled ? aws_elasticache_replication_group.cluster[0].configuration_endpoint_address : null
}

output "port" {
  description = "Redis port"
  value       = 6379
}

# Security Information
output "auth_token_enabled" {
  description = "Whether auth token is enabled"
  value       = var.auth_token_enabled
}

output "auth_token_secret_arn" {
  description = "Secrets Manager ARN for auth token"
  value       = var.auth_token_enabled ? aws_secretsmanager_secret.auth_token[0].arn : null
}

output "auth_token_secret_name" {
  description = "Secrets Manager secret name for auth token"
  value       = var.auth_token_enabled ? aws_secretsmanager_secret.auth_token[0].name : null
}

output "security_group_id" {
  description = "Security group ID"
  value       = local.shared_security_group != null ? local.shared_security_group : aws_security_group.redis[0].id
}

# Network Information
output "subnet_group_name" {
  description = "Cache subnet group name"
  value       = aws_elasticache_subnet_group.main.name
}

# Configuration Information
output "engine_version" {
  description = "Redis engine version"
  value       = local.cluster_mode_enabled ? aws_elasticache_replication_group.cluster[0].engine_version_actual : aws_elasticache_replication_group.main[0].engine_version_actual
}

output "node_type" {
  description = "Node type"
  value       = var.node_type != "" ? var.node_type : local.config.node_type
}

output "parameter_group_name" {
  description = "Parameter group name"
  value       = aws_elasticache_parameter_group.main.name
}

# Cluster Configuration
output "cluster_mode_enabled" {
  description = "Whether cluster mode is enabled"
  value       = local.cluster_mode_enabled
}

output "num_cache_clusters" {
  description = "Number of cache clusters"
  value       = local.cluster_mode_enabled ? aws_elasticache_replication_group.cluster[0].num_cache_clusters : aws_elasticache_replication_group.main[0].num_cache_clusters
}

output "num_node_groups" {
  description = "Number of node groups (cluster mode only)"
  value       = local.cluster_mode_enabled ? aws_elasticache_replication_group.cluster[0].num_node_groups : null
}

output "replicas_per_node_group" {
  description = "Number of replicas per node group (cluster mode only)"
  value       = local.cluster_mode_enabled ? aws_elasticache_replication_group.cluster[0].replicas_per_node_group : null
}

# High Availability
output "multi_az_enabled" {
  description = "Multi-AZ deployment status"
  value       = local.cluster_mode_enabled ? aws_elasticache_replication_group.cluster[0].multi_az_enabled : aws_elasticache_replication_group.main[0].multi_az_enabled
}

output "automatic_failover_enabled" {
  description = "Automatic failover status"
  value       = local.cluster_mode_enabled ? aws_elasticache_replication_group.cluster[0].automatic_failover_enabled : aws_elasticache_replication_group.main[0].automatic_failover_enabled
}

# Encryption Information
output "encryption_at_rest_enabled" {
  description = "Encryption at rest status"
  value       = local.cluster_mode_enabled ? aws_elasticache_replication_group.cluster[0].at_rest_encryption_enabled : aws_elasticache_replication_group.main[0].at_rest_encryption_enabled
}

output "encryption_in_transit_enabled" {
  description = "Encryption in transit status"
  value       = local.cluster_mode_enabled ? aws_elasticache_replication_group.cluster[0].transit_encryption_enabled : aws_elasticache_replication_group.main[0].transit_encryption_enabled
}

# KMS Key Information
output "kms_key_id" {
  description = "KMS key ID used for encryption"
  value       = var.create_kms_key ? aws_kms_key.redis[0].key_id : var.kms_key_id
}

output "kms_key_arn" {
  description = "KMS key ARN used for encryption"
  value       = var.create_kms_key ? aws_kms_key.redis[0].arn : var.kms_key_id
}

# Backup Information
output "snapshot_retention_limit" {
  description = "Snapshot retention limit in days"
  value       = var.snapshot_retention_limit
}

output "snapshot_window" {
  description = "Snapshot window"
  value       = var.snapshot_window
}

# Maintenance Information
output "maintenance_window" {
  description = "Maintenance window"
  value       = var.maintenance_window
}

# CloudWatch Alarms
output "cloudwatch_alarm_cpu_id" {
  description = "CloudWatch CPU utilization alarm ID"
  value       = var.create_cloudwatch_alarms ? aws_cloudwatch_metric_alarm.cpu_utilization[0].id : null
}

output "cloudwatch_alarm_memory_id" {
  description = "CloudWatch memory utilization alarm ID"
  value       = var.create_cloudwatch_alarms ? aws_cloudwatch_metric_alarm.memory_utilization[0].id : null
}

output "cloudwatch_alarm_connection_id" {
  description = "CloudWatch connection count alarm ID"
  value       = var.create_cloudwatch_alarms ? aws_cloudwatch_metric_alarm.connection_count[0].id : null
}

output "cloudwatch_alarm_eviction_id" {
  description = "CloudWatch eviction alarm ID"
  value       = var.create_cloudwatch_alarms ? aws_cloudwatch_metric_alarm.evictions[0].id : null
}

# Connection String Information
output "connection_string" {
  description = "Redis connection string"
  value = var.auth_token_enabled ? (
    local.cluster_mode_enabled ? 
    "rediss://:AUTH_TOKEN@${aws_elasticache_replication_group.cluster[0].configuration_endpoint_address}:6379" :
    "rediss://:AUTH_TOKEN@${aws_elasticache_replication_group.main[0].primary_endpoint_address}:6379"
  ) : (
    local.cluster_mode_enabled ?
    "redis://${aws_elasticache_replication_group.cluster[0].configuration_endpoint_address}:6379" :
    "redis://${aws_elasticache_replication_group.main[0].primary_endpoint_address}:6379"
  )
  sensitive = true
}

output "connection_info" {
  description = "Complete connection information"
  value = {
    host = local.cluster_mode_enabled ? 
           aws_elasticache_replication_group.cluster[0].configuration_endpoint_address : 
           aws_elasticache_replication_group.main[0].primary_endpoint_address
    port = 6379
    auth_token_required = var.auth_token_enabled
    ssl_enabled = var.encryption_in_transit_enabled
    cluster_mode = local.cluster_mode_enabled
  }
}

# Member Clusters (for detailed information)
output "member_clusters" {
  description = "Member cluster IDs"
  value       = local.cluster_mode_enabled ? aws_elasticache_replication_group.cluster[0].member_clusters : aws_elasticache_replication_group.main[0].member_clusters
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

# Log Delivery Configuration
output "log_delivery_configuration" {
  description = "Log delivery configuration"
  value       = var.log_delivery_configuration
}

# Tags
output "tags" {
  description = "Tags applied to the Redis cluster"
  value       = local.cluster_mode_enabled ? aws_elasticache_replication_group.cluster[0].tags_all : aws_elasticache_replication_group.main[0].tags_all
}