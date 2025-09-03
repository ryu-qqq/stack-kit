# StackKit Atlantis + AI Reviewer 단순 버전
# 기존 VPC, S3, DynamoDB 리소스를 사용하는 실용적 구성

terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100"
    }
  }
  
  # S3 백엔드 설정 (기존 버킷과 테이블 사용)
  backend "s3" {
    # 이 값들은 variables.tf에서 설정됩니다
    # bucket         = var.terraform_state_bucket
    # key            = "atlantis/terraform.tfstate"
    # region         = var.aws_region
    # dynamodb_table = var.terraform_lock_table
    # encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "stackkit-atlantis"
      Environment = var.environment
      Owner       = var.org_name
      ManagedBy   = "terraform"
    }
  }
}

locals {
  name_prefix = "${var.org_name}-atlantis-${var.environment}"
  
  common_tags = {
    Project     = "stackkit-atlantis"
    Environment = var.environment
    Owner       = var.org_name
    ManagedBy   = "terraform"
  }
}

# 기존 리소스 데이터 소스들
data "aws_vpc" "main" {
  id = var.vpc_id
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  filter {
    name   = "subnet-id"
    values = var.public_subnet_ids
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  filter {
    name   = "subnet-id"
    values = var.private_subnet_ids
  }
}

data "aws_s3_bucket" "atlantis_artifacts" {
  bucket = var.s3_bucket_name
}

# GitHub Token과 Webhook Secret을 위한 Secrets Manager
resource "aws_secretsmanager_secret" "github_token" {
  name        = "${local.name_prefix}/github-token"
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
  name        = "${local.name_prefix}/webhook-secret"
  description = "GitHub webhook secret for Atlantis"
  
  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "webhook_secret" {
  secret_id     = aws_secretsmanager_secret.webhook_secret.id
  secret_string = random_password.webhook_secret.result
}

# Application Load Balancer
resource "aws_lb" "atlantis" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.atlantis_alb.id]
  subnets            = var.public_subnet_ids
  
  enable_deletion_protection = var.environment == "prod"
  
  tags = local.common_tags
}

resource "aws_lb_target_group" "atlantis" {
  name     = "${local.name_prefix}-tg"
  port     = 4141
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  
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
  vpc_id      = var.vpc_id
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

resource "aws_security_group" "atlantis_ecs" {
  name_prefix = "${local.name_prefix}-ecs-"
  vpc_id      = var.vpc_id
  description = "Security group for Atlantis ECS service"
  
  ingress {
    description     = "HTTP from ALB"
    from_port       = 4141
    to_port         = 4141
    protocol        = "tcp"
    security_groups = [aws_security_group.atlantis_alb.id]
  }
  
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecs-sg"
  })
}

# ECS Cluster
resource "aws_ecs_cluster" "atlantis" {
  name = "${local.name_prefix}-cluster"
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  
  tags = local.common_tags
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "atlantis" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = var.environment == "prod" ? 30 : 7
  
  tags = local.common_tags
}

# ECS Task Definition
resource "aws_ecs_task_definition" "atlantis" {
  family                   = "${local.name_prefix}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.environment == "prod" ? 1024 : 512
  memory                   = var.environment == "prod" ? 2048 : 1024
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn           = aws_iam_role.ecs_task_role.arn
  
  container_definitions = jsonencode([
    {
      name  = "atlantis"
      image = "ghcr.io/runatlantis/atlantis:v0.28.5"
      
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
          value = "http://${aws_lb.atlantis.dns_name}"
        },
        {
          name  = "ATLANTIS_REPO_ALLOWLIST"
          value = join(",", var.repo_allowlist)
        },
        {
          name  = "ATLANTIS_GH_USER"
          value = var.github_user
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
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.atlantis.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "atlantis"
        }
      }
    }
  ])
  
  tags = local.common_tags
}

# ECS Service
resource "aws_ecs_service" "atlantis" {
  name            = "${local.name_prefix}-service"
  cluster         = aws_ecs_cluster.atlantis.id
  task_definition = aws_ecs_task_definition.atlantis.arn
  desired_count   = var.environment == "prod" ? 2 : 1
  launch_type     = "FARGATE"
  
  network_configuration {
    security_groups = [aws_security_group.atlantis_ecs.id]
    subnets         = var.private_subnet_ids
  }
  
  load_balancer {
    target_group_arn = aws_lb_target_group.atlantis.arn
    container_name   = "atlantis"
    container_port   = 4141
  }
  
  depends_on = [aws_lb_listener.atlantis]
  
  tags = local.common_tags
}

# IAM Roles
resource "aws_iam_role" "ecs_execution_role" {
  name = "${local.name_prefix}-ecs-execution-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
  
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_execution_secrets" {
  name = "${local.name_prefix}-ecs-execution-secrets"
  role = aws_iam_role.ecs_execution_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.github_token.arn,
          aws_secretsmanager_secret.webhook_secret.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role" "ecs_task_role" {
  name = "${local.name_prefix}-ecs-task-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
  
  tags = local.common_tags
}

# Atlantis가 S3에 업로드할 수 있는 권한
resource "aws_iam_role_policy" "atlantis_s3_access" {
  name = "${local.name_prefix}-atlantis-s3-access"
  role = aws_iam_role.ecs_task_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${data.aws_s3_bucket.atlantis_artifacts.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = data.aws_s3_bucket.atlantis_artifacts.arn
      }
    ]
  })
}

# SQS Queue for AI Reviews (simple version)
resource "aws_sqs_queue" "ai_reviews" {
  name                      = "${local.name_prefix}-ai-reviews"
  message_retention_seconds = 1209600  # 14 days
  visibility_timeout_seconds = 300     # 5 minutes
  
  tags = local.common_tags
}

# Lambda function for AI reviews (placeholder)
resource "aws_lambda_function" "ai_reviewer" {
  filename         = "../../../lambda-packages/atlantis-ai-reviewer-1.0.0.jar"
  function_name    = "${local.name_prefix}-ai-reviewer"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "com.stackkit.atlantis.reviewer.UnifiedReviewerHandler::handleRequest"
  runtime         = "java21"
  memory_size     = var.environment == "prod" ? 1024 : 512
  timeout         = 300
  
  environment {
    variables = {
      S3_BUCKET         = var.s3_bucket_name
      SLACK_WEBHOOK_URL = var.slack_webhook_url
      OPENAI_API_KEY    = var.openai_api_key
    }
  }
  
  tags = local.common_tags
}

# Lambda IAM Role
resource "aws_iam_role" "lambda_execution_role" {
  name = "${local.name_prefix}-lambda-execution-role"
  
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
  
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_s3_access" {
  name = "${local.name_prefix}-lambda-s3-access"
  role = aws_iam_role.lambda_execution_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${data.aws_s3_bucket.atlantis_artifacts.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.ai_reviews.arn
      }
    ]
  })
}