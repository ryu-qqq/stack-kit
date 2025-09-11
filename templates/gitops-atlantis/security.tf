# =======================================
# Security Configuration for GitOps Atlantis
# =======================================
# Following StackKit standards for security groups, IAM roles, and secrets

# =====================================
# 1. RANDOM SECRETS GENERATION
# =====================================

resource "random_password" "webhook_secret" {
  length  = 32
  special = true
  
  keepers = {
    environment = var.environment
    project     = var.project_name
  }
}

# =====================================
# 2. APPLICATION LOAD BALANCER SECURITY GROUP
# =====================================

resource "aws_security_group" "alb" {
  name_prefix = "${local.name_prefix}-alb-"
  description = "Security group for Atlantis Application Load Balancer"
  vpc_id      = local.vpc_id
  
  # HTTP inbound (for redirect to HTTPS)
  ingress {
    description = "HTTP from allowed CIDR blocks"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }
  
  # HTTPS inbound
  ingress {
    description = "HTTPS from allowed CIDR blocks"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }
  
  # All outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb-sg"
    Type = "LoadBalancer"
  })
  
  lifecycle {
    create_before_destroy = true
  }
}

# =====================================
# 3. ECS TASKS SECURITY GROUP
# =====================================

resource "aws_security_group" "ecs" {
  name_prefix = "${local.name_prefix}-ecs-"
  description = "Security group for Atlantis ECS tasks"
  vpc_id      = local.vpc_id
  
  # Atlantis application port from ALB only
  ingress {
    description     = "Atlantis port from ALB"
    from_port       = var.atlantis_port
    to_port         = var.atlantis_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  
  # All outbound traffic (for Git operations, API calls, etc.)
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecs-sg"
    Type = "Container"
  })
  
  lifecycle {
    create_before_destroy = true
  }
}

# =====================================
# 4. EFS SECURITY GROUP (CONDITIONAL)
# =====================================

resource "aws_security_group" "efs" {
  count = var.enable_efs ? 1 : 0
  
  name_prefix = "${local.name_prefix}-efs-"
  description = "Security group for Atlantis EFS file system"
  vpc_id      = local.vpc_id
  
  # NFS from ECS tasks only
  ingress {
    description     = "NFS from ECS tasks"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }
  
  # No outbound rules needed for EFS
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-efs-sg"
    Type = "Storage"
  })
  
  lifecycle {
    create_before_destroy = true
  }
}

# =====================================
# 5. ECS EXECUTION ROLE
# =====================================

resource "aws_iam_role" "ecs_execution" {
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
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecs-execution-role"
    Type = "ExecutionRole"
  })
}

# Standard ECS task execution policy
resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Custom policy for Secrets Manager access
resource "aws_iam_role_policy" "ecs_execution_secrets" {
  name = "${local.name_prefix}-execution-secrets-policy"
  role = aws_iam_role.ecs_execution.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:atlantis/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      }
    ]
  })
}

# =====================================
# 6. ECS TASK ROLE (ATLANTIS PERMISSIONS)
# =====================================

resource "aws_iam_role" "ecs_task" {
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
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecs-task-role"
    Type = "TaskRole"
  })
}

