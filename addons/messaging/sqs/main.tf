# SQS Messaging Addon - Main Configuration
# Version: v1.0.0
# Purpose: Enterprise-grade SQS implementation with DLQ, monitoring, and security

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Main SQS Queue
resource "aws_sqs_queue" "main" {
  name                       = var.fifo_queue ? "${var.environment}-${var.project_name}-${var.queue_name}.fifo" : "${var.environment}-${var.project_name}-${var.queue_name}"
  delay_seconds              = var.delay_seconds
  max_message_size           = var.max_message_size
  message_retention_seconds  = var.message_retention_seconds
  receive_wait_time_seconds  = var.receive_wait_time_seconds
  visibility_timeout_seconds = var.visibility_timeout_seconds
  
  # FIFO Configuration
  fifo_queue                        = var.fifo_queue
  content_based_deduplication       = var.fifo_queue ? var.content_based_deduplication : null
  deduplication_scope              = var.fifo_queue && var.deduplication_scope != null ? var.deduplication_scope : null
  fifo_throughput_limit            = var.fifo_queue && var.fifo_throughput_limit != null ? var.fifo_throughput_limit : null

  # Dead Letter Queue Configuration
  redrive_policy = var.enable_dlq ? jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[0].arn
    maxReceiveCount     = var.max_receive_count
  }) : var.custom_redrive_policy

  # Allow failures configuration
  redrive_allow_policy = var.redrive_allow_policy

  # Encryption Configuration
  kms_master_key_id                 = var.kms_master_key_id
  kms_data_key_reuse_period_seconds = var.kms_data_key_reuse_period_seconds
  sqs_managed_sse_enabled          = var.sqs_managed_sse_enabled

  tags = merge(var.common_tags, var.additional_tags, {
    Name        = "${var.environment}-${var.project_name}-${var.queue_name}"
    Environment = var.environment
    Project     = var.project_name
    Type        = "SQS-Queue"
    FIFO        = var.fifo_queue ? "true" : "false"
    Version     = "v1.0.0"
  })
}

# Dead Letter Queue
resource "aws_sqs_queue" "dlq" {
  count = var.enable_dlq ? 1 : 0

  name = var.fifo_queue ? 
    "${var.environment}-${var.project_name}-${replace(var.queue_name, ".fifo", "")}-dlq.fifo" : 
    "${var.environment}-${var.project_name}-${var.queue_name}-dlq"
  
  delay_seconds              = 0
  max_message_size           = var.max_message_size
  message_retention_seconds  = var.dlq_message_retention_seconds
  receive_wait_time_seconds  = 0
  visibility_timeout_seconds = 30
  
  # FIFO Configuration for DLQ
  fifo_queue                  = var.fifo_queue
  content_based_deduplication = var.fifo_queue ? true : null

  # Encryption (inherit from main queue)
  kms_master_key_id                 = var.kms_master_key_id
  kms_data_key_reuse_period_seconds = var.kms_data_key_reuse_period_seconds
  sqs_managed_sse_enabled          = var.sqs_managed_sse_enabled

  tags = merge(var.common_tags, var.additional_tags, {
    Name        = "${var.environment}-${var.project_name}-${var.queue_name}-dlq"
    Environment = var.environment
    Project     = var.project_name
    Type        = "SQS-DLQ"
    FIFO        = var.fifo_queue ? "true" : "false"
    Version     = "v1.0.0"
  })
}

# Queue Policy for Cross-Account Access
resource "aws_sqs_queue_policy" "main" {
  count = var.queue_policy != null ? 1 : 0

  queue_url = aws_sqs_queue.main.id
  policy    = var.queue_policy
}

# DLQ Policy
resource "aws_sqs_queue_policy" "dlq" {
  count = var.enable_dlq && var.dlq_policy != null ? 1 : 0

  queue_url = aws_sqs_queue.dlq[0].id
  policy    = var.dlq_policy
}

# IAM Role for Queue Access
resource "aws_iam_role" "queue_access" {
  count = var.create_iam_role ? 1 : 0

  name = "${var.project_name}-${var.environment}-${var.queue_name}-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = var.iam_role_principals
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-${var.queue_name}-role"
  })
}

