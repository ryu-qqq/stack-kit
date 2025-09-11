# Prometheus Enhanced Monitoring Addon
# Version: v1.0.0
# Purpose: ECS-based Prometheus deployment with service discovery, Grafana integration, and enhanced monitoring

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC and Subnet data sources (assume existing VPC)
data "aws_vpc" "main" {
  count = var.vpc_id != null ? 1 : 0
  id    = var.vpc_id
}

data "aws_subnets" "private" {
  count = var.vpc_id != null ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  tags = {
    Type = "private"
  }
}

data "aws_subnets" "public" {
  count = var.vpc_id != null ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  tags = {
    Type = "public"
  }
}

# ECS Cluster for Prometheus
resource "aws_ecs_cluster" "prometheus" {
  name = "${var.project_name}-${var.environment}-prometheus-cluster"

  configuration {
    execute_command_configuration {
      kms_key_id = var.kms_key_id
      logging    = "OVERRIDE"

      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.prometheus_cluster.name
      }
    }
  }

  dynamic "service_connect_defaults" {
    for_each = var.enable_service_connect ? [1] : []
    content {
      namespace = aws_service_discovery_private_dns_namespace.prometheus[0].arn
    }
  }

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-prometheus-cluster"
    Environment = var.environment
    Module      = "prometheus-addon"
    Version     = "v1.0.0"
    Purpose     = "monitoring"
  })
}

# CloudWatch Log Group for ECS Cluster
resource "aws_cloudwatch_log_group" "prometheus_cluster" {
  name              = "/aws/ecs/cluster/${var.project_name}-${var.environment}-prometheus"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_id

  tags = merge(var.common_tags, {
    Name        = "prometheus-cluster-logs"
    Environment = var.environment
    Module      = "prometheus-addon"
  })
}

# Service Discovery Namespace
resource "aws_service_discovery_private_dns_namespace" "prometheus" {
  count = var.enable_service_connect ? 1 : 0
  name  = "${var.project_name}-${var.environment}-prometheus.local"
  vpc   = var.vpc_id

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-prometheus-namespace"
    Environment = var.environment
    Module      = "prometheus-addon"
  })
}

# Security Group for Prometheus services
resource "aws_security_group" "prometheus" {
  name_prefix = "${var.project_name}-${var.environment}-prometheus-"
  vpc_id      = var.vpc_id
  description = "Security group for Prometheus monitoring services"

  # Prometheus server port
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main[0].cidr_block]
    description = "Prometheus server access"
  }

  # Grafana port
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = var.grafana_public_access ? ["0.0.0.0/0"] : [data.aws_vpc.main[0].cidr_block]
    description = "Grafana dashboard access"
  }

  # AlertManager port
  ingress {
    from_port   = 9093
    to_port     = 9093
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main[0].cidr_block]
    description = "AlertManager access"
  }

  # Node Exporter port
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main[0].cidr_block]
    description = "Node Exporter metrics"
  }

  # cAdvisor port
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main[0].cidr_block]
    description = "cAdvisor container metrics"
  }

  # Custom application metrics ports
  dynamic "ingress" {
    for_each = var.custom_metrics_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = [data.aws_vpc.main[0].cidr_block]
      description = "Custom metrics port ${ingress.value}"
    }
  }

  # Outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-prometheus-sg"
    Environment = var.environment
    Module      = "prometheus-addon"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Application Load Balancer for Prometheus services
resource "aws_lb" "prometheus" {
  count           = var.enable_alb ? 1 : 0
  name            = "${var.project_name}-${var.environment}-prometheus-alb"
  load_balancer_type = "application"
  internal        = !var.prometheus_public_access
  security_groups = [aws_security_group.prometheus_alb[0].id]
  subnets         = var.prometheus_public_access ? data.aws_subnets.public[0].ids : data.aws_subnets.private[0].ids

  enable_deletion_protection = var.environment == "prod" ? true : false

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-prometheus-alb"
    Environment = var.environment
    Module      = "prometheus-addon"
  })
}

