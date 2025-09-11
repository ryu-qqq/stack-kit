# =======================================
# ECS Compute Module for GitOps Atlantis
# =======================================
# Following StackKit standards for compute resources

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = local.common_tags
}

# CloudWatch Log Group for ECS tasks
resource "aws_cloudwatch_log_group" "atlantis" {
  name              = "/ecs/${local.name_prefix}-atlantis"
  retention_in_days = var.log_retention_days

  tags = local.common_tags
}

# ECS Task Definition
resource "aws_ecs_task_definition" "atlantis" {
  family                   = "${local.name_prefix}-atlantis"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = local.task_cpu
  memory                   = local.task_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn           = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name  = "atlantis"
    image = var.atlantis_image

    essential = true

    portMappings = [{
      containerPort = var.atlantis_port
      protocol      = "tcp"
    }]

    environment = [
      {
        name  = "ATLANTIS_PORT"
        value = tostring(var.atlantis_port)
      },
      {
        name  = "ATLANTIS_ATLANTIS_URL"
        value = local.atlantis_url
      },
      {
        name  = "ATLANTIS_REPO_ALLOWLIST"
        value = var.atlantis_repo_allowlist
      },
      {
        name  = "ATLANTIS_GH_USER"
        value = var.atlantis_github_user
      },
      {
        name  = "ATLANTIS_DATA_DIR"
        value = "/atlantis-data"
      },
      {
        name  = "ATLANTIS_HIDE_PREV_PLAN_COMMENTS"
        value = tostring(var.hide_prev_plan_comments)
      },
      {
        name  = "ATLANTIS_REPO_CONFIG"
        value = var.atlantis_repo_config
      },
      {
        name  = "ATLANTIS_WRITE_GIT_CREDS"
        value = "true"
      },
      {
        name  = "ATLANTIS_ENABLE_DIFF_MARKDOWN_FORMAT"
        value = "true"
      },
      {
        name  = "ATLANTIS_SILENCE_FORK_PR_ERRORS"
        value = "true"
      },
      {
        name  = "ATLANTIS_DEFAULT_TF_VERSION"
        value = var.terraform_version
      }
    ]

    secrets = [
      {
        name      = "ATLANTIS_GH_TOKEN"
        valueFrom = data.aws_secretsmanager_secret.github_token.arn
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.atlantis.name
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = "atlantis"
      }
    }

    mountPoints = var.enable_efs ? [{
      sourceVolume  = "atlantis-data"
      containerPath = "/atlantis-data"
    }] : []

    ulimits = [{
      name      = "nofile"
      softLimit = 4096
      hardLimit = 8192
    }]

    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:${var.atlantis_port}/healthz || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
  }])

  dynamic "volume" {
    for_each = var.enable_efs ? [1] : []
    content {
      name = "atlantis-data"

      efs_volume_configuration {
        file_system_id          = aws_efs_file_system.main[0].id
        root_directory          = "/"
        transit_encryption      = "ENABLED"
        transit_encryption_port = 2999
        authorization_config {
          access_point_id = aws_efs_access_point.atlantis[0].id
          iam             = "ENABLED"
        }
      }
    }
  }

  tags = local.common_tags
}

# ECS Service
resource "aws_ecs_service" "atlantis" {
  name                              = "${local.name_prefix}-service"
  cluster                           = aws_ecs_cluster.main.id
  task_definition                   = aws_ecs_task_definition.atlantis.arn
  desired_count                     = var.desired_count
  launch_type                       = "FARGATE"
  platform_version                  = "LATEST"
  health_check_grace_period_seconds = 60

  network_configuration {
    subnets          = local.private_subnet_ids
    security_groups  = [local.ecs_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.atlantis.arn
    container_name   = "atlantis"
    container_port   = var.atlantis_port
  }

  deployment_configuration {
    maximum_percent         = 200
    minimum_healthy_percent = 100
    deployment_circuit_breaker {
      enable   = true
      rollback = true
    }
  }

  enable_ecs_managed_tags = true
  propagate_tags          = "TASK_DEFINITION"

  tags = local.common_tags

  depends_on = [aws_lb_listener.https]
}

# Auto Scaling Target
resource "aws_appautoscaling_target" "ecs" {
  count = var.enable_autoscaling ? 1 : 0

  max_capacity       = var.ecs_max_capacity
  min_capacity       = var.ecs_min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.atlantis.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  tags = local.common_tags
}

# Auto Scaling Policy - CPU
resource "aws_appautoscaling_policy" "cpu" {
  count = var.enable_autoscaling ? 1 : 0

  name               = "${local.name_prefix}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = var.target_cpu_utilization
  }

  tags = local.common_tags
}

# Auto Scaling Policy - Memory
resource "aws_appautoscaling_policy" "memory" {
  count = var.enable_autoscaling ? 1 : 0

  name               = "${local.name_prefix}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = var.target_memory_utilization
  }

  tags = local.common_tags
}

# CloudWatch Alarm - High CPU
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  count = var.enable_autoscaling ? 1 : 0

  alarm_name          = "${local.name_prefix}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = var.target_cpu_utilization + 10
  alarm_description   = "This metric monitors ECS CPU utilization"

  dimensions = {
    ServiceName = aws_ecs_service.atlantis.name
    ClusterName = aws_ecs_cluster.main.name
  }

  alarm_actions = [aws_appautoscaling_policy.cpu[0].arn]

  tags = local.common_tags
}

# CloudWatch Alarm - High Memory
resource "aws_cloudwatch_metric_alarm" "memory_high" {
  count = var.enable_autoscaling ? 1 : 0

  alarm_name          = "${local.name_prefix}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = var.target_memory_utilization + 10
  alarm_description   = "This metric monitors ECS memory utilization"

  dimensions = {
    ServiceName = aws_ecs_service.atlantis.name
    ClusterName = aws_ecs_cluster.main.name
  }

  alarm_actions = [aws_appautoscaling_policy.memory[0].arn]

  tags = local.common_tags
}