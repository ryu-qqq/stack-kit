# 🚀 StackKit 퀵스타트 가이드

**10분만에 중앙 집중식 Atlantis + AI 리뷰어를 구축하여 안전한 인프라 관리 시작!**

이 가이드는 중앙 Atlantis 서버 1개로 모든 프로젝트 레포지토리를 관리하며, StackKit 모듈을 재사용하는 방법을 안내합니다.

---

## 📋 사전 준비

### 1. 필수 도구 설치
```bash
# Terraform 설치 확인 (>= 1.7.0 필요)
terraform --version

# AWS CLI 설치 확인 (>= 2.0 필요)
aws --version

# jq 설치 확인 (JSON 처리용)
jq --version
```

### 2. AWS 자격증명 설정
```bash
# AWS 자격증명 설정
aws configure

# 권한 확인
aws sts get-caller-identity
```

### 3. 저장소 클론
```bash
git clone https://github.com/your-org/stackkit.git
cd stackkit
```

---

## 🏗️ 방법 1: 모듈만 사용하기 (간단한 설정)

기존 프로젝트에 StackKit 모듈만 추가하여 인프라를 구축합니다.

### Step 1: 스택 생성
```bash
# 새로운 애플리케이션 스택 생성
terraform/scripts/new-stack.sh my-app dev

# 생성된 디렉토리로 이동
cd terraform/stacks/my-app-dev-ap-northeast-2
```

### Step 2: VPC 모듈 추가
```bash
# main.tf에 VPC 모듈 추가
cat >> main.tf << 'EOF'

# VPC 모듈 - 네트워킹 기반
module "vpc" {
  source = "../../modules/vpc"
  
  project_name = "my-app"
  environment  = "dev"
  vpc_cidr     = "10.0.0.0/16"
  
  # Multi-AZ 구성
  availability_zones = ["ap-northeast-2a", "ap-northeast-2c"]
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]
  
  # NAT Gateway (dev는 단일, prod는 다중)
  enable_nat_gateway = true
  single_nat_gateway = true
  
  common_tags = local.common_tags
}
EOF
```

### Step 3: 인프라 배포
```bash
# Terraform 초기화
terraform init -backend-config=backend.hcl

# 계획 확인
terraform plan

# 배포 실행
terraform apply
```

**🎉 완료!** AWS VPC가 생성되었습니다.

---

## 💻 방법 2: 중앙 Atlantis + 프로젝트 레포 연동 (권장)

중앙 Atlantis 서버 1개가 모든 프로젝트 레포의 PR을 관리하는 효율적인 설정입니다.

### Step 1: 중앙 Atlantis 구축 (최초 1회)
```bash
# atlantis-infrastructure 전용 레포 생성 후 실행
./scripts/setup-atlantis-central.sh \
    --org-name=mycompany \
    --github-token=ghp_xxxxxxxxxxxx \
    --slack-webhook=https://hooks.slack.com/services/... \
    --openai-key=sk-xxxxxxxxxxxxxxxx \
    --allowlist="github.com/myorg/*"
```

**설치 과정** (약 10분):
- ✅ VPC, ECS, Lambda, S3 등 완전한 AWS 인프라 생성
- ✅ Java 17 기반 AI 리뷰어 Lambda 함수 생성  
- ✅ Atlantis 서버 ECS Fargate에 배포 (고가용성)
- ✅ 모든 허용된 레포의 PR을 처리할 수 있도록 설정
- ✅ 완전한 문서 및 관리 가이드 생성

### Step 2: 프로젝트 레포 연동
각 프로젝트 레포에서:
```bash
# StackKit 모듈 + 중앙 Atlantis 연동
./scripts/setup-project-repo.sh \
    --project-name=my-web-app \
    --type=web-app \
    --atlantis-url=http://your-atlantis-url \
    --s3-bucket=your-atlantis-s3-bucket
```

**결과**:
1. StackKit 모듈을 사용한 Terraform 구성 생성
2. 중앙 Atlantis와 연동하는 `atlantis.yaml` 생성
3. GitHub Webhook 설정 안내 (프로젝트별 1회)

---

## 💻 고급 시나리오: 웹 애플리케이션 스택

