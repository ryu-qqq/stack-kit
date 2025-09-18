# Ephemeral Development Environment Module
# Cost-optimized for small teams with automatic cleanup

locals {
  name_prefix = "atlantis-${var.environment_name}"

  common_tags = {
    Environment = var.environment_name
    ManagedBy   = "Terraform"
    AutoCleanup = var.enable_auto_destroy
    TTL         = var.ttl_hours
    CostCenter  = "development"
    PR          = var.pr_number
  }
}

# ECS Cluster for dev environment
resource "aws_ecs_cluster" "dev" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = var.enable_monitoring ? "enabled" : "disabled"
  }

  tags = local.common_tags
}

# ECS Task Definition with minimal resources
resource "aws_ecs_task_definition" "dev" {
  family                   = "${local.name_prefix}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "atlantis"
      image = "${var.ecr_repository_url}:${var.image_tag}"

      environment = [
        {
          name  = "ATLANTIS_PORT"
          value = "4141"
        },
        {
          name  = "ATLANTIS_ATLANTIS_URL"
          value = "https://${local.name_prefix}.${var.domain_name}"
        },
        {
          name  = "ATLANTIS_REPO_ALLOWLIST"
          value = var.repo_allowlist
        },
        {
          name  = "ENVIRONMENT"
          value = "dev"
        }
      ]

      secrets = [
        {
          name      = "ATLANTIS_GH_TOKEN"
          valueFrom = var.github_token_secret_arn
        },
        {
          name      = "ATLANTIS_GH_WEBHOOK_SECRET"
          valueFrom = var.github_webhook_secret_arn
        }
      ]

      portMappings = [
        {
          containerPort = 4141
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.dev.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:4141/healthz || exit 1"]
        interval    = 30
        timeout     = 10
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = local.common_tags
}

# ECS Service with Spot instances support
resource "aws_ecs_service" "dev" {
  name            = "${local.name_prefix}-service"
  cluster         = aws_ecs_cluster.dev.id
  task_definition = aws_ecs_task_definition.dev.arn
  desired_count   = var.min_tasks
  # launch_type removed - using capacity_provider_strategy instead

  # Use Spot instances for cost savings
  capacity_provider_strategy {
    capacity_provider = var.use_spot_instances ? "FARGATE_SPOT" : "FARGATE"
    weight            = 100
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.dev.arn
    container_name   = "atlantis"
    container_port   = 4141
  }

  # Single task for Vault DB compatibility
  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = local.common_tags
}

# Auto-scaling for cost optimization
resource "aws_appautoscaling_target" "dev" {
  max_capacity       = var.max_tasks
  min_capacity       = var.min_tasks
  resource_id        = "service/${aws_ecs_cluster.dev.name}/${aws_ecs_service.dev.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Scale to zero when idle
resource "aws_appautoscaling_policy" "scale_to_zero" {
  name               = "${local.name_prefix}-scale-to-zero"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.dev.resource_id
  scalable_dimension = aws_appautoscaling_target.dev.scalable_dimension
  service_namespace  = aws_appautoscaling_target.dev.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 5.0
    scale_in_cooldown  = var.idle_timeout_minutes * 60
    scale_out_cooldown = 60
  }
}

# CloudWatch Log Group with short retention
resource "aws_cloudwatch_log_group" "dev" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = 3 # Minimal retention for dev

  tags = local.common_tags
}

# Lambda for auto-cleanup
resource "aws_lambda_function" "auto_cleanup" {
  count = var.enable_auto_destroy ? 1 : 0

  filename         = "${path.module}/lambda/auto_cleanup.zip"
  function_name    = "${local.name_prefix}-auto-cleanup"
  role             = aws_iam_role.lambda_cleanup[0].arn
  handler          = "auto_cleanup.handler"
  source_code_hash = filebase64sha256("${path.module}/lambda/auto_cleanup.zip")
  runtime          = "python3.11"
  timeout          = 60

  environment {
    variables = {
      ENVIRONMENT_NAME = var.environment_name
      TTL_HOURS        = var.ttl_hours
      CLUSTER_NAME     = aws_ecs_cluster.dev.name
      SERVICE_NAME     = aws_ecs_service.dev.name
    }
  }

  tags = local.common_tags
}

# EventBridge rule for auto-cleanup
resource "aws_cloudwatch_event_rule" "auto_cleanup" {
  count = var.enable_auto_destroy ? 1 : 0

  name                = "${local.name_prefix}-cleanup-schedule"
  description         = "Trigger cleanup after TTL"
  schedule_expression = "rate(1 hour)"

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "auto_cleanup" {
  count = var.enable_auto_destroy ? 1 : 0

  rule      = aws_cloudwatch_event_rule.auto_cleanup[0].name
  target_id = "LambdaFunction"
  arn       = aws_lambda_function.auto_cleanup[0].arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  count = var.enable_auto_destroy ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auto_cleanup[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.auto_cleanup[0].arn
}
