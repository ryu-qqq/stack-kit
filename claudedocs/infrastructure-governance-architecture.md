# 🏗️ StackKit 기반 조직 인프라 거버넌스 아키텍처

## 📊 현재 상황 분석 및 평가

### StackKit-Terraform 패키지 준비도 평가

#### ✅ **거버넌스에 적합한 기능들**
1. **모듈화된 구조** - 재사용 가능한 표준 모듈
2. **정책 검증 시스템** - OPA + Shell 가드
3. **엔터프라이즈 기능** - 멀티테넌트, 팀 경계
4. **CI/CD 파이프라인** - GitHub Actions 검증

#### ❌ **부족한 부분들**
1. **중앙 거버넌스 메커니즘** - 프로젝트 간 정책 강제 부재
2. **모듈 버전 관리** - 버전 태깅 및 릴리즈 프로세스 없음
3. **프로젝트 격리** - 프로젝트별 권한 및 리소스 제한 미흡
4. **표준화된 인터페이스** - 일관된 모듈 사용 패턴 부재

---

## 🎯 권장 아키텍처: Hub-and-Spoke 모델

### 구조 개요

```
┌─────────────────────────────────────────────────────────┐
│                  중앙 인프라 레포지토리                   │
│                 (stackkit-terraform)                     │
├─────────────────────────────────────────────────────────┤
│  • 공유 인프라 (VPC, RDS, ECS Cluster)                  │
│  • 표준 모듈 라이브러리                                  │
│  • 거버넌스 정책 및 검증 규칙                           │
│  • 모듈 버전 관리 및 릴리즈                             │
└────────────┬───────────────────────┬────────────────────┘
             │                       │
    ┌────────▼────────┐    ┌────────▼────────┐
    │  프로젝트 A 레포  │    │  프로젝트 B 레포  │
    ├─────────────────┤    ├─────────────────┤
    │ • 프로젝트 전용  │    │ • 프로젝트 전용  │
    │   인프라 정의    │    │   인프라 정의    │
    │ • 중앙 모듈 참조 │    │ • 중앙 모듈 참조 │
    │ • 환경별 변수    │    │ • 환경별 변수    │
    └─────────────────┘    └─────────────────┘
```

---

## 📁 레포지토리 구조 설계

### 1. 중앙 인프라 레포 (stackkit-terraform)

```
stackkit-terraform/
├── shared-infrastructure/        # 공유 인프라
│   ├── networking/               # 공유 VPC, Transit Gateway
│   │   ├── main.tf
│   │   ├── outputs.tf           # 다른 프로젝트에서 참조할 출력값
│   │   └── remote-state.tf       # Remote state 설정
│   ├── databases/                # 공유 RDS, ElastiCache
│   ├── container-platform/       # 공유 ECS/EKS 클러스터
│   └── security/                 # 공유 보안 그룹, IAM 역할
│
├── modules/                      # 표준 모듈 라이브러리
│   ├── compute/
│   ├── networking/
│   └── storage/
│
├── governance/                   # 거버넌스 및 정책
│   ├── policies/                 # OPA 정책
│   │   ├── cost-control.rego    # 비용 통제
│   │   ├── security.rego        # 보안 정책
│   │   └── compliance.rego      # 컴플라이언스
│   ├── validation/               # 검증 스크립트
│   └── templates/                # 프로젝트 템플릿
│
└── .github/
    └── workflows/
        ├── module-release.yml    # 모듈 버전 릴리즈
        └── shared-infra-deploy.yml # 공유 인프라 배포
```

### 2. 프로젝트별 레포 구조

```
project-a-infrastructure/
├── .terraform-version            # Terraform 버전 고정
├── atlantis.yaml                 # Atlantis 설정
├── terragrunt.hcl               # Terragrunt 설정 (선택사항)
│
├── environments/
│   ├── dev/
│   │   ├── backend.tf           # Remote state 설정
│   │   ├── provider.tf          # Provider 설정
│   │   ├── main.tf              # 인프라 정의
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── data.tf              # 공유 인프라 참조
│   ├── staging/
│   └── prod/
│
├── modules/                      # 프로젝트 전용 모듈 (필요시)
│   └── custom-service/
│
└── .github/
    └── workflows/
        └── terraform-deploy.yml  # 프로젝트 배포 파이프라인
```

