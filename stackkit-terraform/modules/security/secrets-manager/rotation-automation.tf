# Automated Secret Rotation with Lambda Functions
# GitHub tokens, API keys, and database credentials rotation

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  
  # Rotation schedules by secret type
  rotation_configs = {
    github_tokens = {
      schedule_days = 90
      backup_tokens = 2
      validation_required = true
      notification_days = 7
    }
    webhook_secrets = {
      schedule_days = 30
      backup_tokens = 1
      validation_required = true
      notification_days = 3
    }
    api_keys = {
      schedule_days = 60
      backup_tokens = 1
      validation_required = true
      notification_days = 5
    }
    database_passwords = {
      schedule_days = 180
      backup_tokens = 0
      validation_required = true
      notification_days = 14
    }
  }
}

# IAM role for rotation Lambda functions
resource "aws_iam_role" "rotation_lambda_role" {
  name = "StackKit-SecretRotation-LambdaRole"
  path = "/security/"

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

  tags = {
    Purpose   = "SecretRotation"
    ManagedBy = "StackKit-Security"
  }
}

# IAM policy for rotation Lambda functions
resource "aws_iam_role_policy" "rotation_lambda_policy" {
  name = "rotation-lambda-policy"
  role = aws_iam_role.rotation_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowBasicLambdaExecution"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${local.region}:${local.account_id}:*"
      },
      {
        Sid    = "AllowSecretsManagerAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:UpdateSecretVersionStage",
          "secretsmanager:PutSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:stackkit/*"
      },
      {
        Sid    = "AllowKMSAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = var.secrets_kms_key_arn
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${local.region}.amazonaws.com"
          }
        }
      },
      {
        Sid    = "AllowSNSPublish"
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.rotation_notifications.arn
      },
      {
        Sid    = "AllowCloudWatchMetrics"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "StackKit/Security/Rotation"
          }
        }
      }
    ]
  })
}

# GitHub token rotation Lambda function
resource "aws_lambda_function" "github_token_rotator" {
  filename         = data.archive_file.github_rotator.output_path
  function_name    = "stackkit-github-token-rotator"
  role            = aws_iam_role.rotation_lambda_role.arn
  handler         = "index.lambda_handler"
  runtime         = "python3.9"
  timeout         = 300
  source_code_hash = data.archive_file.github_rotator.output_base64sha256

  environment {
    variables = {
      SECRETS_MANAGER_ENDPOINT = "https://secretsmanager.${local.region}.amazonaws.com"
      SNS_TOPIC_ARN           = aws_sns_topic.rotation_notifications.arn
      GITHUB_ORG              = var.github_organization
      VALIDATION_ENABLED      = "true"
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.rotation_dlq.arn
  }

  tags = {
    Purpose   = "GitHubTokenRotation"
    ManagedBy = "StackKit-Security"
  }

  depends_on = [aws_iam_role_policy.rotation_lambda_policy]
}

# GitHub token rotator source code
data "archive_file" "github_rotator" {
  type        = "zip"
  output_path = "/tmp/github-rotator.zip"
  source {
    content = templatefile("${path.module}/lambda/github_rotator.py", {
      github_org = var.github_organization
    })
    filename = "index.py"
  }
}

# Webhook secret rotation Lambda function
resource "aws_lambda_function" "webhook_secret_rotator" {
  filename         = data.archive_file.webhook_rotator.output_path
  function_name    = "stackkit-webhook-secret-rotator"
  role            = aws_iam_role.rotation_lambda_role.arn
  handler         = "index.lambda_handler"
  runtime         = "python3.9"
  timeout         = 300
  source_code_hash = data.archive_file.webhook_rotator.output_base64sha256

  environment {
    variables = {
      SECRETS_MANAGER_ENDPOINT = "https://secretsmanager.${local.region}.amazonaws.com"
      SNS_TOPIC_ARN           = aws_sns_topic.rotation_notifications.arn
      ATLANTIS_URL            = var.atlantis_url
      VALIDATION_ENABLED      = "true"
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.rotation_dlq.arn
  }

  tags = {
    Purpose   = "WebhookSecretRotation"
    ManagedBy = "StackKit-Security"
  }

  depends_on = [aws_iam_role_policy.rotation_lambda_policy]
}

# Webhook secret rotator source code
data "archive_file" "webhook_rotator" {
  type        = "zip"
  output_path = "/tmp/webhook-rotator.zip"
  source {
    content = templatefile("${path.module}/lambda/webhook_rotator.py", {
      atlantis_url = var.atlantis_url
    })
    filename = "index.py"
  }
}

# API keys rotation Lambda function
resource "aws_lambda_function" "api_key_rotator" {
  filename         = data.archive_file.api_key_rotator.output_path
  function_name    = "stackkit-api-key-rotator"
  role            = aws_iam_role.rotation_lambda_role.arn
  handler         = "index.lambda_handler"
  runtime         = "python3.9"
  timeout         = 300
  source_code_hash = data.archive_file.api_key_rotator.output_base64sha256

  environment {
    variables = {
      SECRETS_MANAGER_ENDPOINT = "https://secretsmanager.${local.region}.amazonaws.com"
      SNS_TOPIC_ARN           = aws_sns_topic.rotation_notifications.arn
      VALIDATION_ENABLED      = "true"
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.rotation_dlq.arn
  }

  tags = {
    Purpose   = "APIKeyRotation"
    ManagedBy = "StackKit-Security"
  }

  depends_on = [aws_iam_role_policy.rotation_lambda_policy]
}

# API key rotator source code
data "archive_file" "api_key_rotator" {
  type        = "zip"
  output_path = "/tmp/api-key-rotator.zip"
  source {
    content = file("${path.module}/lambda/api_key_rotator.py")
    filename = "index.py"
  }
}

# Database password rotation Lambda function
resource "aws_lambda_function" "database_password_rotator" {
  filename         = data.archive_file.database_rotator.output_path
  function_name    = "stackkit-database-password-rotator"
  role            = aws_iam_role.rotation_lambda_role.arn
  handler         = "index.lambda_handler"
  runtime         = "python3.9"
  timeout         = 600
  source_code_hash = data.archive_file.database_rotator.output_base64sha256

  environment {
    variables = {
      SECRETS_MANAGER_ENDPOINT = "https://secretsmanager.${local.region}.amazonaws.com"
      SNS_TOPIC_ARN           = aws_sns_topic.rotation_notifications.arn
      VALIDATION_ENABLED      = "true"
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.rotation_dlq.arn
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.rotation_lambda.id]
  }

  tags = {
    Purpose   = "DatabasePasswordRotation"
    ManagedBy = "StackKit-Security"
  }

  depends_on = [aws_iam_role_policy.rotation_lambda_policy]
}

# Database password rotator source code
data "archive_file" "database_rotator" {
  type        = "zip"
  output_path = "/tmp/database-rotator.zip"
  source {
    content = file("${path.module}/lambda/database_rotator.py")
    filename = "index.py"
  }
}

# Security group for database rotation Lambda
resource "aws_security_group" "rotation_lambda" {
  name_prefix = "stackkit-rotation-lambda-"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS to AWS APIs"
  }

  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "PostgreSQL database access"
  }

  egress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "MySQL database access"
  }

  tags = {
    Name      = "stackkit-rotation-lambda-sg"
    Purpose   = "DatabaseRotation"
    ManagedBy = "StackKit-Security"
  }
}

