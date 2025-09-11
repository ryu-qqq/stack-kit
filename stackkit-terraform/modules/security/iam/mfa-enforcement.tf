# Multi-Factor Authentication Enforcement
# Enterprise MFA policies with session management and device compliance

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
  
  # MFA enforcement levels by team and environment
  mfa_requirements = {
    production = {
      mfa_required = true
      mfa_max_age = 3600    # 1 hour
      trusted_devices_only = true
      hardware_mfa_preferred = true
      virtual_mfa_allowed = false
    }
    staging = {
      mfa_required = true
      mfa_max_age = 7200    # 2 hours
      trusted_devices_only = false
      hardware_mfa_preferred = false
      virtual_mfa_allowed = true
    }
    development = {
      mfa_required = false
      mfa_max_age = 14400   # 4 hours
      trusted_devices_only = false
      hardware_mfa_preferred = false
      virtual_mfa_allowed = true
    }
  }

  # High-privilege actions requiring MFA
  privileged_actions = [
    "iam:CreateUser",
    "iam:DeleteUser", 
    "iam:CreateRole",
    "iam:DeleteRole",
    "iam:AttachUserPolicy",
    "iam:DetachUserPolicy",
    "iam:PutUserPolicy",
    "iam:DeleteUserPolicy",
    "kms:CreateKey",
    "kms:ScheduleKeyDeletion",
    "secretsmanager:DeleteSecret",
    "secretsmanager:UpdateSecret",
    "rds:DeleteDBInstance",
    "ec2:TerminateInstances",
    "s3:DeleteBucket",
    "cloudformation:DeleteStack"
  ]
}

# Base MFA enforcement policy
resource "aws_iam_policy" "mfa_enforcement" {
  name        = "StackKit-MFA-Enforcement"
  path        = "/security/"
  description = "Enforce MFA for all privileged operations"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyAllExceptAssumeRoleWithoutMFA"
        Effect = "Deny"
        NotAction = [
          "sts:AssumeRole",
          "iam:ListUsers",
          "iam:ListRoles", 
          "iam:ListMFADevices",
          "iam:CreateVirtualMFADevice",
          "iam:EnableMFADevice",
          "iam:ResyncMFADevice"
        ]
        Resource = "*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      },
      {
        Sid    = "DenyPrivilegedActionsWithoutRecentMFA"
        Effect = "Deny"
        Action = local.privileged_actions
        Resource = "*"
        Condition = {
          NumericGreaterThan = {
            "aws:MultiFactorAuthAge" = "3600"
          }
        }
      },
      {
        Sid    = "AllowMFAManagement"
        Effect = "Allow"
        Action = [
          "iam:CreateVirtualMFADevice",
          "iam:DeleteVirtualMFADevice",
          "iam:ListMFADevices",
          "iam:EnableMFADevice",
          "iam:DeactivateMFADevice",
          "iam:ResyncMFADevice",
          "iam:GetUser",
          "iam:ChangePassword"
        ]
        Resource = [
          "arn:aws:iam::${local.account_id}:mfa/$${aws:username}",
          "arn:aws:iam::${local.account_id}:user/$${aws:username}"
        ]
      },
      {
        Sid    = "AllowAssumeRoleWithMFA"
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = "arn:aws:iam::${local.account_id}:role/StackKit-*"
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
          NumericLessThan = {
            "aws:MultiFactorAuthAge" = "3600"
          }
        }
      }
    ]
  })

  tags = {
    Purpose   = "MFAEnforcement"
    ManagedBy = "StackKit-Security"
  }
}

