# =======================================
# Networking Infrastructure - StackKit Standard
# =======================================
# VPC, subnets, internet gateway, NAT gateway, and routing
# Supports both existing VPC reuse and new VPC creation

# =======================================
# Data Sources for Existing Infrastructure
# =======================================

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

# =======================================
# VPC - Conditional Creation
# =======================================

resource "aws_vpc" "main" {
  count = var.use_existing_vpc ? 0 : 1

  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
    Type = "VPC"
  })
}

# =======================================
# Internet Gateway
# =======================================

resource "aws_internet_gateway" "main" {
  count = var.use_existing_vpc ? 0 : 1

  vpc_id = aws_vpc.main[0].id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
    Type = "InternetGateway"
  })

  depends_on = [aws_vpc.main]
}

# =======================================
# Public Subnets - Multi-AZ
# =======================================

resource "aws_subnet" "public" {
  count = var.use_existing_vpc ? 0 : length(local.availability_zones)

  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = local.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-${count.index + 1}"
    Type = "PublicSubnet"
    AZ   = local.availability_zones[count.index]
  })

  depends_on = [aws_vpc.main]
}

# =======================================
# Private Subnets - Multi-AZ
# =======================================

resource "aws_subnet" "private" {
  count = var.use_existing_vpc ? 0 : length(local.availability_zones)

  vpc_id            = aws_vpc.main[0].id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = local.availability_zones[count.index]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-${count.index + 1}"
    Type = "PrivateSubnet"
    AZ   = local.availability_zones[count.index]
  })

  depends_on = [aws_vpc.main]
}

# =======================================
# Elastic IPs for NAT Gateways
# =======================================

resource "aws_eip" "nat" {
  count = var.use_existing_vpc ? 0 : (var.enable_nat_gateway ? length(local.availability_zones) : 0)

  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-eip-${count.index + 1}"
    Type = "NatGatewayEIP"
    AZ   = local.availability_zones[count.index]
  })

  depends_on = [aws_internet_gateway.main]
}

# =======================================
# NAT Gateways - Multi-AZ for High Availability
# =======================================

resource "aws_nat_gateway" "main" {
  count = var.use_existing_vpc ? 0 : (var.enable_nat_gateway ? length(local.availability_zones) : 0)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-gw-${count.index + 1}"
    Type = "NatGateway"
    AZ   = local.availability_zones[count.index]
  })

  depends_on = [
    aws_internet_gateway.main,
    aws_eip.nat
  ]
}

# =======================================
# Route Tables
# =======================================

# Public Route Table (shared across all public subnets)
resource "aws_route_table" "public" {
  count = var.use_existing_vpc ? 0 : 1

  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-rt"
    Type = "PublicRouteTable"
  })

  depends_on = [aws_internet_gateway.main]
}

# Private Route Tables (one per AZ for NAT Gateway routing)
resource "aws_route_table" "private" {
  count = var.use_existing_vpc ? 0 : length(local.availability_zones)

  vpc_id = aws_vpc.main[0].id

  # Conditional route to NAT Gateway
  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.main[count.index].id
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-rt-${count.index + 1}"
    Type = "PrivateRouteTable"
    AZ   = local.availability_zones[count.index]
  })

  depends_on = [aws_nat_gateway.main]
}

# =======================================
# Route Table Associations
# =======================================

# Public Subnet Associations
resource "aws_route_table_association" "public" {
  count = var.use_existing_vpc ? 0 : length(local.availability_zones)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id

  depends_on = [
    aws_subnet.public,
    aws_route_table.public
  ]
}

# Private Subnet Associations
resource "aws_route_table_association" "private" {
  count = var.use_existing_vpc ? 0 : length(local.availability_zones)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id

  depends_on = [
    aws_subnet.private,
    aws_route_table.private
  ]
}