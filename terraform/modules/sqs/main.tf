# SQS Queue
resource "aws_sqs_queue" "main" {
  name                       = "${var.environment}-${var.project_name}-${var.queue_name}"
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

  # Dead Letter Queue
  redrive_policy = var.create_dlq ? jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[0].arn
    maxReceiveCount     = var.max_receive_count
  }) : var.redrive_policy

  # Allow failures
  redrive_allow_policy = var.redrive_allow_policy

  # Encryption
  kms_master_key_id                 = var.kms_master_key_id
  kms_data_key_reuse_period_seconds = var.kms_data_key_reuse_period_seconds
  sqs_managed_sse_enabled          = var.sqs_managed_sse_enabled

  tags = merge(var.common_tags, {
    Name = "${var.environment}-${var.project_name}-${var.queue_name}"
  })
}

# Dead Letter Queue
resource "aws_sqs_queue" "dlq" {
  count = var.create_dlq ? 1 : 0

  name                       = var.fifo_queue ? "${var.environment}-${var.project_name}-${replace(var.queue_name, ".fifo", "")}-dlq.fifo" : "${var.environment}-${var.project_name}-${var.queue_name}-dlq"
  delay_seconds              = 0
  max_message_size           = var.max_message_size
  message_retention_seconds  = var.dlq_message_retention_seconds
  receive_wait_time_seconds  = 0
  visibility_timeout_seconds = 30
  
  # FIFO Configuration for DLQ
  fifo_queue                  = var.fifo_queue
  content_based_deduplication = var.fifo_queue ? true : null

  # Encryption (same as main queue)
  kms_master_key_id                 = var.kms_master_key_id
  kms_data_key_reuse_period_seconds = var.kms_data_key_reuse_period_seconds
  sqs_managed_sse_enabled          = var.sqs_managed_sse_enabled

  tags = merge(var.common_tags, {
    Name = "${var.environment}-${var.project_name}-${var.queue_name}-dlq"
  })
}

# Queue Policy
resource "aws_sqs_queue_policy" "main" {
  count = var.queue_policy != null ? 1 : 0

  queue_url = aws_sqs_queue.main.id
  policy    = var.queue_policy
}

resource "aws_sqs_queue_policy" "dlq" {
  count = var.create_dlq && var.dlq_policy != null ? 1 : 0

  queue_url = aws_sqs_queue.dlq[0].id
  policy    = var.dlq_policy
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "queue_messages_visible" {
  count = var.create_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-${var.queue_name}-messages-visible"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ApproximateNumberOfVisibleMessages"
  namespace           = "AWS/SQS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.visible_messages_alarm_threshold
  alarm_description   = "This metric monitors SQS visible messages"
  alarm_actions       = var.alarm_actions

  dimensions = {
    QueueName = aws_sqs_queue.main.name
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "queue_age_of_oldest_message" {
  count = var.create_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-${var.queue_name}-oldest-message-age"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ApproximateAgeOfOldestMessage"
  namespace           = "AWS/SQS"
  period              = "300"
  statistic           = "Maximum"
  threshold           = var.oldest_message_age_alarm_threshold
  alarm_description   = "This metric monitors SQS oldest message age"
  alarm_actions       = var.alarm_actions

  dimensions = {
    QueueName = aws_sqs_queue.main.name
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "dlq_messages_visible" {
  count = var.create_dlq && var.create_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-${var.queue_name}-dlq-messages-visible"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ApproximateNumberOfVisibleMessages"
  namespace           = "AWS/SQS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.dlq_messages_alarm_threshold
  alarm_description   = "This metric monitors SQS DLQ visible messages"
  alarm_actions       = var.alarm_actions

  dimensions = {
    QueueName = aws_sqs_queue.dlq[0].name
  }

  tags = var.common_tags
}

# IAM Policy for Queue Access (optional)
resource "aws_iam_policy" "sqs_access" {
  count = var.create_iam_policy ? 1 : 0

  name        = "${var.project_name}-${var.environment}-${var.queue_name}-access-policy"
  path        = "/"
  description = "IAM policy for SQS queue access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = [
          aws_sqs_queue.main.arn,
          var.create_dlq ? aws_sqs_queue.dlq[0].arn : null
        ]
      }
    ]
  })

  tags = var.common_tags
}

# Lambda Event Source Mapping (optional)
resource "aws_lambda_event_source_mapping" "sqs" {
  count = var.lambda_trigger != null ? 1 : 0

  event_source_arn = aws_sqs_queue.main.arn
  function_name    = var.lambda_trigger.function_name
  batch_size       = var.lambda_trigger.batch_size
  enabled          = var.lambda_trigger.enabled

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