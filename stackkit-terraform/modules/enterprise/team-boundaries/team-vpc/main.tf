# Team VPC Module - Isolated networking per team
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
  availability_zones = data.aws_availability_zones.available.names
  
  # Calculate subnets based on team VPC CIDR
  # VPC: 10.{team_id}.0.0/16
  # Public subnets: 10.{team_id}.1.0/24, 10.{team_id}.2.0/24
  # Private subnets: 10.{team_id}.11.0/24, 10.{team_id}.12.0/24
  # Database subnets: 10.{team_id}.21.0/24, 10.{team_id}.22.0/24
  
  vpc_cidr_parts = split(".", replace(var.vpc_cidr, "/16", ""))
  base_cidr = "${local.vpc_cidr_parts[0]}.${local.vpc_cidr_parts[1]}"
  
  public_subnets = [
    "${local.base_cidr}.1.0/24",
    "${local.base_cidr}.2.0/24"
  ]
  
  private_subnets = [
    "${local.base_cidr}.11.0/24", 
    "${local.base_cidr}.12.0/24"
  ]
  
  database_subnets = [
    "${local.base_cidr}.21.0/24",
    "${local.base_cidr}.22.0/24"
  ]
  
  common_tags = {
    Team        = var.team_name
    TeamId      = var.team_id
    Environment = var.environment
    Purpose     = "team-networking"
    ManagedBy   = "StackKit-Enterprise"
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_region" "current" {}

# VPC
resource "aws_vpc" "team_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = merge(local.common_tags, {
    Name = "stackkit-team-${var.team_name}-vpc"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "team_igw" {
  vpc_id = aws_vpc.team_vpc.id
  
  tags = merge(local.common_tags, {
    Name = "stackkit-team-${var.team_name}-igw"
  })
}

# Public Subnets
resource "aws_subnet" "public" {
  count = length(local.public_subnets)
  
  vpc_id                  = aws_vpc.team_vpc.id
  cidr_block              = local.public_subnets[count.index]
  availability_zone       = local.availability_zones[count.index]
  map_public_ip_on_launch = true
  
  tags = merge(local.common_tags, {
    Name = "stackkit-team-${var.team_name}-public-${count.index + 1}"
    Type = "Public"
    Tier = "public"
  })
}

# Private Subnets
resource "aws_subnet" "private" {
  count = length(local.private_subnets)
  
  vpc_id            = aws_vpc.team_vpc.id
  cidr_block        = local.private_subnets[count.index]
  availability_zone = local.availability_zones[count.index]
  
  tags = merge(local.common_tags, {
    Name = "stackkit-team-${var.team_name}-private-${count.index + 1}"
    Type = "Private"
    Tier = "private"
  })
}

# Database Subnets
resource "aws_subnet" "database" {
  count = length(local.database_subnets)
  
  vpc_id            = aws_vpc.team_vpc.id
  cidr_block        = local.database_subnets[count.index]
  availability_zone = local.availability_zones[count.index]
  
  tags = merge(local.common_tags, {
    Name = "stackkit-team-${var.team_name}-db-${count.index + 1}"
    Type = "Database"
    Tier = "database"
  })
}

# NAT Gateways (one per AZ for HA)
resource "aws_eip" "nat" {
  count = length(local.private_subnets)
  
  domain = "vpc"
  
  tags = merge(local.common_tags, {
    Name = "stackkit-team-${var.team_name}-nat-eip-${count.index + 1}"
  })
  
  depends_on = [aws_internet_gateway.team_igw]
}

resource "aws_nat_gateway" "team_nat" {
  count = length(local.private_subnets)
  
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  
  tags = merge(local.common_tags, {
    Name = "stackkit-team-${var.team_name}-nat-${count.index + 1}"
  })
  
  depends_on = [aws_internet_gateway.team_igw]
}

# Route Tables - Public
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.team_vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.team_igw.id
  }
  
  tags = merge(local.common_tags, {
    Name = "stackkit-team-${var.team_name}-public-rt"
    Type = "Public"
  })
}

# Route Table Associations - Public
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)
  
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route Tables - Private (one per NAT Gateway for HA)
resource "aws_route_table" "private" {
  count = length(aws_subnet.private)
  
  vpc_id = aws_vpc.team_vpc.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.team_nat[count.index].id
  }
  
  tags = merge(local.common_tags, {
    Name = "stackkit-team-${var.team_name}-private-rt-${count.index + 1}"
    Type = "Private"
  })
}

# Route Table Associations - Private  
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)
  
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Route Table - Database
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.team_vpc.id
  
  tags = merge(local.common_tags, {
    Name = "stackkit-team-${var.team_name}-db-rt"
    Type = "Database"
  })
}

