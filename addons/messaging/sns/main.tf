# SNS Messaging Addon - Main Configuration
# Version: v1.0.0
# Purpose: Enterprise-grade SNS implementation with multi-protocol subscriptions and monitoring

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# SNS Topic
resource "aws_sns_topic" "main" {
  name         = var.fifo_topic ? "${var.project_name}-${var.environment}-${var.topic_name}.fifo" : "${var.project_name}-${var.environment}-${var.topic_name}"
  display_name = var.display_name
  policy       = var.topic_policy
  
  # Delivery policy for retry logic
  delivery_policy = var.delivery_policy

  # FIFO Configuration
  fifo_topic                  = var.fifo_topic
  content_based_deduplication = var.fifo_topic ? var.content_based_deduplication : null

  # Encryption
  kms_master_key_id = var.kms_master_key_id

  # Delivery status logging
  application_success_feedback_role_arn    = var.create_delivery_status_role ? aws_iam_role.sns_delivery_status[0].arn : var.application_success_feedback_role_arn
  application_success_feedback_sample_rate = var.application_success_feedback_sample_rate
  application_failure_feedback_role_arn    = var.create_delivery_status_role ? aws_iam_role.sns_delivery_status[0].arn : var.application_failure_feedback_role_arn
  
  http_success_feedback_role_arn    = var.create_delivery_status_role ? aws_iam_role.sns_delivery_status[0].arn : var.http_success_feedback_role_arn
  http_success_feedback_sample_rate = var.http_success_feedback_sample_rate
  http_failure_feedback_role_arn    = var.create_delivery_status_role ? aws_iam_role.sns_delivery_status[0].arn : var.http_failure_feedback_role_arn
  
  lambda_success_feedback_role_arn    = var.create_delivery_status_role ? aws_iam_role.sns_delivery_status[0].arn : var.lambda_success_feedback_role_arn
  lambda_success_feedback_sample_rate = var.lambda_success_feedback_sample_rate
  lambda_failure_feedback_role_arn    = var.create_delivery_status_role ? aws_iam_role.sns_delivery_status[0].arn : var.lambda_failure_feedback_role_arn
  
  sqs_success_feedback_role_arn    = var.create_delivery_status_role ? aws_iam_role.sns_delivery_status[0].arn : var.sqs_success_feedback_role_arn
  sqs_success_feedback_sample_rate = var.sqs_success_feedback_sample_rate
  sqs_failure_feedback_role_arn    = var.create_delivery_status_role ? aws_iam_role.sns_delivery_status[0].arn : var.sqs_failure_feedback_role_arn
  
  firehose_success_feedback_role_arn    = var.create_delivery_status_role ? aws_iam_role.sns_delivery_status[0].arn : var.firehose_success_feedback_role_arn
  firehose_success_feedback_sample_rate = var.firehose_success_feedback_sample_rate
  firehose_failure_feedback_role_arn    = var.create_delivery_status_role ? aws_iam_role.sns_delivery_status[0].arn : var.firehose_failure_feedback_role_arn

  tags = merge(var.common_tags, var.additional_tags, {
    Name        = "${var.project_name}-${var.environment}-${var.topic_name}"
    Environment = var.environment
    Project     = var.project_name
    Type        = "SNS-Topic"
    FIFO        = var.fifo_topic ? "true" : "false"
    Version     = "v1.0.0"
  })
}

# SNS Topic Subscriptions
resource "aws_sns_topic_subscription" "subscriptions" {
  count = length(var.subscriptions)

  topic_arn                       = aws_sns_topic.main.arn
  protocol                        = var.subscriptions[count.index].protocol
  endpoint                        = var.subscriptions[count.index].endpoint
  confirmation_timeout_in_minutes = var.subscriptions[count.index].confirmation_timeout_in_minutes
  endpoint_auto_confirms          = var.subscriptions[count.index].endpoint_auto_confirms
  raw_message_delivery           = var.subscriptions[count.index].raw_message_delivery
  filter_policy                  = var.subscriptions[count.index].filter_policy
  filter_policy_scope            = var.subscriptions[count.index].filter_policy_scope
  delivery_policy                = var.subscriptions[count.index].delivery_policy
  redrive_policy                 = var.subscriptions[count.index].redrive_policy
}

# Data Protection Policy
resource "aws_sns_topic_data_protection_policy" "main" {
  count = var.data_protection_policy != null ? 1 : 0

  arn    = aws_sns_topic.main.arn
  policy = var.data_protection_policy
}

# IAM Role for SNS Delivery Status Logging
resource "aws_iam_role" "sns_delivery_status" {
  count = var.create_delivery_status_role ? 1 : 0

  name = "${var.project_name}-${var.environment}-${var.topic_name}-delivery-status-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-${var.topic_name}-delivery-status-role"
  })
}

# IAM Policy for Delivery Status Logging
resource "aws_iam_role_policy" "sns_delivery_status" {
  count = var.create_delivery_status_role ? 1 : 0

  name = "${var.project_name}-${var.environment}-${var.topic_name}-delivery-status-policy"
  role = aws_iam_role.sns_delivery_status[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:PutMetricFilter",
          "logs:PutRetentionPolicy"
        ]
        Resource = "*"
      }
    ]
  })
}