# Security Group for ALB
resource "aws_security_group" "prometheus_alb" {
  count       = var.enable_alb ? 1 : 0
  name_prefix = "${var.project_name}-${var.environment}-prometheus-alb-"
  vpc_id      = var.vpc_id
  description = "Security group for Prometheus ALB"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.prometheus_public_access ? ["0.0.0.0/0"] : [data.aws_vpc.main[0].cidr_block]
    description = "HTTP access"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.prometheus_public_access ? ["0.0.0.0/0"] : [data.aws_vpc.main[0].cidr_block]
    description = "HTTPS access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-prometheus-alb-sg"
    Environment = var.environment
    Module      = "prometheus-addon"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Target Groups for Prometheus services
resource "aws_lb_target_group" "prometheus" {
  count    = var.enable_alb ? 1 : 0
  name     = "${var.project_name}-${var.environment}-prometheus-tg"
  port     = 9090
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/-/healthy"
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-prometheus-tg"
    Environment = var.environment
    Module      = "prometheus-addon"
  })
}

resource "aws_lb_target_group" "grafana" {
  count    = var.enable_alb && var.enable_grafana ? 1 : 0
  name     = "${var.project_name}-${var.environment}-grafana-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/api/health"
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-grafana-tg"
    Environment = var.environment
    Module      = "prometheus-addon"
  })
}

# ALB Listeners
resource "aws_lb_listener" "prometheus" {
  count             = var.enable_alb ? 1 : 0
  load_balancer_arn = aws_lb.prometheus[0].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prometheus[0].arn
  }
}

resource "aws_lb_listener" "grafana" {
  count             = var.enable_alb && var.enable_grafana ? 1 : 0
  load_balancer_arn = aws_lb.prometheus[0].arn
  port              = "3000"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana[0].arn
  }
}

# S3 Bucket for Prometheus storage (optional)
resource "aws_s3_bucket" "prometheus_storage" {
  count  = var.enable_remote_storage ? 1 : 0
  bucket = "${var.project_name}-${var.environment}-prometheus-storage"

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-prometheus-storage"
    Environment = var.environment
    Module      = "prometheus-addon"
    Purpose     = "metrics-storage"
  })
}

resource "aws_s3_bucket_versioning" "prometheus_storage" {
  count  = var.enable_remote_storage ? 1 : 0
  bucket = aws_s3_bucket.prometheus_storage[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_encryption" "prometheus_storage" {
  count  = var.enable_remote_storage ? 1 : 0
  bucket = aws_s3_bucket.prometheus_storage[0].id

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

# IAM Role for ECS Tasks
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project_name}-${var.environment}-prometheus-task-execution-role"

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

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-prometheus-task-execution-role"
    Environment = var.environment
    Module      = "prometheus-addon"
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Role for Prometheus Task
resource "aws_iam_role" "prometheus_task" {
  name = "${var.project_name}-${var.environment}-prometheus-task-role"

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

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-prometheus-task-role"
    Environment = var.environment
    Module      = "prometheus-addon"
  })
}

