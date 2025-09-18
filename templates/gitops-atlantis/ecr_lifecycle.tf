# =======================================
# Simplified ECR Repository Management
# =======================================
# MVP-focused ECR configuration without Lambda functions

# ECR Repository for Atlantis images
resource "aws_ecr_repository" "atlantis" {
  name                 = "ORG_NAME_PLACEHOLDER/atlantis"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = local.common_tags
}

# ECR Lifecycle Policy for automated cleanup
resource "aws_ecr_lifecycle_policy" "atlantis_lifecycle" {
  repository = aws_ecr_repository.atlantis.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 production images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "release-"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep last 5 development images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["dev-", "staging-", "test-"]
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 3
        description  = "Delete untagged images older than 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 4
        description  = "Delete images older than 30 days"
        selection = {
          tagStatus   = "any"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ECR Repository Policy for ECS access - Temporarily disabled for MVP
# resource "aws_ecr_repository_policy" "atlantis_policy" {
#   repository = aws_ecr_repository.atlantis.name

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid    = "AllowPullFromECS"
#         Effect = "Allow"
#         Principal = {
#           AWS = aws_iam_role.ecs_task.arn
#         }
#         Action = [
#           "ecr:GetDownloadUrlForLayer",
#           "ecr:BatchGetImage",
#           "ecr:BatchCheckLayerAvailability"
#         ]
#       },
#       {
#         Sid    = "AllowPushFromGitHubActions"
#         Effect = "Allow"
#         Principal = {
#           AWS = [
#             "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/github-actions-ecr-role"
#           ]
#         }
#         Action = [
#           "ecr:GetDownloadUrlForLayer",
#           "ecr:BatchGetImage",
#           "ecr:BatchCheckLayerAvailability",
#           "ecr:PutImage",
#           "ecr:InitiateLayerUpload",
#           "ecr:UploadLayerPart",
#           "ecr:CompleteLayerUpload",
#           "ecr:BatchDeleteImage"
#         ]
#       }
#     ]
#   })
# }

# CloudWatch Log Group for ECR scanning results
resource "aws_cloudwatch_log_group" "ecr_scan_results" {
  name              = "/aws/ecr/scan-results/${aws_ecr_repository.atlantis.name}"
  retention_in_days = var.log_retention_days

  tags = local.common_tags
}

# CloudWatch Metric Filter for ECR vulnerabilities
resource "aws_cloudwatch_log_metric_filter" "ecr_vulnerabilities" {
  name           = "${local.name_prefix}-ecr-vulnerabilities"
  log_group_name = aws_cloudwatch_log_group.ecr_scan_results.name
  pattern        = "[timestamp, request_id, severity=\"HIGH\" || severity=\"CRITICAL\"]"

  metric_transformation {
    name      = "ECRHighVulnerabilities"
    namespace = "ECR/Security"
    value     = "1"
  }
}

# CloudWatch Alarm for high/critical vulnerabilities
resource "aws_cloudwatch_metric_alarm" "ecr_high_vulnerabilities" {
  alarm_name          = "${local.name_prefix}-ecr-high-vulnerabilities"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ECRHighVulnerabilities"
  namespace           = "ECR/Security"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "High or critical vulnerabilities found in Atlantis ECR images"
  alarm_actions       = [aws_sns_topic.atlantis_alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = local.common_tags
}

# EventBridge Rule for ECR image push events (direct SNS notification)
resource "aws_cloudwatch_event_rule" "ecr_image_push" {
  name        = "${local.name_prefix}-ecr-image-push"
  description = "Trigger on ECR image push to Atlantis repository"

  event_pattern = jsonencode({
    source        = ["aws.ecr"]
    "detail-type" = ["ECR Image Action"]
    detail = {
      "action-type"     = ["PUSH"]
      "repository-name" = [aws_ecr_repository.atlantis.name]
    }
  })

  tags = local.common_tags
}

# EventBridge target for SNS notification on image push
resource "aws_cloudwatch_event_target" "ecr_image_push_sns" {
  rule      = aws_cloudwatch_event_rule.ecr_image_push.name
  target_id = "ECRImagePushSNS"
  arn       = aws_sns_topic.atlantis_alerts.arn
}

# SNS topic policy to allow EventBridge
resource "aws_sns_topic_policy" "atlantis_alerts_eventbridge" {
  arn = aws_sns_topic.atlantis_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridgePublish"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.atlantis_alerts.arn
      }
    ]
  })
}