# Production environment MFA policy (hardware MFA required)
resource "aws_iam_policy" "production_mfa" {
  name        = "StackKit-Production-MFA"
  path        = "/security/"
  description = "Production environment MFA requirements"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RequireHardwareMFAForProduction"
        Effect = "Deny"
        Action = "*"
        Resource = "*"
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "false"
          }
          StringEquals = {
            "aws:RequestTag/Environment" = "prod"
          }
        }
      },
      {
        Sid    = "DenyVirtualMFAForProduction"
        Effect = "Deny"
        Action = "*"
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Environment" = "prod"
          }
          StringNotLike = {
            "aws:MultiFactorAuthType" = "hardware"
          }
        }
      },
      {
        Sid    = "RequireRecentMFAForProduction"
        Effect = "Deny"
        Action = "*"
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Environment" = "prod"
          }
          NumericGreaterThan = {
            "aws:MultiFactorAuthAge" = "3600"
          }
        }
      }
    ]
  })

  tags = {
    Environment = "production"
    Purpose     = "HardwareMFA"
    ManagedBy   = "StackKit-Security"
  }
}

# Staging environment MFA policy (virtual MFA allowed)
resource "aws_iam_policy" "staging_mfa" {
  name        = "StackKit-Staging-MFA"
  path        = "/security/"
  description = "Staging environment MFA requirements"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RequireMFAForStaging"
        Effect = "Deny"
        Action = "*"
        Resource = "*"
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "false"
          }
          StringEquals = {
            "aws:RequestTag/Environment" = "staging"
          }
        }
      },
      {
        Sid    = "AllowVirtualMFAForStaging"
        Effect = "Allow"
        Action = "*"
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Environment" = "staging"
          }
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
          NumericLessThan = {
            "aws:MultiFactorAuthAge" = "7200"
          }
        }
      }
    ]
  })

  tags = {
    Environment = "staging"
    Purpose     = "VirtualMFA"
    ManagedBy   = "StackKit-Security"
  }
}

# MFA device compliance monitoring
resource "aws_iam_policy" "mfa_compliance" {
  name        = "StackKit-MFA-Compliance"
  path        = "/security/"
  description = "MFA compliance monitoring and enforcement"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowMFAComplianceChecks"
        Effect = "Allow"
        Action = [
          "iam:ListUsers",
          "iam:ListMFADevices",
          "iam:GetUser",
          "iam:ListAccessKeys",
          "iam:GetAccessKeyLastUsed",
          "iam:ListUserPolicies",
          "iam:ListAttachedUserPolicies"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:PrincipalTag/Role" = ["SecurityAdmin", "ComplianceAuditor"]
          }
        }
      },
      {
        Sid    = "AllowMFAComplianceReporting"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "logs:CreateLogGroup",
          "logs:CreateLogStream", 
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${local.region}:${local.account_id}:log-group:/stackkit/security/mfa-compliance*",
          "arn:aws:cloudwatch:${local.region}:${local.account_id}:metric/StackKit/Security/*"
        ]
      }
    ]
  })

  tags = {
    Purpose   = "MFACompliance"
    ManagedBy = "StackKit-Security"
  }
}

# MFA session management policy
resource "aws_iam_policy" "mfa_session_management" {
  name        = "StackKit-MFA-SessionMgmt"
  path        = "/security/"
  description = "MFA session timeout and management"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnforceMFASessionTimeout"
        Effect = "Deny"
        Action = "*"
        Resource = "*"
        Condition = {
          DateGreaterThan = {
            "aws:CurrentTime" = "aws:MultiFactorAuthTime + 3600"
          }
          StringNotEquals = {
            "aws:PrincipalTag/SessionExtension" = "approved"
          }
        }
      },
      {
        Sid    = "RequireReauthenticationForSensitiveOps"
        Effect = "Deny"
        Action = [
          "iam:*",
          "kms:*",
          "secretsmanager:*",
          "organizations:*"
        ]
        Resource = "*"
        Condition = {
          NumericGreaterThan = {
            "aws:MultiFactorAuthAge" = "1800"  # 30 minutes for sensitive ops
          }
        }
      },
      {
        Sid    = "AllowSessionExtensionWithApproval"
        Effect = "Allow"
        Action = "sts:TagSession"
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedSessionTag/SessionExtension" = "approved"
            "aws:PrincipalTag/ApprovalAuthority" = ["SecurityAdmin", "BreakGlass"]
          }
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      }
    ]
  })

  tags = {
    Purpose   = "SessionManagement"
    ManagedBy = "StackKit-Security"
  }
}

