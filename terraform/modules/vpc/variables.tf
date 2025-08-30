variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "environment" {
  description = "환경 (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "환경은 dev, staging, prod 중 하나여야 합니다."
  }
}

variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string
  default     = "10.0.0.0/16"
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "유효한 CIDR 블록을 입력해주세요."
  }
}

variable "public_subnet_cidrs" {
  description = "퍼블릭 서브넷 CIDR 블록 리스트"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
  validation {
    condition = length(var.public_subnet_cidrs) >= 1 && length(var.public_subnet_cidrs) <= 6
    error_message = "퍼블릭 서브넷은 1개 이상 6개 이하로 설정해주세요."
  }
}

variable "private_subnet_cidrs" {
  description = "프라이빗 서브넷 CIDR 블록 리스트"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
  validation {
    condition = length(var.private_subnet_cidrs) >= 1 && length(var.private_subnet_cidrs) <= 6
    error_message = "프라이빗 서브넷은 1개 이상 6개 이하로 설정해주세요."
  }
}

variable "enable_nat_gateway" {
  description = "NAT Gateway 활성화 여부"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "모든 리소스에 적용할 공통 태그"
  type        = map(string)
  default     = {}
}