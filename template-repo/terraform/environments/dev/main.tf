# StackKit Atlantis + AI Reviewer Infrastructure (Dev Environment)
# 이 파일은 config/config.yml 설정을 기반으로 자동 구성됩니다

terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

# AWS Provider Configuration
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = local.common_tags
  }
}

# Local values from config
locals {
  # Read config.yml and parse values
  config_file = file("${path.root}/../../../config/config.yml")
  config = yamldecode(local.config_file)
  
  # Extracted configuration values
  org_name = var.org_name != "" ? var.org_name : local.config.organization.name
  environment = var.environment != "" ? var.environment : local.config.environment.name
  
  # Common tags
  common_tags = {
    Project     = "stackkit-atlantis"
    Environment = local.environment
    Owner       = local.org_name
    ManagedBy   = "terraform"
    Repository  = "stackkit-template"
  }
  
  # Resource naming
  name_prefix = "${local.org_name}-atlantis-${local.environment}"
  
  # AI Reviewer configuration
  ai_config = local.config.ai_reviewer
  atlantis_config = local.config.atlantis
  
  # GitHub repository patterns
  repo_allowlist = join(",", local.config.github.repository_patterns)
}

# VPC Module for Atlantis Infrastructure
module "vpc" {
  source = "github.com/your-org/stackkit//terraform/modules/vpc?ref=v2.1.0"
  
  project_name = local.org_name
  environment  = local.environment
  vpc_cidr     = "10.0.0.0/16"
  
  # Multi-AZ setup for production-like environment
  availability_zones = data.aws_availability_zones.available.names
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]
  
  # NAT Gateway configuration
  enable_nat_gateway = true
  single_nat_gateway = local.environment == "dev" ? true : false
  
  common_tags = local.common_tags
}

# S3 Bucket for Atlantis Plans and Apply Results
module "s3_bucket" {
  source = "github.com/your-org/stackkit//terraform/modules/s3?ref=v2.1.0"
  
  project_name = local.org_name
  environment  = local.environment
  bucket_name  = "${local.name_prefix}-artifacts"
  
  # Enable versioning for plan/apply tracking
  versioning_enabled = true
  
  # Lifecycle policy for cost optimization
  lifecycle_rules = [
    {
      id     = "atlantis-artifacts"
      status = "Enabled"
      
      expiration = {
        days = local.environment == "prod" ? 90 : 30
      }
      
      noncurrent_version_expiration = {
        noncurrent_days = 7
      }
    }
  ]
  
  common_tags = local.common_tags
}

# SQS Queue for AI Review Events
module "sqs_queue" {
  source = "github.com/your-org/stackkit//terraform/modules/sqs?ref=v2.1.0"
  
  project_name = local.org_name
  environment  = local.environment
  queue_name   = "${local.name_prefix}-ai-reviews"
  
  # Standard queue for S3 event compatibility
  queue_type = "standard"
  
  # Message retention
  message_retention_seconds = 1209600  # 14 days
  visibility_timeout_seconds = 300     # 5 minutes
  
  # Dead letter queue for failed processing
  create_dlq = true
  max_receive_count = 3
  
  common_tags = local.common_tags
}

# Lambda Function for AI Reviews
module "ai_reviewer_lambda" {
  source = "github.com/your-org/stackkit//terraform/modules/lambda?ref=v2.1.0"
  
  project_name  = local.org_name
  environment   = local.environment
  function_name = "ai-reviewer"
  
  # Runtime configuration
  runtime = "java21"
  handler = "com.stackkit.atlantis.reviewer.UnifiedReviewerHandler::handleRequest"
  
  # Package from GitHub Actions artifact
  filename = "../../../lambda-packages/atlantis-ai-reviewer-1.0.0.jar"
  
  # Performance configuration based on environment
  memory_size = local.environment == "prod" ? 1024 : 512
  timeout     = 300
  
  # Environment variables
  environment_variables = {
    S3_BUCKET         = module.s3_bucket.bucket_name
    SLACK_WEBHOOK_URL = var.slack_webhook_url
    OPENAI_API_KEY    = var.openai_api_key
    INFRACOST_API_KEY = var.infracost_api_key
    AI_MODEL          = local.ai_config.model
    LANGUAGE          = local.ai_config.language
    COST_THRESHOLD    = tostring(local.ai_config.cost_threshold)
  }
  
