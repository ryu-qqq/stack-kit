# Atlantis AI Reviewer Stack - ECS + Atlantis + AI Review Pipeline

locals {
  # Simplified naming: env-service
  name_prefix = "${var.env}-atlantis"
  
  common_tags = {
    Project     = "stackkit"
    Environment = var.env
    Stack       = var.stack_name
    Owner       = "platform"
    ManagedBy   = "terraform"
  }
}

# VPC Module for Atlantis Infrastructure (conditional)
module "vpc" {
  count  = var.use_existing_vpc ? 0 : 1
  source = "../../../modules/vpc"
  
  project_name = "atlantis"
  environment  = var.env
  vpc_cidr     = "10.0.0.0/16"
  
  common_tags = local.common_tags
}

# Data sources for existing VPC resources
data "aws_vpc" "existing" {
  count = var.use_existing_vpc ? 1 : 0
  id    = var.existing_vpc_id
}

data "aws_subnets" "existing_public" {
  count = var.use_existing_vpc ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [var.existing_vpc_id]
  }
  filter {
    name   = "subnet-id"
    values = var.existing_public_subnet_ids
  }
}

data "aws_subnets" "existing_private" {
  count = var.use_existing_vpc ? 1 : 0
  filter {
    name   = "vpc-id"  
    values = [var.existing_vpc_id]
  }
  filter {
    name   = "subnet-id"
    values = var.existing_private_subnet_ids
  }
}

# Local values for VPC references
locals {
  vpc_id = var.use_existing_vpc ? data.aws_vpc.existing[0].id : module.vpc[0].vpc_id
  public_subnet_ids = var.use_existing_vpc ? var.existing_public_subnet_ids : module.vpc[0].public_subnet_ids
  private_subnet_ids = var.use_existing_vpc ? var.existing_private_subnet_ids : module.vpc[0].private_subnet_ids
}

# Use existing S3 bucket for Atlantis outputs
# No module needed - using existing bucket specified in variables

# Data source for existing S3 bucket
data "aws_s3_bucket" "existing_atlantis_outputs" {
  bucket = var.existing_s3_bucket_name
}

# Local values for resource references
locals {
  atlantis_outputs_bucket_name = data.aws_s3_bucket.existing_atlantis_outputs.bucket
  atlantis_outputs_bucket_arn = data.aws_s3_bucket.existing_atlantis_outputs.arn
  
  # ALB references
  alb_arn = var.use_existing_alb ? data.aws_lb.existing_atlantis[0].arn : aws_lb.atlantis[0].arn
  alb_dns_name = var.use_existing_alb ? var.existing_alb_dns_name : aws_lb.atlantis[0].dns_name
  alb_zone_id = var.use_existing_alb ? data.aws_lb.existing_atlantis[0].zone_id : aws_lb.atlantis[0].zone_id
}

# SQS Queue for AI processing pipeline (FIFO)
module "ai_review_queue" {
  source = "../../../modules/sqs"
  
  project_name = "atlantis"
  environment  = var.env
  queue_name   = "ai-reviews"
  
  # Standard Queue Configuration (FIFO not supported by S3 notifications)
  fifo_queue                  = false
  content_based_deduplication = false
  
  visibility_timeout_seconds = 900  # 15 minutes for AI processing
  message_retention_seconds  = 1209600  # 14 days
  
  # DLQ for failed processing
  create_dlq = true
  max_receive_count = 3
  
  common_tags = local.common_tags
}

# S3 Event Notification to SQS for AI Review trigger
resource "aws_s3_bucket_notification" "atlantis_outputs_notification" {
  bucket = local.atlantis_outputs_bucket_name

  queue {
    queue_arn     = module.ai_review_queue.queue_arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "terraform/${var.env}/atlantis/"
    filter_suffix = "manifest.json"
  }

  depends_on = [aws_sqs_queue_policy.ai_review_queue_policy]
}

# SQS Queue Policy to allow S3 to send messages
resource "aws_sqs_queue_policy" "ai_review_queue_policy" {
  queue_url = module.ai_review_queue.queue_url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3ToSendMessages"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = module.ai_review_queue.queue_arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = local.atlantis_outputs_bucket_arn
          }
        }
      }
    ]
  })
}

# Lambda Function for AI Review (unified)
module "ai_reviewer" {
  source = "../../../modules/lambda"
  
  project_name  = "atlantis"
  environment   = var.env
  function_name = "ai-reviewer"
  runtime       = "java17"
  handler       = "com.stackkit.atlantis.reviewer.UnifiedReviewerHandler::handleRequest"
  filename      = "../../../../ai-reviewer/build/libs/atlantis-ai-reviewer-1.0.0.jar"
  
