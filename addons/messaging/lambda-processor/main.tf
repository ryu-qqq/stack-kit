# Lambda Processor Messaging Addon - Main Configuration
# Version: v1.0.0
# Purpose: Event-driven Lambda function for message processing with VPC and monitoring

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Lambda Function
resource "aws_lambda_function" "processor" {
  function_name                  = "${var.environment}-${var.project_name}-${var.function_name}"
  role                          = aws_iam_role.lambda.arn
  handler                       = var.handler
  source_code_hash              = var.source_code_hash
  runtime                       = var.runtime
  memory_size                   = var.memory_size
  timeout                       = var.timeout
  reserved_concurrent_executions = var.reserved_concurrent_executions
  publish                       = var.publish

  # Package configuration
  filename         = var.filename
  s3_bucket       = var.s3_bucket
  s3_key          = var.s3_key
  s3_object_version = var.s3_object_version
  image_uri       = var.image_uri
  package_type    = var.package_type

  # Architecture
  architectures = var.architectures

  # Environment variables
  dynamic "environment" {
    for_each = var.environment_variables != null ? [var.environment_variables] : []
    content {
      variables = environment.value
    }
  }

  # VPC configuration for secure message processing
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  # Dead letter queue for failed processing
  dynamic "dead_letter_config" {
    for_each = var.dead_letter_queue_arn != null ? [1] : []
    content {
      target_arn = var.dead_letter_queue_arn
    }
  }

  # X-Ray tracing for debugging
  tracing_config {
    mode = var.tracing_mode
  }

  # KMS encryption
  kms_key_arn = var.kms_key_arn

  # Layers
  layers = var.layers

  tags = merge(var.common_tags, var.additional_tags, {
    Name        = "${var.project_name}-${var.environment}-${var.function_name}"
    Environment = var.environment
    Project     = var.project_name
    Type        = "Lambda-Processor"
    Purpose     = "Message-Processing"
    Version     = "v1.0.0"
  })

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy_attachment.lambda_vpc,
    aws_cloudwatch_log_group.lambda,
  ]
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.environment}-${var.project_name}-${var.function_name}"
  retention_in_days = var.log_retention_days

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-${var.function_name}-logs"
  })
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-${var.environment}-${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-${var.function_name}-role"
  })
}

# Basic execution role policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda.name
}

# VPC execution role policy (if VPC is configured)
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  count = var.vpc_config != null ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  role       = aws_iam_role.lambda.name
}

# X-Ray tracing policy
resource "aws_iam_role_policy_attachment" "lambda_xray" {
  count = var.tracing_mode == "Active" ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
  role       = aws_iam_role.lambda.name
}

# Message Processing Policies
resource "aws_iam_policy" "message_processing" {
  name        = "${var.project_name}-${var.environment}-${var.function_name}-processing-policy"
  path        = "/"
  description = "IAM policy for message processing Lambda function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      # SQS permissions for message processing
      var.sqs_config != null ? [
        {
          Effect = "Allow"
          Action = [
            "sqs:ReceiveMessage",
            "sqs:DeleteMessage",
            "sqs:GetQueueAttributes",
            "sqs:ChangeMessageVisibility"
          ]
          Resource = [var.sqs_config.queue_arn]
        }
      ] : [],
      
      # SNS permissions for publishing results
      var.sns_config != null ? [
        {
          Effect = "Allow"
          Action = [
            "sns:Publish"
          ]
          Resource = var.sns_config.topic_arns
        }
      ] : [],
      
      # DynamoDB permissions for state management
      var.dynamodb_config != null ? [
        {
          Effect = "Allow"
          Action = [
            "dynamodb:GetItem",
            "dynamodb:PutItem",
            "dynamodb:UpdateItem",
            "dynamodb:DeleteItem",
            "dynamodb:Query",
            "dynamodb:Scan"
          ]
          Resource = var.dynamodb_config.table_arns
        }
      ] : [],
      
      # S3 permissions for file processing
      var.s3_config != null ? [
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject"
          ]
          Resource = [for bucket in var.s3_config.bucket_arns : "${bucket}/*"]
        },
        {
          Effect = "Allow"
          Action = [
            "s3:ListBucket"
          ]
          Resource = var.s3_config.bucket_arns
        }
      ] : [],
      
      # KMS permissions for decryption
      var.kms_key_arn != null ? [
        {
          Effect = "Allow"
          Action = [
            "kms:Decrypt",
            "kms:GenerateDataKey"
          ]
          Resource = [var.kms_key_arn]
        }
      ] : [],
      
      # Additional custom permissions
      var.additional_iam_policies
    )
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "message_processing" {
  policy_arn = aws_iam_policy.message_processing.arn
  role       = aws_iam_role.lambda.name
}

