output "instance_ids" {
  description = "EC2 인스턴스 ID 리스트"
  value       = aws_instance.main[*].id
}

output "private_ips" {
  description = "프라이빗 IP 주소 리스트"
  value       = aws_instance.main[*].private_ip
}

output "public_ips" {
  description = "퍼블릭 IP 주소 리스트"
  value       = aws_instance.main[*].public_ip
}

output "elastic_ips" {
  description = "Elastic IP 주소 리스트"
  value       = var.create_eip ? aws_eip.main[*].public_ip : []
}

output "instance_arns" {
  description = "EC2 인스턴스 ARN 리스트"
  value       = aws_instance.main[*].arn
}

output "security_group_id" {
  description = "Security Group ID"
  value       = var.create_security_group ? aws_security_group.main[0].id : null
}

output "key_name" {
  description = "SSH 키 페어 이름"
  value       = var.key_name
}

output "availability_zones" {
  description = "인스턴스가 배포된 가용 영역 리스트"
  value       = aws_instance.main[*].availability_zone
}