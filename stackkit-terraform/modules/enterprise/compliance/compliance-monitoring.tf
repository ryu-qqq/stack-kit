# Automated Compliance Monitoring and Reporting
# SOC2, HIPAA, ISO27001 validation with real-time compliance scoring

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

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  
  # Compliance frameworks configuration
  compliance_frameworks = {
    soc2 = {
      name = "SOC 2 Type II"
      controls = [
        "CC1.1", "CC1.2", "CC1.3", "CC1.4",  # Control Environment
        "CC6.1", "CC6.2", "CC6.3", "CC6.6", "CC6.7", "CC6.8",  # Logical Access
        "CC7.1", "CC7.2", "CC7.3", "CC7.4",  # System Operations
        "CC8.1", "CC8.2",  # Change Management
        "CC9.1", "CC9.2"   # Risk Mitigation
      ]
      monitoring_rules = [
        "access-control-validation",
        "encryption-compliance",
        "audit-logging",
        "vulnerability-management",
        "incident-response"
      ]
    }
    
    hipaa = {
      name = "HIPAA Security Rule"
      controls = [
        "164.306", "164.308", "164.310", "164.312", "164.314", "164.316"
      ]
      monitoring_rules = [
        "phi-encryption",
        "access-controls",
        "audit-controls", 
        "integrity-controls",
        "transmission-security"
      ]
    }
    
    iso27001 = {
      name = "ISO 27001"
      controls = [
        "A.8", "A.9", "A.10", "A.11", "A.12", "A.13", "A.14", "A.15", "A.16", "A.17", "A.18"
      ]
      monitoring_rules = [
        "asset-management",
        "access-control",
        "cryptography",
        "operations-security",
        "communications-security"
      ]
    }
  }
}

# AWS Config for compliance monitoring
resource "aws_config_configuration_recorder" "compliance_recorder" {
  name     = "stackkit-compliance-recorder"
  role_arn = aws_iam_role.config_role.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
    recording_mode {
      recording_frequency = "DAILY"
      recording_mode_overrides {
        description         = "Critical resources continuous monitoring"
        resource_types      = [
          "AWS::IAM::Role",
          "AWS::IAM::Policy", 
          "AWS::KMS::Key",
          "AWS::SecretsManager::Secret",
          "AWS::S3::Bucket"
        ]
        recording_frequency = "CONTINUOUS"
      }
    }
  }

  depends_on = [aws_config_delivery_channel.compliance_delivery_channel]

  tags = {
    Purpose   = "ComplianceMonitoring"
    ManagedBy = "StackKit-Security"
  }
}

resource "aws_config_delivery_channel" "compliance_delivery_channel" {
  name           = "stackkit-compliance-delivery"
  s3_bucket_name = aws_s3_bucket.compliance_logs.bucket
  s3_key_prefix  = "config"

  snapshot_delivery_properties {
    delivery_frequency = "TwentyFour_Hours"
  }

  depends_on = [aws_s3_bucket_policy.compliance_logs]
}

# S3 bucket for compliance logs
resource "aws_s3_bucket" "compliance_logs" {
  bucket        = "stackkit-compliance-logs-${local.account_id}-${local.region}"
  force_destroy = false

  tags = {
    Purpose   = "ComplianceLogs"
    ManagedBy = "StackKit-Security"
  }
}

resource "aws_s3_bucket_versioning" "compliance_logs" {
  bucket = aws_s3_bucket.compliance_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "compliance_logs" {
  bucket = aws_s3_bucket.compliance_logs.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.compliance.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "compliance_logs" {
  bucket = aws_s3_bucket.compliance_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "compliance_logs" {
  bucket = aws_s3_bucket.compliance_logs.id

  rule {
    id     = "compliance-logs-lifecycle"
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
      days          = 2555  # 7 years
      storage_class = "DEEP_ARCHIVE"
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }
  }
}

resource "aws_s3_bucket_policy" "compliance_logs" {
  bucket = aws_s3_bucket.compliance_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSConfigBucketPermissionsCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.compliance_logs.arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = local.account_id
          }
        }
      },
      {
        Sid    = "AWSConfigBucketExistenceCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.compliance_logs.arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = local.account_id
          }
        }
      },
      {
        Sid    = "AWSConfigBucketDelivery"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.compliance_logs.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
            "AWS:SourceAccount" = local.account_id
          }
        }
      }
    ]
  })
}

# KMS key for compliance data encryption
resource "aws_kms_key" "compliance" {
  description             = "StackKit compliance data encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

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
        Sid    = "Allow AWS Config"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow compliance services"
        Effect = "Allow"
        Principal = {
          Service = [
            "securityhub.amazonaws.com",
            "guardduty.amazonaws.com", 
            "inspector.amazonaws.com"
          ]
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name      = "StackKit-Compliance-KMS"
    Purpose   = "ComplianceEncryption"
    ManagedBy = "StackKit-Security"
  }
}

