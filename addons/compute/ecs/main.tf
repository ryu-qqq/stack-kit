# ECS Service Addon - Reusable ECS Service for StackKit
# Version: v1.0.0
# Purpose: Provides a ready-to-use ECS service that integrates with shared infrastructure

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data sources for shared infrastructure
data "terraform_remote_state" "shared_infrastructure" {
  backend = "s3"
  config = {
    bucket = var.shared_state_bucket
    key    = var.shared_state_key
    region = var.aws_region
  }
}

# Data source for ECS cluster from shared infrastructure
data "aws_ecs_cluster" "shared" {
  count        = var.use_shared_cluster ? 1 : 0
  cluster_name = var.shared_cluster_name != null ? var.shared_cluster_name : data.terraform_remote_state.shared_infrastructure.outputs.ecs_cluster_name
}

# CloudWatch Log Group for container logs
resource "aws_cloudwatch_log_group" "service" {
  name              = "/ecs/${var.project_name}/${var.environment}/${var.service_name}"
  retention_in_days = var.log_retention_days

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-${var.service_name}-logs"
    Service     = var.service_name
    Environment = var.environment
  })
}

# ECS Task Definition
resource "aws_ecs_task_definition" "service" {
  family                   = "${var.project_name}-${var.environment}-${var.service_name}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.environment_config[var.environment].cpu
  memory                   = var.environment_config[var.environment].memory
  execution_role_arn       = aws_iam_role.execution_role.arn
  task_role_arn            = aws_iam_role.task_role.arn

  container_definitions = jsonencode([
    {
      name  = var.service_name
      image = var.container_image

      # Environment-specific resource allocation
      cpu    = var.environment_config[var.environment].container_cpu
      memory = var.environment_config[var.environment].container_memory

      # Port mappings - conditional based on service type
      portMappings = var.service_type == "api" ? [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ] : []

      # Essential container
      essential = true

      # Logging configuration
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.service.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }

      # Environment variables
      environment = [
        for key, value in var.environment_variables : {
          name  = key
          value = tostring(value)
        }
      ]

      # Secrets from Parameter Store/Secrets Manager
      secrets = [
        for key, value in var.secrets : {
          name      = key
          valueFrom = value
        }
      ]

      # Health check for API services
      healthCheck = var.service_type == "api" ? {
        command     = ["CMD-SHELL", var.health_check_command]
        interval    = var.health_check_interval
        timeout     = var.health_check_timeout
        retries     = var.health_check_retries
        startPeriod = var.health_check_start_period
      } : null
    }
  ])

  # Dynamic volume configuration
  dynamic "volume" {
    for_each = var.volumes
    content {
      name = volume.value.name

      dynamic "efs_volume_configuration" {
        for_each = volume.value.efs_volume_configuration != null ? [volume.value.efs_volume_configuration] : []
        content {
          file_system_id     = efs_volume_configuration.value.file_system_id
          transit_encryption = lookup(efs_volume_configuration.value, "transit_encryption", "ENABLED")
          root_directory     = lookup(efs_volume_configuration.value, "root_directory", "/")
        }
      }
    }
  }

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-${var.service_name}-task"
    Service     = var.service_name
    Environment = var.environment
    Version     = "v1.0.0"
  })
}

# Security Group for ECS Service
resource "aws_security_group" "service" {
  name_prefix = "${var.project_name}-${var.environment}-${var.service_name}-"
  vpc_id      = var.use_shared_infrastructure ? data.terraform_remote_state.shared_infrastructure.outputs.vpc_id : var.vpc_id
  description = "Security group for ${var.service_name} ECS service"

  # Ingress rules - conditional based on service type
  dynamic "ingress" {
    for_each = var.service_type == "api" ? [1] : []
    content {
      description     = "ALB to ECS service"
      from_port       = var.container_port
      to_port         = var.container_port
      protocol        = "tcp"
      security_groups = var.use_shared_infrastructure ? [data.terraform_remote_state.shared_infrastructure.outputs.alb_security_group_id] : var.alb_security_group_ids
    }
  }

  # Custom ingress rules
  dynamic "ingress" {
    for_each = var.additional_security_group_rules
    content {
      description     = ingress.value.description
      from_port       = ingress.value.from_port
      to_port         = ingress.value.to_port
      protocol        = ingress.value.protocol
      cidr_blocks     = lookup(ingress.value, "cidr_blocks", null)
      security_groups = lookup(ingress.value, "security_groups", null)
    }
  }

  # Egress - allow all outbound
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-${var.service_name}-sg"
    Service     = var.service_name
    Environment = var.environment
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ECS Service
resource "aws_ecs_service" "service" {
  name            = var.service_name
  cluster         = var.use_shared_cluster ? data.aws_ecs_cluster.shared[0].id : var.cluster_id
  task_definition = aws_ecs_task_definition.service.arn
  desired_count   = var.environment_config[var.environment].desired_count
  launch_type     = "FARGATE"

  # Deployment configuration removed due to compatibility issues with some AWS provider versions

  # Network configuration
  network_configuration {
    subnets          = var.use_shared_infrastructure ? data.terraform_remote_state.shared_infrastructure.outputs.private_subnet_ids : var.subnet_ids
    security_groups  = [aws_security_group.service.id]
    assign_public_ip = false
  }

  # Load balancer configuration for API services
  dynamic "load_balancer" {
    for_each = var.service_type == "api" && var.enable_alb ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.service[0].arn
      container_name   = var.service_name
      container_port   = var.container_port
    }
  }

  # Service discovery configuration
  dynamic "service_registries" {
    for_each = var.enable_service_discovery ? [1] : []
    content {
      registry_arn = aws_service_discovery_service.service[0].arn
    }
  }

  enable_execute_command = var.enable_execute_command

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-${var.service_name}-service"
    Service     = var.service_name
    Environment = var.environment
  })

  depends_on = [
    aws_iam_role_policy_attachment.execution_role_policy,
    aws_lb_target_group.service
  ]
}

