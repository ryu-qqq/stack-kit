# 🧩 StackKit Terraform 모듈 가이드

## 개요
StackKit은 재사용 가능한 Terraform 모듈들을 제공하여 팀에서 일관된 인프라를 구축할 수 있도록 합니다.

## 📦 사용 가능한 모듈

### 네트워킹
- **[vpc/](./vpc/)** - VPC, 서브넷, NAT Gateway, 라우팅 테이블
- **[security-group/](./security-group/)** - 보안 그룹 및 규칙 관리

### 컴퓨팅
- **[ec2/](./ec2/)** - EC2 인스턴스, Auto Scaling, Launch Template
- **[ecs/](./ecs/)** - ECS 클러스터, 서비스, 태스크 정의
- **[lambda/](./lambda/)** - Lambda 함수, 이벤트 소스, 권한

### 데이터베이스
- **[rds/](./rds/)** - RDS 인스턴스, 서브넷 그룹, 파라미터 그룹
- **[dynamodb/](./dynamodb/)** - DynamoDB 테이블, 인덱스, 스트림
- **[elasticache/](./elasticache/)** - Redis/Memcached 클러스터

### 스토리지
- **[s3/](./s3/)** - S3 버킷, 정책, 라이프사이클, 알림
- **[efs/](./efs/)** - EFS 파일 시스템, 마운트 타겟

### 메시징
- **[sqs/](./sqs/)** - SQS 큐, DLQ, 정책
- **[sns/](./sns/)** - SNS 토픽, 구독, 정책
- **[eventbridge/](./eventbridge/)** - EventBridge 버스, 규칙, 타겟

### 보안
- **[kms/](./kms/)** - KMS 키, 별칭, 정책
- **[iam/](./iam/)** - IAM 역할, 정책, 사용자

## 🚀 빠른 시작

### 1. 기본 사용법
```hcl
module "vpc" {
  source = "../../modules/vpc"
  
  project_name = "my-app"
  environment  = "dev"
  vpc_cidr     = "10.0.0.0/16"
  
  common_tags = {
    Project     = "my-app"
    Environment = "dev"
    Owner       = "platform"
  }
}
```

### 2. 모듈 조합 예제
```hcl
# VPC 생성
module "vpc" {
  source = "../../modules/vpc"
  # ... 설정
}

# VPC를 사용하는 EC2
module "web_server" {
  source = "../../modules/ec2"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnet_ids
  # ... 기타 설정
}

# VPC를 사용하는 RDS
module "database" {
  source = "../../modules/rds"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  # ... 기타 설정
}
```

## 📋 공통 변수

모든 모듈은 다음 공통 변수를 지원합니다:

```hcl
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

variable "common_tags" {
  description = "모든 리소스에 적용할 공통 태그"
  type        = map(string)
  default     = {}
}
```

## 🏗️ 모듈 아키텍처 패턴

### 1. 웹 애플리케이션 스택
```hcl
# 3-tier 웹 애플리케이션
module "vpc" { source = "../../modules/vpc" }
module "web_servers" { source = "../../modules/ec2" }
module "database" { source = "../../modules/rds" }
module "cache" { source = "../../modules/elasticache" }
module "storage" { source = "../../modules/s3" }
```

### 2. 마이크로서비스 API
```hcl
# 서버리스 API 스택
module "vpc" { source = "../../modules/vpc" }
module "api_lambda" { source = "../../modules/lambda" }
module "database" { source = "../../modules/dynamodb" }
module "queue" { source = "../../modules/sqs" }
module "notifications" { source = "../../modules/sns" }
```

### 3. 데이터 파이프라인
```hcl
# 이벤트 기반 데이터 처리
module "processor_lambda" { source = "../../modules/lambda" }
module "event_bus" { source = "../../modules/eventbridge" }
module "processing_queue" { source = "../../modules/sqs" }
module "data_storage" { source = "../../modules/s3" }
```

## 🔧 환경별 설정

### 환경별 리소스 크기 조정
```hcl
locals {
  env_config = {
    dev = {
      instance_type = "t3.micro"
      instance_count = 1
      db_instance_class = "db.t3.micro"
    }
    staging = {
      instance_type = "t3.small"
      instance_count = 2
      db_instance_class = "db.t3.small"
    }
    prod = {
      instance_type = "t3.medium"
      instance_count = 3
      db_instance_class = "db.t3.medium"
    }
  }
}

module "ec2" {
  source = "../../modules/ec2"
  
  instance_type  = local.env_config[var.environment].instance_type
  instance_count = local.env_config[var.environment].instance_count
  # ...
}
```

