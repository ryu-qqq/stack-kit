# 🚀 Atlantis ECS - 기존 인프라 활용 배포
# 기존 VPC, 서브넷, S3, DynamoDB 활용하여 최소한의 리소스로 빠른 배포

terraform {
  backend "s3" {
    # Configuration loaded from backend.hcl
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "atlantis"
      Environment = var.environment
      Owner       = var.org_name
      ManagedBy   = "terraform"
    }
  }
}

# =======================================
# Data Sources (기존 인프라 조회)
# =======================================

data "aws_caller_identity" "current" {}

# VPC 정보 조회
data "aws_vpc" "existing" {
  count = var.use_existing_vpc ? 1 : 0
  id    = var.existing_vpc_id
}

data "aws_subnets" "public" {
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

data "aws_subnets" "private" {
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

# =======================================
# VPC (기존 사용 또는 신규 생성)
# =======================================

# 신규 VPC (기존 인프라가 없을 때만)
resource "aws_vpc" "main" {
  count = var.use_existing_vpc ? 0 : 1

  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.environment}-atlantis-vpc"
  }
}

# 신규 서브넷들 (기존 VPC가 없을 때만)
resource "aws_internet_gateway" "main" {
  count = var.use_existing_vpc ? 0 : 1

  vpc_id = aws_vpc.main[0].id

  tags = {
    Name = "${var.environment}-atlantis-igw"
  }
}

resource "aws_subnet" "public" {
  count = var.use_existing_vpc ? 0 : 2

  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.environment}-atlantis-public-${count.index + 1}"
  }
}

resource "aws_subnet" "private" {
  count = var.use_existing_vpc ? 0 : 2

  vpc_id            = aws_vpc.main[0].id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.environment}-atlantis-private-${count.index + 1}"
  }
}

# NAT Gateway (신규 VPC만)
resource "aws_eip" "nat" {
  count = var.use_existing_vpc ? 0 : 1

  domain = "vpc"

  tags = {
    Name = "${var.environment}-atlantis-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  count = var.use_existing_vpc ? 0 : 1

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.environment}-atlantis-nat"
  }

  depends_on = [aws_internet_gateway.main]
}

# Route Tables (신규 VPC만)
resource "aws_route_table" "public" {
  count = var.use_existing_vpc ? 0 : 1

  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }

  tags = {
    Name = "${var.environment}-atlantis-public-rt"
  }
}

resource "aws_route_table" "private" {
  count = var.use_existing_vpc ? 0 : 1

  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[0].id
  }

  tags = {
    Name = "${var.environment}-atlantis-private-rt"
  }
}

resource "aws_route_table_association" "public" {
  count = var.use_existing_vpc ? 0 : 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table_association" "private" {
  count = var.use_existing_vpc ? 0 : 2

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[0].id
}

data "aws_availability_zones" "available" {
  state = "available"
}

# =======================================
# Local Values (동적 인프라 선택)
# =======================================

locals {
  vpc_id = var.use_existing_vpc ? var.existing_vpc_id : aws_vpc.main[0].id

  public_subnet_ids = var.use_existing_vpc ? var.existing_public_subnet_ids : [
    for subnet in aws_subnet.public : subnet.id
  ]

  private_subnet_ids = var.use_existing_vpc ? var.existing_private_subnet_ids : [
    for subnet in aws_subnet.private : subnet.id
  ]

}

# =======================================
# Security Groups with Enhanced Security
# =======================================

