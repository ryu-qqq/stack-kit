# Team Atlantis Module - Multi-tenant Atlantis deployment per team
terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  atlantis_image = var.atlantis_image != "" ? var.atlantis_image : "ghcr.io/runatlantis/atlantis:v${var.atlantis_version}"
  
  # Task sizing configurations
  task_sizes = {
    small = {
      cpu           = 256
      memory        = 512
      desired_count = 1
    }
    medium = {
      cpu           = 512
      memory        = 1024
      desired_count = 2
    }
    large = {
      cpu           = 1024
      memory        = 2048
      desired_count = 3
    }
  }
  
  task_config = local.task_sizes[var.atlantis_size]
  
  common_tags = {
    Team            = var.team_name
    TeamId          = var.team_id
    Organization    = var.organization
    Environment     = var.environment
    Purpose         = "atlantis"
    ManagedBy       = "StackKit-Enterprise"
  }
  
  # Subdomain for team Atlantis
  subdomain = var.subdomain != "" ? var.subdomain : var.team_name
  full_domain = var.domain_name != "" ? "${local.subdomain}.${var.domain_name}" : ""
}

# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# ECS Cluster for team Atlantis
resource "aws_ecs_cluster" "atlantis" {
  name = "stackkit-team-${var.team_name}-atlantis"
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  
  tags = merge(local.common_tags, {
    Name = "stackkit-team-${var.team_name}-atlantis-cluster"
  })
}

# CloudWatch Log Group for Atlantis
resource "aws_cloudwatch_log_group" "atlantis" {
  name              = "/ecs/stackkit-team-${var.team_name}-atlantis"
  retention_in_days = var.log_retention_days
  
  tags = local.common_tags
}

# Secrets Manager for team-specific secrets
resource "aws_secretsmanager_secret" "atlantis_secrets" {
  name        = "stackkit-team-${var.team_name}-atlantis-secrets"
  description = "Secrets for team ${var.team_name} Atlantis instance"
  
  tags = local.common_tags
}

# Secret version (will be updated by deployment script)
resource "aws_secretsmanager_secret_version" "atlantis_secrets" {
  secret_id = aws_secretsmanager_secret.atlantis_secrets.id
  secret_string = jsonencode({
    github_token      = "placeholder-to-be-updated"
    github_secret     = random_password.github_webhook_secret.result
    slack_webhook_url = var.slack_webhook_url
    infracost_api_key = var.infracost_api_key
  })
  
  lifecycle {
    ignore_changes = [secret_string]
  }
}

# Random password for GitHub webhook secret
resource "random_password" "github_webhook_secret" {
  length  = 32
  special = true
}

# Application Load Balancer
resource "aws_lb" "atlantis" {
  name               = "stackkit-team-${var.team_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids
  
  enable_deletion_protection = var.environment == "prod" ? true : false
  
  access_logs {
    bucket  = aws_s3_bucket.alb_logs.bucket
    prefix  = "atlantis-alb"
    enabled = true
  }
  
  tags = merge(local.common_tags, {
    Name = "stackkit-team-${var.team_name}-atlantis-alb"
  })
}

# S3 bucket for ALB access logs
resource "aws_s3_bucket" "alb_logs" {
  bucket = "stackkit-team-${var.team_name}-alb-logs-${random_id.bucket_suffix.hex}"
  
  tags = local.common_tags
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  
  rule {
    id     = "delete_old_logs"
    status = "Enabled"
    
    expiration {
      days = 90
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ALB Target Group
resource "aws_lb_target_group" "atlantis" {
  name                 = "stackkit-team-${var.team_name}-tg"
  port                 = 4141
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "ip"
  deregistration_delay = 30
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/healthz"
    matcher             = "200"
    protocol            = "HTTP"
    port                = "traffic-port"
  }
  
  tags = merge(local.common_tags, {
    Name = "stackkit-team-${var.team_name}-atlantis-tg"
  })
}

# ALB Listener (HTTP - redirects to HTTPS if domain is configured)
resource "aws_lb_listener" "atlantis_http" {
  load_balancer_arn = aws_lb.atlantis.arn
  port              = "80"
  protocol          = "HTTP"
  
  # Redirect to HTTPS if domain is configured
  dynamic "default_action" {
    for_each = var.certificate_arn != "" ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }
  
  # Forward to target group if no HTTPS
  dynamic "default_action" {
    for_each = var.certificate_arn == "" ? [1] : []
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.atlantis.arn
    }
  }
  
  tags = local.common_tags
}

# ALB Listener (HTTPS - only if certificate is provided)
resource "aws_lb_listener" "atlantis_https" {
  count = var.certificate_arn != "" ? 1 : 0
  
  load_balancer_arn = aws_lb.atlantis.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.certificate_arn
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.atlantis.arn
  }
  
  tags = local.common_tags
}

# Route53 DNS record (if domain is configured)
resource "aws_route53_record" "atlantis" {
  count = local.full_domain != "" && var.route53_zone_id != "" ? 1 : 0
  
  zone_id = var.route53_zone_id
  name    = local.full_domain
  type    = "A"
  
  alias {
    name                   = aws_lb.atlantis.dns_name
    zone_id                = aws_lb.atlantis.zone_id
    evaluate_target_health = true
  }
}

