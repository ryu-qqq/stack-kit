# MySQL RDS Database Addon v1.0.0
# Composable MySQL RDS module for stackkit

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Data sources for shared infrastructure
data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket = var.shared_state_bucket
    key    = var.shared_state_key
    region = var.aws_region
  }
}

data "aws_caller_identity" "current" {}

# Local values for shared infrastructure references
locals {
  vpc_id                = data.terraform_remote_state.shared.outputs.vpc_id
  private_subnet_ids    = data.terraform_remote_state.shared.outputs.private_subnet_ids
  database_subnet_ids   = try(data.terraform_remote_state.shared.outputs.database_subnet_ids, local.private_subnet_ids)
  shared_security_group = try(data.terraform_remote_state.shared.outputs.database_security_group_id, null)
  
  # Environment-specific configurations
  is_production = var.environment == "prod"
  
  # RDS configurations based on environment
  instance_config = {
    dev = {
      instance_class    = "db.t3.micro"
      allocated_storage = 20
      multi_az          = false
      backup_retention  = 7
      maintenance_window = "sun:03:00-sun:04:00"
      backup_window     = "02:00-03:00"
    }
    staging = {
      instance_class    = "db.t3.small"
      allocated_storage = 50
      multi_az          = true
      backup_retention  = 14
      maintenance_window = "sun:03:00-sun:04:00"
      backup_window     = "02:00-03:00"
    }
    prod = {
      instance_class    = "db.r5.large"
      allocated_storage = 100
      multi_az          = true
      backup_retention  = 30
      maintenance_window = "sun:03:00-sun:04:00"
      backup_window     = "02:00-03:00"
    }
  }
  
  config = local.instance_config[var.environment]
  
  # Tags
  common_tags = merge(var.common_tags, {
    Component   = "database"
    Type        = "mysql-rds"
    Environment = var.environment
    Version     = "v1.0.0"
  })
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-mysql-subnet-group"
  subnet_ids = local.database_subnet_ids

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-mysql-subnet-group"
  })
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  count = local.shared_security_group == null ? 1 : 0
  
  name_prefix = "${var.project_name}-${var.environment}-mysql-"
  vpc_id      = local.vpc_id
  
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "MySQL access from allowed networks"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-mysql-sg"
  })
}

# Parameter Group
resource "aws_db_parameter_group" "main" {
  family = var.parameter_group_family
  name   = "${var.project_name}-${var.environment}-mysql-params"

  dynamic "parameter" {
    for_each = var.custom_parameters
    content {
      name  = parameter.value.name
      value = parameter.value.value
    }
  }

  # Default production-ready parameters
  parameter {
    name  = "innodb_buffer_pool_size"
    value = local.is_production ? "{DBInstanceClassMemory*3/4}" : "{DBInstanceClassMemory/2}"
  }
  
  parameter {
    name  = "slow_query_log"
    value = "1"
  }
  
  parameter {
    name  = "log_queries_not_using_indexes"
    value = local.is_production ? "1" : "0"
  }
  
  parameter {
    name  = "long_query_time"
    value = "2"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-mysql-params"
  })
}

# Option Group
resource "aws_db_option_group" "main" {
  name                     = "${var.project_name}-${var.environment}-mysql-options"
  option_group_description = "MySQL option group for ${var.project_name}-${var.environment}"
  engine_name              = "mysql"
  major_engine_version     = var.major_engine_version

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-mysql-options"
  })
}

# KMS Key for encryption
resource "aws_kms_key" "rds" {
  count = var.create_kms_key ? 1 : 0
  
  description             = "KMS key for RDS encryption - ${var.project_name}-${var.environment}"
  deletion_window_in_days = var.kms_deletion_window
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-rds-kms"
  })
}

resource "aws_kms_alias" "rds" {
  count = var.create_kms_key ? 1 : 0
  
  name          = "alias/${var.project_name}-${var.environment}-rds"
  target_key_id = aws_kms_key.rds[0].key_id
}