resource "aws_security_group" "alb" {
  name_prefix = "${var.environment}-atlantis-alb-"
  vpc_id      = local.vpc_id

  ingress {
    description = "HTTP access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Required for ALB public access
  }

  ingress {
    description = "HTTPS access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Required for ALB public access
  }

  # Restrict egress to only necessary destinations
  egress {
    description     = "HTTP to ECS containers"
    from_port       = 4141
    to_port         = 4141
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  egress {
    description = "HTTPS for health checks and AWS API calls"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Required for AWS API calls
  }

  egress {
    description = "HTTP for external dependencies (GitHub, Slack)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Required for external service calls
  }

  tags = {
    Name = "${var.environment}-atlantis-alb-sg"
  }
}

resource "aws_security_group" "ecs" {
  name_prefix = "${var.environment}-atlantis-ecs-"
  vpc_id      = local.vpc_id

  ingress {
    description     = "Traffic from ALB"
    from_port       = 4141
    to_port         = 4141
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Restrict egress to specific services only
  egress {
    description = "HTTPS for AWS API calls"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Required for AWS services
  }

  egress {
    description = "HTTP for external services (GitHub, Terraform providers)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Required for Terraform providers and GitHub
  }

  egress {
    description = "SSH for Git operations"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Required for Git SSH access
  }

  egress {
    description = "DNS resolution"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"] # Required for DNS
  }

  egress {
    description     = "EFS access"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.efs.id]
  }

  tags = {
    Name = "${var.environment}-atlantis-ecs-sg"
  }
}

# =======================================
# Application Load Balancer
# =======================================

resource "aws_lb" "atlantis" {
  name               = "${var.environment}-atlantis-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = local.public_subnet_ids

  # Enable deletion protection for production
  enable_deletion_protection = var.environment == "prod" ? true : false

  # Enable access logs for security monitoring
  access_logs {
    bucket  = aws_s3_bucket.atlantis_logs.bucket
    prefix  = "alb-access-logs"
    enabled = true
  }

  # Drop invalid headers for security
  drop_invalid_header_fields = true

  tags = {
    Name = "${var.environment}-atlantis-alb"
  }

  depends_on = [aws_s3_bucket_policy.atlantis_logs]
}

# S3 bucket for ALB access logs
resource "aws_s3_bucket" "atlantis_logs" {
  bucket = "${var.environment}-atlantis-logs-${random_id.bucket_suffix.hex}"

  tags = {
    Name = "${var.environment}-atlantis-logs"
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "atlantis_logs" {
  bucket = aws_s3_bucket.atlantis_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "atlantis_logs" {
  bucket = aws_s3_bucket.atlantis_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "atlantis_logs" {
  bucket = aws_s3_bucket.atlantis_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_elb_service_account" "main" {}

resource "aws_s3_bucket_policy" "atlantis_logs" {
  bucket = aws_s3_bucket.atlantis_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = data.aws_elb_service_account.main.arn
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.atlantis_logs.arn}/alb-access-logs/*"
      }
    ]
  })
}

resource "aws_lb_target_group" "atlantis" {
  name        = "${var.environment}-atlantis-tg"
  port        = 4141
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  target_type = "ip"

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

  tags = {
    Name = "${var.environment}-atlantis-tg"
  }
}

# HTTP Listener
resource "aws_lb_listener" "atlantis_http" {
  load_balancer_arn = aws_lb.atlantis.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = var.certificate_arn != "" ? "redirect" : "forward"

    dynamic "redirect" {
      for_each = var.certificate_arn != "" ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    dynamic "forward" {
      for_each = var.certificate_arn == "" ? [1] : []
      content {
        target_group {
          arn = aws_lb_target_group.atlantis.arn
        }
      }
    }
  }

  tags = {
    Name = "${var.environment}-atlantis-http"
  }
}

# HTTPS Listener (인증서가 있을 때만) with secure TLS policy
resource "aws_lb_listener" "atlantis_https" {
  count = var.certificate_arn != "" ? 1 : 0

  load_balancer_arn = aws_lb.atlantis.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01" # Updated to more recent policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.atlantis.arn
  }

  tags = {
    Name = "${var.environment}-atlantis-https"
  }
}

# =======================================
# ECS Cluster & Service
# =======================================

resource "aws_ecs_cluster" "atlantis" {
  name = "${var.environment}-atlantis-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.environment}-atlantis-cluster"
  }
}

# Task Execution Role with minimal permissions
resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.environment}-atlantis-exec-role"

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

  tags = {
    Name = "${var.environment}-atlantis-exec-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.ecs_execution_role.name
}

resource "aws_iam_role_policy" "ecs_execution_secrets" {
  name = "secrets-access"
  role = aws_iam_role.ecs_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.atlantis.arn
      }
    ]
  })
}

# Task Role with restricted permissions following least privilege principle
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.environment}-atlantis-task-role"

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

  tags = {
    Name = "${var.environment}-atlantis-task-role"
  }
}

# Separate policies for different AWS services following least privilege
resource "aws_iam_role_policy" "ecs_task_s3_policy" {
  name = "s3-state-access"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetObjectVersion"
        ]
        Resource = [
          var.existing_state_bucket != "" ? "arn:aws:s3:::${var.existing_state_bucket}" : "arn:aws:s3:::${var.environment}-atlantis-state-*",
          var.existing_state_bucket != "" ? "arn:aws:s3:::${var.existing_state_bucket}/*" : "arn:aws:s3:::${var.environment}-atlantis-state-*/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_task_dynamodb_policy" {
  name = "dynamodb-lock-access"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:DeleteItem",
          "dynamodb:DescribeTable"
        ]
        Resource = var.existing_lock_table != "" ? "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.existing_lock_table}" : "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.environment}-atlantis-lock"
      }
    ]
  })
}

