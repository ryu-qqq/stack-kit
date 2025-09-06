# 🏗️ StackKit 팀 가이드라인

**다른 팀이 StackKit 표준을 활용하여 인프라를 구축하는 방법**

이 문서는 `atlantis-ecs` 프로젝트를 통해 검증된 StackKit 활용 패턴을 다른 팀들에게 전파하기 위한 가이드라인입니다.

## 🎯 목적

- **표준화**: 모든 팀이 동일한 패턴으로 인프라 구축
- **효율성**: 검증된 모듈 재사용으로 개발 시간 단축  
- **일관성**: 유지보수와 협업이 쉬운 코드 구조
- **품질**: 보안, 성능, 비용 최적화가 내장된 구성

## 📋 프로젝트 시작 체크리스트

### 1. 사전 준비 ✅

- [ ] `atlantis-ecs` 프로젝트 구조 검토
- [ ] `VARIABLE_STANDARDS.md` 숙지
- [ ] `terraform/modules/` 사용 가능한 모듈 확인
- [ ] 프로젝트 요구사항 정의

### 2. 프로젝트 구조 생성 ✅

```bash
# 새 프로젝트 디렉토리 생성
mkdir my-service-infrastructure
cd my-service-infrastructure

# 기본 파일 구조
touch main.tf variables.tf outputs.tf terraform.tfvars.example
mkdir examples
```

### 3. 표준 템플릿 작성 ✅

**main.tf 기본 구조**:
```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Stack       = "${var.project_name}-${var.environment}"
    Owner       = var.org_name
    ManagedBy   = "terraform"
    CreatedBy   = "stackkit-[your-project]"
  }
}

# StackKit 모듈 활용
module "vpc" {
  source = "./terraform/modules/vpc"
  # 표준 변수 전달...
}
```

## 🧩 모듈 활용 패턴

### 기본 네트워킹 패턴

```hcl
module "vpc" {
  source = "./terraform/modules/vpc"
  
  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
  
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  
  enable_nat_gateway = true
  single_nat_gateway = var.environment == "dev"  # 비용 최적화
  
  common_tags = local.common_tags
}
```

### 컨테이너 서비스 패턴

```hcl
module "ecs" {
  source = "./terraform/modules/ecs"
  
  project_name = var.project_name
  environment  = var.environment
  cluster_name = "your-service"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  # 환경별 설정
  task_cpu    = var.environment == "prod" ? "2048" : "1024"
  task_memory = var.environment == "prod" ? "4096" : "2048"
  
  common_tags = local.common_tags
}
```

### 스토리지 패턴

```hcl
module "storage" {
  source = "./terraform/modules/s3"
  
  project_name = var.project_name
  environment  = var.environment
  bucket_name  = "${var.org_name}-${var.project_name}-${var.environment}"
  
  versioning_enabled  = var.environment == "prod"
  block_public_access = true
  
  common_tags = local.common_tags
}
```

## 📐 VARIABLE_STANDARDS.md 준수

### ✅ 필수 준수 사항

```hcl
# 표준 변수명 (약어 금지)
variable "org_name" {        # ❌ org
  type = string
}

variable "aws_region" {      # ❌ region  
  type = string
  default = "ap-northeast-2"
}

variable "environment" {     # ❌ env
  type = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

# 기존 리소스는 existing_ 접두어
variable "existing_vpc_id" {  # ❌ vpc_id
  type = string
  default = ""
}
```

### ✅ 유효성 검증 패턴

```hcl
variable "certificate_arn" {
  type = string
  validation {
    condition     = can(regex("^arn:aws:acm:", var.certificate_arn))
    error_message = "certificate_arn must be a valid ACM certificate ARN."
  }
}

variable "task_cpu" {
  type = string
  validation {
    condition     = contains(["256", "512", "1024", "2048", "4096"], var.task_cpu)
    error_message = "task_cpu must be one of: 256, 512, 1024, 2048, 4096."
  }
}
```

## 🏷️ 태깅 표준

### 표준 태그 적용

```hcl
locals {
  common_tags = {
    Project     = var.project_name      # 프로젝트명
    Environment = var.environment       # 환경 (dev/staging/prod)
    Stack       = "${var.project_name}-${var.environment}"
    Owner       = var.org_name          # 소유 조직
    ManagedBy   = "terraform"           # 관리 도구
    CreatedBy   = "stackkit-[project]"  # 생성 도구
    CostCenter  = var.cost_center       # 비용 센터 (선택)
  }
}

# 모든 리소스에 적용
resource "aws_instance" "example" {
  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-instance"
    Type = "web-server"  # 리소스별 추가 태그
  })
}
```

## 🔧 환경별 최적화 패턴

### 개발 환경 최적화

```hcl
locals {
  # 환경별 설정
  env_config = {
    dev = {
      instance_type        = "t3.micro"
      min_capacity        = 1
      max_capacity        = 2
      multi_az            = false
      backup_retention    = 1
      single_nat_gateway  = true   # 비용 절약
      log_retention_days  = 7
    }
    staging = {
      instance_type        = "t3.small"
      min_capacity        = 2
      max_capacity        = 4
      multi_az            = false
      backup_retention    = 7
      single_nat_gateway  = false
      log_retention_days  = 14
    }
    prod = {
      instance_type        = "t3.medium"
      min_capacity        = 3
      max_capacity        = 10
      multi_az            = true   # 고가용성
      backup_retention    = 30
      single_nat_gateway  = false
      log_retention_days  = 90
    }
  }
}

# 사용법
task_cpu = local.env_config[var.environment].instance_type
```

