# 🏷️ StackKit 표준 변수명 가이드

Terraform 프로젝트 전체에서 일관된 변수명 사용을 위한 표준 가이드입니다.

---

## 🎯 핵심 원칙

### 1. 일관성 (Consistency)
- **하나의 개념은 하나의 변수명**으로 통일
- 프로젝트 전체에서 동일한 이름 사용
- 약어보다는 명확한 단어 선호

### 2. 명확성 (Clarity)
- 변수의 목적이 이름으로 명확히 드러남
- 타입과 용도를 변수명에서 유추 가능
- 혼동될 수 있는 유사한 이름 지양

### 3. 확장성 (Scalability)
- 새로운 환경이나 서비스 추가 시에도 일관성 유지
- Hierarchical naming으로 구조화
- Future-proof naming

---

## 📋 표준 변수명 목록

### 🌍 기본 환경 변수

| 변수명 | 타입 | 설명 | 예시 값 |
|--------|------|------|---------|
| `org_name` | `string` | **조직/회사 이름** | `connectly`, `mycompany` |
| `environment` | `string` | **환경 구분자** | `dev`, `staging`, `prod` |
| `aws_region` | `string` | **AWS 리전** (region ❌) | `ap-northeast-2`, `us-east-1` |
| `stack_name` | `string` | **스택 식별자** | `connectly-atlantis-prod` |

### 🔐 보안 및 인증

| 변수명 | 타입 | 설명 | 예시 값 |
|--------|------|------|---------|
| `secret_name` | `string` | **Secrets Manager 시크릿 이름** | `connectly-atlantis-prod` |
| `github_token` | `string` | **GitHub Personal Access Token** | `ghp_xxxxxxxxxxxx` (sensitive) |
| `webhook_secret` | `string` | **GitHub 웹훅 시크릿** | auto-generated (sensitive) |

### 🌐 네트워킹

| 변수명 | 타입 | 설명 | 예시 값 |
|--------|------|------|---------|
| `custom_domain` | `string` | **사용자 정의 도메인** | `atlantis.company.com` |
| `certificate_arn` | `string` | **SSL 인증서 ARN** | `arn:aws:acm:...` |
| `existing_vpc_id` | `string` | **기존 VPC ID (재사용 시)** | `vpc-0f162b9e588276e09` |
| `existing_public_subnet_ids` | `list(string)` | **기존 퍼블릭 서브넷 ID 목록** | `["subnet-abc123", "subnet-def456"]` |
| `existing_private_subnet_ids` | `list(string)` | **기존 프라이빗 서브넷 ID 목록** | `["subnet-ghi789", "subnet-jkl012"]` |

### ⚙️ 인프라 옵션

| 변수명 | 타입 | 설명 | 기본값 |
|--------|------|------|--------|
| `use_existing_vpc` | `bool` | **기존 VPC 사용 여부** | `false` |
| `use_existing_ecs_cluster` | `bool` | **기존 ECS 클러스터 사용 여부** | `false` |
| `use_existing_alb` | `bool` | **기존 ALB 사용 여부** | `false` |

### 🐙 Git 관련

| 변수명 | 타입 | 설명 | 예시 값 |
|--------|------|------|---------|
| `git_username` | `string` | **Git 사용자명** | `connectly-atlantis` |
| `git_hostname` | `string` | **Git 호스트명** | `github.com` |
| `repo_allowlist` | `list(string)` | **허용된 저장소 패턴 목록** | `["github.com/myorg/*"]` |

### 💰 비용 관리

| 변수명 | 타입 | 설명 | 예시 값 |
|--------|------|------|---------|
| `infracost_api_key` | `string` | **Infracost API 키 (선택사항)** | `ico-xxx...` (sensitive) |

---

## ❌ 사용하지 말아야 할 변수명

### 🔴 금지된 변수명