VPC 위에 웹 서버와 데이터베이스를 추가해보겠습니다.

### Step 1: EC2 웹 서버 추가
```bash
# main.tf에 EC2 모듈 추가
cat >> main.tf << 'EOF'

# EC2 웹 서버
module "web_servers" {
  source = "../../modules/ec2"
  
  project_name = "my-app"
  environment  = "dev"
  instance_type = "t3.micro"
  
  # Auto Scaling 설정
  min_size         = 1
  max_size         = 3
  desired_capacity = 1
  
  # 네트워킹
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnet_ids
  
  # 보안 그룹 규칙
  security_group_rules = [
    {
      type        = "ingress"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTP access"
    },
    {
      type        = "ingress"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTPS access"
    }
  ]
  
  common_tags = local.common_tags
}
EOF
```

### Step 2: RDS 데이터베이스 추가
```bash
# main.tf에 RDS 모듈 추가
cat >> main.tf << 'EOF'

# RDS 데이터베이스
module "database" {
  source = "../../modules/rds"
  
  project_name = "my-app"
  environment  = "dev"
  
  # 데이터베이스 설정
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"
  allocated_storage = 20
  
  # 데이터베이스 정보
  db_name  = "myapp"
  username = "admin"
  # 패스워드는 AWS Secrets Manager에서 자동 생성
  
  # 가용성 설정 (dev는 단일 AZ)
  multi_az = false
  backup_retention_period = 1
  backup_window = "03:00-04:00"
  
  # 네트워킹 (Private 서브넷에 배치)
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  # 보안 설정
  allowed_security_groups = [module.web_servers.security_group_id]
  
  common_tags = local.common_tags
}
EOF
```

### Step 3: 출력 값 추가
```bash
# outputs.tf에 출력 값 추가
cat >> outputs.tf << 'EOF'

# VPC 출력
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

# EC2 출력
output "web_server_security_group_id" {
  description = "Web server security group ID"
  value       = module.web_servers.security_group_id
}

output "load_balancer_dns" {
  description = "Load balancer DNS name"
  value       = module.web_servers.load_balancer_dns_name
}

# RDS 출력
output "database_endpoint" {
  description = "RDS database endpoint"
  value       = module.database.endpoint
}

output "database_secret_arn" {
  description = "Database password secret ARN"
  value       = module.database.password_secret_arn
}
EOF
```

### Step 4: 배포 및 확인
```bash
# 계획 확인
terraform plan

# 배포 실행
terraform apply

# 배포 결과 확인
terraform output
```

---

## ⚡ 고급 시나리오: 서버리스 애플리케이션

Lambda와 DynamoDB를 사용한 서버리스 스택을 구축해보겠습니다.

### Step 1: 새 스택 생성
```bash
# 서버리스 스택 생성
terraform/scripts/new-stack.sh my-serverless-app dev

cd terraform/stacks/my-serverless-app-dev-ap-northeast-2
```

### Step 2: DynamoDB 테이블 추가
```bash
# main.tf에 DynamoDB 모듈 추가
cat >> main.tf << 'EOF'

# DynamoDB 테이블
module "user_table" {
  source = "../../modules/dynamodb"
  
  project_name = "my-serverless-app"
  environment  = "dev"
  table_name   = "users"
  
  # 키 구성
  hash_key = "user_id"
  range_key = "created_at"
  
  # 속성 정의
  attributes = [
    {
      name = "user_id"
      type = "S"
    },
    {
      name = "created_at"
      type = "S"
    },
    {
      name = "email"
      type = "S"
    }
  ]
  
  # Global Secondary Index
  global_secondary_indexes = [
    {
      name            = "email-index"
      hash_key        = "email"
      projection_type = "ALL"
    }
  ]
  
  # 과금 모드 (dev는 on-demand)
  billing_mode = "PAY_PER_REQUEST"
  
  common_tags = local.common_tags
}
EOF
```

