# 🏗️ Connectly Shared Infrastructure 가이드

## 📋 개요

`connectly-shared-infrastructure`는 Connectly 조직의 **공유 인프라 기반**을 제공하는 핵심 프로젝트입니다. 이 프로젝트는 다른 모든 Connectly 프로젝트들이 참조하고 활용할 수 있는 표준화된 AWS 인프라를 생성하고 관리합니다.

## 🎯 역할과 목적

### 1. **공유 인프라 제공자 (Infrastructure Provider)**
- **VPC 및 네트워킹**: 표준화된 네트워크 환경
- **컴퓨팅 플랫폼**: ECS 클러스터 
- **보안 그룹**: 애플리케이션별 표준 보안 정책
- **스토리지**: 로그 및 백업용 S3 버킷
- **암호화**: KMS 키를 통한 일관된 암호화

### 2. **비용 최적화 (Cost Optimizer)**
- **리소스 공유**: 여러 프로젝트가 동일한 VPC/ECS 클러스터 사용
- **환경별 최적화**: dev는 비용 절약, prod는 고가용성
- **스마트 배치**: Fargate Spot 인스턴스 활용

### 3. **보안 표준화 (Security Standardization)**
- **네트워크 분리**: Public/Private 서브넷 분리
- **최소 권한**: 필요한 포트만 허용하는 보안 그룹
- **암호화 강제**: 모든 저장소에 KMS 암호화 적용

### 4. **운영 효율성 (Operational Efficiency)**
- **중앙 집중 관리**: 하나의 프로젝트로 모든 기반 인프라 관리
- **표준화**: 모든 프로젝트가 동일한 패턴으로 인프라 사용
- **모니터링**: 중앙화된 로깅 및 모니터링

---

## 🏗️ 아키텍처 구조

### 현재 생성된 인프라

```
┌─────────────────────────────────────────────────────────┐
│                 Connectly Shared Infrastructure         │
├─────────────────────────────────────────────────────────┤
│  🌐 Networking Layer                                    │
│  ├── VPC (dev: 10.0.0.0/16, prod: 10.1.0.0/16)        │
│  ├── Public Subnets (ALB, NAT Gateway)                │
│  ├── Private Subnets (Applications, Databases)         │
│  └── Internet/NAT Gateways                             │
│                                                         │
│  💻 Compute Layer                                       │
│  ├── ECS Cluster (Fargate + Spot)                     │
│  └── Capacity Providers                                │
│                                                         │
│  🔒 Security Layer                                      │
│  ├── ALB Security Group                               │
│  ├── ECS Tasks Security Group                         │
│  ├── RDS Security Group                               │
│  └── ElastiCache Security Group                       │
│                                                         │
│  💾 Storage Layer                                       │
│  ├── Application Logs S3 Bucket                       │
│  ├── ALB Logs S3 Bucket                               │
│  ├── Backup S3 Bucket (prod only)                     │
│  └── KMS Encryption Keys                               │
│                                                         │
│  🗄️ Database Layer                                      │
│  ├── RDS Subnet Groups                                │
│  └── ElastiCache Subnet Groups                        │
└─────────────────────────────────────────────────────────┘
```

### 환경별 차이점

| 구성 요소 | Development (dev) | Production (prod) |
|----------|-------------------|-------------------|
| **VPC CIDR** | 10.0.0.0/16 | 10.1.0.0/16 |
| **NAT Gateway** | 1개 (비용 절약) | 2개 (고가용성) |
| **VPC Flow Logs** | 비활성화 | 활성화 (보안) |
| **Container Insights** | 비활성화 | 활성화 (모니터링) |
| **Fargate Strategy** | Spot 우선 | Regular 우선 |
| **백업 버킷** | 없음 | 전용 백업 버킷 |
| **로그 보존** | 표준 기간 | 연장 기간 (컴플라이언스) |

---

## 🔄 사용 방법

### 1. **다른 프로젝트에서 참조하는 방법**

#### Method 1: Terraform Remote State (권장)