# CloudWatch Log Group for Delivery Status
resource "aws_cloudwatch_log_group" "sns_delivery_status" {
  count = var.create_delivery_status_logs ? 1 : 0

  name              = "/aws/sns/${var.project_name}-${var.environment}-${var.topic_name}"
  retention_in_days = var.log_retention_days

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-${var.topic_name}-delivery-logs"
  })
}

# Lambda Permissions for SNS Invocation
resource "aws_lambda_permission" "sns_invoke" {
  count = length([for sub in var.subscriptions : sub if sub.protocol == "lambda"])

  statement_id  = "${var.project_name}-${var.environment}-${var.topic_name}-invoke-lambda-${count.index}"
  action        = "lambda:InvokeFunction"
  function_name = [for sub in var.subscriptions : sub.endpoint if sub.protocol == "lambda"][count.index]
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.main.arn
}

# IAM Role for Topic Access
resource "aws_iam_role" "topic_access" {
  count = var.create_iam_role ? 1 : 0

  name = "${var.project_name}-${var.environment}-${var.topic_name}-role"

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
    Name = "${var.project_name}-${var.environment}-${var.topic_name}-role"
  })
}

# IAM Policy for Topic Operations
resource "aws_iam_policy" "topic_access" {
  count = var.create_iam_role ? 1 : 0

  name        = "${var.project_name}-${var.environment}-${var.topic_name}-policy"
  path        = "/"
  description = "IAM policy for SNS topic access - ${var.topic_name}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Effect = "Allow"
          Action = var.iam_actions
          Resource = [aws_sns_topic.main.arn]
        }
      ],
      var.kms_master_key_id != null ? [
        {
          Effect = "Allow"
          Action = [
            "kms:Decrypt",
            "kms:GenerateDataKey"
          ]
          Resource = [var.kms_master_key_id]
        }
      ] : []
    )
  })

  tags = var.common_tags
}

# Attach Policy to Role
resource "aws_iam_role_policy_attachment" "topic_access" {
  count = var.create_iam_role ? 1 : 0

  policy_arn = aws_iam_policy.topic_access[0].arn
  role       = aws_iam_role.topic_access[0].name
}

# CloudWatch Alarms for Monitoring
resource "aws_cloudwatch_metric_alarm" "failed_notifications" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-${var.topic_name}-failed-notifications"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.monitoring_config.evaluation_periods
  metric_name         = "NumberOfNotificationsFailed"
  namespace           = "AWS/SNS"
  period              = var.monitoring_config.period
  statistic           = "Sum"
  threshold           = var.monitoring_config.failed_notifications_threshold
  alarm_description   = "Failed notifications for ${var.topic_name} topic"
  alarm_actions       = var.monitoring_config.alarm_actions
  ok_actions          = var.monitoring_config.ok_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    TopicName = aws_sns_topic.main.name
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "messages_published" {
  count = var.enable_monitoring && var.monitoring_config.create_publish_alarm ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-${var.topic_name}-messages-published"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.monitoring_config.evaluation_periods
  metric_name         = "NumberOfMessagesPublished"
  namespace           = "AWS/SNS"
  period              = var.monitoring_config.period
  statistic           = "Sum"
  threshold           = var.monitoring_config.messages_published_threshold
  alarm_description   = "Low message count for ${var.topic_name} topic"
  alarm_actions       = var.monitoring_config.alarm_actions
  ok_actions          = var.monitoring_config.ok_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    TopicName = aws_sns_topic.main.name
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "high_publish_rate" {
  count = var.enable_monitoring && var.monitoring_config.create_high_publish_alarm ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-${var.topic_name}-high-publish-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.monitoring_config.evaluation_periods
  metric_name         = "NumberOfMessagesPublished"
  namespace           = "AWS/SNS"
  period              = var.monitoring_config.period
  statistic           = "Sum"
  threshold           = var.monitoring_config.high_publish_threshold
  alarm_description   = "High message publish rate for ${var.topic_name} topic"
  alarm_actions       = var.monitoring_config.alarm_actions
  ok_actions          = var.monitoring_config.ok_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    TopicName = aws_sns_topic.main.name
  }

  tags = var.common_tags
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "topic_metrics" {
  count = var.create_dashboard ? 1 : 0

  dashboard_name = "${var.project_name}-${var.environment}-${var.topic_name}-dashboard"

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
            ["AWS/SNS", "NumberOfMessagesPublished", "TopicName", aws_sns_topic.main.name],
            [".", "NumberOfNotificationsDelivered", ".", "."],
            [".", "NumberOfNotificationsFailed", ".", "."],
            [".", "NumberOfNotificationsFilteredOut", ".", "."]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "SNS Topic Metrics - ${var.topic_name}"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = concat(
            [for idx, sub in var.subscriptions : 
              ["AWS/SNS", "NumberOfMessagesPublished", "TopicName", aws_sns_topic.main.name, "Protocol", sub.protocol]
            ]
          )
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "Messages by Protocol - ${var.topic_name}"
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