# Event Source Mappings for SQS
resource "aws_lambda_event_source_mapping" "sqs" {
  count = var.sqs_config != null ? 1 : 0

  event_source_arn                   = var.sqs_config.queue_arn
  function_name                      = aws_lambda_function.processor.function_name
  batch_size                         = var.sqs_config.batch_size
  maximum_batching_window_in_seconds = var.sqs_config.maximum_batching_window_in_seconds
  enabled                           = var.sqs_config.enabled

  dynamic "scaling_config" {
    for_each = var.sqs_config.scaling_config != null ? [var.sqs_config.scaling_config] : []
    content {
      maximum_concurrency = scaling_config.value.maximum_concurrency
    }
  }

  dynamic "filter_criteria" {
    for_each = var.sqs_config.filter_criteria != null ? [var.sqs_config.filter_criteria] : []
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

# Lambda Permission for SNS Invocation
resource "aws_lambda_permission" "sns_invoke" {
  count = var.sns_config != null ? length(var.sns_config.topic_arns) : 0

  statement_id  = "AllowExecutionFromSNS-${count.index}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = var.sns_config.topic_arns[count.index]
}

# Lambda Permission for EventBridge
resource "aws_lambda_permission" "eventbridge_invoke" {
  count = var.eventbridge_config != null ? length(var.eventbridge_config.rule_arns) : 0

  statement_id  = "AllowExecutionFromEventBridge-${count.index}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = var.eventbridge_config.rule_arns[count.index]
}

# CloudWatch Alarms for Monitoring
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.environment}-${var.project_name}-${var.function_name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.monitoring_config.evaluation_periods
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = var.monitoring_config.period
  statistic           = "Sum"
  threshold           = var.monitoring_config.error_threshold
  alarm_description   = "Lambda errors for ${var.function_name}"
  alarm_actions       = var.monitoring_config.alarm_actions
  ok_actions          = var.monitoring_config.ok_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.processor.function_name
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.environment}-${var.project_name}-${var.function_name}-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.monitoring_config.evaluation_periods
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = var.monitoring_config.period
  statistic           = "Average"
  threshold           = var.monitoring_config.duration_threshold
  alarm_description   = "Lambda duration for ${var.function_name}"
  alarm_actions       = var.monitoring_config.alarm_actions
  ok_actions          = var.monitoring_config.ok_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.processor.function_name
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.environment}-${var.project_name}-${var.function_name}-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.monitoring_config.evaluation_periods
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = var.monitoring_config.period
  statistic           = "Sum"
  threshold           = var.monitoring_config.throttle_threshold
  alarm_description   = "Lambda throttles for ${var.function_name}"
  alarm_actions       = var.monitoring_config.alarm_actions
  ok_actions          = var.monitoring_config.ok_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.processor.function_name
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_concurrent_executions" {
  count = var.enable_monitoring && var.monitoring_config.create_concurrency_alarm ? 1 : 0

  alarm_name          = "${var.environment}-${var.project_name}-${var.function_name}-concurrent-executions"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.monitoring_config.evaluation_periods
  metric_name         = "ConcurrentExecutions"
  namespace           = "AWS/Lambda"
  period              = var.monitoring_config.period
  statistic           = "Maximum"
  threshold           = var.monitoring_config.concurrent_executions_threshold
  alarm_description   = "High concurrent executions for ${var.function_name}"
  alarm_actions       = var.monitoring_config.alarm_actions
  ok_actions          = var.monitoring_config.ok_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.processor.function_name
  }

  tags = var.common_tags
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "lambda_metrics" {
  count = var.create_dashboard ? 1 : 0

  dashboard_name = "${var.project_name}-${var.environment}-${var.function_name}-dashboard"

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
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.processor.function_name],
            [".", "Errors", ".", "."],
            [".", "Duration", ".", "."],
            [".", "Throttles", ".", "."],
            [".", "ConcurrentExecutions", ".", "."]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "Lambda Metrics - ${var.function_name}"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          query = "SOURCE '${aws_cloudwatch_log_group.lambda.name}' | fields @timestamp, @message | sort @timestamp desc | limit 100"
          region = data.aws_region.current.name
          title = "Recent Logs - ${var.function_name}"
        }
      }
    ]
  })
}

# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}