```hcl
# 다른 프로젝트의 data.tf
data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket = "${var.environment}-connectly"  # dev-connectly 또는 prod-connectly
    key    = "connectly-shared/dev/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# 사용 예시 - ECS Service 생성
resource "aws_ecs_service" "app" {
  name            = "my-app"
  cluster         = data.terraform_remote_state.shared.outputs.ecs_cluster_id
  desired_count   = 2
  
  network_configuration {
    subnets         = data.terraform_remote_state.shared.outputs.private_subnet_ids
    security_groups = [data.terraform_remote_state.shared.outputs.ecs_tasks_security_group_id]
  }
}

# ALB 생성
resource "aws_lb" "app" {
  name               = "my-app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [data.terraform_remote_state.shared.outputs.alb_security_group_id]
  subnets           = data.terraform_remote_state.shared.outputs.public_subnet_ids
}

# RDS 데이터베이스 생성
resource "aws_db_instance" "app" {
  identifier     = "my-app-db"
  engine         = "postgres"
  instance_class = "db.t3.micro"
  
  db_subnet_group_name   = data.terraform_remote_state.shared.outputs.rds_subnet_group_name
  vpc_security_group_ids = [data.terraform_remote_state.shared.outputs.rds_security_group_id]
  
  kms_key_id = data.terraform_remote_state.shared.outputs.kms_key_id
}
```

#### Method 2: SSM Parameter Store

```hcl
# SSM을 통한 참조 (크로스 계정 접근 시 유용)
data "aws_ssm_parameter" "vpc_id" {
  name = "/connectly-shared/${var.environment}/vpc/id"
}

data "aws_ssm_parameter" "private_subnet_ids" {
  name = "/connectly-shared/${var.environment}/subnets/private/ids"
}

# 사용
locals {
  vpc_id = data.aws_ssm_parameter.vpc_id.value
  private_subnet_ids = split(",", data.aws_ssm_parameter.private_subnet_ids.value)
}
```

### 2. **새 프로젝트 생성 시 패턴**

```bash
# 1. 새 프로젝트 생성
/Users/sangwon-ryu/stackkit/tools/create-project-infrastructure.sh \
  --project user-service \
  --team backend \
  --org connectly \
  --environments "dev,prod"

# 2. 생성된 프로젝트에서 공유 인프라 참조
cd user-service-infrastructure/environments/dev

# 3. main.tf에서 공유 인프라 활용
module "user_api" {
  source = "git::https://github.com/company/stackkit-terraform.git//modules/compute/ecs-service?ref=v1.0.0"
  
  # 공유 인프라 참조
  vpc_id          = data.terraform_remote_state.shared.outputs.vpc_id
  subnet_ids      = data.terraform_remote_state.shared.outputs.private_subnet_ids
  cluster_id      = data.terraform_remote_state.shared.outputs.ecs_cluster_id
  security_groups = [data.terraform_remote_state.shared.outputs.ecs_tasks_security_group_id]
  
  # 프로젝트 특화 설정
  service_name    = "user-api"
  container_image = "your-registry/user-api:latest"
  container_port  = 8080
}
```

---

## 📊 현재 제공하는 리소스

### 🌐 **네트워크 리소스**
```hcl
vpc_id                  # VPC ID
vpc_cidr                # VPC CIDR 블록
public_subnet_ids       # 퍼블릭 서브넷 ID 목록
private_subnet_ids      # 프라이빗 서브넷 ID 목록
internet_gateway_id     # 인터넷 게이트웨이 ID
nat_gateway_ids         # NAT 게이트웨이 ID 목록
```

### 🔒 **보안 그룹**
```hcl
alb_security_group_id           # ALB용 보안 그룹
ecs_tasks_security_group_id     # ECS 태스크용 보안 그룹  
rds_security_group_id           # RDS용 보안 그룹
elasticache_security_group_id   # ElastiCache용 보안 그룹
```

### 💻 **컴퓨팅 리소스**
```hcl
ecs_cluster_id      # ECS 클러스터 ID
ecs_cluster_arn     # ECS 클러스터 ARN
ecs_cluster_name    # ECS 클러스터 이름
```

### 🗄️ **데이터베이스 리소스**
```hcl
rds_subnet_group_name           # RDS 서브넷 그룹 이름
rds_subnet_group_id             # RDS 서브넷 그룹 ID
elasticache_subnet_group_name   # ElastiCache 서브넷 그룹 이름
```