### Step 3: Lambda 함수 추가
```bash
# Lambda 함수용 코드 준비 (예시)
mkdir -p lambda-code
cat > lambda-code/app.py << 'EOF'
import json
import boto3
from datetime import datetime

dynamodb = boto3.resource('dynamodb')

def lambda_handler(event, context):
    table = dynamodb.Table('my-serverless-app-dev-users')
    
    # 사용자 생성 예시
    response = table.put_item(
        Item={
            'user_id': event.get('user_id', 'default'),
            'created_at': datetime.now().isoformat(),
            'email': event.get('email', 'test@example.com')
        }
    )
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'User created successfully',
            'response': response
        })
    }
EOF

# ZIP 파일 생성
cd lambda-code && zip -r ../api-handler.zip . && cd ..
```

```bash
# main.tf에 Lambda 모듈 추가
cat >> main.tf << 'EOF'

# Lambda 함수
module "api_function" {
  source = "../../modules/lambda"
  
  project_name  = "my-serverless-app"
  environment   = "dev"
  function_name = "api-handler"
  
  # 런타임 설정
  runtime = "python3.11"
  handler = "app.lambda_handler"
  filename = "./api-handler.zip"
  
  # 성능 설정
  memory_size = 128
  timeout     = 30
  
  # 환경 변수
  environment_variables = {
    DYNAMODB_TABLE = module.user_table.table_name
    AWS_REGION     = var.region
  }
  
  # DynamoDB 접근 권한
  additional_iam_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = module.user_table.table_arn
      }
    ]
  })
  
  common_tags = local.common_tags
}
EOF
```

### Step 4: API Gateway 추가 (선택사항)
```bash
# main.tf에 API Gateway 설정 추가 (간단한 예시)
cat >> main.tf << 'EOF'

# Lambda 함수에 API Gateway 권한 부여
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = module.api_function.function_name
  principal     = "apigateway.amazonaws.com"
}
EOF
```

---

## 🔧 도구 및 스크립트 활용

### 검증 도구 사용
```bash
# 전체 검증 (문법, 보안, 비용)
terraform/scripts/validate.sh my-app dev

# 보안 스캔만 실행
terraform/scripts/validate.sh my-app dev --security-only

# 비용 추정만 실행
terraform/scripts/validate.sh my-app dev --cost-only

# JSON 형식으로 결과 출력
terraform/scripts/validate.sh my-app dev --format=json
```

### 배포 스크립트 사용
```bash
# 계획 확인
terraform/scripts/deploy.sh my-app dev plan

# 대화형 배포
terraform/scripts/deploy.sh my-app dev apply

# 자동 승인 (dev/staging 권장)
terraform/scripts/deploy.sh my-app dev apply --auto-approve

# 백업과 함께 배포 (prod 권장)
terraform/scripts/deploy.sh my-app prod apply --backup-state
```

### 기존 리소스 Import
```bash
# VPC Import
terraform/scripts/import-resources.sh \
    ./terraform/stacks/my-app-dev \
    vpc \
    module.vpc.aws_vpc.main \
    vpc-0123456789abcdef0

# 보안 그룹 Import
terraform/scripts/import-resources.sh \
    ./terraform/stacks/my-app-dev \
    security_group \
    module.web_servers.aws_security_group.main \
    sg-0123456789abcdef0
```

---

## 🤖 중앙 Atlantis + AI 리뷰어 워크플로우 체험

방법 2에서 설정한 중앙 집중식 Atlantis + AI 리뷰어의 실제 워크플로우를 체험해봅시다.

### 워크플로우 흐름
1. **PR 생성**: 프로젝트 레포에서 Terraform 변경사항이 포함된 PR 생성
2. **중앙 Atlantis**: 허용된 레포의 PR을 감지하고 자동으로 `terraform plan` 실행
3. **AI 분석**: 중앙 AI 리뷰어가 GPT-4로 Plan 결과를 분석
4. **Slack 알림**: 모든 프로젝트의 분석 결과를 중앙에서 Slack으로 전송
5. **검토 및 Apply**: 검토 후 `atlantis apply` 명령으로 배포

### AI 리뷰 테스트
```bash
# 프로젝트 레포에서 테스트용 변경사항 추가
echo "# 중앙 AI 리뷰어 테스트 변경" >> terraform/stacks/my-web-app/dev/main.tf

# PR 생성
git add .
git commit -m "중앙 AI 리뷰어 테스트: 주석 추가"
git checkout -b feature/test-central-ai-review
git push origin feature/test-central-ai-review

# GitHub에서 PR 생성
# → 중앙 Atlantis가 자동으로 Plan 실행
# → 중앙 AI 리뷰어가 분석하고 Slack으로 결과 전송!
```

