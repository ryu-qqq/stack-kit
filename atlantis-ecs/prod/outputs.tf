# 🚀 Atlantis ECS - 기존 인프라 활용 출력값

# =======================================
# 접속 정보
# =======================================

output "atlantis_url" {
  description = "Atlantis 웹 UI 접속 URL"
  value = var.certificate_arn != "" && var.custom_domain != "" ? "https://${var.custom_domain}" : (
    var.certificate_arn != "" ? "https://${aws_lb.atlantis.dns_name}" : "http://${aws_lb.atlantis.dns_name}"
  )
}

output "atlantis_load_balancer_dns" {
  description = "ALB DNS 이름 (DNS 설정용)"
  value       = aws_lb.atlantis.dns_name
}

# =======================================
# 웹훅 설정용 정보
# =======================================

output "webhook_endpoint" {
  description = "GitHub 웹훅 엔드포인트 URL"
  value = var.certificate_arn != "" && var.custom_domain != "" ? "https://${var.custom_domain}/events" : (
    var.certificate_arn != "" ? "https://${aws_lb.atlantis.dns_name}/events" : "http://${aws_lb.atlantis.dns_name}/events"
  )
}

output "webhook_secret_name" {
  description = "GitHub 웹훅 시크릿이 저장된 Secrets Manager 이름"
  value       = aws_secretsmanager_secret.atlantis.name
}

# =======================================
# 인프라 정보
# =======================================

output "ecs_cluster_name" {
  description = "ECS 클러스터 이름"
  value       = aws_ecs_cluster.atlantis.name
}

output "vpc_id" {
  description = "사용된 VPC ID"
  value       = local.vpc_id
}

output "public_subnet_ids" {
  description = "사용된 퍼블릭 서브넷 ID 목록"
  value       = local.public_subnet_ids
}

output "private_subnet_ids" {
  description = "사용된 프라이빗 서브넷 ID 목록"
  value       = local.private_subnet_ids
}

output "infrastructure_summary" {
  description = "사용된 인프라 요약"
  value = {
    vpc_type        = var.use_existing_vpc ? "기존 VPC 활용" : "신규 VPC 생성"
    vpc_id          = local.vpc_id
    public_subnets  = length(local.public_subnet_ids)
    private_subnets = length(local.private_subnet_ids)
    s3_bucket       = var.existing_state_bucket != "" ? var.existing_state_bucket : "${var.environment}-atlantis-state-${var.aws_region}"
    dynamodb_table  = var.existing_lock_table != "" ? var.existing_lock_table : "${var.environment}-atlantis-lock"
  }
}

# =======================================
# 배포 사용법 안내
# =======================================


output "usage_examples" {
  description = "사용 예제 및 다음 단계"
  value       = <<-EOT
    🎉 Atlantis ECS 배포 완료!
    
    📋 GitHub 웹훅 설정:
    - URL: ${var.certificate_arn != "" && var.custom_domain != "" ? "https://${var.custom_domain}/events" : (var.certificate_arn != "" ? "https://${aws_lb.atlantis.dns_name}/events" : "http://${aws_lb.atlantis.dns_name}/events")}
    - Secret: AWS Secrets Manager '${aws_secretsmanager_secret.atlantis.name}'
    
    🌐 Atlantis 접속:
    - URL: ${var.certificate_arn != "" && var.custom_domain != "" ? "https://${var.custom_domain}" : (var.certificate_arn != "" ? "https://${aws_lb.atlantis.dns_name}" : "http://${aws_lb.atlantis.dns_name}")}
    
    💡 사용법:
    1. PR에 terraform 변경사항 포함
    2. 'atlantis plan' 댓글로 계획 실행
    3. 'atlantis apply' 댓글로 배포 실행${var.enable_infracost ? "\n    4. PR에서 Infracost 비용 분석 자동 확인" : ""}
    
    🔧 고급 사용법:
    - 'atlantis plan -d dir/' (특정 디렉토리)
    - 'atlantis apply -p planname' (특정 plan 적용)
    - 'atlantis unlock' (수동 잠금 해제)
  EOT
}