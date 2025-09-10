# VPC Module Variables - StackKit Infrastructure
# Standardized variable definitions for comprehensive VPC configuration

# ==============================================================================
# REQUIRED VARIABLES
# ==============================================================================

variable "project_name" {
  description = "프로젝트 이름 (리소스 이름에 사용됨)"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name)) && length(var.project_name) <= 20
    error_message = "프로젝트 이름은 소문자, 숫자, 하이픈만 포함하고 20자 이하여야 합니다."
  }
}

variable "environment" {
  description = "환경 구분 (dev, staging, prod)"
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
    error_message = "올바른 CIDR 블록 형식을 입력해주세요."
  }
}

# ==============================================================================
# VPC CORE CONFIGURATION
# ==============================================================================

variable "instance_tenancy" {
  description = "VPC 인스턴스 테넌시"
  type        = string
  default     = "default"
  
  validation {
    condition     = contains(["default", "dedicated"], var.instance_tenancy)
    error_message = "인스턴스 테넌시는 'default' 또는 'dedicated'여야 합니다."
  }
}

variable "enable_dns_hostnames" {
  description = "VPC DNS 호스트네임 활성화"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "VPC DNS 지원 활성화"
  type        = bool
  default     = true
}

variable "enable_ipv6" {
  description = "IPv6 CIDR 블록 할당 활성화"
  type        = bool
  default     = false
}

variable "max_availability_zones" {
  description = "사용할 최대 가용성 영역 수"
  type        = number
  default     = 3
  
  validation {
    condition     = var.max_availability_zones >= 2 && var.max_availability_zones <= 6
    error_message = "가용성 영역 수는 2개 이상 6개 이하여야 합니다."
  }
}

# ==============================================================================
# DHCP OPTIONS
# ==============================================================================

variable "create_vpc_dhcp_options" {
  description = "VPC DHCP 옵션 생성 여부"
  type        = bool
  default     = false
}

variable "dhcp_options_domain_name" {
  description = "DHCP 옵션 도메인 이름"
  type        = string
  default     = null
}

variable "dhcp_options_domain_name_servers" {
  description = "DHCP 옵션 DNS 서버"
  type        = list(string)
  default     = ["AmazonProvidedDNS"]
}

variable "dhcp_options_ntp_servers" {
  description = "DHCP 옵션 NTP 서버"
  type        = list(string)
  default     = []
}

variable "dhcp_options_netbios_name_servers" {
  description = "DHCP 옵션 NetBIOS 네임 서버"
  type        = list(string)
  default     = []
}

variable "dhcp_options_netbios_node_type" {
  description = "DHCP 옵션 NetBIOS 노드 타입"
  type        = number
  default     = null
}

# ==============================================================================
# INTERNET GATEWAY
# ==============================================================================

variable "create_igw" {
  description = "인터넷 게이트웨이 생성 여부"
  type        = bool
  default     = true
}

# ==============================================================================
# SUBNET CONFIGURATION
# ==============================================================================

# Public Subnets
variable "create_public_subnets" {
  description = "퍼블릭 서브넷 생성 여부"
  type        = bool
  default     = true
}

variable "public_subnet_cidrs" {
  description = "퍼블릭 서브넷 CIDR 목록"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "map_public_ip_on_launch" {
  description = "퍼블릭 서브넷에서 자동 퍼블릭 IP 할당"
  type        = bool
  default     = true
}

variable "public_subnet_assign_ipv6_address_on_creation" {
  description = "퍼블릭 서브넷에서 IPv6 주소 자동 할당"
  type        = bool
  default     = false
}

variable "public_subnet_tags" {
  description = "퍼블릭 서브넷 추가 태그"
  type        = map(string)
  default     = {}
}

# Private Subnets
variable "create_private_subnets" {
  description = "프라이빗 서브넷 생성 여부"
  type        = bool
  default     = true
}

variable "private_subnet_cidrs" {
  description = "프라이빗 서브넷 CIDR 목록"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
}

variable "private_subnet_assign_ipv6_address_on_creation" {
  description = "프라이빗 서브넷에서 IPv6 주소 자동 할당"
  type        = bool
  default     = false
}

variable "private_subnet_tags" {
  description = "프라이빗 서브넷 추가 태그"
  type        = map(string)
  default     = {}
}

# Database Subnets
variable "create_database_subnets" {
  description = "데이터베이스 서브넷 생성 여부"
  type        = bool
  default     = false
}

variable "database_subnet_cidrs" {
  description = "데이터베이스 서브넷 CIDR 목록"
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24", "10.0.22.0/24"]
}

variable "database_subnet_tags" {
  description = "데이터베이스 서브넷 추가 태그"
  type        = map(string)
  default     = {}
}

variable "create_database_subnet_group" {
  description = "RDS 데이터베이스 서브넷 그룹 생성 여부"
  type        = bool
  default     = false
}

variable "create_elasticache_subnet_group" {
  description = "ElastiCache 서브넷 그룹 생성 여부"
  type        = bool
  default     = false
}

variable "ignore_subnet_changes" {
  description = "서브넷 가용성 영역 변경 무시 (기존 리소스 보호)"
  type        = bool
  default     = true
}

# ==============================================================================
# NAT GATEWAY CONFIGURATION
# ==============================================================================

variable "enable_nat_gateway" {
  description = "NAT 게이트웨이 활성화"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "단일 NAT 게이트웨이 사용 (비용 절감)"
  type        = bool
  default     = false
}

# ==============================================================================
# ROUTE TABLE CONFIGURATION
# ==============================================================================

variable "public_route_table_tags" {
  description = "퍼블릭 라우트 테이블 추가 태그"
  type        = map(string)
  default     = {}
}

variable "private_route_table_tags" {
  description = "프라이빗 라우트 테이블 추가 태그"
  type        = map(string)
  default     = {}
}

variable "create_database_route_table" {
  description = "데이터베이스 전용 라우트 테이블 생성"
  type        = bool
  default     = false
}

variable "database_route_table_tags" {
  description = "데이터베이스 라우트 테이블 추가 태그"
  type        = map(string)
  default     = {}
}

# ==============================================================================
# NETWORK ACL CONFIGURATION
# ==============================================================================

variable "create_public_network_acl" {
  description = "퍼블릭 네트워크 ACL 생성"
  type        = bool
  default     = false
}

variable "create_private_network_acl" {
  description = "프라이빗 네트워크 ACL 생성"
  type        = bool
  default     = false
}

variable "create_database_network_acl" {
  description = "데이터베이스 네트워크 ACL 생성"
  type        = bool
  default     = false
}

# ==============================================================================
# VPC FLOW LOGS
# ==============================================================================

variable "enable_flow_logs" {
  description = "VPC Flow Logs 활성화"
  type        = bool
  default     = false
}

variable "flow_logs_destination_type" {
  description = "Flow Logs 대상 타입"
  type        = string
  default     = "cloud-watch-logs"
  
  validation {
    condition     = contains(["cloud-watch-logs", "s3"], var.flow_logs_destination_type)
    error_message = "Flow Logs 대상은 'cloud-watch-logs' 또는 's3'여야 합니다."
  }
}

variable "flow_logs_traffic_type" {
  description = "Flow Logs 트래픽 타입"
  type        = string
  default     = "ALL"
  
  validation {
    condition     = contains(["ACCEPT", "REJECT", "ALL"], var.flow_logs_traffic_type)
    error_message = "트래픽 타입은 'ACCEPT', 'REJECT', 'ALL' 중 하나여야 합니다."
  }
}

variable "flow_logs_log_retention" {
  description = "Flow Logs CloudWatch 로그 보존 기간 (일)"
  type        = number
  default     = 7
  
  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.flow_logs_log_retention)
    error_message = "유효한 로그 보존 기간을 선택해주세요."
  }
}

