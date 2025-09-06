# 🚀 Atlantis ECS - 기존 인프라 활용 변수
# 기존 VPC, 서브넷, S3, DynamoDB 활용 가능

# =======================================
# 필수 기본 변수
# =======================================

variable "org_name" {
  description = "조직/회사 이름"
  type        = string
}

variable "environment" {
  description = "배포 환경"
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "stack_name" {
  description = "스택 이름"
  type        = string
}

variable "secret_name" {
  description = "Secrets Manager 시크릿 이름"
  type        = string
}

# =======================================
# 기존 인프라 사용 옵션
# =======================================

variable "use_existing_vpc" {
  description = "기존 VPC 사용 여부"
  type        = bool
  default     = false
}

variable "existing_vpc_id" {
  description = "기존 VPC ID"
  type        = string
  default     = ""
}

variable "existing_public_subnet_ids" {
  description = "기존 퍼블릭 서브넷 ID 목록"
  type        = list(string)
  default     = []
}

variable "existing_private_subnet_ids" {
  description = "기존 프라이빗 서브넷 ID 목록"
  type        = list(string)
  default     = []
}

variable "existing_state_bucket" {
  description = "기존 Terraform 상태 S3 버킷"
  type        = string
  default     = ""
}

variable "existing_lock_table" {
  description = "기존 Terraform 락 DynamoDB 테이블"
  type        = string
  default     = ""
}

# =======================================
# 도메인 & SSL 설정 (선택사항)
# =======================================

variable "custom_domain" {
  description = "커스텀 도메인 (없으면 ALB DNS 사용)"
  type        = string
  default     = ""
}

variable "certificate_arn" {
  description = "SSL 인증서 ARN (HTTPS용)"
  type        = string
  default     = ""
}

# =======================================
# GitHub 설정
# =======================================

variable "git_username" {
  description = "GitHub 사용자명"
  type        = string
}

variable "repo_allowlist" {
  description = "허용된 저장소 패턴 목록"
  type        = list(string)
}

# =======================================
# 기능 토글 (선택사항)
# =======================================

variable "enable_infracost" {
  description = "Infracost 비용 분석 활성화"
  type        = bool
  default     = false
}

