# 🏗️ StackKit - Terraform Infrastructure Framework

**5분만에 AWS 인프라를 구축하고 AI로 검증하세요** 🚀

표준화된 Terraform 모듈과 자동화 스크립트로 복잡한 AWS 인프라를 간단하게 구축하고 관리할 수 있습니다.

## ✨ 핵심 기능

- **🧩 12개 AWS 서비스 모듈**: VPC, EC2, RDS, Lambda 등 즉시 사용 가능
- **🤖 AI-Powered 코드 리뷰**: OpenAI GPT-4로 Terraform Plan/Apply 자동 분석
- **⚡ 5분 인프라 구축**: 스크립트 한 번으로 전체 스택 배포
- **🔄 Atlantis 워크플로우**: PR 기반 인프라 변경 관리
- **📊 비용 최적화**: 환경별 리소스 크기 자동 조정
- **🛡️ 보안 검증**: 자동화된 보안 정책 검사

---

## 🚀 5분 빠른 시작

### 1. 저장소 클론
```bash
git clone https://github.com/your-org/stackkit.git
cd stackkit
```

### 2. 첫 번째 스택 생성
```bash
# 새로운 애플리케이션 스택 생성
terraform/scripts/new-stack.sh my-app dev

# 생성된 디렉토리로 이동
cd terraform/stacks/my-app-dev-ap-northeast-2

# VPC 모듈 추가 (예시)
cat >> main.tf << 'EOF'

module "vpc" {
  source = "../../modules/vpc"
  
  project_name = "my-app"
  environment  = "dev"
  vpc_cidr     = "10.0.0.0/16"
  
  availability_zones = ["ap-northeast-2a", "ap-northeast-2c"]
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]
  
  common_tags = local.common_tags
}
EOF
```

### 3. 인프라 배포
```bash
# 초기화
terraform init -backend-config=backend.hcl

# 검증 (선택사항)
terraform/scripts/validate.sh my-app dev

# 배포
terraform apply
```

**🎉 완료!** 이제 AWS VPC가 생성되었습니다.

---

## 🏗️ 프로젝트 구조

```
stackkit/
├── terraform/
│   ├── modules/                 # 재사용 가능한 AWS 서비스 모듈
│   │   ├── vpc/                # 🌐 VPC, Subnets, NAT, IGW
│   │   ├── ec2/                # 💻 EC2, ASG, Security Groups
│   │   ├── ecs/                # 🐳 ECS, Fargate, Service
│   │   ├── rds/                # 🗄️ MySQL, PostgreSQL, Multi-AZ
│   │   ├── elasticache/        # ⚡ Redis, Memcached, Cluster
│   │   ├── dynamodb/           # 📊 NoSQL DB, GSI, Auto Scaling
│   │   ├── lambda/             # ⚡ 서버리스 함수, VPC 연결
│   │   ├── s3/                 # 📦 객체 스토리지, 정책, 암호화
│   │   ├── sqs/                # 📨 메시지 큐, FIFO, DLQ
│   │   ├── sns/                # 📢 알림 서비스, 구독, 필터
│   │   ├── eventbridge/        # 🔄 이벤트 버스, 규칙, 타겟
│   │   └── kms/                # 🔐 암호화 키, 정책, 로테이션
│   │
│   ├── stacks/                 # 실제 배포 단위
│   │   └── {stack-name}-{env}-{region}/
│   │       ├── main.tf         # 모듈 조합
│   │       ├── variables.tf    # 입력 변수
│   │       ├── outputs.tf      # 출력 값
│   │       ├── backend.tf      # 상태 관리
│   │       └── terraform.tfvars # 환경별 설정
│   │
│   ├── scripts/                # 자동화 도구
│   │   ├── new-stack.sh        # 🆕 스택 생성
│   │   ├── validate.sh         # ✅ 검증 + 비용 추정
│   │   ├── deploy.sh           # 🚀 배포 자동화
│   │   ├── destroy.sh          # 💀 안전한 제거
│   │   └── import-resources.sh # 📦 기존 리소스 Import
│   │
│   └── docs/                   # 문서
│       └── IMPORT_GUIDE.md     # Import 가이드
│
├── ai-reviewer/                # AI 리뷰어 Lambda (Java 17)
│   ├── src/main/java/         # UnifiedReviewerHandler
│   ├── build.gradle           # 빌드 설정
│   └── build.sh               # 빌드 스크립트
│
├── scripts/                    # 통합 스크립트
│   ├── setup-atlantis-ai.sh   # 🤖 AI 리뷰어 원클릭 셋업
│   └── integrate-existing-project.sh # 🔗 기존 프로젝트 통합
│
├── atlantis/                   # Atlantis 설정
│   ├── atlantis.yaml          # 워크플로우 설정
│   └── repos.yaml             # 저장소 정책
│
└── QUICKSTART.md               # 상세한 시작 가이드
```

