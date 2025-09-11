output "db_instance_id" {
  description = "RDS 인스턴스 ID"
  value       = aws_db_instance.main.id
}

output "db_instance_arn" {
  description = "RDS 인스턴스 ARN"
  value       = aws_db_instance.main.arn
}

output "db_instance_endpoint" {
  description = "RDS 인스턴스 엔드포인트"
  value       = aws_db_instance.main.endpoint
}

output "db_instance_address" {
  description = "RDS 인스턴스 주소"
  value       = aws_db_instance.main.address
}

output "db_instance_port" {
  description = "RDS 인스턴스 포트"
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "데이터베이스 이름"
  value       = aws_db_instance.main.db_name
}

output "db_username" {
  description = "마스터 사용자 이름"
  value       = aws_db_instance.main.username
  sensitive   = true
}

output "db_subnet_group_id" {
  description = "DB 서브넷 그룹 ID"
  value       = aws_db_subnet_group.main.id
}

output "db_subnet_group_arn" {
  description = "DB 서브넷 그룹 ARN"
  value       = aws_db_subnet_group.main.arn
}

output "db_parameter_group_id" {
  description = "DB Parameter Group ID"
  value       = var.create_parameter_group ? aws_db_parameter_group.main[0].id : null
}

output "security_group_id" {
  description = "RDS Security Group ID"
  value       = aws_security_group.rds.id
}

output "security_group_arn" {
  description = "RDS Security Group ARN"
  value       = aws_security_group.rds.arn
}

output "read_replica_id" {
  description = "읽기 전용 복제본 ID"
  value       = var.create_read_replica ? aws_db_instance.read_replica[0].id : null
}

output "read_replica_endpoint" {
  description = "읽기 전용 복제본 엔드포인트"
  value       = var.create_read_replica ? aws_db_instance.read_replica[0].endpoint : null
}

output "monitoring_role_arn" {
  description = "RDS 모니터링 역할 ARN"
  value       = var.monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null
}