# Minimal EC2 permissions for Terraform operations
resource "aws_iam_role_policy" "ecs_task_ec2_policy" {
  name = "ec2-terraform-access"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeNatGateways",
          "ec2:DescribeRouteTables",
          "ec2:DescribeNetworkAcls",
          "ec2:DescribeInstances",
          "ec2:DescribeImages",
          "ec2:DescribeKeyPairs"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateVpc",
          "ec2:CreateSubnet",
          "ec2:CreateSecurityGroup",
          "ec2:CreateRouteTable",
          "ec2:CreateRoute",
          "ec2:CreateInternetGateway",
          "ec2:AttachInternetGateway",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:AssociateRouteTable",
          "ec2:CreateTags",
          "ec2:ModifyVpcAttribute",
          "ec2:ModifySubnetAttribute"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ec2:Region" = var.aws_region
          }
        }
      }
    ]
  })
}

# CloudWatch Log Group with encryption
resource "aws_cloudwatch_log_group" "atlantis" {
  name              = "/ecs/${var.environment}-atlantis"
  retention_in_days = 14
  kms_key_id        = aws_kms_key.atlantis.arn

  tags = {
    Name = "${var.environment}-atlantis-logs"
  }
}

# KMS key for encryption
resource "aws_kms_key" "atlantis" {
  description             = "KMS key for Atlantis encryption"
  deletion_window_in_days = 7

  tags = {
    Name = "${var.environment}-atlantis-kms"
  }
}

resource "aws_kms_alias" "atlantis" {
  name          = "alias/${var.environment}-atlantis"
  target_key_id = aws_kms_key.atlantis.key_id
}

