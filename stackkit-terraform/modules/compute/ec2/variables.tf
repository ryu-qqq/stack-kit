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

variable "instance_name" {
  description = "인스턴스 이름"
  type        = string
}

variable "instance_count" {
  description = "생성할 인스턴스 개수"
  type        = number
  default     = 1
  validation {
    condition     = var.instance_count > 0 && var.instance_count <= 10
    error_message = "인스턴스 개수는 1개 이상 10개 이하로 설정해주세요."
  }
}

variable "instance_type" {
  description = "EC2 인스턴스 타입"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "AMI ID (비워두면 Amazon Linux 2 최신 버전 사용)"
  type        = string
  default     = ""
}

variable "key_name" {
  description = "SSH 키 페어 이름"
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "서브넷 ID 리스트"
  type        = list(string)
  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "최소 1개의 서브넷 ID가 필요합니다."
  }
}

variable "security_group_ids" {
  description = "Security Group ID 리스트"
  type        = list(string)
  default     = []
}

variable "create_security_group" {
  description = "Security Group 생성 여부"
  type        = bool
  default     = true
}

variable "ingress_rules" {
  description = "Security Group Ingress 규칙"
  type = list(object({
    from_port       = number
    to_port         = number
    protocol        = string
    cidr_blocks     = list(string)
    security_groups = list(string)
    description     = string
  }))
  default = [
    {
      from_port       = 22
      to_port         = 22
      protocol        = "tcp"
      cidr_blocks     = ["0.0.0.0/0"] # ALLOW_PUBLIC_EXEMPT - SSH access from anywhere (default example)
      security_groups = []
      description     = "SSH access"
    }
  ]
}

variable "associate_public_ip" {
  description = "Public IP 할당 여부"
  type        = bool
  default     = false
}

variable "create_eip" {
  description = "Elastic IP 생성 여부"
  type        = bool
  default     = false
}

variable "user_data" {
  description = "User data 스크립트"
  type        = string
  default     = null
}

variable "user_data_replace_on_change" {
  description = "User data 변경 시 인스턴스 교체 여부"
  type        = bool
  default     = false
}

variable "root_volume_type" {
  description = "루트 볼륨 타입"
  type        = string
  default     = "gp3"
  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2"], var.root_volume_type)
    error_message = "루트 볼륨 타입은 gp2, gp3, io1, io2 중 하나여야 합니다."
  }
}

variable "root_volume_size" {
  description = "루트 볼륨 크기 (GB)"
  type        = number
  default     = 20
  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 1000
    error_message = "루트 볼륨 크기는 8GB 이상 1000GB 이하로 설정해주세요."
  }
}

variable "additional_ebs_volumes" {
  description = "추가 EBS 볼륨 설정"
  type = list(object({
    device_name = string
    volume_type = string
    volume_size = number
  }))
  default = []
}

variable "enable_encryption" {
  description = "EBS 볼륨 암호화 활성화"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "모든 리소스에 적용할 공통 태그"
  type        = map(string)
  default     = {}
}