# Break glass emergency access (requires multiple approvals)
resource "aws_iam_policy" "break_glass_mfa" {
  name        = "StackKit-BreakGlass-MFA"
  path        = "/security/"
  description = "Emergency break glass access with enhanced MFA"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowBreakGlassAccess"
        Effect = "Allow"
        Action = "*"
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:PrincipalTag/BreakGlass" = "activated"
            "aws:PrincipalTag/ApprovedBy" = ["SecurityTeam", "CTO", "CISO"]
          }
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
          NumericLessThan = {
            "aws:MultiFactorAuthAge" = "300"  # 5 minutes for break glass
          }
          DateLessThan = {
            "aws:CurrentTime" = "aws:PrincipalTag/BreakGlassExpiry"
          }
        }
      },
      {
        Sid    = "RequireBreakGlassLogging"
        Effect = "Deny"
        Action = "*"
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:PrincipalTag/BreakGlass" = "activated"
          }
          Bool = {
            "aws:CloudTrailLogged" = "false"
          }
        }
      }
    ]
  })

  tags = {
    Purpose   = "BreakGlassAccess"
    ManagedBy = "StackKit-Security"
  }
}

# CloudWatch log group for MFA compliance monitoring
resource "aws_cloudwatch_log_group" "mfa_compliance" {
  name              = "/stackkit/security/mfa-compliance"
  retention_in_days = 90
  kms_key_id        = var.cloudwatch_kms_key_arn

  tags = {
    Purpose   = "MFACompliance"
    ManagedBy = "StackKit-Security"
  }
}

# CloudWatch dashboard for MFA compliance
resource "aws_cloudwatch_dashboard" "mfa_compliance" {
  dashboard_name = "StackKit-MFA-Compliance"

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
            ["StackKit/Security", "MFACompliantUsers"],
            [".", "MFANonCompliantUsers"],
            [".", "HardwareMFAUsers"],
            [".", "VirtualMFAUsers"]
          ]
          period = 300
          stat   = "Average"
          region = local.region
          title  = "MFA Compliance Overview"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 24
        height = 6

        properties = {
          query   = "SOURCE '/stackkit/security/mfa-compliance'\n| fields @timestamp, eventName, userIdentity.userName, errorCode\n| filter eventName like /MFA/\n| sort @timestamp desc\n| limit 100"
          region  = local.region
          title   = "Recent MFA Events"
        }
      }
    ]
  })

  tags = {
    Purpose   = "MFAMonitoring"
    ManagedBy = "StackKit-Security"
  }
}

# Variables
variable "cloudwatch_kms_key_arn" {
  description = "KMS key ARN for CloudWatch log encryption"
  type        = string
  default     = null
}

# Outputs
output "mfa_enforcement_policies" {
  description = "MFA enforcement policy ARNs"
  value = {
    base_enforcement    = aws_iam_policy.mfa_enforcement.arn
    production_mfa      = aws_iam_policy.production_mfa.arn
    staging_mfa         = aws_iam_policy.staging_mfa.arn
    compliance          = aws_iam_policy.mfa_compliance.arn
    session_management  = aws_iam_policy.mfa_session_management.arn
    break_glass         = aws_iam_policy.break_glass_mfa.arn
  }
}

output "mfa_compliance_log_group" {
  description = "MFA compliance log group name"
  value       = aws_cloudwatch_log_group.mfa_compliance.name
}

output "mfa_dashboard_url" {
  description = "MFA compliance dashboard URL"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${local.region}#dashboards:name=${aws_cloudwatch_dashboard.mfa_compliance.dashboard_name}"
}