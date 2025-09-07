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
# Security Groups
# =======================================

resource "aws_security_group" "alb" {
  name_prefix = "${var.environment}-atlantis-alb-"
  vpc_id      = local.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # ALLOW_PUBLIC_EXEMPT - ALB public access
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # ALLOW_PUBLIC_EXEMPT - ALB public access
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # ALLOW_PUBLIC_EXEMPT - ALB outbound
  }

  tags = {
    Name = "${var.environment}-atlantis-alb-sg"
  }
}

resource "aws_security_group" "ecs" {
  name_prefix = "${var.environment}-atlantis-ecs-"
  vpc_id      = local.vpc_id

  ingress {
    from_port       = 4141
    to_port         = 4141
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # ALLOW_PUBLIC_EXEMPT - ECS outbound
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

  tags = {
    Name = "${var.environment}-atlantis-alb"
  }
}

resource "aws_lb_target_group" "atlantis" {
  name        = "${var.environment}-atlantis-tg"
  port        = 4141
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  target_type = "ip"

  health_check {
    enabled           = true
    healthy_threshold = 2
    path              = "/healthz"
    matcher           = "200"
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

# HTTPS Listener (인증서가 있을 때만)
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

  tags = {
    Name = "${var.environment}-atlantis-https"
  }
}

# =======================================
# ECS Cluster & Service
# =======================================

resource "aws_ecs_cluster" "atlantis" {
  name = "${var.environment}-atlantis-cluster"

  tags = {
    Name = "${var.environment}-atlantis-cluster"
  }
}

# Task Execution Role
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

# Task Role
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
}

resource "aws_iam_role_policy" "ecs_task_policy" {
  name = "atlantis-permissions"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:PutObjectAcl"
        ]
        Resource = [
          var.existing_state_bucket != "" ? "arn:aws:s3:::${var.existing_state_bucket}" : "*",
          var.existing_state_bucket != "" ? "arn:aws:s3:::${var.existing_state_bucket}/*" : "*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:DeleteItem"
        ]
        Resource = var.existing_lock_table != "" ? "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.existing_lock_table}" : "*"
      },
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
          "ec2:CreateVpc",
          "ec2:CreateSubnet",
          "ec2:CreateSecurityGroup",
          "ec2:CreateRouteTable",
          "ec2:CreateRoute",
          "ec2:CreateInternetGateway",
          "ec2:AttachInternetGateway",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:AssociateRouteTable",
          "ec2:CreateTags",
          "ec2:ModifyVpcAttribute"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning",
          "s3:GetBucketEncryption",
          "s3:PutBucketEncryption",
          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketPublicAccessBlock",
          "s3:PutBucketLifecycleConfiguration",
          "s3:GetBucketLifecycleConfiguration"
        ]
        Resource = "*"
      }
    ]
  })
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "atlantis" {
  name              = "/ecs/${var.environment}-atlantis"
  retention_in_days = 7

  tags = {
    Name = "${var.environment}-atlantis-logs"
  }
}

# Task Definition (Infracost 공식 이미지 사용)
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
      name    = "atlantis"
      image   = "runatlantis/atlantis:latest" # 안정적인 공식 버전
      command = [
        "sh", "-c", 
        "mkdir -p /atlantis/bin && curl -fsSL https://github.com/jqlang/jq/releases/latest/download/jq-linux-amd64 -o /atlantis/bin/jq && chmod +x /atlantis/bin/jq && curl -fsSL https://releases.hashicorp.com/terraform/1.7.5/terraform_1.7.5_linux_amd64.zip -o /tmp/terraform.zip && unzip -o /tmp/terraform.zip -d /tmp && chmod +x /tmp/terraform && cp /tmp/terraform /atlantis/bin/terraform1.7.5 && cp /tmp/terraform /atlantis/bin/terraform && (curl -fsSL https://github.com/infracost/infracost/releases/latest/download/infracost-linux-amd64.tar.gz | tar -xz -C /tmp && chmod +x /tmp/infracost-linux-amd64 && cp /tmp/infracost-linux-amd64 /atlantis/bin/infracost || echo 'Infracost installation failed, continuing without it') && export PATH=/atlantis/bin:/tmp:$PATH && atlantis server"
      ]
      user    = "1000:1000"

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
        ],
        [
          {
            name  = "ATLANTIS_ENABLE_POLICY_CHECKS"
            value = "true"
          },
          {
            name  = "INFRACOST_ENABLE_CLOUD"
            value = "true"
          },
          {
            name  = "INFRACOST_ENABLE_DASHBOARD"
            value = "true"
          },
          {
            name  = "PATH"
            value = "/atlantis/bin:/tmp:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
          }
        ])

      secrets = concat([
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
      ])

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

      essential = true
    }
  ])

  tags = {
    Name = "${var.environment}-atlantis-task"
  }
}

# ECS Service
resource "aws_ecs_service" "atlantis" {
  name            = "atlantis"
  cluster         = aws_ecs_cluster.atlantis.id
  task_definition = aws_ecs_task_definition.atlantis.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = local.private_subnet_ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0

  deployment_circuit_breaker {
    enable   = false
    rollback = false
  }

  enable_execute_command = true

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
# EFS File System (Atlantis 데이터 영속화)
# =======================================

resource "aws_efs_file_system" "atlantis" {
  creation_token = "${var.environment}-atlantis-efs"

  performance_mode                = "generalPurpose"
  throughput_mode                 = "provisioned"
  provisioned_throughput_in_mibps = 10

  tags = {
    Name = "${var.environment}-atlantis-efs"
  }
}

resource "aws_efs_access_point" "atlantis" {
  file_system_id = aws_efs_file_system.atlantis.id

  root_directory {
    path = "/atlantis"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }

  posix_user {
    gid = 1000
    uid = 1000
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
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-atlantis-efs-sg"
  }
}

# =======================================
# Secrets Manager
# =======================================

resource "aws_secretsmanager_secret" "atlantis" {
  name                    = var.secret_name
  description             = "Atlantis secrets for ${var.org_name}-${var.environment}"
  recovery_window_in_days = 7

  tags = {
    Name = "${var.environment}-atlantis-secrets"
  }
}
