# StackKit 변수명 표준

## 기본 원칙

1. **snake_case** 사용 (Terraform 표준)
2. **prefix 기반 그룹핑** (service_name 형태)
3. **명확하고 일관된 naming**
4. **타입 명시적 표현**

## 필수 공통 변수

### 프로젝트 메타데이터
```hcl
project_name    = string  # 프로젝트 이름
team           = string  # 팀 이름  
organization   = string  # 조직 이름
environment    = string  # 환경 (dev/staging/prod)
cost_center    = string  # 비용 센터
owner_email    = string  # 소유자 이메일
```

### AWS 기본 설정
```hcl
aws_region     = string  # AWS 리전
tags          = map(string)  # 공통 태그 (지역화)
```

## 서비스별 표준 변수명

### Networking
```hcl
# VPC
vpc_cidr                    = string       # VPC CIDR
use_existing_vpc           = bool         # 기존 VPC 사용 여부
existing_vpc_id            = string       # 기존 VPC ID
existing_public_subnet_ids = list(string) # 기존 퍼블릭 서브넷 IDs
existing_private_subnet_ids = list(string) # 기존 프라이빗 서브넷 IDs

# NAT Gateway
enable_nat_gateway = bool # NAT Gateway 생성 여부
```

### ECS
```hcl
# Cluster
enable_container_insights = bool   # Container Insights 활성화

# Task Definition
ecs_task_cpu    = string  # CPU 단위 (256, 512, 1024...)
ecs_task_memory = string  # 메모리 MB (512, 1024, 2048...)
task_image      = string  # 컨테이너 이미지

# Service
ecs_min_capacity = number # 최소 태스크 수
ecs_max_capacity = number # 최대 태스크 수
desired_count    = number # 희망 태스크 수

# Auto Scaling
enable_autoscaling         = bool   # 오토스케일링 활성화
target_cpu_utilization    = number # CPU 사용률 임계값
target_memory_utilization = number # 메모리 사용률 임계값
```

### Load Balancer
```hcl
# ALB
enable_deletion_protection = bool         # 삭제 보호
certificate_arn           = string       # ACM 인증서 ARN
additional_certificate_arns = list(string) # 추가 인증서들
ssl_policy                = string       # SSL 정책

# Target Group
health_check_path     = string # 헬스체크 경로
health_check_interval = number # 헬스체크 간격
```

### Security
```hcl
# Security Groups (자동 생성되는 ID들은 변수로 노출하지 않음)
allowed_cidr_blocks = list(string) # 허용할 CIDR 블록들

# Secrets
secret_recovery_window_days = number # 시크릿 복구 기간
```

### Storage
```hcl
# EFS
enable_efs              = bool   # EFS 활성화
efs_performance_mode    = string # EFS 성능 모드
efs_throughput_mode     = string # EFS 처리량 모드
efs_lifecycle_policy    = string # EFS 라이프사이클 정책

# S3 (Terraform State)
create_terraform_state_bucket = bool # Terraform State S3 버킷 생성
create_terraform_lock_table   = bool # Terraform Lock DynamoDB 테이블 생성
```

### Logging
```hcl
log_retention_days = number # CloudWatch 로그 보존 기간
```

### 서비스 특화 변수 (Atlantis)
```hcl
# Atlantis 설정
atlantis_host               = string # Atlantis 호스트명
atlantis_port               = number # Atlantis 포트 (기본: 4141)
atlantis_image              = string # Atlantis 이미지
atlantis_repo_allowlist     = string # 허용 레포지토리 패턴
atlantis_repo_config        = string # atlantis.yaml 경로
atlantis_github_user        = string # GitHub 사용자명
hide_prev_plan_comments     = bool   # 이전 plan 댓글 숨기기
terraform_version           = string # Terraform 버전
```

## 금지된 변수명 패턴

### ❌ 잘못된 예시
```hcl
vpc_id          # 리소스 ID는 변수가 아닌 data source나 local
subnet_ids      # 복수형이지만 list 타입 명시 없음
tags            # 너무 일반적, local.common_tags 사용
alb_arn         # 리소스 ARN은 output
security_group_id # 리소스 ID는 output
```

### ✅ 올바른 예시
```hcl
existing_vpc_id            # 기존 리소스 참조는 명시적
existing_subnet_ids        # 기존 리소스 + 복수형
use_existing_vpc          # boolean은 enable_/use_ prefix
enable_container_insights # boolean은 enable_ prefix
atlantis_github_user      # 서비스명 prefix
```

## 변수 그룹 분류

1. **메타데이터**: project_name, team, organization, environment
2. **인프라 설정**: aws_region, vpc_cidr, subnet configurations
3. **서비스 설정**: ECS, ALB, Security 관련
4. **기능 토글**: enable_*, use_*, create_* (boolean)
5. **서비스별 특화**: atlantis_*, 기타 애플리케이션별

## 변수 정의 템플릿

```hcl
variable "project_name" {
  description = "Name of the project"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights for ECS cluster"
  type        = bool
  default     = true
}

variable "ecs_task_cpu" {
  description = "CPU units for ECS task (256, 512, 1024, 2048, 4096)"
  type        = string
  default     = "512"
  
  validation {
    condition     = contains(["256", "512", "1024", "2048", "4096"], var.ecs_task_cpu)
    error_message = "ECS task CPU must be one of: 256, 512, 1024, 2048, 4096."
  }
}
```