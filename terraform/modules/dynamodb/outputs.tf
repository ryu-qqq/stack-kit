output "table_id" {
  description = "DynamoDB 테이블 ID"
  value       = aws_dynamodb_table.main.id
}

output "table_arn" {
  description = "DynamoDB 테이블 ARN"
  value       = aws_dynamodb_table.main.arn
}

output "table_name" {
  description = "DynamoDB 테이블 이름"
  value       = aws_dynamodb_table.main.name
}

output "table_stream_arn" {
  description = "DynamoDB 스트림 ARN"
  value       = var.stream_enabled ? aws_dynamodb_table.main.stream_arn : null
}

output "table_stream_label" {
  description = "DynamoDB 스트림 레이블"
  value       = var.stream_enabled ? aws_dynamodb_table.main.stream_label : null
}

output "hash_key" {
  description = "해시 키 (파티션 키)"
  value       = var.hash_key
}

output "range_key" {
  description = "레인지 키 (정렬 키)"
  value       = var.range_key
}

output "billing_mode" {
  description = "청구 모드"
  value       = var.billing_mode
}

output "read_capacity" {
  description = "읽기 용량 단위"
  value       = var.billing_mode == "PROVISIONED" ? var.read_capacity : null
}

output "write_capacity" {
  description = "쓰기 용량 단위"
  value       = var.billing_mode == "PROVISIONED" ? var.write_capacity : null
}

output "global_secondary_indexes" {
  description = "글로벌 보조 인덱스 정보"
  value       = aws_dynamodb_table.main.global_secondary_index
}

output "local_secondary_indexes" {
  description = "로컬 보조 인덱스 정보"
  value       = aws_dynamodb_table.main.local_secondary_index
}

output "point_in_time_recovery_enabled" {
  description = "특정 시점 복구 활성화 여부"
  value       = var.point_in_time_recovery_enabled
}

output "server_side_encryption_enabled" {
  description = "서버측 암호화 활성화 여부"
  value       = var.server_side_encryption_enabled
}

output "kms_key_id" {
  description = "KMS 키 ID"
  value       = var.kms_key_id
}

output "ttl_enabled" {
  description = "TTL 활성화 여부"
  value       = var.ttl_enabled
}

output "ttl_attribute_name" {
  description = "TTL 속성 이름"
  value       = var.ttl_enabled ? var.ttl_attribute_name : null
}

output "autoscaling_read_target_arn" {
  description = "Auto Scaling 읽기 대상 ARN"
  value       = var.billing_mode == "PROVISIONED" && var.enable_autoscaling ? aws_appautoscaling_target.read[0].arn : null
}

output "autoscaling_write_target_arn" {
  description = "Auto Scaling 쓰기 대상 ARN"
  value       = var.billing_mode == "PROVISIONED" && var.enable_autoscaling ? aws_appautoscaling_target.write[0].arn : null
}

output "backup_plan_id" {
  description = "백업 계획 ID"
  value       = var.enable_backup ? aws_backup_plan.dynamodb[0].id : null
}

output "backup_plan_arn" {
  description = "백업 계획 ARN"
  value       = var.enable_backup ? aws_backup_plan.dynamodb[0].arn : null
}

output "backup_vault_name" {
  description = "백업 볼트 이름"
  value       = var.enable_backup ? aws_backup_vault.dynamodb[0].name : null
}

output "backup_vault_arn" {
  description = "백업 볼트 ARN"
  value       = var.enable_backup ? aws_backup_vault.dynamodb[0].arn : null
}

output "table_class" {
  description = "테이블 클래스"
  value       = var.table_class
}

output "deletion_protection_enabled" {
  description = "삭제 보호 활성화 여부"
  value       = var.deletion_protection_enabled
}