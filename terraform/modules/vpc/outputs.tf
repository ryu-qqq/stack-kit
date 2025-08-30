output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "VPC CIDR 블록"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "퍼블릭 서브넷 ID 리스트"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "프라이빗 서브넷 ID 리스트"
  value       = aws_subnet.private[*].id
}

output "public_subnet_cidrs" {
  description = "퍼블릭 서브넷 CIDR 블록 리스트"
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_cidrs" {
  description = "프라이빗 서브넷 CIDR 블록 리스트"
  value       = aws_subnet.private[*].cidr_block
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_ids" {
  description = "NAT Gateway ID 리스트"
  value       = aws_nat_gateway.main[*].id
}

output "default_security_group_id" {
  description = "기본 Security Group ID"
  value       = aws_security_group.default.id
}

output "public_route_table_id" {
  description = "퍼블릭 Route Table ID"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "프라이빗 Route Table ID 리스트"
  value       = aws_route_table.private[*].id
}