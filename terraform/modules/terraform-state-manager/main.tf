# Terraform State Management Module for StackKit Infrastructure
# Provides automated state backup, recovery, and consistency management
# with error handling and rollback capabilities.

# ==============================================================================
# STATE STORAGE INFRASTRUCTURE
# ==============================================================================

# Primary S3 bucket for state storage
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project_name}-${var.environment}-terraform-state-${random_id.bucket_suffix.hex}"
  
  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-terraform-state"
    Purpose     = "TerraformState"
    Environment = var.environment
    Project     = var.project_name
  })
  
  lifecycle {
    prevent_destroy = true
  }
}

# State backup bucket (different region for DR)
resource "aws_s3_bucket" "terraform_state_backup" {
  count = var.enable_cross_region_backup ? 1 : 0
  
  provider = aws.backup
  bucket   = "${var.project_name}-${var.environment}-terraform-state-backup-${random_id.bucket_suffix.hex}"
  
  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-terraform-state-backup"
    Purpose = "TerraformStateBackup"
  })
  
  lifecycle {
    prevent_destroy = true
  }
}

# Random suffix for bucket uniqueness
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# ==============================================================================
# BUCKET SECURITY CONFIGURATIONS
# ==============================================================================

# Block public access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "terraform_state_backup" {
  count = var.enable_cross_region_backup ? 1 : 0
  
  provider = aws.backup
  bucket   = aws_s3_bucket.terraform_state_backup[0].id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_id
      sse_algorithm     = var.kms_key_id != null ? "aws:kms" : "AES256"
    }
    bucket_key_enabled = var.kms_key_id != null
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_backup" {
  count = var.enable_cross_region_backup ? 1 : 0
  
  provider = aws.backup
  bucket   = aws_s3_bucket.terraform_state_backup[0].id
  
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.backup_kms_key_id
      sse_algorithm     = var.backup_kms_key_id != null ? "aws:kms" : "AES256"
    }
    bucket_key_enabled = var.backup_kms_key_id != null
  }
}

# Versioning for state history
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state_backup" {
  count = var.enable_cross_region_backup ? 1 : 0
  
  provider = aws.backup
  bucket   = aws_s3_bucket.terraform_state_backup[0].id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  depends_on = [aws_s3_bucket_versioning.terraform_state]
  bucket     = aws_s3_bucket.terraform_state.id
  
  rule {
    id     = "state_lifecycle"
    status = "Enabled"
    
    # Keep current versions
    expiration {
      days = var.state_retention_days
    }
    
    # Manage non-current versions
    noncurrent_version_expiration {
      noncurrent_days = var.old_version_retention_days
    }
    
    # Clean up incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# ==============================================================================
# DYNAMODB LOCK TABLE
# ==============================================================================

resource "aws_dynamodb_table" "terraform_lock" {
  name           = "${var.project_name}-${var.environment}-terraform-lock"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"
  
  attribute {
    name = "LockID"
    type = "S"
  }
  
  server_side_encryption {
    enabled     = var.enable_dynamodb_encryption
    kms_key_arn = var.dynamodb_kms_key_id
  }
  
  point_in_time_recovery {
    enabled = var.enable_dynamodb_pitr
  }
  
  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-terraform-lock"
    Purpose = "TerraformLocking"
  })
  
  lifecycle {
    prevent_destroy = true
  }
}

# ==============================================================================
# CROSS-REGION REPLICATION
# ==============================================================================

# Replication configuration for state backup
resource "aws_s3_bucket_replication_configuration" "terraform_state_replication" {
  count = var.enable_cross_region_backup ? 1 : 0
  
  role   = aws_iam_role.replication_role[0].arn
  bucket = aws_s3_bucket.terraform_state.id
  
  depends_on = [aws_s3_bucket_versioning.terraform_state]
  
  rule {
    id     = "replicate_state"
    status = "Enabled"
    
    destination {
      bucket        = aws_s3_bucket.terraform_state_backup[0].arn
      storage_class = "STANDARD_IA"
      
      dynamic "encryption_configuration" {
        for_each = var.backup_kms_key_id != null ? [1] : []
        content {
          replica_kms_key_id = var.backup_kms_key_id
        }
      }
    }
  }
}