---

## 🔧 구현 방법

### Step 1: 공유 인프라 Remote State 설정

```hcl
# shared-infrastructure/networking/remote-state.tf
terraform {
  backend "s3" {
    bucket         = "company-terraform-state"
    key            = "shared/networking/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

# shared-infrastructure/networking/outputs.tf
output "vpc_id" {
  value       = aws_vpc.shared.id
  description = "Shared VPC ID"
}

output "private_subnet_ids" {
  value       = aws_subnet.private[*].id
  description = "Private subnet IDs"
}

output "public_subnet_ids" {
  value       = aws_subnet.public[*].id
  description = "Public subnet IDs"
}
```

### Step 2: 프로젝트에서 공유 인프라 참조

```hcl
# project-a-infrastructure/environments/dev/data.tf
data "terraform_remote_state" "shared_vpc" {
  backend = "s3"
  config = {
    bucket = "company-terraform-state"
    key    = "shared/networking/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "shared_ecs" {
  backend = "s3"
  config = {
    bucket = "company-terraform-state"
    key    = "shared/container-platform/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# project-a-infrastructure/environments/dev/main.tf
module "application" {
  source = "git::https://github.com/company/stackkit-terraform.git//modules/compute/ecs-service?ref=v1.2.0"
  
  # 공유 인프라 참조
  vpc_id             = data.terraform_remote_state.shared_vpc.outputs.vpc_id
  subnet_ids         = data.terraform_remote_state.shared_vpc.outputs.private_subnet_ids
  ecs_cluster_id     = data.terraform_remote_state.shared_ecs.outputs.cluster_id
  
  # 프로젝트별 설정
  service_name       = "project-a-api"
  container_image    = "company/project-a:${var.image_tag}"
  
  # 표준 태그
  tags = local.common_tags
}
```

### Step 3: 모듈 버전 관리

```hcl
# 모듈 참조 시 버전 태그 사용
module "rds" {
  source = "git::https://github.com/company/stackkit-terraform.git//modules/database/rds?ref=v1.2.0"
  # ...
}

# 또는 Terraform Registry 사용
module "vpc" {
  source  = "company/vpc/aws"
  version = "1.2.0"
  # ...
}
```

---

## 🚨 거버넌스 정책 및 검증

### 1. 강화된 OPA 정책

```rego
# governance/policies/project-limits.rego
package terraform.project_limits

# 프로젝트별 리소스 제한
max_instances_per_project := 10
max_rds_instances := 2
max_s3_buckets := 5

# EC2 인스턴스 개수 제한
deny[msg] {
  count([r | r := input.resource_changes[_]; r.type == "aws_instance"]) > max_instances_per_project
  msg := sprintf("Project cannot have more than %d EC2 instances", [max_instances_per_project])
}

# 인스턴스 타입 제한
allowed_instance_types := {
  "dev": ["t3.micro", "t3.small", "t3.medium"],
  "staging": ["t3.small", "t3.medium", "t3.large"],
  "prod": ["t3.medium", "t3.large", "t3.xlarge", "m5.large", "m5.xlarge"]
}

deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_instance"
  environment := resource.change.after.tags.Environment
  instance_type := resource.change.after.instance_type
  not instance_type in allowed_instance_types[environment]
  msg := sprintf("Instance type %s not allowed in %s environment", [instance_type, environment])
}

# 필수 태그 검증
required_tags := {
  "Project",
  "Team",
  "Environment",
  "CostCenter",
  "Owner",
  "ManagedBy"
}

deny[msg] {
  resource := input.resource_changes[_]
  resource.mode == "managed"
  tags := resource.change.after.tags
  missing := required_tags - {k | tags[k]}
  count(missing) > 0
  msg := sprintf("Resource %s.%s missing required tags: %v", [resource.type, resource.name, missing])
}
```

