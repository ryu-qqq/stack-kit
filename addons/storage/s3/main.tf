# S3 Enhanced Storage Addon
# Version: v1.0.0
# Purpose: Enhanced S3 storage with advanced lifecycle, security, and monitoring

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Data sources for existing resources
data "aws_kms_key" "s3" {
  count  = var.kms_key_alias != null ? 1 : 0
  key_id = "alias/${var.kms_key_alias}"
}

data "aws_iam_policy_document" "bucket_policy" {
  count = var.enable_enhanced_security ? 1 : 0

  # Deny unencrypted uploads
  statement {
    sid    = "DenyUnencryptedObjectUploads"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.addon.arn}/*"]
    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["AES256", "aws:kms"]
    }
  }

  # Deny insecure transport
  statement {
    sid    = "DenyInsecureConnections"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:*"]
    resources = [
      aws_s3_bucket.addon.arn,
      "${aws_s3_bucket.addon.arn}/*"
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  # Environment-specific access controls
  dynamic "statement" {
    for_each = var.environment_access_controls
    content {
      sid    = "Environment${title(statement.key)}Access"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = statement.value.allowed_principals
      }
      actions   = statement.value.allowed_actions
      resources = statement.value.apply_to_objects ? ["${aws_s3_bucket.addon.arn}/*"] : [aws_s3_bucket.addon.arn]
      
      dynamic "condition" {
        for_each = statement.value.conditions
        content {
          test     = condition.value.test
          variable = condition.value.variable
          values   = condition.value.values
        }
      }
    }
  }
}

# Enhanced S3 bucket with addon features
resource "aws_s3_bucket" "addon" {
  bucket        = var.bucket_name_override != null ? var.bucket_name_override : "${var.project_name}-${var.environment}-${var.bucket_purpose}"
  force_destroy = var.force_destroy

  tags = merge(var.common_tags, {
    Name        = var.bucket_name_override != null ? var.bucket_name_override : "${var.project_name}-${var.environment}-${var.bucket_purpose}"
    Environment = var.environment
    Purpose     = var.bucket_purpose
    Module      = "s3-addon"
    Version     = "v1.0.0"
    Addon       = "true"
  })
}

# Enhanced bucket versioning with advanced configuration
resource "aws_s3_bucket_versioning" "addon" {
  bucket = aws_s3_bucket.addon.id
  
  versioning_configuration {
    status     = var.versioning_enabled ? "Enabled" : "Suspended"
    mfa_delete = var.mfa_delete_enabled ? "Enabled" : "Disabled"
  }
}

# Multi-layer encryption with key rotation
resource "aws_s3_bucket_server_side_encryption_configuration" "addon" {
  bucket = aws_s3_bucket.addon.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_alias != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_alias != null ? data.aws_kms_key.s3[0].arn : null
    }
    bucket_key_enabled = var.kms_key_alias != null ? var.bucket_key_enabled : false
  }
}

# Enhanced public access blocking
resource "aws_s3_bucket_public_access_block" "addon" {
  bucket = aws_s3_bucket.addon.id

  block_public_acls       = var.block_public_access
  block_public_policy     = var.block_public_access
  ignore_public_acls      = var.block_public_access
  restrict_public_buckets = var.block_public_access

  depends_on = [aws_s3_bucket_policy.addon]
}

# Enhanced bucket policy
resource "aws_s3_bucket_policy" "addon" {
  count  = var.enable_enhanced_security ? 1 : 0
  bucket = aws_s3_bucket.addon.id
  policy = data.aws_iam_policy_document.bucket_policy[0].json

  depends_on = [aws_s3_bucket_public_access_block.addon]
}

# Advanced lifecycle configuration with intelligent tiering
resource "aws_s3_bucket_lifecycle_configuration" "addon" {
  count  = length(var.lifecycle_rules) > 0 || var.enable_intelligent_tiering ? 1 : 0
  bucket = aws_s3_bucket.addon.id

  # Standard lifecycle rules
  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      id     = rule.value.id
      status = rule.value.status

      dynamic "filter" {
        for_each = lookup(rule.value, "filter", null) != null ? [rule.value.filter] : []
        content {
          prefix                   = lookup(filter.value, "prefix", null)
          object_size_greater_than = lookup(filter.value, "object_size_greater_than", null)
          object_size_less_than    = lookup(filter.value, "object_size_less_than", null)
          
          dynamic "tag" {
            for_each = lookup(filter.value, "tags", {})
            content {
              key   = tag.key
              value = tag.value
            }
          }
        }
      }

      dynamic "expiration" {
        for_each = lookup(rule.value, "expiration", null) != null ? [rule.value.expiration] : []
        content {
          days                         = lookup(expiration.value, "days", null)
          date                         = lookup(expiration.value, "date", null)
          expired_object_delete_marker = lookup(expiration.value, "expired_object_delete_marker", null)
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = lookup(rule.value, "noncurrent_version_expiration", null) != null ? [rule.value.noncurrent_version_expiration] : []
        content {
          noncurrent_days = noncurrent_version_expiration.value.days
        }
      }

      dynamic "transition" {
        for_each = lookup(rule.value, "transitions", [])
        content {
          days          = lookup(transition.value, "days", null)
          date          = lookup(transition.value, "date", null)
          storage_class = transition.value.storage_class
        }
      }

      dynamic "noncurrent_version_transition" {
        for_each = lookup(rule.value, "noncurrent_version_transitions", [])
        content {
          noncurrent_days = noncurrent_version_transition.value.days
          storage_class   = noncurrent_version_transition.value.storage_class
        }
      }

      dynamic "abort_incomplete_multipart_upload" {
        for_each = lookup(rule.value, "abort_incomplete_multipart_upload_days", null) != null ? [1] : []
        content {
          days_after_initiation = rule.value.abort_incomplete_multipart_upload_days
        }
      }
    }
  }

  # Intelligent tiering rule
  dynamic "rule" {
    for_each = var.enable_intelligent_tiering ? [1] : []
    content {
      id     = "intelligent-tiering"
      status = "Enabled"

      filter {
        prefix = var.intelligent_tiering_prefix
      }

      transition {
        days          = var.intelligent_tiering_days
        storage_class = "INTELLIGENT_TIERING"
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.addon]
}

# Cross-region replication
resource "aws_s3_bucket_replication_configuration" "addon" {
  count      = var.replication_configuration != null ? 1 : 0
  role       = aws_iam_role.replication[0].arn
  bucket     = aws_s3_bucket.addon.id
  depends_on = [aws_s3_bucket_versioning.addon]

  dynamic "rule" {
    for_each = var.replication_configuration.rules
    content {
      id       = rule.value.id
      status   = rule.value.status
      priority = lookup(rule.value, "priority", null)
      prefix   = lookup(rule.value, "prefix", null)

      destination {
        bucket             = rule.value.destination_bucket
        storage_class      = lookup(rule.value, "storage_class", "STANDARD")
        replica_kms_key_id = lookup(rule.value, "replica_kms_key_id", null)
        
        dynamic "access_control_translation" {
          for_each = lookup(rule.value, "owner_override", false) ? [1] : []
          content {
            owner = "Destination"
          }
        }
        
        dynamic "account_id" {
          for_each = lookup(rule.value, "account_id", null) != null ? [rule.value.account_id] : []
          content {
            account_id = account_id.value
          }
        }
      }

      dynamic "filter" {
        for_each = lookup(rule.value, "filter_tags", null) != null ? [1] : []
        content {
          dynamic "tag" {
            for_each = rule.value.filter_tags
            content {
              key   = tag.key
              value = tag.value
            }
          }
        }
      }

      dynamic "delete_marker_replication_status" {
        for_each = lookup(rule.value, "delete_marker_replication", false) ? ["Enabled"] : []
        content {
          status = delete_marker_replication_status.value
        }
      }
    }
  }
}

# IAM role for replication
resource "aws_iam_role" "replication" {
  count = var.replication_configuration != null ? 1 : 0
  name  = "${var.project_name}-${var.environment}-s3-replication-role"

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

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-s3-replication-role"
  })
}

# IAM policy for replication
resource "aws_iam_role_policy" "replication" {
  count = var.replication_configuration != null ? 1 : 0
  name  = "${var.project_name}-${var.environment}-s3-replication-policy"
  role  = aws_iam_role.replication[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Resource = "${aws_s3_bucket.addon.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.addon.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Resource = [for rule in var.replication_configuration.rules : "${rule.destination_bucket}/*"]
      }
    ]
  })
}

# Enhanced monitoring and metrics
resource "aws_s3_bucket_metric" "addon" {
  count  = var.enable_detailed_monitoring ? 1 : 0
  bucket = aws_s3_bucket.addon.id
  name   = "EntireBucket"
}

# Request metrics configuration
resource "aws_s3_bucket_analytics_configuration" "addon" {
  count  = var.enable_analytics ? 1 : 0
  bucket = aws_s3_bucket.addon.id
  name   = "EntireBucket"

  dynamic "storage_class_analysis" {
    for_each = var.analytics_export_destination != null ? [1] : []
    content {
      data_export {
        destination {
          s3_bucket_destination {
            bucket_arn = var.analytics_export_destination
            prefix     = var.analytics_export_prefix
            format     = "CSV"
          }
        }
        output_schema_version = "V_1"
      }
    }
  }
}

# Enhanced notification configuration with multiple targets
resource "aws_s3_bucket_notification" "addon" {
  count  = var.notification_configuration != null ? 1 : 0
  bucket = aws_s3_bucket.addon.id

  dynamic "lambda_function" {
    for_each = lookup(var.notification_configuration, "lambda_notifications", [])
    content {
      lambda_function_arn = lambda_function.value.function_arn
      events              = lambda_function.value.events
      filter_prefix       = lookup(lambda_function.value, "filter_prefix", null)
      filter_suffix       = lookup(lambda_function.value, "filter_suffix", null)
    }
  }

  dynamic "queue" {
    for_each = lookup(var.notification_configuration, "sqs_notifications", [])
    content {
      queue_arn     = queue.value.queue_arn
      events        = queue.value.events
      filter_prefix = lookup(queue.value, "filter_prefix", null)
      filter_suffix = lookup(queue.value, "filter_suffix", null)
    }
  }

  dynamic "topic" {
    for_each = lookup(var.notification_configuration, "sns_notifications", [])
    content {
      topic_arn     = topic.value.topic_arn
      events        = topic.value.events
      filter_prefix = lookup(topic.value, "filter_prefix", null)
      filter_suffix = lookup(topic.value, "filter_suffix", null)
    }
  }

  depends_on = [aws_s3_bucket_public_access_block.addon]
}

# CORS configuration for web applications
resource "aws_s3_bucket_cors_configuration" "addon" {
  count  = var.cors_configuration != null ? 1 : 0
  bucket = aws_s3_bucket.addon.id

  dynamic "cors_rule" {
    for_each = var.cors_configuration
    content {
      id              = lookup(cors_rule.value, "id", null)
      allowed_headers = lookup(cors_rule.value, "allowed_headers", null)
      allowed_methods = cors_rule.value.allowed_methods
      allowed_origins = cors_rule.value.allowed_origins
      expose_headers  = lookup(cors_rule.value, "expose_headers", null)
      max_age_seconds = lookup(cors_rule.value, "max_age_seconds", null)
    }
  }
}

# Website configuration for static hosting
resource "aws_s3_bucket_website_configuration" "addon" {
  count  = var.website_configuration != null ? 1 : 0
  bucket = aws_s3_bucket.addon.id

  dynamic "index_document" {
    for_each = lookup(var.website_configuration, "index_document", null) != null ? [var.website_configuration.index_document] : []
    content {
      suffix = index_document.value.suffix
    }
  }

  dynamic "error_document" {
    for_each = lookup(var.website_configuration, "error_document", null) != null ? [var.website_configuration.error_document] : []
    content {
      key = error_document.value.key
    }
  }

  dynamic "redirect_all_requests_to" {
    for_each = lookup(var.website_configuration, "redirect_all_requests_to", null) != null ? [var.website_configuration.redirect_all_requests_to] : []
    content {
      host_name = redirect_all_requests_to.value.host_name
      protocol  = lookup(redirect_all_requests_to.value, "protocol", null)
    }
  }

  dynamic "routing_rule" {
    for_each = lookup(var.website_configuration, "routing_rules", [])
    content {
      dynamic "condition" {
        for_each = lookup(routing_rule.value, "condition", null) != null ? [routing_rule.value.condition] : []
        content {
          http_error_code_returned_equals = lookup(condition.value, "http_error_code_returned_equals", null)
          key_prefix_equals               = lookup(condition.value, "key_prefix_equals", null)
        }
      }

      dynamic "redirect" {
        for_each = lookup(routing_rule.value, "redirect", null) != null ? [routing_rule.value.redirect] : []
        content {
          host_name               = lookup(redirect.value, "host_name", null)
          http_redirect_code      = lookup(redirect.value, "http_redirect_code", null)
          protocol                = lookup(redirect.value, "protocol", null)
          replace_key_prefix_with = lookup(redirect.value, "replace_key_prefix_with", null)
          replace_key_with        = lookup(redirect.value, "replace_key_with", null)
        }
      }
    }
  }
}

# Inventory configuration for compliance and governance
resource "aws_s3_bucket_inventory" "addon" {
  count  = var.inventory_configuration != null ? 1 : 0
  bucket = aws_s3_bucket.addon.id
  name   = var.inventory_configuration.name

  included_object_versions = lookup(var.inventory_configuration, "included_object_versions", "Current")
  enabled                  = lookup(var.inventory_configuration, "enabled", true)
  optional_fields          = lookup(var.inventory_configuration, "optional_fields", [])

  schedule {
    frequency = lookup(var.inventory_configuration.schedule, "frequency", "Daily")
  }

  destination {
    bucket {
      format     = lookup(var.inventory_configuration.destination, "format", "CSV")
      bucket_arn = var.inventory_configuration.destination.bucket_arn
      prefix     = lookup(var.inventory_configuration.destination, "prefix", null)
      
      dynamic "encryption" {
        for_each = lookup(var.inventory_configuration.destination, "encryption", null) != null ? [var.inventory_configuration.destination.encryption] : []
        content {
          dynamic "sse_kms" {
            for_each = lookup(encryption.value, "kms_key_id", null) != null ? [encryption.value] : []
            content {
              key_id = sse_kms.value.kms_key_id
            }
          }
          
          dynamic "sse_s3" {
            for_each = lookup(encryption.value, "kms_key_id", null) == null ? [1] : []
            content {}
          }
        }
      }
    }
  }

  dynamic "filter" {
    for_each = lookup(var.inventory_configuration, "filter", null) != null ? [var.inventory_configuration.filter] : []
    content {
      prefix = filter.value.prefix
    }
  }
}