# Terraform state bucket access (conditional)
resource "aws_iam_role_policy" "terraform_state_access" {
  count = var.create_terraform_state_bucket ? 1 : 0
  
  name = "${local.name_prefix}-terraform-state-policy"
  role = aws_iam_role.ecs_task.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketVersioning",
          "s3:ListBucketVersions"
        ]
        Resource = "arn:aws:s3:::${local.name_prefix}-terraform-state"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::${local.name_prefix}-terraform-state/*"
      }
    ]
  })
}

# DynamoDB lock table access (conditional)
resource "aws_iam_role_policy" "terraform_lock_access" {
  count = var.create_terraform_lock_table ? 1 : 0
  
  name = "${local.name_prefix}-terraform-lock-policy"
  role = aws_iam_role.ecs_task.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${local.name_prefix}-terraform-lock"
      }
    ]
  })
}

# Atlantis infrastructure management policy
resource "aws_iam_role_policy" "atlantis_infrastructure" {
  name = "${local.name_prefix}-atlantis-infrastructure-policy"
  role = aws_iam_role.ecs_task.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Core AWS services for infrastructure
      {
        Effect = "Allow"
        Action = [
          # VPC and Networking
          "ec2:Describe*",
          "ec2:CreateVpc",
          "ec2:DeleteVpc",
          "ec2:ModifyVpcAttribute",
          "ec2:CreateSubnet",
          "ec2:DeleteSubnet",
          "ec2:ModifySubnetAttribute",
          "ec2:CreateInternetGateway",
          "ec2:AttachInternetGateway",
          "ec2:DetachInternetGateway",
          "ec2:DeleteInternetGateway",
          "ec2:CreateNatGateway",
          "ec2:DeleteNatGateway",
          "ec2:CreateRouteTable",
          "ec2:DeleteRouteTable",
          "ec2:CreateRoute",
          "ec2:DeleteRoute",
          "ec2:AssociateRouteTable",
          "ec2:DisassociateRouteTable",
          "ec2:AllocateAddress",
          "ec2:ReleaseAddress",
          "ec2:AssociateAddress",
          "ec2:DisassociateAddress",
          
          # Security Groups
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:ModifySecurityGroupRules",
          
          # Key Pairs
          "ec2:CreateKeyPair",
          "ec2:DeleteKeyPair",
          "ec2:ImportKeyPair",
          
          # Instances
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:RebootInstances",
          "ec2:ModifyInstanceAttribute",
          
          # Load Balancers
          "elasticloadbalancing:*",
          
          # Auto Scaling
          "autoscaling:*",
          
          # ECS
          "ecs:*",
          
          # CloudWatch
          "cloudwatch:*",
          "logs:*",
          
          # Route 53
          "route53:*",
          
          # ACM
          "acm:*",
          
          # Secrets Manager
          "secretsmanager:*",
          
          # KMS
          "kms:*",
          
          # Systems Manager
          "ssm:*",
          
          # S3
          "s3:*",
          
          # DynamoDB
          "dynamodb:*",
          
          # Lambda
          "lambda:*",
          
          # SNS
          "sns:*",
          
          # SQS
          "sqs:*"
        ]
        Resource = "*"
      },
      # IAM permissions (restricted to prevent privilege escalation)
      {
        Effect = "Allow"
        Action = [
          "iam:Get*",
          "iam:List*",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:UpdateRole",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:PassRole"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "iam:PermissionsBoundary" = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${local.name_prefix}-atlantis-permissions-boundary"
          }
        }
      }
    ]
  })
}

# Permissions boundary to prevent privilege escalation
resource "aws_iam_policy" "atlantis_permissions_boundary" {
  name        = "${local.name_prefix}-atlantis-permissions-boundary"
  description = "Permissions boundary for Atlantis-created resources"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "*"
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:RequestedRegion" = [data.aws_region.current.name]
          }
        }
      },
      {
        Effect = "Deny"
        Action = [
          "iam:CreateUser",
          "iam:CreateGroup",
          "iam:DeleteUser",
          "iam:DeleteGroup",
          "iam:AttachUserPolicy",
          "iam:DetachUserPolicy",
          "iam:PutUserPolicy",
          "iam:DeleteUserPolicy",
          "organizations:*",
          "account:*",
          "billing:*"
        ]
        Resource = "*"
      }
    ]
  })
  
  tags = local.common_tags
}

# =====================================
# 7. SECRETS MANAGER SECRET FOR WEBHOOK
# =====================================

resource "aws_secretsmanager_secret" "webhook_secret" {
  name                    = "atlantis/webhook-secret"
  description             = "Webhook secret for Atlantis GitHub integration"
  recovery_window_in_days = var.secret_recovery_window_days
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-webhook-secret"
    Type = "Secret"
  })
}

resource "aws_secretsmanager_secret_version" "webhook_secret" {
  secret_id = aws_secretsmanager_secret.webhook_secret.id
  secret_string = jsonencode({
    secret = random_password.webhook_secret.result
  })
}