# IAM Policy for Prometheus service discovery
resource "aws_iam_role_policy" "prometheus_service_discovery" {
  name = "${var.project_name}-${var.environment}-prometheus-service-discovery"
  role = aws_iam_role.prometheus_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeRegions",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ecs:ListClusters",
          "ecs:ListTasks",
          "ecs:DescribeTasks",
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeContainerInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/ecs/prometheus/*"
      }
    ]
  })
}

# IAM Policy for S3 remote storage (if enabled)
resource "aws_iam_role_policy" "prometheus_s3_storage" {
  count = var.enable_remote_storage ? 1 : 0
  name  = "${var.project_name}-${var.environment}-prometheus-s3-storage"
  role  = aws_iam_role.prometheus_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.prometheus_storage[0].arn,
          "${aws_s3_bucket.prometheus_storage[0].arn}/*"
        ]
      }
    ]
  })
}

# EFS for persistent storage
resource "aws_efs_file_system" "prometheus" {
  count          = var.enable_persistent_storage ? 1 : 0
  creation_token = "${var.project_name}-${var.environment}-prometheus-efs"
  encrypted      = true
  kms_key_id     = var.kms_key_id

  performance_mode = "generalPurpose"
  throughput_mode  = "provisioned"
  provisioned_throughput_in_mibps = var.efs_provisioned_throughput

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-prometheus-efs"
    Environment = var.environment
    Module      = "prometheus-addon"
    Purpose     = "metrics-storage"
  })
}

# EFS Mount Targets
resource "aws_efs_mount_target" "prometheus" {
  count           = var.enable_persistent_storage ? length(data.aws_subnets.private[0].ids) : 0
  file_system_id  = aws_efs_file_system.prometheus[0].id
  subnet_id       = data.aws_subnets.private[0].ids[count.index]
  security_groups = [aws_security_group.efs[0].id]
}

# Security Group for EFS
resource "aws_security_group" "efs" {
  count       = var.enable_persistent_storage ? 1 : 0
  name_prefix = "${var.project_name}-${var.environment}-prometheus-efs-"
  vpc_id      = var.vpc_id
  description = "Security group for Prometheus EFS"

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.prometheus.id]
    description     = "EFS access from Prometheus tasks"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-prometheus-efs-sg"
    Environment = var.environment
    Module      = "prometheus-addon"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# CloudWatch Log Groups for services
resource "aws_cloudwatch_log_group" "prometheus" {
  name              = "/aws/ecs/prometheus/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_id

  tags = merge(var.common_tags, {
    Name        = "prometheus-logs"
    Environment = var.environment
    Module      = "prometheus-addon"
  })
}

resource "aws_cloudwatch_log_group" "grafana" {
  count             = var.enable_grafana ? 1 : 0
  name              = "/aws/ecs/grafana/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_id

  tags = merge(var.common_tags, {
    Name        = "grafana-logs"
    Environment = var.environment
    Module      = "prometheus-addon"
  })
}

resource "aws_cloudwatch_log_group" "alertmanager" {
  count             = var.enable_alertmanager ? 1 : 0
  name              = "/aws/ecs/alertmanager/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_id

  tags = merge(var.common_tags, {
    Name        = "alertmanager-logs"
    Environment = var.environment
    Module      = "prometheus-addon"
  })
}

# Prometheus configuration file
locals {
  prometheus_config = yamlencode({
    global = {
      scrape_interval     = var.prometheus_config.scrape_interval
      evaluation_interval = var.prometheus_config.evaluation_interval
      external_labels     = var.prometheus_config.external_labels
    }
    
    alerting = var.enable_alertmanager ? {
      alertmanagers = [
        {
          static_configs = [
            {
              targets = ["alertmanager:9093"]
            }
          ]
        }
      ]
    } : {}

    rule_files = var.enable_alertmanager ? [
      "/etc/prometheus/rules/*.yml"
    ] : []

    scrape_configs = concat(
      [
        {
          job_name = "prometheus"
          static_configs = [
            {
              targets = ["localhost:9090"]
            }
          ]
        }
      ],
      var.enable_grafana ? [
        {
          job_name = "grafana"
          static_configs = [
            {
              targets = ["grafana:3000"]
            }
          ]
        }
      ] : [],
      var.enable_alertmanager ? [
        {
          job_name = "alertmanager"
          static_configs = [
            {
              targets = ["alertmanager:9093"]
            }
          ]
        }
      ] : [],
      [
        {
          job_name = "ecs-service-discovery"
          ec2_sd_configs = [
            {
              region = data.aws_region.current.name
              port   = 9100
            }
          ]
          relabel_configs = [
            {
              source_labels = ["__meta_ec2_tag_Name"]
              target_label  = "instance"
            },
            {
              source_labels = ["__meta_ec2_instance_state"]
              regex         = "running"
              action        = "keep"
            }
          ]
        }
      ],
      var.custom_scrape_configs
    )
    
    remote_write = var.enable_remote_storage ? [
      {
        url = "s3://${aws_s3_bucket.prometheus_storage[0].bucket}/metrics"
      }
    ] : []
  })
}

# Store Prometheus configuration in Parameter Store
resource "aws_ssm_parameter" "prometheus_config" {
  name  = "/${var.project_name}/${var.environment}/prometheus/config"
  type  = "String"
  value = local.prometheus_config

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-prometheus-config"
    Environment = var.environment
    Module      = "prometheus-addon"
  })
}

# Store Grafana configuration
resource "aws_ssm_parameter" "grafana_config" {
  count = var.enable_grafana ? 1 : 0
  name  = "/${var.project_name}/${var.environment}/grafana/config"
  type  = "String"
  value = jsonencode(var.grafana_config)

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-grafana-config"
    Environment = var.environment
    Module      = "prometheus-addon"
  })
}

# Store AlertManager configuration
resource "aws_ssm_parameter" "alertmanager_config" {
  count = var.enable_alertmanager ? 1 : 0
  name  = "/${var.project_name}/${var.environment}/alertmanager/config"
  type  = "String"
  value = yamlencode(var.alertmanager_config)

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-alertmanager-config"
    Environment = var.environment
    Module      = "prometheus-addon"
  })
}