---

## 🧩 핵심 모듈 소개

### 🌐 **VPC 모듈** - 네트워킹 기반
```hcl
module "vpc" {
  source = "../../modules/vpc"
  
  project_name = "my-app"
  environment  = "dev"
  vpc_cidr     = "10.0.0.0/16"
  
  # Multi-AZ 구성
  availability_zones = ["ap-northeast-2a", "ap-northeast-2c"]
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]
  
  # NAT Gateway (환경별 최적화)
  enable_nat_gateway = true
  single_nat_gateway = var.environment == "dev"
  
  common_tags = local.common_tags
}
```

### 💻 **EC2 모듈** - 컴퓨팅 자원
```hcl
module "web_servers" {
  source = "../../modules/ec2"
  
  project_name  = "my-app"
  environment   = "dev"
  instance_type = var.environment == "prod" ? "t3.medium" : "t3.micro"
  
  # Auto Scaling
  min_size         = var.environment == "prod" ? 2 : 1
  max_size         = var.environment == "prod" ? 10 : 3
  desired_capacity = var.environment == "prod" ? 2 : 1
  
  # 네트워킹
  vpc_id    = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnet_ids
  
  common_tags = local.common_tags
}
```

### 🗄️ **RDS 모듈** - 데이터베이스
```hcl
module "database" {
  source = "../../modules/rds"
  
  project_name    = "my-app"
  environment     = "dev"
  engine          = "mysql"
  engine_version  = "8.0"
  instance_class  = var.environment == "prod" ? "db.t3.small" : "db.t3.micro"
  
  # 가용성 (환경별 설정)
  multi_az = var.environment == "prod"
  backup_retention_period = var.environment == "prod" ? 7 : 1
  
  # 네트워킹
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  common_tags = local.common_tags
}
```

### ⚡ **Lambda 모듈** - 서버리스
```hcl
module "api_function" {
  source = "../../modules/lambda"
  
  project_name  = "my-app"
  environment   = "dev"
  function_name = "api-handler"
  
  runtime = "python3.11"
  handler = "app.lambda_handler"
  filename = "api-handler.zip"
  
  # 성능 (환경별 최적화)
  memory_size = var.environment == "prod" ? 512 : 128
  timeout     = 30
  
  # 환경 변수
  environment_variables = {
    DB_ENDPOINT = module.database.endpoint
    CACHE_ENDPOINT = module.cache.endpoint
  }
  
  common_tags = local.common_tags
}
```

---

## 🔧 자동화 스크립트

### `new-stack.sh` - 스택 생성
```bash
# 기본 사용법
terraform/scripts/new-stack.sh <stack_name> <environment> [region]

# 예시
terraform/scripts/new-stack.sh my-app dev ap-northeast-2
terraform/scripts/new-stack.sh my-api prod us-east-1
```

**생성되는 파일들**:
- `main.tf` - 모듈 조합 및 설정
- `variables.tf` - 입력 변수 정의  
- `outputs.tf` - 출력 값
- `backend.tf` - S3 상태 관리 설정
- `terraform.tfvars` - 환경별 변수 값

### `validate.sh` - 종합 검증
```bash
# 전체 검증 (추천)
terraform/scripts/validate.sh my-app dev

# 비용 추정만
terraform/scripts/validate.sh my-app dev --cost-only

# JSON 형식 출력
terraform/scripts/validate.sh my-app dev --format=json
```