## 🛡️ 보안 패턴

### 보안 그룹 설정

```hcl
resource "aws_security_group" "app" {
  name_prefix = "${var.project_name}-${var.environment}-app-"
  vpc_id      = module.vpc.vpc_id

  # 주석으로 퍼블릭 접근 명시
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # ALLOW_PUBLIC_EXEMPT - ALB public access
    description = "HTTP from ALB"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # ALLOW_PUBLIC_EXEMPT - outbound internet
    description = "All outbound traffic"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-app-sg"
  })
}
```

### Secrets 관리

```hcl
resource "aws_secretsmanager_secret" "app" {
  name                    = "${var.org_name}-${var.project_name}-${var.environment}"
  description            = "Application secrets for ${var.project_name}"
  recovery_window_in_days = 7

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-secrets"
  })
}
```

## 📤 출력값 패턴

### 실용적인 출력 구성

```hcl
# 필수 접근 정보
output "application_url" {
  description = "애플리케이션 접속 URL"
  value       = "https://${aws_lb.main.dns_name}"
}

# 인프라 정보
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

# 모니터링 링크
output "monitoring_links" {
  description = "모니터링 콘솔 링크"
  value = {
    cloudwatch = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}"
    ecs        = "https://console.aws.amazon.com/ecs/v2/clusters"
  }
}

# 설정 가이드
output "setup_instructions" {
  description = "설정 완료 후 해야 할 일"
  value = <<-EOT
    🎉 배포 완료!
    
    다음 단계:
    1. 애플리케이션 접속: ${var.custom_domain}
    2. 모니터링 확인: CloudWatch 콘솔
    3. 로그 확인: /aws/ecs/${var.project_name}
  EOT
}
```

## 📝 예시 파일 구성

### terraform.tfvars.example

```hcl
# =======================================
# [PROJECT_NAME] Configuration Example
# =======================================
# 이 파일을 terraform.tfvars로 복사하고 실제 값으로 수정하세요

# 필수: 조직 정보
org_name    = "mycompany"
environment = "dev"          # dev, staging, prod
project_name = "my-service"

# 필수: AWS 설정
aws_region = "ap-northeast-2"

# 네트워킹 (선택사항, 기본값 사용 가능)
vpc_cidr = "10.0.0.0/16"

# 환경별 설정 예시
# 개발환경: CPU 512, Memory 1024
# 프로덕션: CPU 2048, Memory 4096
task_cpu    = "1024"
task_memory = "2048"
```

### examples/ 디렉토리

```
examples/
├── dev-environment.tfvars      # 개발 환경 최적화 설정
├── prod-environment.tfvars     # 프로덕션 환경 설정
├── existing-vpc.tf             # 기존 VPC 활용 방법
└── multi-region.tf             # 다중 리전 배포 방법
```

## 🔍 품질 검증 방법

### 1. StackKit CLI 활용

```bash
# 표준 준수 확인
./terraform/tools/stackkit-cli.sh security .

# 비용 추정
./terraform/tools/stackkit-cli.sh cost my-service dev
```

### 2. 수동 검증 체크리스트

- [ ] VARIABLE_STANDARDS.md 준수 확인
- [ ] `terraform/modules/` 활용 확인
- [ ] 환경별 최적화 적용 확인
- [ ] 보안 그룹 주석 처리 확인
- [ ] 태깅 정책 적용 확인

## 🚀 배포 권장 절차

### 1. 개발 환경부터

```bash
# 1. 개발 환경 배포
cp examples/dev-environment.tfvars terraform.tfvars
terraform init
terraform plan
terraform apply

# 2. 검증 및 테스트
terraform output setup_instructions

# 3. 스테이징/프로덕션 단계적 배포
```

### 2. CI/CD 연동

```yaml
# .github/workflows/infrastructure.yml
name: Infrastructure Deployment
on:
  pull_request:
    paths: ['*.tf', '**/*.tf']

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Terraform Validate
        run: |
          terraform init
          terraform validate
          ./terraform/tools/stackkit-cli.sh security .
```

## 📞 지원 및 문의

### 질문이나 도움이 필요한 경우

- **Slack**: #infrastructure 채널에서 질문
- **GitHub Issues**: 버그 리포트나 개선 제안
- **Office Hours**: 매주 금요일 오후 4시 (Infrastructure 팀)

### 새로운 모듈 요청

1. **Slack #infrastructure**에서 요구사항 공유
2. **GitHub Issue** 생성하여 구체적인 스펙 정리
3. **Infrastructure 팀**과 설계 논의 후 개발

### 성공 사례 공유

다른 팀들이 참고할 수 있도록 성공적인 구축 사례를 공유해 주세요:
- **Slack #infrastructure**에 프로젝트 소개
- **README.md**에 활용 사례 추가 PR
- **팀 미팅**에서 경험 공유

---

**StackKit을 활용하면 모든 팀이 일관되고 안정적인 인프라를 구축할 수 있습니다.**

**Infrastructure Team**  
**마지막 업데이트**: 2024년 9월