## 🛡️ 보안 베스트 프랙티스

### 1. 네트워킹 보안
```hcl
# VPC에서 프라이빗 서브넷 사용
module "vpc" {
  source = "../../modules/vpc"
  
  # 프라이빗 서브넷에 데이터베이스 배치
  enable_nat_gateway = true
}

module "database" {
  source = "../../modules/rds"
  
  # 프라이빗 서브넷 사용
  subnet_ids = module.vpc.private_subnet_ids
}
```

### 2. 암호화
```hcl
# KMS 키 생성
module "kms_key" {
  source = "../../modules/kms"
  
  key_name    = "app-encryption-key"
  description = "Application data encryption"
}

# S3 버킷 암호화
module "storage" {
  source = "../../modules/s3"
  
  encryption_key_arn = module.kms_key.key_arn
}
```

### 3. 액세스 제어
```hcl
# 최소 권한 원칙
module "app_role" {
  source = "../../modules/iam"
  
  role_name = "app-execution-role"
  policies = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  ]
  
  # 커스텀 정책으로 세밀한 권한 제어
  custom_policies = [
    {
      name = "S3Access"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = ["s3:GetObject", "s3:PutObject"]
            Resource = "${module.storage.bucket_arn}/*"
          }
        ]
      })
    }
  ]
}
```

## 📊 비용 최적화

### 환경별 리소스 최적화
```hcl
# 개발 환경 비용 절약
module "ec2_dev" {
  source = "../../modules/ec2"
  
  instance_type = "t3.micro"  # 개발용 소형 인스턴스
  
  # 개발 환경은 업무시간만 실행
  schedule_enabled = var.environment == "dev"
  schedule_start   = "0 9 * * 1-5"   # 평일 오전 9시
  schedule_stop    = "0 18 * * 1-5"  # 평일 오후 6시
}

# RDS 개발 환경 최적화
module "rds_dev" {
  source = "../../modules/rds"
  
  instance_class = "db.t3.micro"
  multi_az      = false  # 개발환경은 단일 AZ
  backup_retention_period = 1  # 최소 백업 보존
}
```

## 📝 모듈 개발 가이드

### 새 모듈 생성 구조
```
modules/new-module/
├── main.tf          # 리소스 정의
├── variables.tf     # 입력 변수
├── outputs.tf       # 출력 값
├── versions.tf      # Terraform/Provider 버전
├── README.md        # 모듈 문서
└── examples/        # 사용 예제
    └── basic/
        ├── main.tf
        └── variables.tf
```

### 모듈 템플릿
```hcl
# variables.tf
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

variable "common_tags" {
  description = "모든 리소스에 적용할 공통 태그"
  type        = map(string)
  default     = {}
}

# main.tf
resource "aws_example_resource" "main" {
  name = "${var.project_name}-${var.environment}-example"
  
  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-example"
  })
}

# outputs.tf
output "resource_id" {
  description = "리소스 ID"
  value       = aws_example_resource.main.id
}

output "resource_arn" {
  description = "리소스 ARN"
  value       = aws_example_resource.main.arn
}
```

## 🧪 테스트

### 모듈 테스트
```bash
# 1. 예제 디렉토리로 이동
cd modules/vpc/examples/basic

# 2. 테스트 실행
terraform init
terraform plan
terraform apply -auto-approve

# 3. 정리
terraform destroy -auto-approve
```

## 🔄 업데이트 가이드

### 모듈 버전 관리
```hcl
# 특정 버전 사용 (권장)
module "vpc" {
  source = "git::https://github.com/your-org/stackkit.git//terraform/modules/vpc?ref=v1.2.0"
  # ... 설정
}

# 최신 버전 사용 (개발용)
module "vpc" {
  source = "../../modules/vpc"
  # ... 설정
}
```

## 📚 추가 리소스

### 학습 자료
- [Terraform Module 작성 가이드](https://www.terraform.io/docs/modules/index.html)
- [AWS Provider 문서](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

### 커뮤니티
- Issues: [GitHub Issues](../../issues)
- 토론: [Discussions](../../discussions)
- Slack: `#infrastructure` 채널

---
*📦 모듈을 사용하여 더 빠르고 일관된 인프라를 구축하세요!*