### 💾 **스토리지 및 암호화**
```hcl
logs_bucket_id      # 애플리케이션 로그 버킷 ID
logs_bucket_arn     # 애플리케이션 로그 버킷 ARN
alb_logs_bucket_id  # ALB 로그 버킷 ID
kms_key_id          # KMS 키 ID
kms_key_arn         # KMS 키 ARN
```

---

## 🚀 배포 및 관리

### 1. **초기 배포**

```bash
# 개발 환경 배포
cd /Users/sangwon-ryu/connectly-shared-infrastructure/environments/dev
terraform init
terraform plan
terraform apply

# 프로덕션 환경 배포  
cd /Users/sangwon-ryu/connectly-shared-infrastructure/environments/prod
terraform init
terraform plan  
terraform apply
```

### 2. **상태 관리**

현재 구성된 백엔드:
- **버킷**: `dev-connectly`, `prod-connectly`
- **DynamoDB**: `dev-connectly-tf-lock`, `prod-connectly-tf-lock`
- **키**: `connectly-shared/dev/terraform.tfstate`, `connectly-shared/prod/terraform.tfstate`

### 3. **업데이트 프로세스**

```bash
# 1. 개발 환경에서 먼저 테스트
cd environments/dev
terraform plan
terraform apply

# 2. 다른 프로젝트들에 미치는 영향 확인
# 3. 프로덕션 배포
cd environments/prod
terraform plan
terraform apply
```

---

## 💡 모범 사례 및 가이드라인

### 1. **새 프로젝트 시작 시**
```bash
# ✅ 올바른 방법
1. create-project-infrastructure.sh로 표준 구조 생성
2. data.tf에서 공유 인프라 참조 설정
3. 프로젝트별 리소스만 main.tf에 정의
4. 공유 보안 그룹 최대한 활용

# ❌ 피해야 할 방법
1. 새로운 VPC 생성
2. 별도의 ECS 클러스터 생성
3. 커스텀 보안 그룹 남발
4. 암호화 키 개별 생성
```

### 2. **비용 최적화**
```bash
# 개발 환경
- 단일 NAT Gateway 사용
- Fargate Spot 인스턴스 우선 사용  
- 불필요한 로깅 기능 비활성화

# 프로덕션 환경
- 고가용성을 위한 이중 NAT Gateway
- 적절한 모니터링 활성화
- 백업 및 컴플라이언스 기능 활용
```

### 3. **보안 고려사항**
```bash
# 네트워크 보안
- Private 서브넷에 애플리케이션 배치
- 보안 그룹 규칙 최소화
- VPC Flow Logs 활용 (prod)

# 데이터 보안  
- KMS 키를 통한 암호화 필수
- 로그 데이터 암호화
- Secrets Manager 활용
```

---

## 🔮 향후 확장 계획

### 1. **단기 계획 (1-2개월)**
- RDS 인스턴스 추가 (공유 데이터베이스)
- ElastiCache 클러스터 구성
- CloudWatch 대시보드 구성
- Route53 호스팅 존 설정

### 2. **중기 계획 (3-6개월)**  
- EKS 클러스터 추가 (Kubernetes 워크로드)
- Application Load Balancer 공유
- API Gateway 구성
- CloudFront 배포

### 3. **장기 계획 (6개월+)**
- 멀티 리전 구성
- 재해 복구 시스템
- 고급 모니터링 및 알림
- 비용 최적화 자동화

---

## 📞 지원 및 문의

### 트러블슈팅
1. **모듈 오류**: stackkit-terraform 모듈 경로 확인
2. **상태 파일 문제**: 백엔드 설정 및 권한 확인  
3. **리소스 충돌**: 기존 리소스명과 중복 확인

### 연락처
- **Slack**: #platform-infrastructure
- **이슈**: GitHub Issues
- **문서**: 이 README 및 모듈별 문서

---

## 🎯 결론

`connectly-shared-infrastructure`는 Connectly 조직의 **인프라 백본**입니다. 이를 통해:

1. **표준화**: 모든 프로젝트가 일관된 인프라 패턴 사용
2. **비용 절약**: 리소스 공유를 통한 비용 최적화
3. **보안 강화**: 중앙 관리되는 보안 정책
4. **운영 효율성**: 인프라 관리 복잡성 감소

모든 새로운 Connectly 프로젝트는 이 공유 인프라를 기반으로 구축되어야 하며, 필요에 따라 프로젝트별 추가 리소스만 생성하는 것이 원칙입니다.