# Secret rotation configurations
resource "aws_secretsmanager_secret_rotation" "github_token_rotation" {
  for_each = var.github_secrets
  
  secret_id           = each.value.secret_arn
  rotation_interval   = local.rotation_configs.github_tokens.schedule_days
  rotation_lambda_arn = aws_lambda_function.github_token_rotator.arn

  rotation_rules {
    automatically_after_days = local.rotation_configs.github_tokens.schedule_days
  }

  tags = {
    RotationType = "GitHubToken"
    ManagedBy    = "StackKit-Security"
  }
}

resource "aws_secretsmanager_secret_rotation" "webhook_secret_rotation" {
  for_each = var.webhook_secrets
  
  secret_id           = each.value.secret_arn
  rotation_interval   = local.rotation_configs.webhook_secrets.schedule_days
  rotation_lambda_arn = aws_lambda_function.webhook_secret_rotator.arn

  rotation_rules {
    automatically_after_days = local.rotation_configs.webhook_secrets.schedule_days
  }

  tags = {
    RotationType = "WebhookSecret"
    ManagedBy    = "StackKit-Security"
  }
}

resource "aws_secretsmanager_secret_rotation" "api_key_rotation" {
  for_each = var.api_key_secrets
  
  secret_id           = each.value.secret_arn
  rotation_interval   = local.rotation_configs.api_keys.schedule_days
  rotation_lambda_arn = aws_lambda_function.api_key_rotator.arn

  rotation_rules {
    automatically_after_days = local.rotation_configs.api_keys.schedule_days
  }

  tags = {
    RotationType = "APIKey"
    ManagedBy    = "StackKit-Security"
  }
}

resource "aws_secretsmanager_secret_rotation" "database_rotation" {
  for_each = var.database_secrets
  
  secret_id           = each.value.secret_arn
  rotation_interval   = local.rotation_configs.database_passwords.schedule_days
  rotation_lambda_arn = aws_lambda_function.database_password_rotator.arn

  rotation_rules {
    automatically_after_days = local.rotation_configs.database_passwords.schedule_days
  }

  tags = {
    RotationType = "DatabasePassword"
    ManagedBy    = "StackKit-Security"
  }
}

# SNS topic for rotation notifications
resource "aws_sns_topic" "rotation_notifications" {
  name              = "stackkit-secret-rotation-notifications"
  kms_master_key_id = var.secrets_kms_key_arn

  tags = {
    Purpose   = "RotationNotifications"
    ManagedBy = "StackKit-Security"
  }
}

