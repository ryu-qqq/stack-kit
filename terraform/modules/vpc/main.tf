# VPC Module for StackKit Infrastructure
# Standardized VPC module with comprehensive features, monitoring, and security

# ==============================================================================
# DATA SOURCES
# ==============================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ==============================================================================
# LOCALS
# ==============================================================================

locals {
  # Standard naming convention
  name_prefix = "${var.project_name}-${var.environment}"
  
  # Availability zones management
  max_azs = min(length(data.aws_availability_zones.available.names), var.max_availability_zones)
  
  # Subnet calculations
  public_subnet_count  = var.create_public_subnets ? min(length(var.public_subnet_cidrs), local.max_azs) : 0
  private_subnet_count = var.create_private_subnets ? min(length(var.private_subnet_cidrs), local.max_azs) : 0
  database_subnet_count = var.create_database_subnets ? min(length(var.database_subnet_cidrs), local.max_azs) : 0
  
  # NAT Gateway strategy
  nat_gateway_count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : local.public_subnet_count) : 0
  
  # Enhanced tags
  vpc_tags = merge(var.common_tags, var.vpc_tags, {
    Name         = "${local.name_prefix}-vpc"
    Component    = "Networking"
    Tier         = "Infrastructure"
    Environment  = var.environment
    Project      = var.project_name
  })
}

# ==============================================================================
# VPC CORE RESOURCES
# ==============================================================================

# Primary VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  instance_tenancy     = var.instance_tenancy
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support
  
  # IPv6 support
  assign_generated_ipv6_cidr_block = var.enable_ipv6
  
  tags = local.vpc_tags
  
  lifecycle {
    prevent_destroy = var.prevent_destroy
  }
}

# VPC DHCP Options
resource "aws_vpc_dhcp_options" "main" {
  count = var.create_vpc_dhcp_options ? 1 : 0
  
  domain_name          = var.dhcp_options_domain_name != null ? var.dhcp_options_domain_name : "${data.aws_region.current.name}.compute.internal"
  domain_name_servers  = var.dhcp_options_domain_name_servers
  ntp_servers          = var.dhcp_options_ntp_servers
  netbios_name_servers = var.dhcp_options_netbios_name_servers
  netbios_node_type    = var.dhcp_options_netbios_node_type
  
  tags = merge(local.vpc_tags, {
    Name = "${local.name_prefix}-dhcp-options"
  })
}

resource "aws_vpc_dhcp_options_association" "main" {
  count = var.create_vpc_dhcp_options ? 1 : 0
  
  vpc_id          = aws_vpc.main.id
  dhcp_options_id = aws_vpc_dhcp_options.main[0].id
}

# ==============================================================================
# INTERNET GATEWAY
# ==============================================================================

resource "aws_internet_gateway" "main" {
  count = var.create_igw ? 1 : 0
  
  vpc_id = aws_vpc.main.id
  
  tags = merge(local.vpc_tags, {
    Name = "${local.name_prefix}-igw"
  })
  
  depends_on = [aws_vpc.main]
}

# ==============================================================================
# SUBNETS
# ==============================================================================

# Public Subnets
resource "aws_subnet" "public" {
  count = local.public_subnet_count
  
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = var.map_public_ip_on_launch
  
  # IPv6 support
  ipv6_cidr_block                 = var.enable_ipv6 ? cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, count.index) : null
  assign_ipv6_address_on_creation = var.enable_ipv6 ? var.public_subnet_assign_ipv6_address_on_creation : false
  
  tags = merge(local.vpc_tags, var.public_subnet_tags, {
    Name = "${local.name_prefix}-public-subnet-${count.index + 1}"
    Type = "Public"
    Tier = "Public"
    "kubernetes.io/role/elb" = var.enable_kubernetes_tags ? "1" : null
  })
  
  lifecycle {
    ignore_changes = var.ignore_subnet_changes ? [availability_zone] : []
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count = local.private_subnet_count
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  # IPv6 support
  ipv6_cidr_block                 = var.enable_ipv6 ? cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, count.index + local.public_subnet_count) : null
  assign_ipv6_address_on_creation = var.enable_ipv6 ? var.private_subnet_assign_ipv6_address_on_creation : false
  
  tags = merge(local.vpc_tags, var.private_subnet_tags, {
    Name = "${local.name_prefix}-private-subnet-${count.index + 1}"
    Type = "Private"
    Tier = "Private"
    "kubernetes.io/role/internal-elb" = var.enable_kubernetes_tags ? "1" : null
  })
  
  lifecycle {
    ignore_changes = var.ignore_subnet_changes ? [availability_zone] : []
  }
}

# Database Subnets
resource "aws_subnet" "database" {
  count = local.database_subnet_count
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.database_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  tags = merge(local.vpc_tags, var.database_subnet_tags, {
    Name = "${local.name_prefix}-database-subnet-${count.index + 1}"
    Type = "Database"
    Tier = "Data"
  })
  
  lifecycle {
    ignore_changes = var.ignore_subnet_changes ? [availability_zone] : []
  }
}