### AI 리뷰 결과 예시
Slack에서 받게 되는 메시지:
```
🤖 AI Review - Terraform Plan

📊 변경 사항
• 생성: 0개 리소스
• 수정: 0개 리소스  
• 삭제: 0개 리소스
• 월 예상 비용: $0

🔍 주요 변경사항
• 주석 추가 (코드 변경 없음)

✅ 승인 권장
인프라 변경이 없는 문서 업데이트입니다.

💰 비용 영향: 없음
🔒 보안 영향: 없음
```

### 실제 리소스 변경 시 예시
```
🤖 AI Review - Terraform Plan

📊 변경 사항
• 생성: 3개 리소스 (EC2, Security Group, ELB)
• 수정: 1개 리소스 (Auto Scaling Group)
• 삭제: 0개 리소스
• 월 예상 비용: +$45

🔍 주요 변경사항
• t3.micro → t3.small 인스턴스 타입 변경
• 새로운 보안 그룹 추가 (포트 443 허용)
• ELB 추가로 고가용성 확보

⚠️ 주의사항
• 비용이 월 $23에서 $68로 증가합니다
• 보안 그룹에 HTTPS 포트가 모든 IP에 열립니다

✅ 승인 권장 (조건부)
성능 향상이 예상되지만 비용 증가를 검토하세요.
```

---

## 📊 환경별 설정 가이드

### 개발 환경 (dev)
```hcl
# terraform.tfvars
environment = "dev"

# 비용 최적화
instance_type = "t3.micro"
db_instance_class = "db.t3.micro"
multi_az = false
backup_retention_period = 1

# 단순화
single_nat_gateway = true
enable_deletion_protection = false
```

### 스테이징 환경 (staging)  
```hcl
# terraform.tfvars
environment = "staging"

# 성능 향상
instance_type = "t3.small"
db_instance_class = "db.t3.small"
multi_az = false
backup_retention_period = 3

# 보안 강화
single_nat_gateway = false
enable_deletion_protection = true
```

### 프로덕션 환경 (prod)
```hcl
# terraform.tfvars
environment = "prod"

# 고성능
instance_type = "t3.medium"
db_instance_class = "db.t3.small"
multi_az = true
backup_retention_period = 7

# 최대 보안 및 가용성
single_nat_gateway = false
enable_deletion_protection = true
enable_enhanced_monitoring = true
```

---

## 💰 비용 최적화 팁

### 환경별 리소스 크기 조정
```hcl
# variables.tf에 환경별 변수 추가
variable "instance_configs" {
  type = map(object({
    instance_type = string
    min_size      = number
    max_size      = number
  }))
  
  default = {
    dev = {
      instance_type = "t3.micro"
      min_size     = 1
      max_size     = 2
    }
    staging = {
      instance_type = "t3.small"
      min_size     = 1
      max_size     = 3
    }
    prod = {
      instance_type = "t3.medium"
      min_size     = 2
      max_size     = 10
    }
  }
}

# main.tf에서 사용
instance_type = var.instance_configs[var.environment].instance_type
min_size     = var.instance_configs[var.environment].min_size
max_size     = var.instance_configs[var.environment].max_size
```

### 예상 비용 (월간)

| 환경 | EC2 | RDS | Lambda | 총합 |
|------|-----|-----|--------|------|
| **dev** | ~$8 | ~$15 | ~$0 | **~$23** |
| **staging** | ~$25 | ~$30 | ~$1 | **~$56** |
| **prod** | ~$50 | ~$60 | ~$2 | **~$112** |

### 비용 모니터링
```bash
# 비용 추정 확인
terraform/scripts/validate.sh my-app dev --cost-only

# Infracost 상세 보고서
infracost breakdown --path ./terraform/stacks/my-app-dev-ap-northeast-2
```

---

## 🚨 문제 해결

### 일반적인 오류들

#### 1. AWS 자격증명 오류
```bash
# 현재 자격증명 확인
aws sts get-caller-identity

# 권한 확인
aws iam list-attached-user-policies --user-name your-username

# 새 프로필 설정
aws configure --profile stackkit
export AWS_PROFILE=stackkit
```