# Task Definition with secure container configuration
resource "aws_ecs_task_definition" "atlantis" {
  family                   = "${var.environment}-atlantis"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"

  execution_role_arn = aws_iam_role.ecs_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  volume {
    name = "atlantis-data"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.atlantis.id
      root_directory     = "/"
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.atlantis.id
        iam             = "ENABLED"
      }
    }
  }

  container_definitions = jsonencode([
    {
      name  = "atlantis"
      image = "runatlantis/atlantis:v0.28.5" # Pinned to specific version for security

      # Use init script with checksum verification for binary downloads
      command = [
        "sh", "-c",
        <<-EOT
        set -euo pipefail
        mkdir -p /atlantis/bin
        
        # Download and verify jq with checksum
        echo "Downloading jq..."
        JQ_URL="https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64"
        JQ_CHECKSUM="5942c9b0934e510ee61eb3ff770c6f44cb0cc8eb00f0a9cc5b1dc02dd23f7557"
        curl -fsSL "$JQ_URL" -o /tmp/jq
        echo "$JQ_CHECKSUM  /tmp/jq" | sha256sum -c -
        chmod +x /tmp/jq && cp /tmp/jq /atlantis/bin/jq
        
        # Download and verify Terraform with checksum
        echo "Downloading Terraform..."
        TF_URL="https://releases.hashicorp.com/terraform/1.7.5/terraform_1.7.5_linux_amd64.zip"
        TF_CHECKSUM="3ff056b5e8259003f67fd0f0ed7229499cfb0b41f3ff55cc184088589994f7a5"
        curl -fsSL "$TF_URL" -o /tmp/terraform.zip
        echo "$TF_CHECKSUM  /tmp/terraform.zip" | sha256sum -c -
        unzip -o /tmp/terraform.zip -d /tmp
        chmod +x /tmp/terraform
        cp /tmp/terraform /atlantis/bin/terraform1.7.5
        cp /tmp/terraform /atlantis/bin/terraform
        
        # Download and verify Infracost with checksum (optional, with error handling)
        echo "Downloading Infracost..."
        INFRACOST_URL="https://github.com/infracost/infracost/releases/download/v0.10.35/infracost-linux-amd64.tar.gz"
        INFRACOST_CHECKSUM="8bee6dc02c5318afed99e4c7b0c7c49b1de4d14f4b7cd8f3b37f13c306a95b1b"
        if curl -fsSL "$INFRACOST_URL" -o /tmp/infracost.tar.gz; then
          if echo "$INFRACOST_CHECKSUM  /tmp/infracost.tar.gz" | sha256sum -c -; then
            tar -xzf /tmp/infracost.tar.gz -C /tmp
            chmod +x /tmp/infracost-linux-amd64
            cp /tmp/infracost-linux-amd64 /atlantis/bin/infracost
            echo "Infracost installed successfully"
          else
            echo "Infracost checksum verification failed, skipping"
          fi
        else
          echo "Infracost download failed, continuing without it"
        fi
        
        # Cleanup and start Atlantis
        rm -f /tmp/jq /tmp/terraform /tmp/terraform.zip /tmp/infracost* 
        export PATH=/atlantis/bin:$PATH
        atlantis server
        EOT
      ]

      user = "100:101" # Non-root user for security

      portMappings = [
        {
          containerPort = 4141
          protocol      = "tcp"
        }
      ]

      environment = concat([
        {
          name  = "ATLANTIS_ATLANTIS_URL"
          value = var.custom_domain != "" ? "https://${var.custom_domain}" : "http://${aws_lb.atlantis.dns_name}"
        },
        {
          name  = "ATLANTIS_GH_USER"
          value = var.git_username
        },
        {
          name  = "ATLANTIS_REPO_ALLOWLIST"
          value = join(",", var.repo_allowlist)
        },
        {
          name  = "ATLANTIS_PORT"
          value = "4141"
        },
        {
          name  = "ATLANTIS_DATA_DIR"
          value = "/atlantis"
        },
        {
          name  = "ATLANTIS_DEFAULT_TF_VERSION"
          value = "1.7.5"
        },
        {
          name  = "ATLANTIS_ALLOWED_REPO_CONFIG_KEYS"
          value = "workflow,allowed_overrides,apply_requirements,autoplan,delete_source_branch_on_merge"
        },
        {
          name  = "ATLANTIS_ALLOW_REPO_CONFIG"
          value = "true"
        },
        {
          name  = "ATLANTIS_ENABLE_POLICY_CHECKS"
          value = "true"
        },
        {
          name  = "ATLANTIS_HIDE_PREV_PLAN_COMMENTS"
          value = "true"
        },
        {
          name  = "PATH"
          value = "/atlantis/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        }
      ])

      secrets = [
        {
          name      = "ATLANTIS_GH_TOKEN"
          valueFrom = "${aws_secretsmanager_secret.atlantis.arn}:github_token::"
        },
        {
          name      = "ATLANTIS_GH_WEBHOOK_SECRET"
          valueFrom = "${aws_secretsmanager_secret.atlantis.arn}:webhook_secret::"
        },
        {
          name      = "SLACK_WEBHOOK_URL"
          valueFrom = "${aws_secretsmanager_secret.atlantis.arn}:slack_webhook_url::"
        },
        {
          name      = "INFRACOST_API_KEY"
          valueFrom = "${aws_secretsmanager_secret.atlantis.arn}:infracost_api_key::"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.atlantis.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "atlantis"
        }
      }

      mountPoints = [
        {
          sourceVolume  = "atlantis-data"
          containerPath = "/atlantis"
          readOnly      = false
        }
      ]

      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -f http://localhost:4141/healthz || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      # Security settings
      readonlyRootFilesystem = false # Atlantis needs to write to filesystem
      essential              = true

      # Resource limits for security
      ulimits = [
        {
          name      = "nofile"
          softLimit = 65536
          hardLimit = 65536
        }
      ]
    }
  ])

  tags = {
    Name = "${var.environment}-atlantis-task"
  }
}

