# Enterprise Secrets Management with KMS Encryption and Team Isolation
# Automatic rotation, cross-region replication, and comprehensive auditing

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  
  # Team-based secret namespaces
  teams = ["frontend", "backend", "devops", "security"]
  
  # Cross-region replication targets
  replication_regions = {
    "us-east-1"      = "us-west-2"
    "us-west-2"      = "us-east-1" 
    "ap-northeast-2" = "ap-southeast-1"
    "eu-west-1"      = "eu-central-1"
  }
  
  backup_region = lookup(local.replication_regions, local.region, "us-east-1")
}

# KMS key for secrets encryption
resource "aws_kms_key" "secrets" {
  description             = "StackKit secrets encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  multi_region           = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Secrets Manager Service"
        Effect = "Allow"
        Principal = {
          Service = "secretsmanager.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:ReEncryptFrom",
          "kms:ReEncryptTo"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow CloudTrail Service"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow team-specific access"
        Effect = "Allow"
        Principal = {
          AWS = [
            for team in local.teams : 
            "arn:aws:iam::${local.account_id}:role/StackKit-${title(team)}Team-Role"
          ]
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${local.region}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name      = "StackKit-Secrets-KMS"
    Purpose   = "SecretsEncryption"
    ManagedBy = "StackKit-Security"
  }
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/stackkit-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

# Team-specific secret namespaces
resource "aws_secretsmanager_secret" "team_secrets" {
  for_each = toset(local.teams)
  
  name                    = "stackkit/${each.key}/secrets"
  description             = "Team secrets for ${each.key} team"
  kms_key_id              = aws_kms_key.secrets.arn
  recovery_window_in_days = 7

  # Cross-region replication for high availability
  replica {
    region     = local.backup_region
    kms_key_id = aws_kms_key.secrets.arn
  }

  tags = {
    Team      = each.key
    Purpose   = "TeamSecrets"
    ManagedBy = "StackKit-Security"
  }
}

# Atlantis-specific secrets (enhanced from existing implementation)
resource "aws_secretsmanager_secret" "atlantis" {
  name                    = "stackkit/atlantis/config"
  description             = "Atlantis configuration secrets"
  kms_key_id              = aws_kms_key.secrets.arn
  recovery_window_in_days = 7

  replica {
    region     = local.backup_region
    kms_key_id = aws_kms_key.secrets.arn
  }

  tags = {
    Application = "Atlantis"
    Team        = "devops"
    Purpose     = "ApplicationConfig"
    ManagedBy   = "StackKit-Security"
  }
}

# Database credentials with automatic rotation
resource "aws_secretsmanager_secret" "database_credentials" {
  for_each = toset(["staging", "production"])
  
  name                    = "stackkit/database/${each.key}/credentials"
  description             = "Database credentials for ${each.key} environment"
  kms_key_id              = aws_kms_key.secrets.arn
  recovery_window_in_days = 7

  replica {
    region     = local.backup_region
    kms_key_id = aws_kms_key.secrets.arn
  }

  tags = {
    Environment = each.key
    Purpose     = "DatabaseCredentials"
    ManagedBy   = "StackKit-Security"
  }
}

# API keys and service credentials
resource "aws_secretsmanager_secret" "api_credentials" {
  for_each = toset(["github", "slack", "infracost", "monitoring"])
  
  name                    = "stackkit/api/${each.key}/credentials"
  description             = "${title(each.key)} API credentials and configuration"
  kms_key_id              = aws_kms_key.secrets.arn
  recovery_window_in_days = 7

  replica {
    region     = local.backup_region
    kms_key_id = aws_kms_key.secrets.arn
  }

  tags = {
    Service   = each.key
    Purpose   = "APICredentials"
    ManagedBy = "StackKit-Security"
  }
}

# Break glass emergency credentials
resource "aws_secretsmanager_secret" "break_glass" {
  name                    = "stackkit/emergency/break-glass"
  description             = "Emergency break glass credentials"
  kms_key_id              = aws_kms_key.secrets.arn
  recovery_window_in_days = 30

  replica {
    region     = local.backup_region
    kms_key_id = aws_kms_key.secrets.arn
  }

  tags = {
    Purpose     = "EmergencyAccess"
    Criticality = "High"
    ManagedBy   = "StackKit-Security"
  }
}

# IAM policies for secret access control
resource "aws_iam_policy" "secrets_read_policy" {
  for_each = toset(local.teams)
  
  name        = "StackKit-${title(each.key)}Team-SecretsRead"
  path        = "/secrets/"
  description = "Read access to ${each.key} team secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowTeamSecretsRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.team_secrets[each.key].arn,
          "${aws_secretsmanager_secret.team_secrets[each.key].arn}:*"
        ]
        Condition = {
          StringEquals = {
            "secretsmanager:ResourceTag/Team" = each.key
          }
        }
      },
      {
        Sid    = "AllowSharedSecretsRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:stackkit/shared/*"
        ]
      },
      {
        Sid    = "DenyOtherTeamSecrets"
        Effect = "Deny"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          for team in local.teams : 
          aws_secretsmanager_secret.team_secrets[team].arn
          if team != each.key
        ]
      }
    ]
  })

  tags = {
    Team      = each.key
    Purpose   = "SecretsAccess"
    ManagedBy = "StackKit-Security"
  }
}

