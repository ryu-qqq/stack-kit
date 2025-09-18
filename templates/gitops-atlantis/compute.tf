# =======================================
# Simplified ECS Compute for Atlantis
# =======================================
# MVP-focused configuration without auto-scaling

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
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = var.log_retention_days

  tags = local.common_tags
}

# ECS Task Definition
resource "aws_ecs_task_definition" "atlantis" {
  family                   = local.name_prefix
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = local.task_cpu
  memory                   = local.task_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name  = "atlantis"
    image = var.atlantis_image

    essential = true

    entryPoint = ["/usr/local/bin/atlantis"]
    command    = ["server"]

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
        name  = "ATLANTIS_WRITE_GIT_CREDS"
        value = "true"
      },
      {
        name  = "ATLANTIS_ENABLE_DIFF_MARKDOWN_FORMAT"
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

    # Keep EFS mount for VaultDB state persistence
    mountPoints = [{
      sourceVolume  = "atlantis-data"
      containerPath = "/atlantis-data"
    }]

    ulimits = [{
      name      = "nofile"
      softLimit = 4096
      hardLimit = 8192
    }]

    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:${var.atlantis_port}/healthz || exit 1"]
      interval    = 30
      timeout     = 10
      retries     = 5
      startPeriod = 120 # VaultDB initialization time
    }
  }])

  # EFS volume for persistent storage (VaultDB requirement)
  volume {
    name = "atlantis-data"

    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.atlantis[0].id
      root_directory          = "/"
      transit_encryption      = "ENABLED"
      transit_encryption_port = 2999
      authorization_config {
        access_point_id = aws_efs_access_point.atlantis[0].id
        iam             = "ENABLED"
      }
    }
  }

  tags = local.common_tags
}

# ECS Service - Single instance, no auto-scaling
resource "aws_ecs_service" "atlantis" {
  name                              = "${local.name_prefix}-service"
  cluster                           = aws_ecs_cluster.main.id
  task_definition                   = aws_ecs_task_definition.atlantis.arn
  desired_count                     = 1 # Fixed single instance
  launch_type                       = "FARGATE"
  platform_version                  = "LATEST"
  health_check_grace_period_seconds = local.health_check_grace_period

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

  enable_ecs_managed_tags = true
  propagate_tags          = "TASK_DEFINITION"

  # Simplified deployment configuration
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # Enable ECS Exec for debugging
  enable_execute_command = var.enable_ecs_exec

  lifecycle {
    ignore_changes = [
      task_definition # Managed by deployment pipeline
    ]
  }

  depends_on = [
    aws_lb_listener.https,
    aws_lb_target_group.atlantis
  ]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-service"
    Type = "compute"
  })
}