# ALB Target Group for API services
resource "aws_lb_target_group" "service" {
  count       = var.service_type == "api" && var.enable_alb ? 1 : 0
  name        = "${var.project_name}-${var.environment}-${substr(var.service_name, 0, 16)}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.use_shared_infrastructure ? data.terraform_remote_state.shared_infrastructure.outputs.vpc_id : var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = var.alb_health_check_healthy_threshold
    interval            = var.alb_health_check_interval
    matcher             = var.alb_health_check_matcher
    path                = var.alb_health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = var.alb_health_check_timeout
    unhealthy_threshold = var.alb_health_check_unhealthy_threshold
  }

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-${var.service_name}-tg"
    Service     = var.service_name
    Environment = var.environment
  })
}

# ALB Listener Rule for API services
resource "aws_lb_listener_rule" "service" {
  count        = var.service_type == "api" && var.enable_alb && length(var.alb_listener_rule_conditions) > 0 ? 1 : 0
  listener_arn = var.use_shared_infrastructure ? data.terraform_remote_state.shared_infrastructure.outputs.alb_listener_arn : var.alb_listener_arn
  priority     = var.alb_listener_rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service[0].arn
  }

  dynamic "condition" {
    for_each = var.alb_listener_rule_conditions
    content {
      dynamic "path_pattern" {
        for_each = lookup(condition.value, "path_pattern", null) != null ? [condition.value.path_pattern] : []
        content {
          values = path_pattern.value.values
        }
      }

      dynamic "host_header" {
        for_each = lookup(condition.value, "host_header", null) != null ? [condition.value.host_header] : []
        content {
          values = host_header.value.values
        }
      }
    }
  }
}

# Service Discovery Service
resource "aws_service_discovery_service" "service" {
  count = var.enable_service_discovery ? 1 : 0
  name  = var.service_name

  dns_config {
    namespace_id = var.use_shared_infrastructure ? data.terraform_remote_state.shared_infrastructure.outputs.service_discovery_namespace_id : var.service_discovery_namespace_id

    dns_records {
      ttl  = 60
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-${var.service_name}-discovery"
    Service     = var.service_name
    Environment = var.environment
  })
}

# Auto Scaling Target
resource "aws_appautoscaling_target" "service" {
  count              = var.enable_autoscaling ? 1 : 0
  max_capacity       = var.environment_config[var.environment].max_capacity
  min_capacity       = var.environment_config[var.environment].min_capacity
  resource_id        = "service/${var.use_shared_cluster ? data.aws_ecs_cluster.shared[0].cluster_name : var.cluster_name}/${aws_ecs_service.service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-${var.service_name}-autoscaling-target"
    Service     = var.service_name
    Environment = var.environment
  })
}

# Auto Scaling Policy - CPU
resource "aws_appautoscaling_policy" "cpu" {
  count              = var.enable_autoscaling ? 1 : 0
  name               = "${var.project_name}-${var.environment}-${var.service_name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service[0].resource_id
  scalable_dimension = aws_appautoscaling_target.service[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.service[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.autoscaling_cpu_target
    scale_in_cooldown  = var.autoscaling_scale_in_cooldown
    scale_out_cooldown = var.autoscaling_scale_out_cooldown
  }
}

# Auto Scaling Policy - Memory
resource "aws_appautoscaling_policy" "memory" {
  count              = var.enable_autoscaling ? 1 : 0
  name               = "${var.project_name}-${var.environment}-${var.service_name}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service[0].resource_id
  scalable_dimension = aws_appautoscaling_target.service[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.service[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = var.autoscaling_memory_target
    scale_in_cooldown  = var.autoscaling_scale_in_cooldown
    scale_out_cooldown = var.autoscaling_scale_out_cooldown
  }
}