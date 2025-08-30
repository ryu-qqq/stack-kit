# SNS Topic
resource "aws_sns_topic" "main" {
  name                        = "${var.project_name}-${var.environment}-${var.topic_name}"
  display_name               = var.display_name
  policy                     = var.topic_policy
  delivery_policy            = var.delivery_policy
  application_success_feedback_role_arn    = var.application_success_feedback_role_arn
  application_success_feedback_sample_rate = var.application_success_feedback_sample_rate
  application_failure_feedback_role_arn    = var.application_failure_feedback_role_arn
  http_success_feedback_role_arn           = var.http_success_feedback_role_arn
  http_success_feedback_sample_rate        = var.http_success_feedback_sample_rate
  http_failure_feedback_role_arn           = var.http_failure_feedback_role_arn
  lambda_success_feedback_role_arn         = var.lambda_success_feedback_role_arn
  lambda_success_feedback_sample_rate      = var.lambda_success_feedback_sample_rate
  lambda_failure_feedback_role_arn         = var.lambda_failure_feedback_role_arn
  sqs_success_feedback_role_arn            = var.sqs_success_feedback_role_arn
  sqs_success_feedback_sample_rate         = var.sqs_success_feedback_sample_rate
  sqs_failure_feedback_role_arn            = var.sqs_failure_feedback_role_arn
  firehose_success_feedback_role_arn       = var.firehose_success_feedback_role_arn
  firehose_success_feedback_sample_rate    = var.firehose_success_feedback_sample_rate
  firehose_failure_feedback_role_arn       = var.firehose_failure_feedback_role_arn

  # FIFO Configuration
  fifo_topic                  = var.fifo_topic
  content_based_deduplication = var.fifo_topic ? var.content_based_deduplication : null

  # Encryption
  kms_master_key_id = var.kms_master_key_id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-${var.topic_name}"
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

# Data Message Filtering Policy (advanced)
resource "aws_sns_topic_data_protection_policy" "main" {
  count = var.data_protection_policy != null ? 1 : 0

  arn    = aws_sns_topic.main.arn
  policy = var.data_protection_policy
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "sns_failed_notifications" {
  count = var.create_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-${var.topic_name}-failed-notifications"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "NumberOfNotificationsFailed"
  namespace           = "AWS/SNS"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.failed_notifications_alarm_threshold
  alarm_description   = "This metric monitors SNS failed notifications"
  alarm_actions       = var.alarm_actions

  dimensions = {
    TopicName = aws_sns_topic.main.name
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "sns_messages_published" {
  count = var.create_cloudwatch_alarms && var.create_publish_alarm ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-${var.topic_name}-messages-published"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "NumberOfMessagesPublished"
  namespace           = "AWS/SNS"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.messages_published_alarm_threshold
  alarm_description   = "This metric monitors SNS messages published (low threshold)"
  alarm_actions       = var.alarm_actions

  dimensions = {
    TopicName = aws_sns_topic.main.name
  }

  tags = var.common_tags
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

# CloudWatch Log Group for delivery status
resource "aws_cloudwatch_log_group" "sns_delivery_status" {
  count = var.create_delivery_status_logs ? 1 : 0

  name              = "/aws/sns/${var.project_name}-${var.environment}-${var.topic_name}"
  retention_in_days = var.log_retention_days

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-${var.topic_name}-delivery-logs"
  })
}

# Lambda Permission for SNS (if Lambda subscriptions exist)
resource "aws_lambda_permission" "sns_invoke" {
  count = length([for sub in var.subscriptions : sub if sub.protocol == "lambda"])

  statement_id  = "${var.project_name}-${var.environment}-${var.topic_name}-invoke-lambda-${count.index}"
  action        = "lambda:InvokeFunction"
  function_name = [for sub in var.subscriptions : sub.endpoint if sub.protocol == "lambda"][count.index]
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.main.arn
}

# SQS Queue Policy for SNS (if SQS subscriptions exist)
data "aws_iam_policy_document" "sqs_sns_policy" {
  count = length([for sub in var.subscriptions : sub if sub.protocol == "sqs"]) > 0 ? 1 : 0

  statement {
    effect = "Allow"
    
    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }
    
    actions = ["sqs:SendMessage"]
    
    resources = [for sub in var.subscriptions : sub.endpoint if sub.protocol == "sqs"]
    
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.main.arn]
    }
  }
}

# Cross-account access policy (optional)
resource "aws_sns_topic_policy" "cross_account" {
  count = var.cross_account_policy != null ? 1 : 0

  arn    = aws_sns_topic.main.arn
  policy = var.cross_account_policy
}

# SNS Topic Subscription Filter Policy JSON validation
locals {
  # Validate filter policies are valid JSON
  validated_subscriptions = [
    for sub in var.subscriptions : merge(sub, {
      filter_policy = sub.filter_policy != null ? (
        can(jsondecode(sub.filter_policy)) ? sub.filter_policy : null
      ) : null
    })
  ]
}