# IAM Policy for Queue Operations
resource "aws_iam_policy" "queue_access" {
  count = var.create_iam_role ? 1 : 0

  name        = "${var.project_name}-${var.environment}-${var.queue_name}-policy"
  path        = "/"
  description = "IAM policy for SQS queue access - ${var.queue_name}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Effect = "Allow"
          Action = var.iam_actions
          Resource = concat(
            [aws_sqs_queue.main.arn],
            var.enable_dlq ? [aws_sqs_queue.dlq[0].arn] : []
          )
        }
      ],
      var.kms_master_key_id != null ? [
        {
          Effect = "Allow"
          Action = [
            "kms:Decrypt",
            "kms:GenerateDataKey"
          ]
          Resource = var.kms_master_key_id
        }
      ] : []
    )
  })

  tags = var.common_tags
}

# Attach Policy to Role
resource "aws_iam_role_policy_attachment" "queue_access" {
  count = var.create_iam_role ? 1 : 0

  policy_arn = aws_iam_policy.queue_access[0].arn
  role       = aws_iam_role.queue_access[0].name
}

# Lambda Event Source Mapping
resource "aws_lambda_event_source_mapping" "queue_trigger" {
  count = var.lambda_trigger != null ? 1 : 0

  event_source_arn                   = aws_sqs_queue.main.arn
  function_name                      = var.lambda_trigger.function_name
  batch_size                         = var.lambda_trigger.batch_size
  maximum_batching_window_in_seconds = var.lambda_trigger.maximum_batching_window_in_seconds
  enabled                           = var.lambda_trigger.enabled

  dynamic "scaling_config" {
    for_each = var.lambda_trigger.scaling_config != null ? [var.lambda_trigger.scaling_config] : []
    content {
      maximum_concurrency = scaling_config.value.maximum_concurrency
    }
  }

  dynamic "filter_criteria" {
    for_each = var.lambda_trigger.filter_criteria != null ? [var.lambda_trigger.filter_criteria] : []
    content {
      dynamic "filter" {
        for_each = filter_criteria.value.filters
        content {
          pattern = filter.value.pattern
        }
      }
    }
  }
}

# CloudWatch Alarms for Monitoring
resource "aws_cloudwatch_metric_alarm" "messages_visible" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-${var.queue_name}-messages-visible"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.monitoring_config.evaluation_periods
  metric_name         = "ApproximateNumberOfVisibleMessages"
  namespace           = "AWS/SQS"
  period              = var.monitoring_config.period
  statistic           = "Average"
  threshold           = var.monitoring_config.visible_messages_threshold
  alarm_description   = "Number of visible messages in ${var.queue_name} queue"
  alarm_actions       = var.monitoring_config.alarm_actions
  ok_actions          = var.monitoring_config.ok_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.main.name
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "oldest_message_age" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-${var.queue_name}-oldest-message-age"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.monitoring_config.evaluation_periods
  metric_name         = "ApproximateAgeOfOldestMessage"
  namespace           = "AWS/SQS"
  period              = var.monitoring_config.period
  statistic           = "Maximum"
  threshold           = var.monitoring_config.oldest_message_age_threshold
  alarm_description   = "Age of oldest message in ${var.queue_name} queue"
  alarm_actions       = var.monitoring_config.alarm_actions
  ok_actions          = var.monitoring_config.ok_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.main.name
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  count = var.enable_dlq && var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-${var.queue_name}-dlq-messages"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfVisibleMessages"
  namespace           = "AWS/SQS"
  period              = var.monitoring_config.period
  statistic           = "Average"
  threshold           = var.monitoring_config.dlq_messages_threshold
  alarm_description   = "Messages in DLQ for ${var.queue_name}"
  alarm_actions       = var.monitoring_config.alarm_actions
  ok_actions          = var.monitoring_config.ok_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.dlq[0].name
  }

  tags = var.common_tags
}

# CloudWatch Dashboard (optional)
resource "aws_cloudwatch_dashboard" "queue_metrics" {
  count = var.create_dashboard ? 1 : 0

  dashboard_name = "${var.project_name}-${var.environment}-${var.queue_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfVisibleMessages", "QueueName", aws_sqs_queue.main.name],
            [".", "ApproximateAgeOfOldestMessage", ".", "."],
            [".", "NumberOfMessagesSent", ".", "."],
            [".", "NumberOfMessagesReceived", ".", "."],
            [".", "NumberOfMessagesDeleted", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "SQS Queue Metrics - ${var.queue_name}"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      }
    ]
  })
}

# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}