variable "flow_logs_s3_arn" {
  description = "Flow Logs S3 버킷 ARN (S3 대상 사용 시)"
  type        = string
  default     = null
}

variable "flow_logs_max_aggregation_interval" {
  description = "Flow Logs 최대 집계 간격 (초)"
  type        = number
  default     = 600
  
  validation {
    condition     = contains([60, 600], var.flow_logs_max_aggregation_interval)
    error_message = "집계 간격은 60초 또는 600초여야 합니다."
  }
}

variable "flow_logs_kms_key_id" {
  description = "Flow Logs CloudWatch 암호화용 KMS 키 ID"
  type        = string
  default     = null
}

variable "flow_logs_file_format" {
  description = "S3 Flow Logs 파일 형식"
  type        = string
  default     = null
  
  validation {
    condition = var.flow_logs_file_format == null || contains(["plain-text", "parquet"], var.flow_logs_file_format)
    error_message = "파일 형식은 'plain-text' 또는 'parquet'여야 합니다."
  }
}

variable "flow_logs_hive_compatible_partitions" {
  description = "S3 Flow Logs Hive 호환 파티션 사용"
  type        = bool
  default     = false
}

variable "flow_logs_per_hour_partition" {
  description = "S3 Flow Logs 시간별 파티션 사용"
  type        = bool
  default     = false
}

# ==============================================================================
# SECURITY GROUP CONFIGURATION
# ==============================================================================

variable "manage_default_security_group" {
  description = "기본 보안 그룹 관리 여부"
  type        = bool
  default     = false
}

variable "default_security_group_ingress" {
  description = "기본 보안 그룹 인바운드 규칙"
  type        = list(map(string))
  default     = []
}

variable "default_security_group_egress" {
  description = "기본 보안 그룹 아웃바운드 규칙"
  type        = list(map(string))
  default     = []
}

# ==============================================================================
# VPC ENDPOINTS
# ==============================================================================

variable "enable_s3_endpoint" {
  description = "S3 VPC 엔드포인트 생성"
  type        = bool
  default     = false
}

variable "enable_dynamodb_endpoint" {
  description = "DynamoDB VPC 엔드포인트 생성"
  type        = bool
  default     = false
}

# ==============================================================================
# KUBERNETES INTEGRATION
# ==============================================================================

variable "enable_kubernetes_tags" {
  description = "Kubernetes 클러스터용 태그 추가"
  type        = bool
  default     = false
}

variable "kubernetes_cluster_name" {
  description = "Kubernetes 클러스터 이름 (태그용)"
  type        = string
  default     = null
}

# ==============================================================================
# LIFECYCLE MANAGEMENT
# ==============================================================================

variable "prevent_destroy" {
  description = "VPC 삭제 방지 (프로덕션 환경 권장)"
  type        = bool
  default     = false
}

# ==============================================================================
# TAGGING
# ==============================================================================

variable "common_tags" {
  description = "모든 VPC 리소스에 적용할 공통 태그"
  type        = map(string)
  default     = {}
}

variable "vpc_tags" {
  description = "VPC에만 적용할 추가 태그"
  type        = map(string)
  default     = {}
}