# DynamoDB Table
resource "aws_dynamodb_table" "main" {
  name                        = "${var.project_name}-${var.environment}-${var.table_name}"
  billing_mode                = var.billing_mode
  hash_key                    = var.hash_key
  range_key                   = var.range_key
  deletion_protection_enabled = var.deletion_protection_enabled

  # Provisioned throughput (only for PROVISIONED billing mode)
  read_capacity  = var.billing_mode == "PROVISIONED" ? var.read_capacity : null
  write_capacity = var.billing_mode == "PROVISIONED" ? var.write_capacity : null

  # Attributes
  dynamic "attribute" {
    for_each = var.attributes
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  # Global Secondary Indexes
  dynamic "global_secondary_index" {
    for_each = var.global_secondary_indexes
    content {
      name               = global_secondary_index.value.name
      hash_key           = global_secondary_index.value.hash_key
      range_key          = global_secondary_index.value.range_key
      projection_type    = global_secondary_index.value.projection_type
      non_key_attributes = global_secondary_index.value.non_key_attributes

      read_capacity  = var.billing_mode == "PROVISIONED" ? global_secondary_index.value.read_capacity : null
      write_capacity = var.billing_mode == "PROVISIONED" ? global_secondary_index.value.write_capacity : null
    }
  }

  # Local Secondary Indexes
  dynamic "local_secondary_index" {
    for_each = var.local_secondary_indexes
    content {
      name               = local_secondary_index.value.name
      range_key          = local_secondary_index.value.range_key
      projection_type    = local_secondary_index.value.projection_type
      non_key_attributes = local_secondary_index.value.non_key_attributes
    }
  }

  # Time to Live
  dynamic "ttl" {
    for_each = var.ttl_enabled ? [1] : []
    content {
      attribute_name = var.ttl_attribute_name
      enabled        = true
    }
  }

  # Point-in-time Recovery
  point_in_time_recovery {
    enabled = var.point_in_time_recovery_enabled
  }

  # Server-side Encryption
  server_side_encryption {
    enabled     = var.server_side_encryption_enabled
    kms_key_id  = var.kms_key_id
  }

  # Stream Configuration
  stream_enabled   = var.stream_enabled
  stream_view_type = var.stream_enabled ? var.stream_view_type : null

  # Table Class
  table_class = var.table_class

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-${var.table_name}"
  })
}

# Auto Scaling for DynamoDB Table (Read Capacity)
resource "aws_appautoscaling_target" "read" {
  count = var.billing_mode == "PROVISIONED" && var.enable_autoscaling ? 1 : 0

  max_capacity       = var.autoscaling_read_max_capacity
  min_capacity       = var.autoscaling_read_min_capacity
  resource_id        = "table/${aws_dynamodb_table.main.name}"
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  service_namespace  = "dynamodb"

  tags = var.common_tags
}

resource "aws_appautoscaling_policy" "read" {
  count = var.billing_mode == "PROVISIONED" && var.enable_autoscaling ? 1 : 0

  name               = "${var.project_name}-${var.environment}-${var.table_name}-read-scaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.read[0].resource_id
  scalable_dimension = aws_appautoscaling_target.read[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.read[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }
    target_value = var.autoscaling_read_target_value
  }
}

# Auto Scaling for DynamoDB Table (Write Capacity)
resource "aws_appautoscaling_target" "write" {
  count = var.billing_mode == "PROVISIONED" && var.enable_autoscaling ? 1 : 0

  max_capacity       = var.autoscaling_write_max_capacity
  min_capacity       = var.autoscaling_write_min_capacity
  resource_id        = "table/${aws_dynamodb_table.main.name}"
  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
  service_namespace  = "dynamodb"

  tags = var.common_tags
}

resource "aws_appautoscaling_policy" "write" {
  count = var.billing_mode == "PROVISIONED" && var.enable_autoscaling ? 1 : 0

  name               = "${var.project_name}-${var.environment}-${var.table_name}-write-scaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.write[0].resource_id
  scalable_dimension = aws_appautoscaling_target.write[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.write[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }
    target_value = var.autoscaling_write_target_value
  }
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "read_throttled_requests" {
  count = var.create_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-${var.table_name}-read-throttled-requests"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ReadThrottledEventsSum"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.read_throttle_alarm_threshold
  alarm_description   = "This metric monitors DynamoDB read throttled requests"
  alarm_actions       = var.alarm_actions

  dimensions = {
    TableName = aws_dynamodb_table.main.name
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "write_throttled_requests" {
  count = var.create_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-${var.table_name}-write-throttled-requests"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "WriteThrottledEventsSum"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.write_throttle_alarm_threshold
  alarm_description   = "This metric monitors DynamoDB write throttled requests"
  alarm_actions       = var.alarm_actions

  dimensions = {
    TableName = aws_dynamodb_table.main.name
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "consumed_read_capacity" {
  count = var.billing_mode == "PROVISIONED" && var.create_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-${var.table_name}-high-consumed-read-capacity"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ConsumedReadCapacityUnits"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.read_capacity * 300 * 0.8  # 80% of provisioned capacity
  alarm_description   = "This metric monitors DynamoDB consumed read capacity"
  alarm_actions       = var.alarm_actions

  dimensions = {
    TableName = aws_dynamodb_table.main.name
  }

  tags = var.common_tags
}

# DynamoDB Backup Vault (if backup is enabled)
resource "aws_backup_vault" "dynamodb" {
  count = var.enable_backup ? 1 : 0

  name        = "${var.project_name}-${var.environment}-dynamodb-backup-vault"
  kms_key_arn = var.backup_kms_key_id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-dynamodb-backup-vault"
  })
}

resource "aws_backup_plan" "dynamodb" {
  count = var.enable_backup ? 1 : 0

  name = "${var.project_name}-${var.environment}-dynamodb-backup-plan"

  rule {
    rule_name         = "daily_backup"
    target_vault_name = aws_backup_vault.dynamodb[0].name
    schedule          = var.backup_schedule

    lifecycle {
      cold_storage_after = var.backup_cold_storage_after
      delete_after       = var.backup_delete_after
    }

    recovery_point_tags = var.common_tags
  }

  tags = var.common_tags
}

resource "aws_backup_selection" "dynamodb" {
  count = var.enable_backup ? 1 : 0

  iam_role_arn = aws_iam_role.backup[0].arn
  name         = "${var.project_name}-${var.environment}-dynamodb-backup-selection"
  plan_id      = aws_backup_plan.dynamodb[0].id

  resources = [
    aws_dynamodb_table.main.arn
  ]
}

# IAM Role for Backup
resource "aws_iam_role" "backup" {
  count = var.enable_backup ? 1 : 0

  name = "${var.project_name}-${var.environment}-dynamodb-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "backup" {
  count = var.enable_backup ? 1 : 0

  role       = aws_iam_role.backup[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}