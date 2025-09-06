# Terraform 운영 가이드 (dev/prod · StackKit)

## 📁 리포 구조
```
terraform/
  modules/           # 재사용 모듈(⚠ provider/backend 선언 금지)
    ec2/ ecs/ rds/ s3/ sns/ sqs/ vpc/ dynamodb/ ...
  policies/
    terraform.rego   # OPA Conftest 정책(태그/보안/데이터소스 가드)
  stacks/
    <서비스별-스택들>/  # stackkit-cli로 생성 (backend.hcl 포함)
  tools/
    stackkit-cli.sh  # 스택 생성/검증/플랜/적용 헬퍼
    tf_forbidden.sh  # 정적 가드(쉘): 금지 규칙/필수 파일 검사
.github/
  workflows/
    tf-pr.yml        # PR 검증(쉘 가드+OPA, plan, 코멘트, 아티팩트)
    tf-apply-dev.yml # main 머지 → dev 자동 적용
    tf-apply-prod.yml# 수동 승인 후 prod 적용
```

---

## 🔑 사전 준비(1회)

### 1) 상태 저장 리소스(S3/DynamoDB)
네이밍 규칙:
- **S3 버킷**: `<env>-<org>` (예: `dev-myorg`, `prod-myorg`)
- **DynamoDB 락 테이블**: `<env>-<org>-tf-lock` (예: `dev-myorg-tf-lock`)

> 버킷은 **버전닝**을 켜고, DynamoDB는 **PAY_PER_REQUEST**로 생성하세요.

```bash
# 변수 예시
REGION=ap-northeast-2
ORG=myorg

# dev
aws s3api create-bucket --bucket dev-$ORG --region $REGION   --create-bucket-configuration LocationConstraint=$REGION
aws s3api put-bucket-versioning --bucket dev-$ORG   --versioning-configuration Status=Enabled

aws dynamodb create-table --table-name dev-$ORG-tf-lock   --attribute-definitions AttributeName=LockID,AttributeType=S   --key-schema AttributeName=LockID,KeyType=HASH   --billing-mode PAY_PER_REQUEST --region $REGION

# prod
aws s3api create-bucket --bucket prod-$ORG --region $REGION   --create-bucket-configuration LocationConstraint=$REGION
aws s3api put-bucket-versioning --bucket prod-$ORG   --versioning-configuration Status=Enabled

aws dynamodb create-table --table-name prod-$ORG-tf-lock   --attribute-definitions AttributeName=LockID,AttributeType=S   --key-schema AttributeName=LockID,KeyType=HASH   --billing-mode PAY_PER_REQUEST --region $REGION
```

> 추후 원하면 SSE-KMS(버킷/테이블 암호화)로 강화하세요.

### 2) GitHub Secrets / Variables
필수 값:

id | 종류 | 키 | 예시/설명
---|---|---|---
1 | Secret | `TF_DEV_ROLE_ARN` | `arn:aws:iam::<acct>:role/github-oidc-terraform-dev`
2 | Secret | `TF_PROD_ROLE_ARN` | `arn:aws:iam::<acct>:role/github-oidc-terraform-prod`
3 | Variable | `TF_STACK_REGION` | 기본: `ap-northeast-2` (선택)
4 | Variable | `TF_STACK_NAME` | 레포명과 다르게 쓰고 싶을 때만 지정(선택)
5 | Secret(선택) | `INFRACOST_API_KEY` | 비용 코멘트 활성화 시

> prod 배포 보호: **GitHub → Environments → prod**에 Reviewer(승인자) 지정.

---

## 🧱 스택 생성(backend.hcl 포함)

실행권한:
```bash
chmod +x terraform/tools/{stackkit-cli.sh,tf_forbidden.sh}
```

생성 규칙: `terraform/stacks/<name>-<env>-<region>/` 아래 **필수 6종**을 만듭니다.
- `versions.tf`, `variables.tf`, `main.tf`, `outputs.tf`, `backend.hcl`, `terraform.tfvars`(+ `README.md`)

예시:
```bash
# dev 스택
terraform/tools/stackkit-cli.sh create my-service dev ap-northeast-2   --state-bucket dev-myorg   --lock-table dev-myorg-tf-lock

# prod 스택
terraform/tools/stackkit-cli.sh create my-service prod ap-northeast-2   --state-bucket prod-myorg   --lock-table prod-myorg-tf-lock
```