  # IAM permissions for S3 and SQS access
  additional_iam_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${module.s3_bucket.bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = module.sqs_queue.queue_arn
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:*:secret:atlantis/*"
      }
    ]
  })
  
  common_tags = local.common_tags
}

# ECS Cluster for Atlantis
module "ecs_cluster" {
  source = "github.com/your-org/stackkit//terraform/modules/ecs?ref=v2.1.0"
  
  project_name = local.org_name
  environment  = local.environment
  cluster_name = "atlantis"
  
  # Service configuration
  service_name = "atlantis"
  
  # Container configuration
  container_definitions = [
    {
      name  = "atlantis"
      image = "ghcr.io/runatlantis/atlantis:v0.28.5"
      
      cpu    = local.environment == "prod" ? 1024 : 512
      memory = local.environment == "prod" ? 2048 : 1024
      
      essential = true
      
      portMappings = [
        {
          containerPort = 4141
          protocol      = "tcp"
        }
      ]
      
      environment = [
        {
          name  = "ATLANTIS_ATLANTIS_URL"
          value = "https://${aws_lb.atlantis.dns_name}"
        },
        {
          name  = "ATLANTIS_REPO_ALLOWLIST"
          value = local.repo_allowlist
        },
        {
          name  = "ATLANTIS_GH_USER"
          value = local.org_name
        },
        {
          name  = "ATLANTIS_DATA_DIR"
          value = "/atlantis-data"
        },
        {
          name  = "ATLANTIS_PORT"
          value = "4141"
        }
      ]
      
      secrets = [
        {
          name      = "ATLANTIS_GH_TOKEN"
          valueFrom = aws_secretsmanager_secret.github_token.arn
        },
        {
          name      = "ATLANTIS_GH_WEBHOOK_SECRET"
          valueFrom = aws_secretsmanager_secret.webhook_secret.arn
        }
      ]
      
      mountPoints = [
        {
          sourceVolume  = "atlantis-data"
          containerPath = "/atlantis-data"
          readOnly      = false
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${local.name_prefix}"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "atlantis"
        }
      }
    }
  ]
  
  # Network configuration
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  # Load balancer integration
  load_balancer_arn          = aws_lb.atlantis.arn
  load_balancer_listener_arn = aws_lb_listener.atlantis.arn
  
  # Auto Scaling
  desired_count = local.environment == "prod" ? 2 : 1
  min_capacity  = 1
  max_capacity  = local.environment == "prod" ? 4 : 2
  
  # Health check
  health_check_path = "/healthz"
  
  common_tags = local.common_tags
}

# Application Load Balancer for Atlantis
resource "aws_lb" "atlantis" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.atlantis_alb.id]
  subnets            = module.vpc.public_subnet_ids
  
  enable_deletion_protection = local.environment == "prod"
  
  access_logs {
    bucket  = module.s3_bucket.bucket_name
    prefix  = "alb-logs"
    enabled = true
  }
  
  tags = local.common_tags
}

# ALB Target Group
resource "aws_lb_target_group" "atlantis" {
  name     = "${local.name_prefix}-tg"
  port     = 4141
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/healthz"
    matcher             = "200"
    protocol            = "HTTP"
  }
  
  tags = local.common_tags
}

# ALB Listener
resource "aws_lb_listener" "atlantis" {
  load_balancer_arn = aws_lb.atlantis.arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.atlantis.arn
  }
  
  tags = local.common_tags
}

# Security Groups
resource "aws_security_group" "atlantis_alb" {
  name_prefix = "${local.name_prefix}-alb-"
  vpc_id      = module.vpc.vpc_id
  description = "Security group for Atlantis ALB"
  
  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb-sg"
  })
}

# Secrets Manager for sensitive data
resource "aws_secretsmanager_secret" "github_token" {
  name        = "atlantis/${local.environment}/github-token"
  description = "GitHub token for Atlantis"
  
  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "github_token" {
  secret_id     = aws_secretsmanager_secret.github_token.id
  secret_string = var.github_token
}

resource "random_password" "webhook_secret" {
  length  = 32
  special = true
}

resource "aws_secretsmanager_secret" "webhook_secret" {
  name        = "atlantis/${local.environment}/webhook-secret"
  description = "GitHub webhook secret for Atlantis"
  
  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "webhook_secret" {
  secret_id     = aws_secretsmanager_secret.webhook_secret.id
  secret_string = random_password.webhook_secret.result
}

# S3 Event Notification to SQS
resource "aws_s3_bucket_notification" "atlantis_events" {
  bucket = module.s3_bucket.bucket_name
  
  queue {
    queue_arn = module.sqs_queue.queue_arn
    events    = ["s3:ObjectCreated:*"]
    
    filter_prefix = "atlantis/"
    filter_suffix = ".json"
  }
  
  depends_on = [aws_sqs_queue_policy.s3_notification]
}

# SQS Queue Policy for S3 notifications
resource "aws_sqs_queue_policy" "s3_notification" {
  queue_url = module.sqs_queue.queue_url
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = "sqs:SendMessage"
        Resource = module.sqs_queue.queue_arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = module.s3_bucket.bucket_arn
          }
        }
      }
    ]
  })
}

# Lambda Event Source Mapping for SQS
resource "aws_lambda_event_source_mapping" "ai_reviewer_trigger" {
  event_source_arn = module.sqs_queue.queue_arn
  function_name    = module.ai_reviewer_lambda.function_name
  
  batch_size                         = 10
  maximum_batching_window_in_seconds = 5
  
  # Error handling
  function_response_types = ["ReportBatchItemFailures"]
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "atlantis" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = local.environment == "prod" ? 30 : 7
  
  tags = local.common_tags
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}