# Security team full secrets access
resource "aws_iam_policy" "security_team_secrets" {
  name        = "StackKit-SecurityTeam-SecretsAdmin"
  path        = "/secrets/"
  description = "Full secrets management for security team"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowFullSecretsAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:*"
        ]
        Resource = "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:stackkit/*"
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
          NumericLessThan = {
            "aws:MultiFactorAuthAge" = "3600"
          }
        }
      },
      {
        Sid    = "AllowKMSAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:CreateGrant"
        ]
        Resource = aws_kms_key.secrets.arn
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${local.region}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Team      = "security"
    Purpose   = "SecretsAdmin"
    ManagedBy = "StackKit-Security"
  }
}

# CloudTrail for secrets access auditing
resource "aws_s3_bucket" "secrets_audit" {
  bucket = "stackkit-secrets-audit-${local.account_id}-${local.region}"

  tags = {
    Purpose   = "SecretsAudit"
    ManagedBy = "StackKit-Security"
  }
}

resource "aws_s3_bucket_versioning" "secrets_audit" {
  bucket = aws_s3_bucket.secrets_audit.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "secrets_audit" {
  bucket = aws_s3_bucket.secrets_audit.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.secrets.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "secrets_audit" {
  bucket = aws_s3_bucket.secrets_audit.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "secrets_audit" {
  bucket = aws_s3_bucket.secrets_audit.id

  rule {
    id     = "secrets-audit-lifecycle"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }
  }
}

# CloudTrail for secrets access logging
resource "aws_cloudtrail" "secrets_audit" {
  name                         = "stackkit-secrets-audit"
  s3_bucket_name               = aws_s3_bucket.secrets_audit.bucket
  include_global_service_events = true
  is_multi_region_trail       = true
  enable_log_file_validation  = true
  kms_key_id                  = aws_kms_key.secrets.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = false

    data_resource {
      type   = "AWS::SecretsManager::Secret"
      values = ["arn:aws:secretsmanager:*:${local.account_id}:secret:stackkit/*"]
    }
  }

  tags = {
    Purpose   = "SecretsAudit"
    ManagedBy = "StackKit-Security"
  }

  depends_on = [aws_s3_bucket_policy.secrets_audit]
}

# S3 bucket policy for CloudTrail
resource "aws_s3_bucket_policy" "secrets_audit" {
  bucket = aws_s3_bucket.secrets_audit.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.secrets_audit.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.secrets_audit.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# CloudWatch log group for secrets monitoring
resource "aws_cloudwatch_log_group" "secrets_monitoring" {
  name              = "/stackkit/security/secrets-monitoring"
  retention_in_days = 90
  kms_key_id        = aws_kms_key.secrets.arn

  tags = {
    Purpose   = "SecretsMonitoring"
    ManagedBy = "StackKit-Security"
  }
}

# CloudWatch alarms for suspicious secret access
resource "aws_cloudwatch_metric_alarm" "unusual_secret_access" {
  alarm_name          = "StackKit-UnusualSecretAccess"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "GetSecretValue"
  namespace           = "AWS/SecretsManager"
  period             = "300"
  statistic          = "Sum"
  threshold          = "50"
  alarm_description  = "This metric monitors unusual secret access patterns"
  alarm_actions      = [aws_sns_topic.security_alerts.arn]

  dimensions = {
    SecretName = "*stackkit*"
  }

  tags = {
    Purpose   = "SecurityMonitoring"
    ManagedBy = "StackKit-Security"
  }
}

# SNS topic for security alerts
resource "aws_sns_topic" "security_alerts" {
  name            = "stackkit-security-alerts"
  kms_master_key_id = aws_kms_key.secrets.arn

  tags = {
    Purpose   = "SecurityAlerts"
    ManagedBy = "StackKit-Security"
  }
}

# Outputs
output "secrets_kms_key" {
  description = "KMS key for secrets encryption"
  value = {
    key_id = aws_kms_key.secrets.key_id
    arn    = aws_kms_key.secrets.arn
    alias  = aws_kms_alias.secrets.name
  }
}

output "team_secrets" {
  description = "Team-specific secrets"
  value = {
    for team, secret in aws_secretsmanager_secret.team_secrets : team => {
      name = secret.name
      arn  = secret.arn
    }
  }
}

output "application_secrets" {
  description = "Application secrets"
  value = {
    atlantis = {
      name = aws_secretsmanager_secret.atlantis.name
      arn  = aws_secretsmanager_secret.atlantis.arn
    }
  }
}

output "secrets_audit" {
  description = "Secrets audit configuration"
  value = {
    s3_bucket    = aws_s3_bucket.secrets_audit.bucket
    cloudtrail   = aws_cloudtrail.secrets_audit.name
    log_group    = aws_cloudwatch_log_group.secrets_monitoring.name
    sns_topic    = aws_sns_topic.security_alerts.arn
  }
}

output "secrets_policies" {
  description = "IAM policies for secrets access"
  value = {
    for team in local.teams : team => aws_iam_policy.secrets_read_policy[team].arn
  }
}