#### 2. Terraform 상태 잠금 오류
```bash
# 잠금 상태 확인
aws dynamodb scan --table-name stackkit-tf-lock

# 잠금 해제
terraform force-unlock <LOCK_ID>

# 상태 파일 복구
terraform state pull > backup.tfstate
```

#### 3. 모듈 초기화 오류
```bash
# 모듈 캐시 정리
rm -rf .terraform

# 플러그인 캐시 정리
rm -rf ~/.terraform.d/plugin-cache

# 재초기화
terraform init -upgrade
```

#### 4. 리소스 생성 실패
```bash
# 상세 로그 확인
TF_LOG=DEBUG terraform apply

# 특정 리소스만 재생성
terraform apply -replace=module.vpc.aws_vpc.main

# 단계별 적용
terraform apply -target=module.vpc
terraform apply -target=module.ec2
```

#### 5. 비용 초과
```bash
# 현재 비용 확인
aws ce get-cost-and-usage --time-period Start=2024-01-01,End=2024-01-31

# 리소스 크기 축소
vi terraform.tfvars  # instance_type을 더 작은 크기로 변경

# 불필요한 리소스 제거
terraform destroy -target=module.expensive_resource
```

---

## 📚 다음 단계

### 고급 기능 활용
1. **멀티 모듈 조합**: VPC + EC2 + RDS + Lambda를 조합한 풀스택 애플리케이션
2. **환경별 설정**: dev/staging/prod 환경별 최적화된 설정
3. **모니터링 추가**: CloudWatch, X-Ray를 활용한 관찰 가능성
4. **보안 강화**: WAF, Shield, GuardDuty를 활용한 보안 계층

## 🚀 GitHub Actions 자동 검증 설정 (권장)

모든 PR에서 자동으로 Terraform 검증과 비용 추정을 수행하도록 설정하세요.

### ⚡ 5분 설정
```bash
# 1. 워크플로우 템플릿 복사
mkdir -p .github/workflows
cp .github/workflow-templates/terraform-validation.yml .github/workflows/
cp .github/workflow-templates/terraform-pr-plan.yml .github/workflows/

# 2. GitHub Repository Secrets 설정 (Settings → Secrets → Actions)
# AWS_ROLE_ARN="arn:aws:iam::123456789012:role/GitHubActionsRole"  
# INFRACOST_API_KEY="ico-xxxxxxxxxxxxxxxx" (선택사항)

# 3. 커밋 후 PR 생성
git add .github/workflows/
git commit -m "Add StackKit Terraform validation workflows"
git push origin main
```

### 🎯 자동 검증 기능
- ✅ **Terraform 코드 검증**: Format, Validate, Plan 자동 실행
- 💰 **비용 추정**: Infracost로 인프라 비용 자동 계산
- 🛡️ **보안 검사**: StackKit 보안 정책 자동 검증
- 📊 **PR 코멘트**: 상세한 결과를 PR에 자동으로 추가
- 🚨 **실패 알림**: 문제 발생 시 즉시 알림

**📚 상세 설정 가이드**: [GitHub Actions 가이드](./docs/GITHUB_ACTIONS_GUIDE.md)

---

### 문서 및 가이드
- 📖 **메인 문서**: [README.md](./README.md)
- 🚀 **GitHub Actions 자동 검증**: [docs/GITHUB_ACTIONS_GUIDE.md](./docs/GITHUB_ACTIONS_GUIDE.md)
- 🤖 **중앙 Atlantis 설정**: `./scripts/setup-atlantis-central.sh --help`
- 🚀 **프로젝트 레포 연동**: `./scripts/setup-project-repo.sh --help`
- 📦 **기존 리소스 Import**: [terraform/docs/IMPORT_GUIDE.md](./terraform/docs/IMPORT_GUIDE.md)
- 🔧 **모듈 상세 사용법**: 각 모듈의 `README.md` 파일

### 커뮤니티
- **GitHub Issues**: 버그 리포트 및 기능 요청
- **팀 채널**: `#infrastructure-support`
- **기여하기**: Pull Request를 통한 개선 사항 제안

---