### 2. Pre-commit 훅 설정

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: terraform-fmt
        name: Terraform fmt
        entry: terraform fmt -recursive
        language: system
        files: \.tf$
        
      - id: validate-module-source
        name: Validate module sources
        entry: scripts/validate-module-sources.sh
        language: script
        files: \.tf$
        
      - id: check-remote-state
        name: Check remote state configuration
        entry: scripts/check-remote-state.sh
        language: script
        files: backend\.tf$
```

### 3. CI/CD 파이프라인

```yaml
# .github/workflows/terraform-governance.yml
name: Terraform Governance Pipeline

on:
  pull_request:
    branches: [main]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        
      - name: Check module versions
        run: |
          # 모든 모듈이 버전 태그를 사용하는지 확인
          if grep -r "source.*stackkit-terraform.git" . | grep -v "ref="; then
            echo "Error: All module sources must use version tags"
            exit 1
          fi
          
      - name: Validate against central policies
        run: |
          # 중앙 레포에서 최신 정책 가져오기
          git clone https://github.com/company/stackkit-terraform.git /tmp/central
          
          # OPA 정책 검증
          opa test /tmp/central/governance/policies
          
      - name: Cost estimation
        run: |
          # Infracost로 비용 추정
          infracost breakdown --path . \
            --format json \
            --out-file /tmp/infracost.json
            
          # 비용 임계값 확인
          cost=$(jq '.totalMonthlyCost' /tmp/infracost.json)
          if (( $(echo "$cost > 1000" | bc -l) )); then
            echo "Error: Estimated cost $cost exceeds limit"
            exit 1
          fi
          
      - name: Security scan
        run: |
          # Checkov 보안 스캔
          checkov -d . --framework terraform --soft-fail
          
          # tfsec 스캔
          tfsec . --soft-fail
```

---

## 🔐 접근 제어 및 권한 관리

### 1. AWS IAM 역할 기반 접근

```hcl
# 프로젝트별 IAM 역할
resource "aws_iam_role" "project_deployer" {
  name = "${var.project_name}-terraform-deployer"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      }
      Condition = {
        StringEquals = {
          "aws:PrincipalTag/Team": var.team_name
        }
      }
    }]
  })
}

# 프로젝트별 권한 경계
resource "aws_iam_policy" "project_boundary" {
  name = "${var.project_name}-boundary"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "ecs:*",
          "s3:*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/Project": var.project_name
          }
        }
      },
      {
        Effect = "Deny"
        Action = [
          "ec2:TerminateInstances",
          "rds:DeleteDBInstance"
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:RequestTag/Environment": "dev"
          }
        }
      }
    ]
  })
}
```

### 2. Atlantis 프로젝트별 설정

```yaml
# atlantis.yaml
version: 3
automerge: false
delete_source_branch_on_merge: true

projects:
  - name: project-a-dev
    dir: environments/dev
    workspace: default
    terraform_version: v1.7.5
    autoplan:
      when_modified: ["*.tf", "*.tfvars"]
      enabled: true
    apply_requirements: [approved, mergeable]
    import_requirements: [approved, mergeable]
    workflow: restricted
    
  - name: project-a-prod
    dir: environments/prod
    workspace: default
    terraform_version: v1.7.5
    apply_requirements: [approved, mergeable]
    workflow: production

workflows:
  restricted:
    plan:
      steps:
        - init
        - plan
        - run: opa test -v policies/
        - run: infracost breakdown --path .
        
  production:
    plan:
      steps:
        - init
        - plan
        - run: opa test -v policies/
        - run: infracost breakdown --path .
        - run: checkov -d .
    apply:
      steps:
        - run: echo "Production deployment - requires manual approval"
        - apply
```

---

## 📊 모니터링 및 감사

### 1. 인프라 변경 추적

```hcl
# CloudTrail 로깅
resource "aws_cloudtrail" "terraform_audit" {
  name                          = "terraform-audit-trail"
  s3_bucket_name               = aws_s3_bucket.audit_logs.id
  include_global_service_events = true
  is_multi_region_trail        = true
  enable_logging               = true
  
  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }
  
  tags = {
    Purpose = "Terraform audit logging"
  }
}