# SNS topic policy
resource "aws_sns_topic_policy" "rotation_notifications" {
  arn = aws_sns_topic.rotation_notifications.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLambdaPublish"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.rotation_lambda_role.arn
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.rotation_notifications.arn
      }
    ]
  })
}

# SQS dead letter queue for failed rotations
resource "aws_sqs_queue" "rotation_dlq" {
  name                      = "stackkit-rotation-dlq"
  message_retention_seconds = 1209600  # 14 days
  kms_master_key_id        = var.secrets_kms_key_arn

  tags = {
    Purpose   = "RotationFailures"
    ManagedBy = "StackKit-Security"
  }
}

# EventBridge rules for rotation monitoring
resource "aws_cloudwatch_event_rule" "rotation_success" {
  name        = "stackkit-rotation-success"
  description = "Monitor successful secret rotations"

  event_pattern = jsonencode({
    source      = ["aws.secretsmanager"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["secretsmanager.amazonaws.com"]
      eventName   = ["RotationSucceeded"]
    }
  })

  tags = {
    Purpose   = "RotationMonitoring"
    ManagedBy = "StackKit-Security"
  }
}

resource "aws_cloudwatch_event_rule" "rotation_failure" {
  name        = "stackkit-rotation-failure"
  description = "Monitor failed secret rotations"

  event_pattern = jsonencode({
    source      = ["aws.secretsmanager"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["secretsmanager.amazonaws.com"]
      eventName   = ["RotationFailed"]
    }
  })

  tags = {
    Purpose   = "RotationMonitoring"
    ManagedBy = "StackKit-Security"
  }
}

# CloudWatch alarms for rotation monitoring
resource "aws_cloudwatch_metric_alarm" "rotation_failures" {
  alarm_name          = "StackKit-SecretRotationFailures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period             = "300"
  statistic          = "Sum"
  threshold          = "0"
  alarm_description  = "This metric monitors secret rotation failures"
  alarm_actions      = [aws_sns_topic.rotation_notifications.arn]

  dimensions = {
    FunctionName = aws_lambda_function.github_token_rotator.function_name
  }

  tags = {
    Purpose   = "RotationMonitoring"
    ManagedBy = "StackKit-Security"
  }
}

# CloudWatch dashboard for rotation monitoring
resource "aws_cloudwatch_dashboard" "rotation_monitoring" {
  dashboard_name = "StackKit-Secret-Rotation-Monitoring"

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
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.github_token_rotator.function_name],
            [".", "Errors", ".", "."],
            [".", "Duration", ".", "."]
          ]
          period = 300
          stat   = "Sum"
          region = local.region
          title  = "GitHub Token Rotation Metrics"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.webhook_secret_rotator.function_name],
            [".", "Errors", ".", "."],
            [".", "Duration", ".", "."]
          ]
          period = 300
          stat   = "Sum"
          region = local.region
          title  = "Webhook Secret Rotation Metrics"
        }
      }
    ]
  })

  tags = {
    Purpose   = "RotationMonitoring"
    ManagedBy = "StackKit-Security"
  }
}

# Variables
variable "secrets_kms_key_arn" {
  description = "KMS key ARN for secrets encryption"
  type        = string
}

variable "github_organization" {
  description = "GitHub organization name"
  type        = string
}

variable "atlantis_url" {
  description = "Atlantis URL for webhook validation"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for Lambda functions"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for Lambda functions"
  type        = list(string)
}

variable "github_secrets" {
  description = "GitHub secrets configuration"
  type = map(object({
    secret_arn = string
  }))
  default = {}
}

variable "webhook_secrets" {
  description = "Webhook secrets configuration"
  type = map(object({
    secret_arn = string
  }))
  default = {}
}

variable "api_key_secrets" {
  description = "API key secrets configuration"
  type = map(object({
    secret_arn = string
  }))
  default = {}
}

variable "database_secrets" {
  description = "Database secrets configuration"
  type = map(object({
    secret_arn = string
  }))
  default = {}
}

# Outputs
output "rotation_lambda_functions" {
  description = "Rotation Lambda function ARNs"
  value = {
    github_token = aws_lambda_function.github_token_rotator.arn
    webhook      = aws_lambda_function.webhook_secret_rotator.arn
    api_key      = aws_lambda_function.api_key_rotator.arn
    database     = aws_lambda_function.database_password_rotator.arn
  }
}

output "rotation_notifications" {
  description = "Rotation notification configuration"
  value = {
    sns_topic = aws_sns_topic.rotation_notifications.arn
    dlq       = aws_sqs_queue.rotation_dlq.arn
  }
}

output "rotation_monitoring" {
  description = "Rotation monitoring resources"
  value = {
    dashboard_url = "https://console.aws.amazon.com/cloudwatch/home?region=${local.region}#dashboards:name=${aws_cloudwatch_dashboard.rotation_monitoring.dashboard_name}"
    alarm_arn     = aws_cloudwatch_metric_alarm.rotation_failures.arn
  }
}