# IAM role for ECS task execution
resource "aws_iam_role" "ecs_task_execution" {
  name = "stackkit-team-${var.team_name}-atlantis-execution-role"
  
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

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "secrets_access" {
  name = "SecretsManagerAccess"
  role = aws_iam_role.ecs_task_execution.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.atlantis_secrets.arn
      }
    ]
  })
}

# IAM role for Atlantis task (runtime permissions)
resource "aws_iam_role" "atlantis_task" {
  name = "stackkit-team-${var.team_name}-atlantis-task-role"
  
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

# Policy for Atlantis to manage team resources
resource "aws_iam_role_policy" "atlantis_permissions" {
  name = "AtlantisTeamPermissions"
  role = aws_iam_role.atlantis_task.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "ecs:*", 
          "s3:*",
          "dynamodb:*",
          "rds:*",
          "elasticache:*",
          "cloudwatch:*",
          "logs:*",
          "iam:List*",
          "iam:Get*",
          "iam:CreateRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:DeleteRole",
          "iam:PassRole",
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Team" = var.team_name
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::stackkit-team-${var.team_name}-*",
          "arn:aws:s3:::stackkit-team-${var.team_name}-*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/stackkit-team-${var.team_name}-*"
      }
    ]
  })
}

# ECS Task Definition
resource "aws_ecs_task_definition" "atlantis" {
  family                   = "stackkit-team-${var.team_name}-atlantis"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = local.task_config.cpu
  memory                   = local.task_config.memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.atlantis_task.arn
  
  container_definitions = jsonencode([
    {
      name  = "atlantis"
      image = local.atlantis_image
      
      portMappings = [
        {
          containerPort = 4141
          protocol      = "tcp"
        }
      ]
      
      environment = [
        {
          name  = "ATLANTIS_ATLANTIS_URL"
          value = local.full_domain != "" ? "https://${local.full_domain}" : "http://${aws_lb.atlantis.dns_name}"
        },
        {
          name  = "ATLANTIS_PORT"
          value = "4141"
        },
        {
          name  = "ATLANTIS_REPO_ALLOWLIST"
          value = "github.com/${var.github_org}/*"
        },
        {
          name  = "ATLANTIS_ALLOW_FORK_PRS"
          value = "false"
        },
        {
          name  = "ATLANTIS_DEFAULT_TF_VERSION"
          value = var.terraform_version
        },
        {
          name  = "ATLANTIS_LOG_LEVEL"
          value = var.log_level
        },
        {
          name  = "ATLANTIS_DATA_DIR"
          value = "/atlantis-data"
        },
        {
          name  = "ATLANTIS_WRITE_GIT_CREDS"
          value = "true"
        },
        {
          name  = "ATLANTIS_HIDE_PREV_PLAN_COMMENTS"
          value = "true"
        }
      ]
      
      secrets = [
        {
          name      = "ATLANTIS_GH_TOKEN"
          valueFrom = "${aws_secretsmanager_secret.atlantis_secrets.arn}:github_token::"
        },
        {
          name      = "ATLANTIS_GH_WEBHOOK_SECRET"
          valueFrom = "${aws_secretsmanager_secret.atlantis_secrets.arn}:github_secret::"
        },
        {
          name      = "ATLANTIS_SLACK_TOKEN"
          valueFrom = "${aws_secretsmanager_secret.atlantis_secrets.arn}:slack_webhook_url::"
        },
        {
          name      = "INFRACOST_API_KEY"
          valueFrom = "${aws_secretsmanager_secret.atlantis_secrets.arn}:infracost_api_key::"
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.atlantis.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
      
      healthCheck = {
        command = ["CMD-SHELL", "curl -f http://localhost:4141/healthz || exit 1"]
        interval = 30
        timeout = 5
        retries = 3
        startPeriod = 60
      }
      
      essential = true
    }
  ])
  
  tags = local.common_tags
}

# ECS Service
resource "aws_ecs_service" "atlantis" {
  name            = "stackkit-team-${var.team_name}-atlantis"
  cluster         = aws_ecs_cluster.atlantis.id
  task_definition = aws_ecs_task_definition.atlantis.arn
  desired_count   = local.task_config.desired_count
  launch_type     = "FARGATE"
  
  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [var.atlantis_security_group_id]
    assign_public_ip = false
  }
  
  load_balancer {
    target_group_arn = aws_lb_target_group.atlantis.arn
    container_name   = "atlantis"
    container_port   = 4141
  }
  
  deployment_configuration {
    maximum_percent         = 200
    minimum_healthy_percent = 100
  }
  
  depends_on = [aws_lb_listener.atlantis_http]
  
  tags = local.common_tags
}

# CloudWatch alarms for monitoring
resource "aws_cloudwatch_metric_alarm" "atlantis_cpu" {
  alarm_name          = "stackkit-team-${var.team_name}-atlantis-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ECS CPU utilization for team ${var.team_name} Atlantis"
  
  dimensions = {
    ServiceName = aws_ecs_service.atlantis.name
    ClusterName = aws_ecs_cluster.atlantis.name
  }
  
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "atlantis_memory" {
  alarm_name          = "stackkit-team-${var.team_name}-atlantis-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ECS memory utilization for team ${var.team_name} Atlantis"
  
  dimensions = {
    ServiceName = aws_ecs_service.atlantis.name
    ClusterName = aws_ecs_cluster.atlantis.name
  }
  
  tags = local.common_tags
}