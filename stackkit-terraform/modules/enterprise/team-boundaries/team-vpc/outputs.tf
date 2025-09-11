# Team VPC Module Outputs

output "vpc_id" {
  description = "ID of the team VPC"
  value       = aws_vpc.team_vpc.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the team VPC"
  value       = aws_vpc.team_vpc.cidr_block
}

output "public_subnet_ids" {
  description = "List of IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  description = "List of IDs of the database subnets"
  value       = aws_subnet.database[*].id
}

output "public_subnet_cidrs" {
  description = "List of CIDR blocks of the public subnets"
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_cidrs" {
  description = "List of CIDR blocks of the private subnets"
  value       = aws_subnet.private[*].cidr_block
}

output "database_subnet_cidrs" {
  description = "List of CIDR blocks of the database subnets"
  value       = aws_subnet.database[*].cidr_block
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.team_igw.id
}

output "nat_gateway_ids" {
  description = "List of IDs of the NAT Gateways"
  value       = aws_nat_gateway.team_nat[*].id
}

output "nat_gateway_ips" {
  description = "List of public IPs of the NAT Gateways"
  value       = aws_eip.nat[*].public_ip
}

output "default_security_group_id" {
  description = "ID of the default security group for team resources"
  value       = aws_security_group.team_default.id
}

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "cross_team_security_group_id" {
  description = "ID of the cross-team security group (if enabled)"
  value       = var.enable_cross_team_access ? aws_security_group.cross_team[0].id : null
}

output "route_table_ids" {
  description = "Map of route table IDs by type"
  value = {
    public   = aws_route_table.public.id
    private  = aws_route_table.private[*].id
    database = aws_route_table.database.id
  }
}

output "vpc_endpoint_ids" {
  description = "Map of VPC endpoint IDs"
  value = {
    s3       = aws_vpc_endpoint.s3.id
    dynamodb = aws_vpc_endpoint.dynamodb.id
  }
}

output "availability_zones" {
  description = "List of availability zones used by the team VPC"
  value       = data.aws_availability_zones.available.names
}

output "flow_log_id" {
  description = "ID of the VPC flow log"
  value       = aws_flow_log.team_vpc_flow_log.id
}

output "flow_log_group_name" {
  description = "Name of the CloudWatch log group for VPC flow logs"
  value       = aws_cloudwatch_log_group.vpc_flow_log.name
}

output "network_info" {
  description = "Complete network information for the team"
  value = {
    team_name    = var.team_name
    team_id      = var.team_id
    vpc_id       = aws_vpc.team_vpc.id
    vpc_cidr     = aws_vpc.team_vpc.cidr_block
    environment  = var.environment
    
    subnets = {
      public = {
        ids   = aws_subnet.public[*].id
        cidrs = aws_subnet.public[*].cidr_block
        azs   = aws_subnet.public[*].availability_zone
      }
      private = {
        ids   = aws_subnet.private[*].id
        cidrs = aws_subnet.private[*].cidr_block
        azs   = aws_subnet.private[*].availability_zone
      }
      database = {
        ids   = aws_subnet.database[*].id
        cidrs = aws_subnet.database[*].cidr_block
        azs   = aws_subnet.database[*].availability_zone
      }
    }
    
    security_groups = {
      default    = aws_security_group.team_default.id
      alb        = aws_security_group.alb.id
      cross_team = var.enable_cross_team_access ? aws_security_group.cross_team[0].id : null
    }
    
    nat_gateways = {
      ids = aws_nat_gateway.team_nat[*].id
      ips = aws_eip.nat[*].public_ip
    }
  }
}