**검증 항목**:
- ✅ Terraform 문법 검증
- ✅ 포맷팅 검사
- ✅ 보안 스캔 (tfsec)
- ✅ 정책 준수 검증
- ✅ 비용 추정 (Infracost)

### `deploy.sh` - 안전한 배포
```bash
# 계획 확인
terraform/scripts/deploy.sh my-app dev plan

# 대화형 배포
terraform/scripts/deploy.sh my-app dev apply

# 자동 승인 (dev/staging)
terraform/scripts/deploy.sh my-app dev apply --auto-approve

# 백업과 함께 배포 (prod)
terraform/scripts/deploy.sh my-app prod apply --backup-state
```

---

## 🏛️ 아키텍처 원칙

### Stack-centric 구조
- **모듈**: 재사용 가능한 컴포넌트 (`modules/`)  
- **스택**: 실제 배포 단위 (`stacks/{name}-{env}-{region}/`)
- **환경 분리**: 디렉토리 기반 격리

### 상태 관리 표준
- **백엔드**: S3 + DynamoDB Lock
- **암호화**: KMS 암호화 활성화  
- **격리**: 스택별 독립적 상태 파일
- **백업**: 자동 버전닝

### 명명 규칙
```
리소스명: {project}-{environment}-{service}-{purpose}
예시: my-app-prod-rds-main, my-app-dev-lambda-api
```

### 필수 태그 정책
```hcl
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Stack       = "${var.project_name}-${var.environment}"
    Owner       = "platform"
    ManagedBy   = "terraform"
  }
}
```

---

## 💰 비용 최적화

### 환경별 리소스 크기 자동 조정
```hcl
# EC2 인스턴스
instance_type = var.environment == "prod" ? "t3.large" : "t3.micro"

# RDS
instance_class = var.environment == "prod" ? "db.t3.small" : "db.t3.micro"
multi_az      = var.environment == "prod"

# Lambda
memory_size = var.environment == "prod" ? 512 : 128

# Auto Scaling
min_size = var.environment == "prod" ? 2 : 1
max_size = var.environment == "prod" ? 10 : 2
```

### 예상 비용 (월간)

| 환경 | VPC | EC2 | RDS | Lambda | 총합 |
|------|-----|-----|-----|--------|------|
| **dev** | 무료 | ~$8 | ~$15 | ~$0 | **~$23** |
| **staging** | 무료 | ~$25 | ~$30 | ~$1 | **~$56** |
| **prod** | 무료 | ~$50 | ~$60 | ~$2 | **~$112** |

---

## 🛡️ 보안 및 모범 사례

### 보안 기본 설정
- **전송 중 암호화**: 모든 통신에 TLS/SSL 적용
- **저장 중 암호화**: RDS, S3, EBS 암호화 활성화
- **네트워크 격리**: Private 서브넷에 데이터베이스 배치
- **최소 권한**: 필요한 권한만 부여

### 자동화된 보안 검사
```bash
# 보안 스캔 실행
terraform/scripts/validate.sh my-app dev --security-only

# 정책 위반 검사
terraform/scripts/tf_forbidden.sh terraform/stacks/my-app-dev-ap-northeast-2/
```

### 보안 정책 예시
```hcl
# S3 버킷 암호화 강제
resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.example.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Security Group 최소 권한
resource "aws_security_group_rule" "allow_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web.id
}
```

---

## 🔄 기존 AWS 리소스 Import

### Import 도구 사용
```bash
# VPC Import
terraform/scripts/import-resources.sh \
    ./terraform/stacks/my-app-dev \
    vpc \
    module.vpc.aws_vpc.main \
    vpc-0123456789abcdef0

# RDS Instance Import
terraform/scripts/import-resources.sh \
    ./terraform/stacks/my-app-dev \
    rds \
    module.database.aws_db_instance.main \
    my-database-instance

# Security Group Import
terraform/scripts/import-resources.sh \
    ./terraform/stacks/my-app-dev \
    security_group \
    aws_security_group.web \
    sg-0123456789abcdef0
```

### Import 가이드
자세한 Import 절차는 [`terraform/docs/IMPORT_GUIDE.md`](terraform/docs/IMPORT_GUIDE.md)를 참고하세요.

---

## 🚨 문제 해결

### 일반적인 오류들

