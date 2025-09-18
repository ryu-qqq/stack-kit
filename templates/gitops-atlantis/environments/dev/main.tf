terraform {
  required_version = ">= 1.8.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "prod-ORG_NAME_PLACEHOLDER"
    key            = "terraform-state/dev/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "prod-ORG_NAME_PLACEHOLDER-tf-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment_name
      ManagedBy   = "Terraform"
      Project     = "Atlantis"
      CostCenter  = "Development"
      PR          = var.pr_number
    }
  }
}

# Networking is created in networking.tf

# Create temporary secrets for dev environment
resource "aws_secretsmanager_secret" "github_token_dev" {
  name                    = "atlantis-github-token-dev-${var.pr_number}"
  description             = "GitHub token for dev environment PR ${var.pr_number}"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "github_token_dev" {
  secret_id     = aws_secretsmanager_secret.github_token_dev.id
  secret_string = "temp-token-for-dev" # Placeholder - will be updated manually if needed
}

resource "aws_secretsmanager_secret" "github_webhook_dev" {
  name                    = "atlantis-github-webhook-dev-${var.pr_number}"
  description             = "GitHub webhook secret for dev environment PR ${var.pr_number}"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "github_webhook_dev" {
  secret_id     = aws_secretsmanager_secret.github_webhook_dev.id
  secret_string = "temp-webhook-secret-for-dev" # Placeholder
}

# ECR Repository for dev images
resource "aws_ecr_repository" "atlantis_dev" {
  name                 = "atlantis-dev"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  lifecycle {
    prevent_destroy = false
  }

  tags = {
    Name        = "atlantis-dev"
    Environment = "development"
  }
}

# ECR Lifecycle Policy for dev images
resource "aws_ecr_lifecycle_policy" "atlantis_dev" {
  repository = aws_ecr_repository.atlantis_dev.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 dev images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["dev-", "pr-"]
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Remove untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Deploy the ephemeral environment module
module "ephemeral_dev" {
  source = "../../modules/ephemeral-environment"

  environment_name = var.environment_name
  pr_number        = var.pr_number
  ttl_hours        = var.ttl_hours

  # Cost optimization
  use_spot_instances = var.use_spot_instances
  cpu                = var.cpu
  memory             = var.memory
  max_tasks          = var.max_tasks
  min_tasks          = var.min_tasks

  # Auto-cleanup
  enable_auto_destroy  = var.enable_auto_destroy
  idle_timeout_minutes = var.idle_timeout_minutes

  # Monitoring
  enable_monitoring    = var.enable_monitoring
  enable_cost_tracking = var.enable_cost_tracking

  # Network configuration
  vpc_id             = aws_vpc.dev.id
  private_subnet_ids = aws_subnet.private[*].id
  public_subnet_ids  = aws_subnet.public[*].id

  # Container configuration
  ecr_repository_url = aws_ecr_repository.atlantis_dev.repository_url
  image_tag          = var.image_tag
  domain_name        = var.domain_name
  repo_allowlist     = var.repo_allowlist

  # Secrets
  github_token_secret_arn   = aws_secretsmanager_secret.github_token_dev.arn
  github_webhook_secret_arn = aws_secretsmanager_secret.github_webhook_dev.arn

  aws_region = var.aws_region
}