# Database Subnet Group
resource "aws_db_subnet_group" "database" {
  count = var.create_database_subnet_group && local.database_subnet_count > 0 ? 1 : 0
  
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = aws_subnet.database[*].id
  
  tags = merge(local.vpc_tags, {
    Name = "${local.name_prefix}-db-subnet-group"
  })
}

# ElastiCache Subnet Group
resource "aws_elasticache_subnet_group" "elasticache" {
  count = var.create_elasticache_subnet_group && local.private_subnet_count > 0 ? 1 : 0
  
  name       = "${local.name_prefix}-cache-subnet-group"
  subnet_ids = aws_subnet.private[*].id
  
  tags = merge(local.vpc_tags, {
    Name = "${local.name_prefix}-cache-subnet-group"
  })
}

# ==============================================================================
# NAT GATEWAYS
# ==============================================================================

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count = local.nat_gateway_count
  
  domain = "vpc"
  
  tags = merge(local.vpc_tags, {
    Name = "${local.name_prefix}-nat-eip-${count.index + 1}"
  })
  
  depends_on = [aws_internet_gateway.main]
}

# NAT Gateways
resource "aws_nat_gateway" "main" {
  count = local.nat_gateway_count
  
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[var.single_nat_gateway ? 0 : count.index].id
  
  tags = merge(local.vpc_tags, {
    Name = "${local.name_prefix}-nat-gateway-${count.index + 1}"
  })
  
  depends_on = [aws_internet_gateway.main]
}

# ==============================================================================
# ROUTE TABLES
# ==============================================================================

# Public Route Table
resource "aws_route_table" "public" {
  count = local.public_subnet_count > 0 ? 1 : 0
  
  vpc_id = aws_vpc.main.id
  
  tags = merge(local.vpc_tags, var.public_route_table_tags, {
    Name = "${local.name_prefix}-public-rt"
  })
}

# Private Route Tables
resource "aws_route_table" "private" {
  count = local.private_subnet_count
  
  vpc_id = aws_vpc.main.id
  
  tags = merge(local.vpc_tags, var.private_route_table_tags, {
    Name = "${local.name_prefix}-private-rt-${count.index + 1}"
  })
}

# Database Route Table
resource "aws_route_table" "database" {
  count = local.database_subnet_count > 0 && var.create_database_route_table ? 1 : 0
  
  vpc_id = aws_vpc.main.id
  
  tags = merge(local.vpc_tags, var.database_route_table_tags, {
    Name = "${local.name_prefix}-database-rt"
  })
}

# ==============================================================================
# ROUTES
# ==============================================================================

# Public Routes
resource "aws_route" "public_internet_gateway" {
  count = var.create_igw && local.public_subnet_count > 0 ? 1 : 0
  
  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main[0].id
  
  timeouts {
    create = "5m"
  }
}

# IPv6 Public Routes
resource "aws_route" "public_internet_gateway_ipv6" {
  count = var.create_igw && var.enable_ipv6 && local.public_subnet_count > 0 ? 1 : 0
  
  route_table_id              = aws_route_table.public[0].id
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = aws_internet_gateway.main[0].id
  
  timeouts {
    create = "5m"
  }
}

# Private Routes to NAT Gateway
resource "aws_route" "private_nat_gateway" {
  count = var.enable_nat_gateway ? local.private_subnet_count : 0
  
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[var.single_nat_gateway ? 0 : count.index].id
  
  timeouts {
    create = "5m"
  }
}

# ==============================================================================
# ROUTE TABLE ASSOCIATIONS
# ==============================================================================

# Public Subnet Associations
resource "aws_route_table_association" "public" {
  count = local.public_subnet_count
  
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# Private Subnet Associations
resource "aws_route_table_association" "private" {
  count = local.private_subnet_count
  
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Database Subnet Associations
resource "aws_route_table_association" "database" {
  count = local.database_subnet_count > 0 && var.create_database_route_table ? local.database_subnet_count : 0
  
  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database[0].id
}

# ==============================================================================
# NETWORK ACLS
# ==============================================================================

# Custom Network ACL for Public Subnets
resource "aws_network_acl" "public" {
  count = var.create_public_network_acl && local.public_subnet_count > 0 ? 1 : 0
  
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.public[*].id
  
  tags = merge(local.vpc_tags, {
    Name = "${local.name_prefix}-public-nacl"
  })
}

# Custom Network ACL for Private Subnets
resource "aws_network_acl" "private" {
  count = var.create_private_network_acl && local.private_subnet_count > 0 ? 1 : 0
  
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private[*].id
  
  tags = merge(local.vpc_tags, {
    Name = "${local.name_prefix}-private-nacl"
  })
}

# Custom Network ACL for Database Subnets
resource "aws_network_acl" "database" {
  count = var.create_database_network_acl && local.database_subnet_count > 0 ? 1 : 0
  
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.database[*].id
  
  tags = merge(local.vpc_tags, {
    Name = "${local.name_prefix}-database-nacl"
  })
}

# ==============================================================================
# VPC FLOW LOGS
# ==============================================================================

# CloudWatch Log Group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  count = var.enable_flow_logs && var.flow_logs_destination_type == "cloud-watch-logs" ? 1 : 0
  
  name              = "/aws/vpc/flowlogs/${local.name_prefix}"
  retention_in_days = var.flow_logs_log_retention
  kms_key_id        = var.flow_logs_kms_key_id
  
  tags = merge(local.vpc_tags, {
    Name = "${local.name_prefix}-vpc-flow-logs"
  })
}

# IAM Role for VPC Flow Logs to CloudWatch
resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs && var.flow_logs_destination_type == "cloud-watch-logs" ? 1 : 0
  
  name = "${local.name_prefix}-flow-logs-role"
  
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
  
  tags = local.vpc_tags
}

resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_flow_logs && var.flow_logs_destination_type == "cloud-watch-logs" ? 1 : 0
  
  name = "${local.name_prefix}-flow-logs-policy"
  role = aws_iam_role.flow_logs[0].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

# VPC Flow Logs
resource "aws_flow_log" "vpc" {
  count = var.enable_flow_logs ? 1 : 0
  
  iam_role_arn             = var.flow_logs_destination_type == "cloud-watch-logs" ? aws_iam_role.flow_logs[0].arn : null
  log_destination          = var.flow_logs_destination_type == "cloud-watch-logs" ? aws_cloudwatch_log_group.vpc_flow_logs[0].arn : var.flow_logs_s3_arn
  log_destination_type     = var.flow_logs_destination_type
  traffic_type             = var.flow_logs_traffic_type
  vpc_id                   = aws_vpc.main.id
  max_aggregation_interval = var.flow_logs_max_aggregation_interval
  
  dynamic "destination_options" {
    for_each = var.flow_logs_destination_type == "s3" && var.flow_logs_file_format != null ? [1] : []
    content {
      file_format                = var.flow_logs_file_format
      hive_compatible_partitions = var.flow_logs_hive_compatible_partitions
      per_hour_partition         = var.flow_logs_per_hour_partition
    }
  }
  
  tags = merge(local.vpc_tags, {
    Name = "${local.name_prefix}-vpc-flow-logs"
  })
}

# ==============================================================================
# SECURITY GROUPS
# ==============================================================================

# Default Security Group (updated)
resource "aws_default_security_group" "default" {
  count = var.manage_default_security_group ? 1 : 0
  
  vpc_id = aws_vpc.main.id
  
  # Remove default rules if requested
  dynamic "ingress" {
    for_each = var.default_security_group_ingress
    content {
      description      = ingress.value.description
      from_port        = ingress.value.from_port
      to_port          = ingress.value.to_port
      protocol         = ingress.value.protocol
      cidr_blocks      = lookup(ingress.value, "cidr_blocks", null)
      ipv6_cidr_blocks = lookup(ingress.value, "ipv6_cidr_blocks", null)
      prefix_list_ids  = lookup(ingress.value, "prefix_list_ids", null)
      security_groups  = lookup(ingress.value, "security_groups", null)
      self             = lookup(ingress.value, "self", null)
    }
  }
  
  dynamic "egress" {
    for_each = var.default_security_group_egress
    content {
      description      = egress.value.description
      from_port        = egress.value.from_port
      to_port          = egress.value.to_port
      protocol         = egress.value.protocol
      cidr_blocks      = lookup(egress.value, "cidr_blocks", null)
      ipv6_cidr_blocks = lookup(egress.value, "ipv6_cidr_blocks", null)
      prefix_list_ids  = lookup(egress.value, "prefix_list_ids", null)
      security_groups  = lookup(egress.value, "security_groups", null)
      self             = lookup(egress.value, "self", null)
    }
  }
  
  tags = merge(local.vpc_tags, {
    Name = "${local.name_prefix}-default-sg"
  })
}

# ==============================================================================
# VPC ENDPOINTS
# ==============================================================================

# S3 VPC Endpoint (Gateway)
resource "aws_vpc_endpoint" "s3" {
  count = var.enable_s3_endpoint ? 1 : 0
  
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"
  
  tags = merge(local.vpc_tags, {
    Name = "${local.name_prefix}-s3-endpoint"
  })
}

# S3 VPC Endpoint Route Table Associations
resource "aws_vpc_endpoint_route_table_association" "s3_private" {
  count = var.enable_s3_endpoint ? local.private_subnet_count : 0
  
  vpc_endpoint_id = aws_vpc_endpoint.s3[0].id
  route_table_id  = aws_route_table.private[count.index].id
}

# DynamoDB VPC Endpoint (Gateway)
resource "aws_vpc_endpoint" "dynamodb" {
  count = var.enable_dynamodb_endpoint ? 1 : 0
  
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.dynamodb"
  
  tags = merge(local.vpc_tags, {
    Name = "${local.name_prefix}-dynamodb-endpoint"
  })
}

# DynamoDB VPC Endpoint Route Table Associations
resource "aws_vpc_endpoint_route_table_association" "dynamodb_private" {
  count = var.enable_dynamodb_endpoint ? local.private_subnet_count : 0
  
  vpc_endpoint_id = aws_vpc_endpoint.dynamodb[0].id
  route_table_id  = aws_route_table.private[count.index].id
}