| ❌ 사용 금지 | ✅ 대신 사용 | 이유 |
|------------|-----------|-----|
| `region` | `aws_region` | **AWS 리전임을 명확히 표시** |
| `env` | `environment` | **약어보다 명확한 단어** |
| `org` | `org_name` | **조직의 이름임을 명확히** |
| `domain` | `custom_domain` | **사용자 정의 도메인임을 명시** |
| `vpc_id` | `existing_vpc_id` | **기존 리소스 재사용임을 명시** |
| `cluster_name` | `existing_ecs_cluster_name` | **기존 ECS 클러스터임을 명시** |

### 🟡 주의해야 할 패턴

| ⚠️ 주의 | 문제점 | 권장사항 |
|--------|-------|---------|
| `*_arn` vs `*_id` | **혼동 가능성** | ARN인지 ID인지 명확히 구분 |
| `enable_*` vs `use_*` | **의미 차이** | enable: 기능 활성화, use: 기존 리소스 사용 |
| `bucket` vs `bucket_name` | **타입 불명확** | `bucket_name`으로 문자열임을 명시 |

---

## 📂 파일별 변수명 표준

### terraform.tfvars
```hcl
# ✅ 표준 순서
# 1. 기본 환경 변수
org_name     = "connectly"
environment  = "prod"
aws_region   = "ap-northeast-2"
stack_name   = "connectly-atlantis-prod"

# 2. 보안 설정
secret_name = "connectly-atlantis-prod"

# 3. 도메인 설정
custom_domain   = ""
certificate_arn = ""

# 4. GitHub 설정
git_username    = "connectly-atlantis"
repo_allowlist  = [
    "github.com/myorg/*",
]

# 5. 인프라 옵션
use_existing_vpc         = true
use_existing_ecs_cluster = false
use_existing_alb         = false

# 6. VPC 설정 (기존 VPC 사용 시)
existing_vpc_id = "vpc-0f162b9e588276e09"
existing_public_subnet_ids = ["subnet-abc123", "subnet-def456"]
existing_private_subnet_ids = ["subnet-ghi789", "subnet-jkl012"]

# 7. 추가 옵션
infracost_api_key = ""
```

### variables.tf
```hcl
# ✅ 변수 선언 표준
variable "aws_region" {
  type        = string
  description = "AWS region for deployment"
  # default 값은 가급적 지양, terraform.tfvars 사용 권장
}

variable "environment" { 
  type        = string
  description = "Environment name (dev/staging/prod)"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}
```

### versions.tf
```hcl
# ✅ Provider 설정 표준
provider "aws" {
  region = var.aws_region  # ❌ var.region 사용 금지
}
```

---

## 🔄 마이그레이션 가이드

### 기존 프로젝트에서 신규 표준으로 전환

1. **변수명 일괄 변경**
   ```bash
   # region을 aws_region으로 전체 변경
   find . -name "*.tf" -o -name "*.tfvars" | xargs sed -i 's/var\.region/var.aws_region/g'
   find . -name "*.tf" -o -name "*.tfvars" | xargs sed -i 's/region\s*=/aws_region =/g'
   ```

2. **검증**
   ```bash
   # 변경 후 terraform plan으로 검증
   terraform plan
   
   # 추가 변경 사항 확인
   grep -r "region\s*=" . --include="*.tf" --include="*.tfvars"
   ```

3. **점진적 적용**
   - 개발 환경부터 적용
   - 스테이징 검증 후 프로덕션 적용
   - 각 단계별 동작 확인

---

## 🎯 핵심 요약

### ✅ DO (해야 할 것)
- **`aws_region`** 사용 (region ❌)
- **`org_name`** 사용 (org ❌)
- **`environment`** 사용 (env ❌)
- **`existing_*`** 접두어로 기존 리소스 표시
- **일관된 naming convention** 유지

### ❌ DON'T (하지 말 것)
- 약어나 축약형 변수명
- 같은 개념에 다른 변수명 사용
- 타입이나 용도가 모호한 변수명
- 혼동될 수 있는 유사한 변수명

---

## 📞 문의 및 제안

변수명 표준에 대한 문의나 개선 제안이 있으시면:
- **GitHub Issues**: https://github.com/your-org/stackkit/issues
- **문서 업데이트**: 이 파일을 직접 수정하여 PR 제출

---

**마지막 업데이트**: 2024년 기준  
**적용 범위**: StackKit 전체 프로젝트