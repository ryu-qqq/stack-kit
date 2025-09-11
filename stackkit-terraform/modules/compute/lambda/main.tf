# Lambda Function
resource "aws_lambda_function" "main" {
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

  # VPC configuration
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  # Dead letter queue
  dynamic "dead_letter_config" {
    for_each = var.dead_letter_queue_arn != null ? [1] : []
    content {
      target_arn = var.dead_letter_queue_arn
    }
  }

  # Tracing configuration
  tracing_config {
    mode = var.tracing_mode
  }

  # KMS encryption
  kms_key_arn = var.kms_key_arn

  # File system configuration
  dynamic "file_system_config" {
    for_each = var.file_system_config
    content {
      arn              = file_system_config.value.arn
      local_mount_path = file_system_config.value.local_mount_path
    }
  }

  # Image configuration (for container images)
  dynamic "image_config" {
    for_each = var.package_type == "Image" && var.image_config != null ? [var.image_config] : []
    content {
      entry_point       = image_config.value.entry_point
      command          = image_config.value.command
      working_directory = image_config.value.working_directory
    }
  }

  # Layers
  layers = var.layers

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-${var.function_name}"
  })

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.lambda,
  ]
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-${var.function_name}"
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

# CloudWatch Logs policy
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  policy_arn = aws_iam_policy.lambda_logs.arn
  role       = aws_iam_role.lambda.name
}

resource "aws_iam_policy" "lambda_logs" {
  name        = "${var.project_name}-${var.environment}-${var.function_name}-logs-policy"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.lambda.arn}:*"
      }
    ]
  })
}

# Additional IAM policies
resource "aws_iam_role_policy" "lambda_additional" {
  count = var.additional_iam_policy != null ? 1 : 0

  name = "${var.project_name}-${var.environment}-${var.function_name}-additional-policy"
  role = aws_iam_role.lambda.id

  policy = var.additional_iam_policy
}

# Lambda Permission for various triggers
resource "aws_lambda_permission" "triggers" {
  count = length(var.lambda_permissions)

  statement_id  = var.lambda_permissions[count.index].statement_id
  action        = var.lambda_permissions[count.index].action
  function_name = aws_lambda_function.main.function_name
  principal     = var.lambda_permissions[count.index].principal
  source_arn    = var.lambda_permissions[count.index].source_arn
  source_account = var.lambda_permissions[count.index].source_account
}

# Lambda Function URL (optional)
resource "aws_lambda_function_url" "main" {
  count = var.create_function_url ? 1 : 0

  function_name      = aws_lambda_function.main.function_name
  authorization_type = var.function_url_auth_type

  dynamic "cors" {
    for_each = var.function_url_cors != null ? [var.function_url_cors] : []
    content {
      allow_credentials = cors.value.allow_credentials
      allow_headers     = cors.value.allow_headers
      allow_methods     = cors.value.allow_methods
      allow_origins     = cors.value.allow_origins
      expose_headers    = cors.value.expose_headers
      max_age          = cors.value.max_age
    }
  }
}

# Lambda Alias (optional)
resource "aws_lambda_alias" "main" {
  count = var.create_alias ? 1 : 0

  name             = var.alias_name
  description      = "Alias for ${var.function_name}"
  function_name    = aws_lambda_function.main.function_name
  function_version = var.alias_function_version != null ? var.alias_function_version : aws_lambda_function.main.version

  dynamic "routing_config" {
    for_each = var.alias_routing_config != null ? [var.alias_routing_config] : []
    content {
      additional_version_weights = routing_config.value.additional_version_weights
    }
  }
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  count = var.create_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.environment}-${var.project_name}-${var.function_name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.error_alarm_threshold
  alarm_description   = "This metric monitors lambda errors"
  alarm_actions       = var.alarm_actions

  dimensions = {
    FunctionName = aws_lambda_function.main.function_name
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  count = var.create_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.environment}-${var.project_name}-${var.function_name}-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = var.duration_alarm_threshold
  alarm_description   = "This metric monitors lambda duration"
  alarm_actions       = var.alarm_actions

  dimensions = {
    FunctionName = aws_lambda_function.main.function_name
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  count = var.create_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.environment}-${var.project_name}-${var.function_name}-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.throttle_alarm_threshold
  alarm_description   = "This metric monitors lambda throttles"
  alarm_actions       = var.alarm_actions

  dimensions = {
    FunctionName = aws_lambda_function.main.function_name
  }

  tags = var.common_tags
}