`backend.hcl`는 이렇게 채워집니다(예):
```hcl
bucket         = "dev-myorg"
key            = "stacks/my-service-dev-ap-northeast-2/terraform.tfstate"
region         = "ap-northeast-2"
dynamodb_table = "dev-myorg-tf-lock"
encrypt        = true
```

> **modules/** 내부에는 provider/backend 선언을 넣지 마세요. (가드로 차단됨)

---

## 🧪 로컬 검증 & 플랜
```bash
# 빠른 유효성(백엔드 없이 validate + 쉘가드 + (옵션)OPA)
terraform/tools/stackkit-cli.sh validate my-service dev

# 원격 플랜/적용
terraform/tools/stackkit-cli.sh plan  my-service dev    # plan.tfplan + tfplan.json(있으면)
terraform/tools/stackkit-cli.sh apply my-service dev
```

---

## 🔁 CI/CD 플로우

### PR 열리면 (`tf-pr.yml`)
- 변경된 스택 자동 감지
- `fmt` → `init` → `validate`
- **정책 가드(쉘)**: `terraform/tools/tf_forbidden.sh`
- (옵션) `tflint`, `tfsec`
- `plan` 후 **tfplan.json** 생성
- **OPA Conftest 정책** 실행: `terraform/policies/terraform.rego`
- **PR 코멘트** & **plan 아티팩트** 업로드
- (옵션) Infracost 비용 코멘트

### main 머지되면 (`tf-apply-dev.yml`)
- `dev` 스택 자동 **plan+apply**

### prod 승격(`tf-apply-prod.yml`)
- **수동 트리거**(workflow_dispatch) + **Environment Reviewer 승인** 후 **plan+apply**

---

## 🏷️ 태그/정책 규칙(요약)
- **필수 태그**: `Environment`, `Project`, `Component`, `ManagedBy`  
  (스택 템플릿의 `local.common_tags`에 이미 포함)
- **데이터소스 금지**: `data.aws_sqs_queue`, `data.aws_sns_topic` (이름 조회 의존성 금지)
- **보안그룹 CIDR**: `0.0.0.0/0` 차단(예외 필요 시 `AllowPublicExempt=true` 태그 또는 description에 `ALLOW_PUBLIC_EXEMPT`)
- **prod 스택 필수 파일**: `versions.tf`, `variables.tf`, `main.tf`, `outputs.tf`, `backend.(tf|hcl)`
- **workspace 사용 금지**: 디렉터리 분리 전략 사용

모든 규칙은 PR에서 **쉘 가드 + OPA 정책** 2단계로 검증됩니다.

---

## 💡 자주 묻는 질문(FAQ)

**Q. 스택 생성 후 `init`이 실패해요.**  
A. 상태 저장 리소스(S3/DynamoDB)가 없거나 이름이 달라서입니다. `backend.hcl`의 `bucket`, `dynamodb_table`이 실제 존재하는지 확인하세요.

**Q. Infracost 코멘트가 안 나와요.**  
A. `tf-pr.yml`의 `RUN_INFRACOST`를 `true`로 바꾸고, `INFRACOST_API_KEY`를 Secret으로 넣으세요.

**Q. 모듈 안에서 provider 쓰면 안 되나요?**  
A. 재사용성과 테스트성, State 오염 방지를 위해 **금지**합니다(가드에서 실패).

**Q. 환경을 늘리고 싶어요(stg 등).**  
A. `terraform.rego`의 `valid_environments`와 `variables.tf`의 validation을 확장하고, 워크플로 매트릭스/검출 로직을 조정하세요.

---

## 🧷 체크리스트
- [ ] S3 버킷: `dev-<org>`, `prod-<org>` (버전닝 ON)
- [ ] DynamoDB: `dev-<org>-tf-lock`, `prod-<org>-tf-lock`
- [ ] GitHub Secrets: `TF_DEV_ROLE_ARN`, `TF_PROD_ROLE_ARN`
- [ ] GitHub Variables: `TF_STACK_REGION`(선택), `TF_STACK_NAME`(선택)
- [ ] 실행권한: `chmod +x terraform/tools/{stackkit-cli.sh,tf_forbidden.sh}`
- [ ] `prod` Environment Reviewer 지정
- [ ] 스택 생성: `stackkit-cli.sh create <name> <env> [region] --state-bucket <env>-<org> --lock-table <env>-<org>-tf-lock`

---

## 🧭 네이밍 권장
- **스택 디렉터리**: `<name>-<env>-<region>`
- **리소스 이름 prefix**: `${local.name}-${local.environment}`
- **태그**: `Project=<name>`, `Environment=<env>`, `Component=<name>`, `ManagedBy=terraform`
