# GitHub Actions OIDC Provider and IAM Role
# This configures the IAM role that GitHub Actions uses for deployments

# Data source for existing OIDC provider (should already exist)
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# IAM Role for GitHub Actions
resource "aws_iam_role" "github_actions" {
  name = "GithubActionsDeployRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "GithubActionsDeployRole"
    ManagedBy   = "Terraform"
    Purpose     = "GitHub Actions CI/CD"
    Environment = "all"
  }
}

# S3 Backend Access Policy
resource "aws_iam_role_policy" "github_actions_s3_backend" {
  name = "github-actions-s3-backend-access"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning",
          "s3:GetEncryptionConfiguration"
        ]
        Resource = [
          "arn:aws:s3:::prod-ORG_NAME_PLACEHOLDER",
          "arn:aws:s3:::prod-ORG_NAME_PLACEHOLDER/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:DeleteItem",
          "dynamodb:DescribeTable"
        ]
        Resource = "arn:aws:dynamodb:ap-northeast-2:*:table/prod-ORG_NAME_PLACEHOLDER-tf-lock"
      }
    ]
  })
}

# Terraform Deployment Permissions
resource "aws_iam_role_policy" "github_actions_terraform" {
  name = "github-actions-terraform-deploy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ECS Permissions
      {
        Effect = "Allow"
        Action = [
          "ecs:*",
          "ecr:*"
        ]
        Resource = "*"
      },
      # VPC and Networking
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "elasticloadbalancing:*"
        ]
        Resource = "*"
      },
      # IAM Permissions (for creating service roles)
      {
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:AttachRolePolicy",
          "iam:PutRolePolicy",
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:UpdateAssumeRolePolicy",
          "iam:DeleteRole",
          "iam:DeleteRolePolicy",
          "iam:DetachRolePolicy",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:PassRole"
        ]
        Resource = [
          "arn:aws:iam::*:role/atlantis-*",
          "arn:aws:iam::*:role/ecs-*",
          "arn:aws:iam::*:role/lambda-*"
        ]
      },
      # CloudWatch
      {
        Effect = "Allow"
        Action = [
          "logs:*",
          "cloudwatch:*",
          "events:*"
        ]
        Resource = "*"
      },
      # Lambda
      {
        Effect = "Allow"
        Action = [
          "lambda:*"
        ]
        Resource = "*"
      },
      # Auto Scaling
      {
        Effect = "Allow"
        Action = [
          "autoscaling:*",
          "application-autoscaling:*"
        ]
        Resource = "*"
      },
      # Route53
      {
        Effect = "Allow"
        Action = [
          "route53:*"
        ]
        Resource = "*"
      },
      # Secrets Manager
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      },
      # SNS (for notifications)
      {
        Effect = "Allow"
        Action = [
          "sns:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# Output the role ARN for use in GitHub Secrets
output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "ARN of the IAM role for GitHub Actions. Add this to GitHub Secrets as AWS_ROLE_ARN"
}

# Variables for GitHub configuration
variable "github_org" {
  description = "GitHub organization or username"
  type        = string
  default     = "sangwon-ryu" # Update this with actual GitHub org
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "REPO_NAME_PLACEHOLDER"
}