resource "aws_kms_alias" "compliance" {
  name          = "alias/stackkit-compliance"
  target_key_id = aws_kms_key.compliance.key_id
}

# IAM role for AWS Config
resource "aws_iam_role" "config_role" {
  name = "StackKit-AWSConfig-Role"
  path = "/compliance/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Purpose   = "ComplianceConfig"
    ManagedBy = "StackKit-Security"
  }
}

resource "aws_iam_role_policy_attachment" "config_role" {
  role       = aws_iam_role.config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/ConfigRole"
}

# AWS Config Rules for compliance monitoring
resource "aws_config_config_rule" "soc2_encryption_in_transit" {
  name = "stackkit-soc2-encryption-in-transit"

  source {
    owner             = "AWS"
    source_identifier = "ALB_HTTP_TO_HTTPS_REDIRECTION_CHECK"
  }

  depends_on = [aws_config_configuration_recorder.compliance_recorder]

  tags = {
    Framework = "SOC2"
    Control   = "CC6.7"
    ManagedBy = "StackKit-Security"
  }
}

resource "aws_config_config_rule" "soc2_encryption_at_rest" {
  name = "stackkit-soc2-encryption-at-rest"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder.compliance_recorder]

  tags = {
    Framework = "SOC2"
    Control   = "CC6.7"
    ManagedBy = "StackKit-Security"
  }
}

resource "aws_config_config_rule" "soc2_access_control" {
  name = "stackkit-soc2-access-control"

  source {
    owner             = "AWS"
    source_identifier = "IAM_ROOT_ACCESS_KEY_CHECK"
  }

  depends_on = [aws_config_configuration_recorder.compliance_recorder]

  tags = {
    Framework = "SOC2"
    Control   = "CC6.1"
    ManagedBy = "StackKit-Security"
  }
}

resource "aws_config_config_rule" "hipaa_encryption" {
  name = "stackkit-hipaa-encryption"

  source {
    owner             = "AWS"
    source_identifier = "RDS_STORAGE_ENCRYPTED"
  }

  depends_on = [aws_config_configuration_recorder.compliance_recorder]

  tags = {
    Framework = "HIPAA"
    Control   = "164.312"
    ManagedBy = "StackKit-Security"
  }
}

# Security Hub for centralized compliance dashboard
resource "aws_securityhub_account" "main" {
  enable_default_standards = true
}

resource "aws_securityhub_standards_subscription" "soc2" {
  standards_arn = "arn:aws:securityhub:::ruleset/finding-format/aws-foundational-security-standard/v/1.0.0"
  depends_on    = [aws_securityhub_account.main]
}

# GuardDuty for threat detection
resource "aws_guardduty_detector" "main" {
  enable = true
  
  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  tags = {
    Purpose   = "ThreatDetection"
    ManagedBy = "StackKit-Security"
  }
}

# Inspector for vulnerability assessment
resource "aws_inspector2_enabler" "main" {
  account_ids    = [local.account_id]
  resource_types = ["ECR", "EC2"]
}

# Lambda function for compliance scoring
resource "aws_lambda_function" "compliance_scorer" {
  filename         = data.archive_file.compliance_scorer.output_path
  function_name    = "stackkit-compliance-scorer"
  role            = aws_iam_role.compliance_scorer_role.arn
  handler         = "index.lambda_handler"
  runtime         = "python3.9"
  timeout         = 300
  source_code_hash = data.archive_file.compliance_scorer.output_base64sha256

  environment {
    variables = {
      COMPLIANCE_BUCKET = aws_s3_bucket.compliance_logs.bucket
      SNS_TOPIC_ARN    = aws_sns_topic.compliance_alerts.arn
      FRAMEWORKS       = jsonencode(keys(local.compliance_frameworks))
    }
  }

  tags = {
    Purpose   = "ComplianceScoring"
    ManagedBy = "StackKit-Security"
  }
}

# Compliance scorer Lambda source
data "archive_file" "compliance_scorer" {
  type        = "zip"
  output_path = "/tmp/compliance-scorer.zip"
  source {
    content  = templatefile("${path.module}/lambda/compliance_scorer.py", {
      frameworks = local.compliance_frameworks
    })
    filename = "index.py"
  }
}

# IAM role for compliance scorer Lambda
resource "aws_iam_role" "compliance_scorer_role" {
  name = "StackKit-ComplianceScorer-Role"
  path = "/compliance/"

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
    Purpose   = "ComplianceScoring"
    ManagedBy = "StackKit-Security"
  }
}