# EventBridge 룰 - 인프라 변경 알림
resource "aws_cloudwatch_event_rule" "infra_changes" {
  name        = "terraform-infrastructure-changes"
  description = "Capture all Terraform infrastructure changes"
  
  event_pattern = jsonencode({
    source = ["aws.ec2", "aws.rds", "aws.s3"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventName = [
        "RunInstances",
        "TerminateInstances",
        "CreateDBInstance",
        "DeleteDBInstance"
      ]
    }
  })
}
```

### 2. 비용 추적 대시보드

```hcl
# Cost Explorer 태그 기반 비용 추적
resource "aws_ce_cost_category" "projects" {
  name = "project-cost-tracking"
  
  rule {
    value = "project-a"
    rule {
      tags {
        key    = "Project"
        values = ["project-a"]
      }
    }
  }
  
  rule {
    value = "project-b"
    rule {
      tags {
        key    = "Project"
        values = ["project-b"]
      }
    }
  }
}
```

---

## 🚀 실행 로드맵

### Phase 1: 기반 구축 (Week 1-2)
1. **중앙 레포 구조 개선**
   - 공유 인프라 디렉토리 생성
   - 거버넌스 정책 디렉토리 구성
   - 모듈 버전 태깅 시작

2. **공유 인프라 배포**
   - VPC, 서브넷 생성
   - ECS/EKS 클러스터 구축
   - Remote State 설정

### Phase 2: 프로젝트 템플릿 (Week 3)
1. **프로젝트 템플릿 생성**
   ```bash
   # 프로젝트 생성 스크립트
   ./create-project.sh \
     --name project-a \
     --team backend-team \
     --environments "dev,staging,prod"
   ```

2. **표준 구조 생성**
   - atlantis.yaml
   - 환경별 디렉토리
   - Backend 설정

### Phase 3: 거버넌스 구현 (Week 4)
1. **정책 작성**
   - OPA 정책 구현
   - 비용 제한 설정
   - 보안 규칙 정의

2. **CI/CD 파이프라인**
   - GitHub Actions 워크플로우
   - Pre-commit 훅
   - 자동 검증

### Phase 4: 모니터링 (Week 5)
1. **감사 시스템**
   - CloudTrail 설정
   - EventBridge 알림
   - 로그 수집

2. **대시보드 구축**
   - 비용 추적
   - 리소스 사용량
   - 컴플라이언스 상태

---

## ✅ 체크리스트

### 거버넌스 준비도
- [ ] 중앙 인프라 레포 구성
- [ ] 공유 인프라 배포
- [ ] Remote State 설정
- [ ] 모듈 버전 관리
- [ ] OPA 정책 구현
- [ ] CI/CD 파이프라인
- [ ] 접근 제어 설정
- [ ] 모니터링 시스템

### 프로젝트 온보딩
- [ ] 프로젝트 템플릿 준비
- [ ] 팀별 IAM 역할
- [ ] Atlantis 설정
- [ ] 문서화
- [ ] 교육 자료

---

## 💡 핵심 권장사항

### 1. **점진적 도입**
- 파일럿 프로젝트로 시작
- 피드백 수집 및 개선
- 전사 확대

### 2. **자동화 우선**
- 수동 프로세스 최소화
- 정책 자동 검증
- 자동 문서화

### 3. **교육 및 지원**
- 정기 워크샵
- 베스트 프랙티스 공유
- 내부 챔피언 육성

### 4. **지속적 개선**
- 월간 거버넌스 리뷰
- 정책 업데이트
- 도구 개선

---

## 🎯 결론

현재 stackkit-terraform은 **기본적인 구조는 갖추었지만**, 조직 전체의 인프라 거버넌스를 위해서는 다음이 필요합니다:

1. **중앙 집중식 공유 인프라 관리**
2. **엄격한 거버넌스 정책 및 자동 검증**
3. **프로젝트별 격리 및 권한 관리**
4. **표준화된 프로젝트 구조 및 워크플로우**
5. **지속적인 모니터링 및 감사**

이 아키텍처를 구현하면 **개발자들이 자유롭게 인프라를 구성하되, 조직의 정책과 표준을 자동으로 준수**하게 됩니다.