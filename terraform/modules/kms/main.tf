# KMS Key
resource "aws_kms_key" "main" {
  description              = var.description
  key_usage                = var.key_usage
  key_spec                 = var.key_spec
  customer_master_key_spec = var.customer_master_key_spec
  key_rotation_enabled     = var.enable_key_rotation
  deletion_window_in_days  = var.deletion_window_in_days
  multi_region            = var.multi_region

  policy = var.policy != null ? var.policy : data.aws_iam_policy_document.key_policy.json

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-${var.key_name}"
  })
}

# KMS Key Alias
resource "aws_kms_alias" "main" {
  name          = "alias/${var.project_name}-${var.environment}-${var.key_name}"
  target_key_id = aws_kms_key.main.key_id
}

# Default KMS Key Policy
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "key_policy" {
  # Root permissions
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    
    actions   = ["kms:*"]
    resources = ["*"]
  }

  # Key administrators
  dynamic "statement" {
    for_each = length(var.key_administrators) > 0 ? [1] : []
    content {
      sid    = "Allow administration of the key"
      effect = "Allow"
      
      principals {
        type        = "AWS"
        identifiers = var.key_administrators
      }
      
      actions = [
        "kms:Create*",
        "kms:Describe*",
        "kms:Enable*",
        "kms:List*",
        "kms:Put*",
        "kms:Update*",
        "kms:Revoke*",
        "kms:Disable*",
        "kms:Get*",
        "kms:Delete*",
        "kms:TagResource",
        "kms:UntagResource",
        "kms:ScheduleKeyDeletion",
        "kms:CancelKeyDeletion"
      ]
      
      resources = ["*"]
    }
  }

  # Key users
  dynamic "statement" {
    for_each = length(var.key_users) > 0 ? [1] : []
    content {
      sid    = "Allow use of the key"
      effect = "Allow"
      
      principals {
        type        = "AWS"
        identifiers = var.key_users
      }
      
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ]
      
      resources = ["*"]
    }
  }

  # Service principals
  dynamic "statement" {
    for_each = length(var.service_principals) > 0 ? [1] : []
    content {
      sid    = "Allow service principals"
      effect = "Allow"
      
      principals {
        type        = "Service"
        identifiers = var.service_principals
      }
      
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey",
        "kms:CreateGrant"
      ]
      
      resources = ["*"]
      
      dynamic "condition" {
        for_each = var.service_principal_conditions
        content {
          test     = condition.value.test
          variable = condition.value.variable
          values   = condition.value.values
        }
      }
    }
  }

  # Cross-account access
  dynamic "statement" {
    for_each = length(var.cross_account_principals) > 0 ? [1] : []
    content {
      sid    = "Allow cross-account access"
      effect = "Allow"
      
      principals {
        type        = "AWS"
        identifiers = var.cross_account_principals
      }
      
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ]
      
      resources = ["*"]
    }
  }
}

# KMS Grant (optional)
resource "aws_kms_grant" "main" {
  count = length(var.grants)

  name              = var.grants[count.index].name
  key_id            = aws_kms_key.main.key_id
  grantee_principal = var.grants[count.index].grantee_principal
  operations        = var.grants[count.index].operations

  dynamic "constraints" {
    for_each = var.grants[count.index].constraints != null ? [var.grants[count.index].constraints] : []
    content {
      dynamic "encryption_context_equals" {
        for_each = constraints.value.encryption_context_equals != null ? [constraints.value.encryption_context_equals] : []
        content {
          for_each = encryption_context_equals.value
        }
      }
      
      dynamic "encryption_context_subset" {
        for_each = constraints.value.encryption_context_subset != null ? [constraints.value.encryption_context_subset] : []
        content {
          for_each = encryption_context_subset.value
        }
      }
    }
  }

  dynamic "grant_tokens" {
    for_each = var.grants[count.index].grant_tokens != null ? [var.grants[count.index].grant_tokens] : []
    content {
      for_each = grant_tokens.value
    }
  }
}

# CloudWatch Log Group for KMS usage (optional)
resource "aws_cloudwatch_log_group" "kms_usage" {
  count = var.enable_logging ? 1 : 0

  name              = "/aws/kms/${var.project_name}-${var.environment}-${var.key_name}"
  retention_in_days = var.log_retention_in_days

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-${var.key_name}-logs"
  })
}

# CloudWatch Alarms for KMS
resource "aws_cloudwatch_metric_alarm" "kms_key_usage" {
  count = var.create_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-${var.key_name}-usage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "NumberOfRequestsSucceeded"
  namespace           = "AWS/KMS"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.usage_alarm_threshold
  alarm_description   = "This metric monitors KMS key usage"
  alarm_actions       = var.alarm_actions

  dimensions = {
    KeyId = aws_kms_key.main.key_id
  }

  tags = var.common_tags
}

# CloudWatch Dashboard (optional)
resource "aws_cloudwatch_dashboard" "kms" {
  count = var.create_dashboard ? 1 : 0

  dashboard_name = "${var.project_name}-${var.environment}-kms-${var.key_name}"

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
            ["AWS/KMS", "NumberOfRequestsSucceeded", "KeyId", aws_kms_key.main.key_id],
            [".", "NumberOfRequestsFailed", ".", "."]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "KMS Key Requests"
          view   = "timeSeries"
        }
      }
    ]
  })
}

data "aws_region" "current" {}