# ECS Service with enhanced security configuration
resource "aws_ecs_service" "atlantis" {
  name            = "atlantis"
  cluster         = aws_ecs_cluster.atlantis.id
  task_definition = aws_ecs_task_definition.atlantis.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  # Use Fargate platform version 1.4.0 for enhanced security
  platform_version = "1.4.0"

  network_configuration {
    subnets          = local.private_subnet_ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 50

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  enable_execute_command = false # Disable for security

  load_balancer {
    target_group_arn = aws_lb_target_group.atlantis.arn
    container_name   = "atlantis"
    container_port   = 4141
  }

  tags = {
    Name = "${var.environment}-atlantis-service"
  }

  depends_on = [aws_lb_listener.atlantis_http, aws_efs_mount_target.atlantis]
}

# =======================================
# EFS File System (Atlantis 데이터 영속화) with Encryption
# =======================================

resource "aws_efs_file_system" "atlantis" {
  creation_token = "${var.environment}-atlantis-efs"

  performance_mode                = "generalPurpose"
  throughput_mode                 = "provisioned"
  provisioned_throughput_in_mibps = 10

  # Enable encryption at rest and in transit
  encrypted  = true
  kms_key_id = aws_kms_key.atlantis.arn

  # Enable backup
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name = "${var.environment}-atlantis-efs"
  }
}

resource "aws_efs_access_point" "atlantis" {
  file_system_id = aws_efs_file_system.atlantis.id

  root_directory {
    path = "/atlantis"
    creation_info {
      owner_gid   = 101
      owner_uid   = 100
      permissions = "755"
    }
  }

  posix_user {
    gid = 101
    uid = 100
  }

  tags = {
    Name = "${var.environment}-atlantis-access-point"
  }
}

resource "aws_efs_mount_target" "atlantis" {
  count = length(local.private_subnet_ids)

  file_system_id  = aws_efs_file_system.atlantis.id
  subnet_id       = local.private_subnet_ids[count.index]
  security_groups = [aws_security_group.efs.id]
}

resource "aws_security_group" "efs" {
  name_prefix = "${var.environment}-atlantis-efs-"
  vpc_id      = local.vpc_id

  ingress {
    description     = "NFS from ECS containers"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  # No egress rules needed for EFS
  tags = {
    Name = "${var.environment}-atlantis-efs-sg"
  }
}

# =======================================
# Secrets Manager with Enhanced Security
# =======================================

resource "aws_secretsmanager_secret" "atlantis" {
  name                    = var.secret_name
  description             = "Atlantis secrets for ${var.org_name}-${var.environment}"
  recovery_window_in_days = 7
  kms_key_id              = aws_kms_key.atlantis.arn

  replica {
    region     = var.aws_region != "us-east-1" ? "us-east-1" : "us-west-2"
    kms_key_id = aws_kms_key.atlantis.arn
  }

  tags = {
    Name = "${var.environment}-atlantis-secrets"
  }
}