# Route Table Associations - Database
resource "aws_route_table_association" "database" {
  count = length(aws_subnet.database)
  
  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database.id
}

# VPC Endpoints for AWS services (cost optimization)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.team_vpc.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  
  route_table_ids = concat(
    [aws_route_table.public.id],
    aws_route_table.private[*].id,
    [aws_route_table.database.id]
  )
  
  tags = merge(local.common_tags, {
    Name = "stackkit-team-${var.team_name}-s3-endpoint"
  })
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.team_vpc.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.dynamodb"
  vpc_endpoint_type = "Gateway"
  
  route_table_ids = concat(
    [aws_route_table.public.id],
    aws_route_table.private[*].id,
    [aws_route_table.database.id]
  )
  
  tags = merge(local.common_tags, {
    Name = "stackkit-team-${var.team_name}-dynamodb-endpoint"
  })
}

# Security Groups

# Default security group for team resources
resource "aws_security_group" "team_default" {
  name_prefix = "stackkit-team-${var.team_name}-default"
  vpc_id      = aws_vpc.team_vpc.id
  description = "Default security group for team ${var.team_name}"
  
  # Allow all inbound from same VPC
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "udp"
    cidr_blocks = [var.vpc_cidr]
  }
  
  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(local.common_tags, {
    Name = "stackkit-team-${var.team_name}-default-sg"
  })
}

# ALB security group for team services
resource "aws_security_group" "alb" {
  name_prefix = "stackkit-team-${var.team_name}-alb"
  vpc_id      = aws_vpc.team_vpc.id
  description = "Security group for team ${var.team_name} ALB"
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(local.common_tags, {
    Name = "stackkit-team-${var.team_name}-alb-sg"
  })
}

# Cross-team access (optional)
resource "aws_security_group" "cross_team" {
  count = var.enable_cross_team_access ? 1 : 0
  
  name_prefix = "stackkit-team-${var.team_name}-cross-team"
  vpc_id      = aws_vpc.team_vpc.id
  description = "Security group for cross-team access for team ${var.team_name}"
  
  # Allow inbound from other team VPCs (10.0.0.0/8)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "HTTPS from other teams"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(local.common_tags, {
    Name = "stackkit-team-${var.team_name}-cross-team-sg"
  })
}

# Network ACLs (additional security layer)
resource "aws_network_acl" "team_nacl" {
  vpc_id = aws_vpc.team_vpc.id
  
  # Allow all traffic within VPC
  ingress {
    rule_no    = 100
    protocol   = "-1"
    from_port  = 0
    to_port    = 0
    cidr_block = var.vpc_cidr
    action     = "allow"
  }
  
  # Allow return traffic
  ingress {
    rule_no    = 200
    protocol   = "tcp"
    from_port  = 1024
    to_port    = 65535
    cidr_block = "0.0.0.0/0"
    action     = "allow"
  }
  
  # Allow HTTP/HTTPS inbound
  ingress {
    rule_no    = 300
    protocol   = "tcp"
    from_port  = 80
    to_port    = 80
    cidr_block = "0.0.0.0/0"
    action     = "allow"
  }
  
  ingress {
    rule_no    = 301
    protocol   = "tcp"
    from_port  = 443
    to_port    = 443
    cidr_block = "0.0.0.0/0"
    action     = "allow"
  }
  
  # Allow all outbound
  egress {
    rule_no    = 100
    protocol   = "-1"
    from_port  = 0
    to_port    = 0
    cidr_block = "0.0.0.0/0"
    action     = "allow"
  }
  
  tags = merge(local.common_tags, {
    Name = "stackkit-team-${var.team_name}-nacl"
  })
}

# VPC Flow Logs for security monitoring
resource "aws_flow_log" "team_vpc_flow_log" {
  iam_role_arn    = aws_iam_role.flow_log.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_log.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.team_vpc.id
  
  tags = merge(local.common_tags, {
    Name = "stackkit-team-${var.team_name}-flow-log"
  })
}

resource "aws_cloudwatch_log_group" "vpc_flow_log" {
  name              = "/stackkit/team/${var.team_name}/vpc-flow-logs"
  retention_in_days = 30
  
  tags = local.common_tags
}

resource "aws_iam_role" "flow_log" {
  name = "stackkit-team-${var.team_name}-flow-log-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })
  
  tags = local.common_tags
}

resource "aws_iam_role_policy" "flow_log" {
  name = "stackkit-team-${var.team_name}-flow-log-policy"
  role = aws_iam_role.flow_log.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}