  memory_size = 512
  timeout     = 900  # 15 minutes
  
  # Environment variables for AI and Slack
  environment_variables = {
    ENV = var.env
    S3_BUCKET = local.atlantis_outputs_bucket_name
    S3_PREFIX = "terraform/${var.env}/atlantis"
    SLACK_WEBHOOK_URL = var.slack_webhook_url
    OPENAI_API_KEY = var.openai_api_key
    INFRACOST_API_KEY = var.infracost_api_key
    
    # SQS Configuration
    AI_REVIEW_QUEUE_URL = module.ai_review_queue.queue_url
  }
  
  # Additional IAM policy for SQS access
  additional_iam_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = [
          module.ai_review_queue.queue_arn,
          module.ai_review_queue.dlq_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${local.atlantis_outputs_bucket_arn}/*"
      }
    ]
  })
  
  common_tags = local.common_tags
}

# Lambda Event Source Mapping for SQS trigger (unified)
resource "aws_lambda_event_source_mapping" "ai_reviewer_sqs_trigger" {
  event_source_arn = module.ai_review_queue.queue_arn
  function_name    = module.ai_reviewer.function_name
  batch_size       = 1
}

# SNS for additional notifications
module "atlantis_notifications" {
  source = "../../../modules/sns"
  
  project_name = "atlantis"
  environment  = var.env
  topic_name   = "${var.env}-atlantis-alerts"
  
  common_tags = local.common_tags
}

# EventBridge for orchestration - simplified version
resource "aws_cloudwatch_event_bus" "atlantis" {
  name = "${var.env}-atlantis-events"
  tags = local.common_tags
}

# KMS for encryption - simplified version
resource "aws_kms_key" "atlantis_encryption" {
  description             = "Encryption key for Atlantis AI reviewer infrastructure"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  
  tags = merge(local.common_tags, {
    Name = "${var.stack_name}-atlantis-encryption"
  })
}

resource "aws_kms_alias" "atlantis_encryption" {
  name          = "alias/${var.env}-atlantis-encryption"
  target_key_id = aws_kms_key.atlantis_encryption.key_id
}

# Data source for existing ALB
data "aws_lb" "existing_atlantis" {
  count = var.use_existing_alb ? 1 : 0
  name  = "${var.env}-atlantis-alb"
}

# Data source for existing ALB security group
data "aws_security_groups" "existing_alb_sg" {
  count = var.use_existing_alb ? 1 : 0
  
  filter {
    name   = "group-id"
    values = data.aws_lb.existing_atlantis[0].security_groups
  }
}

# Application Load Balancer for Atlantis (only create if not using existing)
resource "aws_lb" "atlantis" {
  count              = var.use_existing_alb ? 0 : 1
  name               = "${var.env}-atlantis-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = local.public_subnet_ids

  enable_deletion_protection = var.env == "prod" ? true : false

  tags = local.common_tags
}

resource "aws_lb_target_group" "atlantis" {
  name     = "${var.env}-atlantis-tg"
  port     = 4141
  protocol = "HTTP"
  vpc_id   = local.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 15
    matcher             = "200"
    path                = "/healthz"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 10
    unhealthy_threshold = 5
  }

  tags = local.common_tags
}

# ALB Listener (only create if not using existing ALB)
resource "aws_lb_listener" "atlantis" {
  count = var.use_existing_alb ? 0 : 1
  
  load_balancer_arn = local.alb_arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.atlantis.arn
  }
}

# Data source for existing ALB listener (when using existing ALB)
data "aws_lb_listener" "existing_https" {
  count = var.use_existing_alb ? 1 : 0
  
  load_balancer_arn = local.alb_arn
  port              = 443
}

# Listener rule for existing ALB (route /atlantis/* to our target group)
resource "aws_lb_listener_rule" "atlantis" {
  count = var.use_existing_alb ? 1 : 0
  
  listener_arn = data.aws_lb_listener.existing_https[0].arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.atlantis.arn
  }

  condition {
    path_pattern {
      values = ["/atlantis/*", "/atlantis", "/"]
    }
  }
}

# Security Groups
resource "aws_security_group" "alb" {
  name_prefix = "${local.name_prefix}-alb-"
  vpc_id      = local.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # ALLOW_PUBLIC_EXEMPT - ALB needs outbound internet access
  }

  tags = merge(local.common_tags, {
    Name = "${var.stack_name}-atlantis-alb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# CloudWatch Log Group for ECS Tasks
resource "aws_cloudwatch_log_group" "atlantis_ecs" {
  name              = "/ecs/${var.env}-atlantis"
  retention_in_days = 7
  
  tags = merge(local.common_tags, {
    Name = "${var.env}-atlantis-ecs-logs"
  })
}

# ECS Cluster for Atlantis (conditional)
module "atlantis_cluster" {
  count  = var.use_existing_ecs_cluster ? 0 : 1
  source = "../../../modules/ecs"
  
  project_name = "atlantis"
  environment  = var.env
  cluster_name = "${var.env}-atlantis"
  
  # VPC Configuration
  vpc_id     = local.vpc_id
  subnet_ids = local.private_subnet_ids
  
  # Service Configuration
  service_name    = "atlantis"
  desired_count   = var.env == "prod" ? 2 : 1
  task_cpu        = "512"
  task_memory     = "1024"
  
  # Container Definition with Init Container
  container_definitions = [
    {
      name  = "init-atlantis-data"
      image = "alpine:3.18"
      essential = false
      
      command = [
        "/bin/sh",
        "-c",
        "chown -R 100:101 /atlantis-data && chmod -R 755 /atlantis-data && echo 'EFS initialization complete'"
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
          "awslogs-group"         = "/ecs/${var.env}-atlantis"
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "init"
        }
      }
    },
    {
      name  = "atlantis"
      image = "ghcr.io/runatlantis/atlantis:v0.28.5"
      
      portMappings = [
        {
          containerPort = 4141
          protocol      = "tcp"
        }
      ]
      
      environment = [
        {
          name  = "ATLANTIS_GH_USER"
          value = var.git_username
        },
        {
          name  = "ATLANTIS_GH_WEBHOOK_SECRET"
          value = var.webhook_secret
        },
        {
          name  = "ATLANTIS_REPO_ALLOWLIST"
          value = var.repo_allowlist
        },
        {
          name  = "ATLANTIS_ATLANTIS_URL"
          value = var.use_existing_alb ? "https://${local.alb_dns_name}" : "http://${local.alb_dns_name}"
        },
        {
          name  = "ATLANTIS_PORT"
          value = "4141"
        },
        {
          name  = "ATLANTIS_DATA_DIR"
          value = "/atlantis-data"
        },
        {
          name  = "AWS_REGION"
          value = var.region
        },
        {
          name  = "AWS_DEFAULT_REGION"
          value = var.region
        },
        {
          name  = "S3_BUCKET_NAME"
          value = local.atlantis_outputs_bucket_name
        },
        {
          name  = "S3_PREFIX"
          value = "terraform/${var.env}/atlantis"
        },
        {
          name  = "PLAN_QUEUE_URL"
          value = module.ai_review_queue.queue_url
        },
        {
          name  = "APPLY_QUEUE_URL"
          value = module.ai_review_queue.queue_url
        },
        {
          name  = "ATLANTIS_USER_NAME"
          value = "root"
        },
        {
          name  = "ATLANTIS_DISABLE_REPO_LOCKING"
          value = "true"
        },
        {
          name  = "ATLANTIS_HOST"
          value = "0.0.0.0"
        },
        {
          name  = "ATLANTIS_DB_TYPE"
          value = "boltdb"
        },
        {
          name  = "ATLANTIS_WRITE_GIT_CREDS"
          value = "true"
        }
      ]
      
      secrets = [
        {
          name      = "ATLANTIS_GH_TOKEN"
          valueFrom = var.git_token_secret_arn
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.env}-atlantis"
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
      
      mountPoints = [
        {
          sourceVolume  = "atlantis-data"
          containerPath = "/atlantis-data"
          readOnly      = false
        }
      ]
      
      dependsOn = [
        {
          containerName = "init-atlantis-data"
          condition     = "SUCCESS"
        }
      ]
      
      essential = true
    }
  ]
  
  # EFS volume for persistent data storage
  volumes = [
    {
      name = "atlantis-data"
      efs_volume_configuration = {
        file_system_id     = aws_efs_file_system.atlantis_data.id
        access_point_id    = aws_efs_access_point.atlantis_data.id
        transit_encryption = "ENABLED"
      }
    }
  ]
  
  # Load Balancer Configuration
  load_balancer_config = [
    {
      target_group_arn = aws_lb_target_group.atlantis.arn
      container_name   = "atlantis"
      container_port   = 4141
    }
  ]
  
  # Security Group Rules
  security_group_rules = [
    {
      description = "Allow ALB traffic"
      from_port   = 4141
      to_port     = 4141
      protocol    = "tcp"
      security_groups = var.use_existing_alb ? data.aws_security_groups.existing_alb_sg[0].ids : [aws_security_group.alb.id]
    }
  ]
  
  # Custom IAM policies for least privilege access
  task_role_policies = [
    {
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ]
      Resource = [
        local.atlantis_outputs_bucket_arn,
        "${local.atlantis_outputs_bucket_arn}/*"
      ]
    },
    {
      Effect = "Allow"
      Action = [
        "sqs:SendMessage",
        "sqs:GetQueueUrl",
        "sqs:GetQueueAttributes"
      ]
      Resource = [
        module.ai_review_queue.queue_arn,
        module.ai_review_queue.dlq_arn
      ]
    }
  ]
  
  # Auto Scaling
  enable_autoscaling     = true
  autoscaling_min_capacity = var.env == "prod" ? 1 : 1
  autoscaling_max_capacity = var.env == "prod" ? 4 : 2
  
  common_tags = local.common_tags
  
  depends_on = [aws_lb_target_group.atlantis]
}

# EFS File System for Atlantis persistent data
resource "aws_efs_file_system" "atlantis_data" {
  creation_token = "${var.stack_name}-atlantis-data"
  performance_mode = "generalPurpose"
  throughput_mode = "provisioned"
  provisioned_throughput_in_mibps = 100

  encrypted = true
  kms_key_id = aws_kms_key.atlantis_encryption.arn

  tags = merge(local.common_tags, {
    Name = "${var.stack_name}-atlantis-data"
  })
}

resource "aws_efs_mount_target" "atlantis_data" {
  count           = length(local.private_subnet_ids)
  file_system_id  = aws_efs_file_system.atlantis_data.id
  subnet_id       = local.private_subnet_ids[count.index]
  security_groups = [aws_security_group.efs.id]
}

# EFS Access Point for Atlantis with proper permissions
resource "aws_efs_access_point" "atlantis_data" {
  file_system_id = aws_efs_file_system.atlantis_data.id

  posix_user {
    uid = 100
    gid = 101
  }

  root_directory {
    path = "/atlantis-data"
    creation_info {
      owner_uid   = 100
      owner_gid   = 101
      permissions = "0755"
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.stack_name}-atlantis-access-point"
  })
}

resource "aws_security_group" "efs" {
  name_prefix = "${local.name_prefix}-efs-"
  vpc_id      = local.vpc_id

  ingress {
    description = "NFS"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    security_groups = var.use_existing_ecs_cluster ? [] : [module.atlantis_cluster[0].security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # ALLOW_PUBLIC_EXEMPT - EFS needs outbound access for updates
  }

  tags = merge(local.common_tags, {
    Name = "${var.stack_name}-atlantis-efs-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# CloudWatch Log Group for Atlantis
resource "aws_cloudwatch_log_group" "atlantis" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = var.env == "prod" ? 30 : 7
  
  tags = local.common_tags
}

# CloudWatch Alarms for Atlantis monitoring
resource "aws_cloudwatch_metric_alarm" "atlantis_service_count" {
  alarm_name          = "${local.name_prefix}-service-running-count"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "RunningTaskCount"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "This metric monitors the number of running Atlantis tasks"
  alarm_actions       = [module.atlantis_notifications.topic_arn]
  
  dimensions = {
    ServiceName = var.use_existing_ecs_cluster ? "atlantis" : module.atlantis_cluster[0].service_name
    ClusterName = var.use_existing_ecs_cluster ? var.existing_ecs_cluster_name : module.atlantis_cluster[0].cluster_name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "atlantis_cpu_high" {
  alarm_name          = "${local.name_prefix}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors Atlantis CPU utilization"
  alarm_actions       = [module.atlantis_notifications.topic_arn]
  
  dimensions = {
    ServiceName = var.use_existing_ecs_cluster ? "atlantis" : module.atlantis_cluster[0].service_name
    ClusterName = var.use_existing_ecs_cluster ? var.existing_ecs_cluster_name : module.atlantis_cluster[0].cluster_name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "atlantis_memory_high" {
  alarm_name          = "${local.name_prefix}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "This metric monitors Atlantis memory utilization"
  alarm_actions       = [module.atlantis_notifications.topic_arn]
  
  dimensions = {
    ServiceName = var.use_existing_ecs_cluster ? "atlantis" : module.atlantis_cluster[0].service_name
    ClusterName = var.use_existing_ecs_cluster ? var.existing_ecs_cluster_name : module.atlantis_cluster[0].cluster_name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "atlantis_unhealthy_targets" {
  alarm_name          = "${local.name_prefix}-unhealthy-targets"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "This metric monitors healthy targets behind the ALB"
  alarm_actions       = [module.atlantis_notifications.topic_arn]
  
  dimensions = {
    TargetGroup  = aws_lb_target_group.atlantis.arn_suffix
    LoadBalancer = var.use_existing_alb ? data.aws_lb.existing_atlantis[0].arn_suffix : aws_lb.atlantis[0].arn_suffix
  }

  tags = local.common_tags
}
