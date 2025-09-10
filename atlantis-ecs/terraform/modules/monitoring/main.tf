# StackKit Monitoring Module
# CloudWatch 기반 모니터링 및 알림 시스템

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# SNS Topic for alerts
resource "aws_sns_topic" "stackkit_alerts" {
  name = "${var.stack_name}-alerts"

  tags = {
    Name        = "${var.stack_name}-alerts"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# SNS Topic Policy
resource "aws_sns_topic_policy" "stackkit_alerts" {
  arn = aws_sns_topic.stackkit_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.stackkit_alerts.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# Email subscription for alerts
resource "aws_sns_topic_subscription" "email_alerts" {
  count     = var.notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.stackkit_alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# Lambda function for Slack notifications
resource "aws_lambda_function" "slack_notifier" {
  count         = var.slack_webhook_url != "" ? 1 : 0
  filename      = data.archive_file.slack_notifier[0].output_path
  function_name = "${var.stack_name}-slack-notifier"
  role          = aws_iam_role.lambda_role[0].arn
  handler       = "index.handler"
  runtime       = "python3.9"
  timeout       = 30

  source_code_hash = data.archive_file.slack_notifier[0].output_base64sha256

  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.slack_webhook_url
    }
  }

  tags = {
    Name        = "${var.stack_name}-slack-notifier"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Lambda function code for Slack notifications
data "archive_file" "slack_notifier" {
  count       = var.slack_webhook_url != "" ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/slack_notifier.zip"
  
  source {
    content = templatefile("${path.module}/slack_notifier.py", {
      webhook_url = var.slack_webhook_url
    })
    filename = "index.py"
  }
}

# IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  count = var.slack_webhook_url != "" ? 1 : 0
  name  = "${var.stack_name}-lambda-role"

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
}

# IAM policy for Lambda
resource "aws_iam_role_policy" "lambda_policy" {
  count = var.slack_webhook_url != "" ? 1 : 0
  name  = "${var.stack_name}-lambda-policy"
  role  = aws_iam_role.lambda_role[0].id

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
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# SNS subscription for Lambda
resource "aws_sns_topic_subscription" "slack_alerts" {
  count     = var.slack_webhook_url != "" ? 1 : 0
  topic_arn = aws_sns_topic.stackkit_alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.slack_notifier[0].arn
}

# Lambda permission for SNS
resource "aws_lambda_permission" "sns_invoke" {
  count         = var.slack_webhook_url != "" ? 1 : 0
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_notifier[0].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.stackkit_alerts.arn
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "deployment_logs" {
  name              = "/stackkit/${var.stack_name}/deployment"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.stack_name}-deployment-logs"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_log_group" "terraform_logs" {
  name              = "/stackkit/${var.stack_name}/terraform"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.stack_name}-terraform-logs"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_log_group" "atlantis_logs" {
  name              = "/stackkit/${var.stack_name}/atlantis"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.stack_name}-atlantis-logs"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "deployment_failure_rate" {
  alarm_name          = "${var.stack_name}-deployment-failure-rate"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "DeploymentFailure"
  namespace           = "StackKit/Deployment"
  period              = "300"
  statistic           = "Sum"
  threshold           = "2"
  alarm_description   = "This metric monitors deployment failure rate"
  alarm_actions       = [aws_sns_topic.stackkit_alerts.arn]
  ok_actions          = [aws_sns_topic.stackkit_alerts.arn]

  dimensions = {
    StackName   = var.stack_name
    Environment = var.environment
  }

  tags = {
    Name        = "${var.stack_name}-deployment-failure-alarm"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_metric_alarm" "cost_increase" {
  alarm_name          = "${var.stack_name}-cost-increase"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CostChange"
  namespace           = "StackKit/Cost"
  period              = "86400"
  statistic           = "Sum"
  threshold           = var.cost_alert_threshold
  alarm_description   = "This metric monitors infrastructure cost increases"
  alarm_actions       = [aws_sns_topic.stackkit_alerts.arn]

  dimensions = {
    StackName   = var.stack_name
    Environment = var.environment
  }

  tags = {
    Name        = "${var.stack_name}-cost-increase-alarm"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_metric_alarm" "deployment_duration" {
  alarm_name          = "${var.stack_name}-deployment-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "DeploymentDuration"
  namespace           = "StackKit/Deployment"
  period              = "3600"
  statistic           = "Maximum"
  threshold           = var.deployment_duration_threshold
  alarm_description   = "This metric monitors long deployment durations"
  alarm_actions       = [aws_sns_topic.stackkit_alerts.arn]

  dimensions = {
    StackName   = var.stack_name
    Environment = var.environment
  }

  tags = {
    Name        = "${var.stack_name}-deployment-duration-alarm"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "stackkit_dashboard" {
  dashboard_name = "StackKit-${var.stack_name}-${var.environment}"

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
            ["StackKit/Deployment", "DeploymentSuccess", "StackName", var.stack_name, "Environment", var.environment],
            [".", "DeploymentFailure", ".", ".", ".", "."],
            [".", "DeploymentRollback", ".", ".", ".", "."]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "Deployment Status"
          view   = "timeSeries"
          stacked = false
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["StackKit/Deployment", "DeploymentDuration", "StackName", var.stack_name, "Environment", var.environment]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Deployment Duration (seconds)"
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["StackKit/Cost", "TotalCost", "StackName", var.stack_name, "Environment", var.environment],
            [".", "CostChange", ".", ".", ".", "."]
          ]
          period = 86400
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Infrastructure Cost (USD)"
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["StackKit/TerraformState", "ResourceCount", "StackName", var.stack_name, "Environment", var.environment]
          ]
          period = 3600
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Terraform Resources"
          view   = "timeSeries"
        }
      }
    ]
  })
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}