resource "aws_iam_role_policy" "compliance_scorer_policy" {
  name = "compliance-scorer-policy"
  role = aws_iam_role.compliance_scorer_role.id

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
        Resource = "arn:aws:logs:${local.region}:${local.account_id}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "config:GetComplianceDetailsByConfigRule",
          "config:DescribeConfigRules",
          "config:GetComplianceSummaryByConfigRule"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "securityhub:GetFindings",
          "securityhub:GetComplianceSummary"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.compliance_logs.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.compliance_alerts.arn
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "StackKit/Compliance"
          }
        }
      }
    ]
  })
}

# EventBridge rule for daily compliance scoring
resource "aws_cloudwatch_event_rule" "daily_compliance_check" {
  name                = "stackkit-daily-compliance-check"
  description         = "Daily compliance scoring and reporting"
  schedule_expression = "cron(0 6 * * ? *)"  # 6 AM UTC daily

  tags = {
    Purpose   = "ComplianceAutomation"
    ManagedBy = "StackKit-Security"
  }
}

resource "aws_cloudwatch_event_target" "compliance_scorer_target" {
  rule      = aws_cloudwatch_event_rule.daily_compliance_check.name
  target_id = "ComplianceScorerTarget"
  arn       = aws_lambda_function.compliance_scorer.arn
}

resource "aws_lambda_permission" "allow_eventbridge_compliance" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.compliance_scorer.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_compliance_check.arn
}

# SNS topic for compliance alerts
resource "aws_sns_topic" "compliance_alerts" {
  name              = "stackkit-compliance-alerts"
  kms_master_key_id = aws_kms_key.compliance.arn

  tags = {
    Purpose   = "ComplianceAlerts"
    ManagedBy = "StackKit-Security"
  }
}

# CloudWatch dashboard for compliance monitoring
resource "aws_cloudwatch_dashboard" "compliance_overview" {
  dashboard_name = "StackKit-Compliance-Overview"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 8
        height = 6

        properties = {
          metrics = [
            ["StackKit/Compliance", "SOC2Score"],
            [".", "HIPAAScore"],
            [".", "ISO27001Score"]
          ]
          period = 3600
          stat   = "Average"
          region = local.region
          title  = "Compliance Scores"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 0
        width  = 8
        height = 6

        properties = {
          metrics = [
            ["AWS/Config", "ComplianceByConfigRule", "RuleName", "stackkit-soc2-encryption-in-transit", "ComplianceType", "COMPLIANT"],
            ["...", "NON_COMPLIANT"],
            ["...", "stackkit-soc2-access-control", ".", "COMPLIANT"],
            ["...", "NON_COMPLIANT"]
          ]
          period = 3600
          stat   = "Sum"
          region = local.region
          title  = "Config Rule Compliance"
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 0
        width  = 8
        height = 6

        properties = {
          metrics = [
            ["AWS/GuardDuty", "FindingCount", "DetectorId", aws_guardduty_detector.main.id]
          ]
          period = 3600
          stat   = "Sum"
          region = local.region
          title  = "Security Findings"
        }
      }
    ]
  })

  tags = {
    Purpose   = "ComplianceMonitoring"
    ManagedBy = "StackKit-Security"
  }
}

# Variables
variable "notification_email" {
  description = "Email address for compliance notifications"
  type        = string
  default     = ""
}

variable "compliance_frameworks" {
  description = "List of compliance frameworks to monitor"
  type        = list(string)
  default     = ["soc2", "hipaa", "iso27001"]
}

# Outputs
output "compliance_monitoring" {
  description = "Compliance monitoring configuration"
  value = {
    config_recorder     = aws_config_configuration_recorder.compliance_recorder.name
    compliance_bucket   = aws_s3_bucket.compliance_logs.bucket
    security_hub_arn    = aws_securityhub_account.main.arn
    guardduty_detector  = aws_guardduty_detector.main.id
    dashboard_url       = "https://console.aws.amazon.com/cloudwatch/home?region=${local.region}#dashboards:name=${aws_cloudwatch_dashboard.compliance_overview.dashboard_name}"
  }
}

output "compliance_kms_key" {
  description = "KMS key for compliance data encryption"
  value = {
    key_id = aws_kms_key.compliance.key_id
    arn    = aws_kms_key.compliance.arn
    alias  = aws_kms_alias.compliance.name
  }
}

output "compliance_alerts" {
  description = "Compliance alerting configuration"
  value = {
    sns_topic = aws_sns_topic.compliance_alerts.arn
    lambda_function = aws_lambda_function.compliance_scorer.function_name
  }
}