# IAM role for S3 replication
resource "aws_iam_role" "replication_role" {
  count = var.enable_cross_region_backup ? 1 : 0
  
  name = "${var.project_name}-${var.environment}-s3-replication-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "replication_policy" {
  count = var.enable_cross_region_backup ? 1 : 0
  
  name = "${var.project_name}-${var.environment}-s3-replication-policy"
  role = aws_iam_role.replication_role[0].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl"
        ]
        Resource = "${aws_s3_bucket.terraform_state.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.terraform_state.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete"
        ]
        Resource = "${aws_s3_bucket.terraform_state_backup[0].arn}/*"
      }
    ]
  })
}

# ==============================================================================
# STATE MONITORING AND ALERTS
# ==============================================================================

# CloudWatch alarms for state operations
resource "aws_cloudwatch_metric_alarm" "state_operation_errors" {
  count = var.create_monitoring_alarms ? 1 : 0
  
  alarm_name          = "${var.project_name}-${var.environment}-terraform-state-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4xxErrors"
  namespace           = "AWS/S3"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "Terraform state operation errors"
  alarm_actions       = var.alarm_actions
  
  dimensions = {
    BucketName = aws_s3_bucket.terraform_state.bucket
  }
  
  tags = var.common_tags
}

# DynamoDB lock table monitoring
resource "aws_cloudwatch_metric_alarm" "lock_table_throttling" {
  count = var.create_monitoring_alarms ? 1 : 0
  
  alarm_name          = "${var.project_name}-${var.environment}-terraform-lock-throttling"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UserErrors"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Terraform lock table throttling"
  alarm_actions       = var.alarm_actions
  
  dimensions = {
    TableName = aws_dynamodb_table.terraform_lock.name
  }
  
  tags = var.common_tags
}

# ==============================================================================
# AUTOMATED BACKUP LAMBDA
# ==============================================================================

# Lambda function for automated state backups
resource "aws_lambda_function" "state_backup" {
  count = var.enable_automated_backups ? 1 : 0
  
  filename         = data.archive_file.state_backup_zip[0].output_path
  function_name    = "${var.project_name}-${var.environment}-terraform-state-backup"
  role            = aws_iam_role.state_backup_lambda_role[0].arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.state_backup_zip[0].output_base64sha256
  runtime         = "python3.9"
  timeout         = 300
  
  environment {
    variables = {
      STATE_BUCKET   = aws_s3_bucket.terraform_state.bucket
      BACKUP_BUCKET  = var.enable_cross_region_backup ? aws_s3_bucket.terraform_state_backup[0].bucket : ""
      PROJECT_NAME   = var.project_name
      ENVIRONMENT    = var.environment
    }
  }
  
  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-terraform-state-backup"
  })
}

# Lambda deployment package
data "archive_file" "state_backup_zip" {
  count = var.enable_automated_backups ? 1 : 0
  
  type        = "zip"
  output_path = "/tmp/terraform_state_backup.zip"
  
  source {
    content = templatefile("${path.module}/lambda/state_backup.py", {
      project_name = var.project_name
      environment  = var.environment
    })
    filename = "index.py"
  }
}

# Lambda execution role
resource "aws_iam_role" "state_backup_lambda_role" {
  count = var.enable_automated_backups ? 1 : 0
  
  name = "${var.project_name}-${var.environment}-state-backup-lambda-role"
  
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

resource "aws_iam_role_policy" "state_backup_lambda_policy" {
  count = var.enable_automated_backups ? 1 : 0
  
  name = "${var.project_name}-${var.environment}-state-backup-lambda-policy"
  role = aws_iam_role.state_backup_lambda_role[0].id
  
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
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:GetObjectVersion"
        ]
        Resource = [
          aws_s3_bucket.terraform_state.arn,
          "${aws_s3_bucket.terraform_state.arn}/*"
        ]
      }
    ]
  })
}

# CloudWatch Event Rule for scheduled backups
resource "aws_cloudwatch_event_rule" "state_backup_schedule" {
  count = var.enable_automated_backups ? 1 : 0
  
  name                = "${var.project_name}-${var.environment}-terraform-state-backup-schedule"
  description         = "Triggers Terraform state backup"
  schedule_expression = var.backup_schedule_expression
  
  tags = var.common_tags
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  count = var.enable_automated_backups ? 1 : 0
  
  rule      = aws_cloudwatch_event_rule.state_backup_schedule[0].name
  target_id = "TerraformStateBackupLambdaTarget"
  arn       = aws_lambda_function.state_backup[0].arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_lambda" {
  count = var.enable_automated_backups ? 1 : 0
  
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.state_backup[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.state_backup_schedule[0].arn
}

# ==============================================================================
# DATA SOURCES
# ==============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_region" "backup" {
  count    = var.enable_cross_region_backup ? 1 : 0
  provider = aws.backup
}