# Random password for master user
resource "random_password" "master" {
  length  = 16
  special = true
}

# Secrets Manager for database credentials
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.project_name}-${var.environment}-mysql-credentials"
  description             = "MySQL database credentials for ${var.project_name}-${var.environment}"
  recovery_window_in_days = var.secret_recovery_window

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-mysql-credentials"
  })
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.master_username
    password = random_password.master.result
    endpoint = aws_db_instance.main.endpoint
    port     = aws_db_instance.main.port
    dbname   = aws_db_instance.main.db_name
  })
}

# RDS Instance
resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-${var.environment}-mysql"

  # Engine configuration
  engine                = "mysql"
  engine_version        = var.engine_version
  instance_class        = var.instance_class != "" ? var.instance_class : local.config.instance_class
  
  # Storage configuration
  allocated_storage     = var.allocated_storage != 0 ? var.allocated_storage : local.config.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = var.storage_encrypted
  kms_key_id           = var.create_kms_key ? aws_kms_key.rds[0].arn : var.kms_key_id
  
  # Database configuration
  db_name  = var.database_name
  username = var.master_username
  password = random_password.master.result
  
  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [local.shared_security_group != null ? local.shared_security_group : aws_security_group.rds[0].id]
  publicly_accessible    = var.publicly_accessible
  port                   = var.port
  
  # High availability
  multi_az = var.multi_az != null ? var.multi_az : local.config.multi_az
  
  # Backup configuration
  backup_retention_period = var.backup_retention_period != null ? var.backup_retention_period : local.config.backup_retention
  backup_window          = var.backup_window != "" ? var.backup_window : local.config.backup_window
  copy_tags_to_snapshot  = true
  delete_automated_backups = false
  
  # Maintenance
  maintenance_window = var.maintenance_window != "" ? var.maintenance_window : local.config.maintenance_window
  
  # Monitoring
  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null
  
  performance_insights_enabled = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null
  
  # Parameter and option groups
  parameter_group_name = aws_db_parameter_group.main.name
  option_group_name    = aws_db_option_group.main.name
  
  # Security
  deletion_protection = local.is_production ? true : var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.project_name}-${var.environment}-mysql-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  
  # Other options
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  apply_immediately         = var.apply_immediately
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-mysql"
  })
  
  depends_on = [aws_db_subnet_group.main]
  
  lifecycle {
    ignore_changes = [
      final_snapshot_identifier,
      password
    ]
  }
}

# IAM Role for Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0
  
  name = "${var.project_name}-${var.environment}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0
  
  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "cpu_utilization" {
  count = var.create_cloudwatch_alarms ? 1 : 0
  
  alarm_name          = "${var.project_name}-${var.environment}-mysql-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  alarm_description   = "This metric monitors RDS CPU utilization"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "connection_count" {
  count = var.create_cloudwatch_alarms ? 1 : 0
  
  alarm_name          = "${var.project_name}-${var.environment}-mysql-connection-count"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.connection_alarm_threshold
  alarm_description   = "This metric monitors RDS connection count"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "free_storage_space" {
  count = var.create_cloudwatch_alarms ? 1 : 0
  
  alarm_name          = "${var.project_name}-${var.environment}-mysql-free-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.free_storage_alarm_threshold
  alarm_description   = "This metric monitors RDS free storage space"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  tags = local.common_tags
}

# Read Replica (for production only)
resource "aws_db_instance" "read_replica" {
  count = local.is_production && var.create_read_replica ? 1 : 0
  
  identifier             = "${var.project_name}-${var.environment}-mysql-read-replica"
  replicate_source_db    = aws_db_instance.main.identifier
  instance_class         = var.read_replica_instance_class != "" ? var.read_replica_instance_class : local.config.instance_class
  publicly_accessible    = false
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  
  # Monitoring
  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null
  
  performance_insights_enabled = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null
  
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-mysql-read-replica"
    Type = "read-replica"
  })
}