# MySQL RDS Outputs

# Database Instance Information
output "db_instance_id" {
  description = "RDS instance ID"
  value       = aws_db_instance.main.id
}

output "db_instance_arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.main.arn
}

output "db_instance_identifier" {
  description = "RDS instance identifier"
  value       = aws_db_instance.main.identifier
}

output "db_instance_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
}

output "db_instance_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "db_instance_hosted_zone_id" {
  description = "RDS instance hosted zone ID"
  value       = aws_db_instance.main.hosted_zone_id
}

# Database Configuration
output "database_name" {
  description = "Database name"
  value       = aws_db_instance.main.db_name
}

output "master_username" {
  description = "Master username"
  value       = aws_db_instance.main.username
  sensitive   = true
}

# Connection Information
output "connection_string" {
  description = "Database connection string"
  value       = "mysql://${aws_db_instance.main.username}:PASSWORD@${aws_db_instance.main.endpoint}:${aws_db_instance.main.port}/${aws_db_instance.main.db_name}"
  sensitive   = true
}

output "jdbc_connection_string" {
  description = "JDBC connection string"
  value       = "jdbc:mysql://${aws_db_instance.main.endpoint}:${aws_db_instance.main.port}/${aws_db_instance.main.db_name}"
}

# Security Information
output "security_group_id" {
  description = "Security group ID"
  value       = local.shared_security_group != null ? local.shared_security_group : aws_security_group.rds[0].id
}

output "subnet_group_name" {
  description = "DB subnet group name"
  value       = aws_db_subnet_group.main.name
}

# Secrets Manager
output "credentials_secret_arn" {
  description = "Secrets Manager secret ARN for database credentials"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "credentials_secret_name" {
  description = "Secrets Manager secret name for database credentials"
  value       = aws_secretsmanager_secret.db_credentials.name
}

# Parameter and Option Groups
output "parameter_group_name" {
  description = "DB parameter group name"
  value       = aws_db_parameter_group.main.name
}

output "option_group_name" {
  description = "DB option group name"
  value       = aws_db_option_group.main.name
}

# KMS Key
output "kms_key_id" {
  description = "KMS key ID used for encryption"
  value       = var.create_kms_key ? aws_kms_key.rds[0].key_id : var.kms_key_id
}

output "kms_key_arn" {
  description = "KMS key ARN used for encryption"
  value       = var.create_kms_key ? aws_kms_key.rds[0].arn : var.kms_key_id
}

# Read Replica Information
output "read_replica_endpoint" {
  description = "Read replica endpoint"
  value       = var.create_read_replica && local.is_production ? aws_db_instance.read_replica[0].endpoint : null
}

output "read_replica_identifier" {
  description = "Read replica identifier"
  value       = var.create_read_replica && local.is_production ? aws_db_instance.read_replica[0].identifier : null
}

# Monitoring
output "monitoring_role_arn" {
  description = "Enhanced monitoring IAM role ARN"
  value       = var.monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null
}

# CloudWatch Alarms
output "cloudwatch_alarm_cpu_id" {
  description = "CloudWatch CPU utilization alarm ID"
  value       = var.create_cloudwatch_alarms ? aws_cloudwatch_metric_alarm.cpu_utilization[0].id : null
}

output "cloudwatch_alarm_connection_id" {
  description = "CloudWatch connection count alarm ID"
  value       = var.create_cloudwatch_alarms ? aws_cloudwatch_metric_alarm.connection_count[0].id : null
}

output "cloudwatch_alarm_storage_id" {
  description = "CloudWatch free storage alarm ID"
  value       = var.create_cloudwatch_alarms ? aws_cloudwatch_metric_alarm.free_storage_space[0].id : null
}

# Backup Information
output "backup_retention_period" {
  description = "Backup retention period in days"
  value       = aws_db_instance.main.backup_retention_period
}

output "backup_window" {
  description = "Backup window"
  value       = aws_db_instance.main.backup_window
}

output "maintenance_window" {
  description = "Maintenance window"
  value       = aws_db_instance.main.maintenance_window
}

# High Availability
output "multi_az" {
  description = "Multi-AZ deployment status"
  value       = aws_db_instance.main.multi_az
}

output "availability_zone" {
  description = "Availability zone of the instance"
  value       = aws_db_instance.main.availability_zone
}

# Storage Information
output "allocated_storage" {
  description = "Allocated storage in GB"
  value       = aws_db_instance.main.allocated_storage
}

output "storage_type" {
  description = "Storage type"
  value       = aws_db_instance.main.storage_type
}

output "storage_encrypted" {
  description = "Storage encryption status"
  value       = aws_db_instance.main.storage_encrypted
}

# Version Information
output "engine_version" {
  description = "Database engine version"
  value       = aws_db_instance.main.engine_version
}

output "engine_version_actual" {
  description = "Actual database engine version"
  value       = aws_db_instance.main.engine_version_actual
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

# Tags
output "tags" {
  description = "Tags applied to the RDS instance"
  value       = aws_db_instance.main.tags_all
}