#### 1. AWS 자격증명 오류
```bash
# 현재 자격증명 확인
aws sts get-caller-identity

# 권한 확인
aws iam list-attached-user-policies --user-name your-username
```

#### 2. Terraform 상태 잠금 오류  
```bash
# 잠금 해제
terraform force-unlock <LOCK_ID>

# 상태 파일 새로고침
terraform refresh
```

#### 3. 모듈 초기화 오류
```bash
# 모듈 캐시 정리
rm -rf .terraform

# 재초기화
terraform init -upgrade
```

#### 4. 비용 초과 경고
```bash
# 비용 추정 확인
terraform/scripts/validate.sh my-app dev --cost-only

# 리소스 크기 조정
vi terraform.tfvars  # instance_type 등 수정
```

---

## 📚 추가 가이드

- 📖 **상세 시작 가이드**: [QUICKSTART.md](./QUICKSTART.md)
- 🤖 **AI 리뷰어 + Atlantis 설정**: [부록 A](#부록-a-ai-powered-terraform-워크플로우)
- 📦 **기존 리소스 Import**: [terraform/docs/IMPORT_GUIDE.md](./terraform/docs/IMPORT_GUIDE.md)
- 🔧 **모듈 사용법**: 각 모듈의 `README.md` 참조

---

## 🏷️ 버전 정보

- **StackKit**: v2.1.0
- **Terraform**: >= 1.7.0
- **AWS Provider**: ~> 5.100
- **Java**: 17 (AI 리뷰어)

---

# 부록 A: AI-Powered Terraform 워크플로우

## 🤖 개요

StackKit의 AI-Reviewer + Atlantis 조합을 통해 PR 기반의 지능형 인프라 관리가 가능합니다.

### 🔄 워크플로우
1. **PR 생성** → Atlantis가 `terraform plan` 자동 실행
2. **Plan 분석** → UnifiedReviewerHandler가 결과를 OpenAI GPT-4로 분석
3. **AI 리뷰** → Slack으로 보안/비용/아키텍처 분석 결과 전송
4. **승인 & Apply** → 배포 결과도 동일한 AI 분석 과정

```
┌─────────────┐    ┌──────────┐    ┌─────────┐    ┌─────────────┐    ┌─────────┐
│     PR      │───▶│ Atlantis │───▶│   S3    │───▶│ Lambda      │───▶│  Slack  │
│  terraform  │    │   ECS    │    │ Plans/  │    │ Unified     │    │ AI      │
│   changes   │    │ Cluster  │    │ Results │    │ Reviewer    │    │ Review  │
└─────────────┘    └──────────┘    └─────────┘    └─────────────┘    └─────────┘
```

## 🚀 설치 및 설정

### 1. 사전 준비사항

#### GitHub Personal Access Token 생성
1. GitHub → Settings → Developer settings → Personal access tokens
2. Generate new token (classic)
3. 필요한 권한: `repo`, `admin:repo_hook`

#### Slack Webhook URL 생성
1. Slack → Apps → Incoming Webhooks
2. Add to Slack → 채널 선택
3. Webhook URL 복사

#### OpenAI API Key 생성
1. OpenAI Platform → API Keys  
2. Create new secret key
3. API Key 복사 (sk-로 시작)

### 2. 원클릭 설치

```bash
# AI-Reviewer + Atlantis 자동 설치
./scripts/setup-atlantis-ai.sh \
    --github-token=ghp_xxxxxxxxxxxx \
    --slack-webhook=https://hooks.slack.com/services/... \
    --openai-key=sk-xxxxxxxxxxxxxxxx \
    --repo-allowlist="github.com/myorg/*"
```

**설치 과정** (약 5-7분):
- ✅ UnifiedReviewerHandler Lambda 빌드 (Java 17)
- ✅ AWS Secrets Manager에 시크릿 저장  
- ✅ Terraform 스택 생성 및 배포
- ✅ Atlantis ECS 클러스터 구축
- ✅ S3, SQS, EventBridge 연동 설정

### 2.1. 수동 배포 (고급 사용자)

기존 인프라를 활용하거나 세부 설정을 제어하려면:

```bash
# 1. 환경 설정
cd terraform/stacks/atlantis-ai-reviewer/dev
cp terraform.tfvars.example terraform.tfvars

# 2. 기존 리소스 활용 설정
echo 'use_existing_s3_bucket = true' >> terraform.tfvars
echo 'existing_s3_bucket_name = "your-existing-bucket"' >> terraform.tfvars
echo 'use_existing_alb = true' >> terraform.tfvars
echo 'existing_alb_dns_name = "your-alb-dns.com"' >> terraform.tfvars

# 3. Java AI Reviewer 빌드
cd ../../../../ai-reviewer
./gradlew build

# 4. Terraform 배포
cd ../terraform/stacks/atlantis-ai-reviewer/dev
terraform init
terraform plan
terraform apply
```

**⚠️ 주의사항:**
- **명명 규칙**: 모든 리소스는 `환경-프로젝트-리소스명` 형식 (예: `dev-atlantis-ai-reviewer`)
- **SQS 큐**: FIFO 큐는 S3 notification과 호환되지 않으므로 Standard 큐 사용
- **로그 그룹**: ECS 태스크용 CloudWatch 로그 그룹 `/ecs/dev-atlantis` 자동 생성

### 3. GitHub Repository 설정

배포 완료 후 다음 단계로 GitHub Repository를 설정합니다:

#### 3.1. Webhook 추가

1. **GitHub Repository → Settings → Webhooks → Add webhook**

2. **Webhook 설정:**
   ```
   Payload URL: http://dev-atlantis-alb-xxxxx.ap-northeast-2.elb.amazonaws.com/events
   Content type: application/json
   Secret: [AWS Secrets Manager에서 확인]
   ```

3. **Secret 확인 방법:**
   ```bash
   # AWS Secrets Manager에서 webhook secret 확인
   aws secretsmanager get-secret-value \
     --secret-id atlantis/webhook-secret \
     --query SecretString --output text
   ```

4. **이벤트 선택:**
   - ✅ Pull requests
   - ✅ Issue comments  
   - ✅ Push
   - ✅ Pull request reviews

5. **Active 체크 후 Add webhook**

#### 3.2. atlantis.yaml 추가

Repository 루트에 `atlantis.yaml` 파일 생성:

```yaml
version: 3
projects:
- name: my-project
  dir: .
  workflow: stackkit-ai-review
  apply_requirements: [approved]
  
workflows:
  stackkit-ai-review:
    plan:
      steps:
      - init
      - plan
    apply:
      steps:
      - apply
```

#### 3.3. 연결 테스트

1. **테스트 PR 생성:**
   ```bash
   # 간단한 변경사항으로 테스트
   echo "# Test" >> test.md
   git add test.md
   git commit -m "test: Atlantis AI 연동 테스트"
   git push origin feature/test-atlantis
   ```

2. **PR 생성 후 확인사항:**
   - Atlantis가 자동으로 `terraform plan` 실행
   - S3에 plan 결과 저장 (`terraform/dev/atlantis/` 경로)
   - Lambda 함수가 AI 분석 수행
   - Slack에 AI 리뷰 결과 전송

3. **문제 발생 시 로그 확인:**
   ```bash
   # Atlantis 로그 확인
   aws logs tail /ecs/dev-atlantis --since 10m --region ap-northeast-2
   
   # Lambda 로그 확인  
   aws logs tail /aws/lambda/dev-atlantis-ai-reviewer --since 10m --region ap-northeast-2
   ```

## 🏗️ 생성되는 AWS 인프라

### 핵심 구성 요소
- **ECS Fargate 클러스터**: Atlantis 컨테이너 실행
- **Application Load Balancer**: GitHub Webhook 엔드포인트
- **S3 버킷**: Terraform Plan/Apply 결과 저장  
- **SQS Queue**: Plan/Apply 이벤트 처리 (Standard Queue)
- **Lambda Function**: UnifiedReviewerHandler (Java 21)
- **EFS**: Atlantis 데이터 영속성 (BoltDB)
- **CloudWatch**: 로깅 및 모니터링
- **Secrets Manager**: 민감한 정보 보관

### UnifiedReviewerHandler 특징
- **지능형 메시지 라우팅**: SQS 메시지 속성으로 Plan/Apply 자동 구분
- **통합 처리**: 기존 별도 핸들러를 하나로 통합하여 관리 효율성 증대
- **FIFO 호환**: Standard Queue와 FIFO Queue 모두 지원

## 📱 AI 리뷰 예시

### Terraform Plan 리뷰
```
🤖 AI Review - Terraform Plan

📊 변경 사항
• 생성: 5개 리소스
• 수정: 1개 리소스  
• 삭제: 0개 리소스
• 월 예상 비용: ~$35

🔍 주요 변경사항
• AWS RDS 인스턴스 생성 (db.t3.micro)
• VPC Security Group 규칙 업데이트
• S3 버킷 정책 수정

🛡️ 보안 검토
• RDS 암호화 활성화됨 ✅
• Security Group에 불필요한 0.0.0.0/0 규칙 없음 ✅
• S3 버킷 퍼블릭 액세스 차단됨 ✅

💰 비용 최적화 제안
• dev 환경에서 Multi-AZ 비활성화 고려
• 예약 인스턴스 활용 검토

✅ 승인 권장
변경사항이 AWS 모범사례를 준수하며 안전합니다.
```

### Terraform Apply 결과
```
✅ 배포 완료!

🏗️ 프로젝트: my-app
🌍 환경: dev

📊 변경사항
• 생성: 5개
• 수정: 1개
• 삭제: 0개

🤖 AI 요약
모든 리소스가 성공적으로 배포되었습니다. 
보안 설정이 적절히 구성되어 있으며, 
예상 비용 범위 내에서 운영 가능합니다.
```

## 💰 운영 비용 (월간)

| 리소스 | 예상 비용 | 설명 |
|--------|-----------|------|
| ECS Fargate | $15-25 | Atlantis 컨테이너 (512 CPU, 1GB Memory) |
| ALB | $16 | Application Load Balancer |
| EFS | $1-3 | Atlantis 데이터 저장소 (BoltDB) |
| Lambda | $0-2 | UnifiedReviewerHandler 실행 |
| S3 | $1-5 | Plan/Apply 결과 저장 |
| SQS/SNS | $0-1 | 메시징 서비스 |
| **총 예상** | **$33-52** | 월간 운영 비용 |

## 🔧 고급 설정

### AI 프롬프트 커스터마이징
```bash
# UnifiedReviewerHandler 수정
vi ai-reviewer/src/main/java/com/stackkit/atlantis/reviewer/UnifiedReviewerHandler.java

# 재빌드 및 배포
cd ai-reviewer && ./build.sh
cd ../terraform/stacks/atlantis-ai-reviewer-dev-us-east-1
terraform apply
```

### Atlantis 정책 설정
```yaml
# atlantis/repos.yaml
repos:
- id: github.com/myorg/my-repo
  apply_requirements: [approved, mergeable]
  allowed_overrides: [apply_requirements]
  allow_custom_workflows: true
```

### 기존 리소스 재사용
```hcl
# terraform.tfvars
use_existing_vpc = true
existing_vpc_id = "vpc-0123456789abcdef0"
existing_public_subnet_ids = ["subnet-pub1", "subnet-pub2"]

use_existing_s3_bucket = true
existing_s3_bucket_name = "my-atlantis-bucket"
```

## ✅ 배포 성공 확인

배포가 완료되면 다음 사항들을 확인하여 정상 작동을 검증합니다:

### 1. 인프라 상태 확인
```bash
# ECS 서비스 상태 (ACTIVE, 1/1 실행 중이어야 함)
aws ecs describe-services --cluster dev-atlantis --services atlantis --region ap-northeast-2 \
  --query 'services[0].{Status:status,RunningCount:runningCount,DesiredCount:desiredCount}' --output table

# ALB 타겟 그룹 상태 (healthy 상태여야 함)
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups --names "dev-atlantis-tg" --region ap-northeast-2 \
    --query 'TargetGroups[0].TargetGroupArn' --output text) --region ap-northeast-2

# Atlantis 웹 UI 접속 테스트 (HTTP 200 응답)
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://dev-atlantis-alb-xxxxx.ap-northeast-2.elb.amazonaws.com
```

### 2. 로그 확인
```bash
# Atlantis 정상 시작 로그 확인
aws logs tail /ecs/dev-atlantis --since 5m --region ap-northeast-2 | grep "Atlantis started"

# 예상 출력: "Atlantis started - listening on port 4141"
```

### 3. 리소스 명명 규칙 확인
모든 리소스가 `환경-프로젝트-리소스명` 형식으로 생성되었는지 확인:
- ✅ Lambda: `dev-atlantis-ai-reviewer`
- ✅ SQS 큐: `dev-atlantis-ai-reviews`
- ✅ ECS 클러스터: `dev-atlantis`
- ✅ ALB: `dev-atlantis-alb-xxxxx`
- ✅ 로그 그룹: `/ecs/dev-atlantis`

### 4. 접속 정보
```bash
# Terraform 출력에서 접속 정보 확인
terraform output -json | jq -r '.atlantis_url.value'
# 출력 예: http://dev-atlantis-alb-341663552.ap-northeast-2.elb.amazonaws.com
```

## 🔄 기존 프로젝트 통합

```bash
# 기존 Terraform 프로젝트에 AI 리뷰 추가
./scripts/integrate-existing-project.sh \
    --project-dir=/path/to/your/terraform/project \
    --atlantis-url=http://dev-atlantis-alb-xxxxx.ap-northeast-2.elb.amazonaws.com \
    --import-existing

# 생성된 가이드 확인
cat /path/to/your/terraform/project/STACKKIT_INTEGRATION_GUIDE.md
```

## 🔗 GitHub Webhook 설정

배포가 완료되면 GitHub Repository에 Webhook을 설정하여 PR에서 자동 AI 리뷰를 활성화합니다:

### 1. Atlantis URL 확인
```bash
# Terraform 출력에서 Atlantis URL 확인
terraform output atlantis_url
# 예: http://dev-atlantis-alb-341663552.ap-northeast-2.elb.amazonaws.com
```

### 2. GitHub Webhook Secret 확인
```bash
# AWS Secrets Manager에서 Webhook Secret 확인
aws secretsmanager get-secret-value \
  --secret-id atlantis/dev/webhook-secret \
  --region ap-northeast-2 \
  --query 'SecretString' --output text
```

### 3. GitHub Repository Webhook 설정
1. **GitHub Repository → Settings → Webhooks → Add webhook**
2. **Payload URL**: `http://dev-atlantis-alb-xxxxx.ap-northeast-2.elb.amazonaws.com/events`
3. **Content type**: `application/json`
4. **Secret**: 위에서 확인한 webhook secret 입력
5. **Events 선택**:
   - ✅ Pull requests
   - ✅ Issue comments
   - ✅ Pull request reviews
   - ✅ Pull request review comments
   - ✅ Pushes
6. **Active** 체크 후 **Add webhook** 클릭

### 4. 연결 테스트
```bash
# Webhook 연결 상태 확인 (GitHub에서 Recent Deliveries 탭 확인)
# 또는 Atlantis 로그에서 webhook 수신 확인
aws logs tail /ecs/dev-atlantis --since 5m --region ap-northeast-2 | grep "webhook"
```

### 5. AI 리뷰 테스트
1. **테스트 PR 생성**: Terraform 파일을 수정하여 PR 생성
2. **Atlantis 명령어**: PR 코멘트에 `atlantis plan` 입력
3. **AI 리뷰 확인**: 몇 분 후 AI가 분석한 리뷰 코멘트 확인

### 6. 문제 해결
**Webhook이 동작하지 않을 때:**
```bash
# GitHub Webhook 전달 상태 확인 (GitHub Repository → Settings → Webhooks)
# Atlantis 로그 확인
aws logs tail /ecs/dev-atlantis --since 10m --region ap-northeast-2

# Lambda 함수 로그 확인 (AI 리뷰 처리)
aws logs tail /aws/lambda/dev-atlantis-ai-reviewer --since 10m --region ap-northeast-2

# SQS 큐 메시지 확인
aws sqs get-queue-attributes \
  --queue-url https://sqs.ap-northeast-2.amazonaws.com/ACCOUNT/dev-atlantis-ai-reviews \
  --attribute-names ApproximateNumberOfMessages --region ap-northeast-2
```

---