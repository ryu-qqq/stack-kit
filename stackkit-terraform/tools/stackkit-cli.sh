#!/usr/bin/env bash
set -euo pipefail

# =========================================
# StackKit CLI – 스택 생성/검증/배포 보조 스크립트
# 구조: terraform/{modules,policies,stacks,tools}
# =========================================

# ───── 색상/아이콘 ─────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
INFO="ℹ️"; OK="✅"; ERR="❌"; WARN="⚠️"

log()   { echo -e "${BLUE}${INFO} $*${NC}"; }
ok()    { echo -e "${GREEN}${OK} $*${NC}"; }
warn()  { echo -e "${YELLOW}${WARN} $*${NC}"; }
fail()  { echo -e "${RED}${ERR} $*${NC}"; exit 1; }

# ───── 경로/기본값 ─────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# terraform 루트(기본: script 상위 디렉터리)
TERRAFORM_ROOT="${TERRAFORM_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
TOOLS_DIR="$TERRAFORM_ROOT/tools"
POLICY_DIR="$TERRAFORM_ROOT/policies"

# Git repo 루트/이름 자동 감지(깃이 없어도 동작)
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || cd "$SCRIPT_DIR/../.." && pwd)"
REPO_NAME="$(basename "$REPO_ROOT")"

DEFAULT_REGION="${DEFAULT_REGION:-ap-northeast-2}"

need_cmd() { command -v "$1" >/dev/null 2>&1 || fail "$1 명령을 찾을 수 없습니다."; }

# macOS 대비 realpath 대체
_relpath() {
  if command -v realpath >/dev/null 2>&1; then
    realpath --relative-to="$(pwd)" "$1"
  else
    python - "$1" <<'PY'
import os,sys
p=os.path.abspath(sys.argv[1]); print(os.path.relpath(p, os.getcwd()))
PY
  fi
}

usage() {
  cat <<EOF
${INFO} StackKit CLI

사용법:
  $(basename "$0") scaffold [--envs dev,prod] [--region ap-northeast-2] [--org ORG] [--name NAME]
    - 현재 레포명을 기본 name으로 자동 인식하여 여러 env 스택을 한 번에 생성

  $(basename "$0") create <name> <env> [region] [--state-bucket BUCKET] [--lock-table TABLE] [--org ORG]
  $(basename "$0") init   <name> <env> [region] [--backend false]
  $(basename "$0") plan   <name> <env> [region] [--tfvars FILE]
  $(basename "$0") apply  <name> <env> [region] [--tfvars FILE]
  $(basename "$0") validate <name> <env> [region]

규칙:
  - 스택 경로: terraform/stacks/<name>-<env>-<region>/
  - 필수 파일: versions.tf, variables.tf, main.tf, outputs.tf, backend.hcl, terraform.tfvars
  - 정책 가드:
      - 쉘 가드 : terraform/tools/tf_forbidden.sh
      - OPA     : terraform/policies/terraform.rego (tfplan.json 기반)
EOF
}

# ───── 경로 도우미 ─────────────────────────────────────────────────────
stack_dir() {
  local name="$1" env="$2" region="${3:-$DEFAULT_REGION}"
  echo "$TERRAFORM_ROOT/stacks/${name}-${env}-${region}"
}

# ───── 템플릿 파일 생성기 ─────────────────────────────────────────────
write_versions_tf() {
  cat > "$1/versions.tf" <<'HCL'
terraform {
  required_version = ">= 1.6.0, < 2.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
}
HCL
}

write_variables_tf() {
  cat > "$1/variables.tf" <<'HCL'
variable "project_name" {
  type        = string
  description = "프로젝트/스택 이름"
}

variable "environment" {
  type        = string
  description = "환경 (dev|prod)"
  validation {
    condition     = contains(["dev","prod"], var.environment)
    error_message = "environment must be one of dev|prod."
  }
}

variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "ap-northeast-2"
}
HCL
}

write_main_tf() {
  cat > "$1/main.tf" <<'HCL'
locals {
  name        = var.project_name
  environment = var.environment
  region      = var.aws_region

  # OPA(terraform.rego)에서 요구하는 필수 태그
  common_tags = {
    Project     = local.name
    Environment = local.environment
    Component   = local.name
    ManagedBy   = "terraform"
    CreatedBy   = "stackkit-cli"
  }
}

# provider는 stacks 레벨에서만! (modules/ 내 선언 금지)
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = local.common_tags
  }
}

# modules 조립 예시(주석)
# module "example" {
#   source = "../../modules/s3"
#   name   = "${local.name}-${local.environment}-logs"
# }
HCL
}

write_outputs_tf() {
  cat > "$1/outputs.tf" <<'HCL'
output "stack_name" {
  description = "스택 식별자(name-env-region)"
  value       = "${var.project_name}-${var.environment}-${var.aws_region}"
}

# 필요시 module 출력값을 노출하세요.
HCL
}

write_backend_hcl() {
  local dir="$1" name="$2" env="$3" region="$4" bucket="$5" table="$6"
  cat > "$dir/backend.hcl" <<HCL
bucket         = "${bucket}"
key            = "stacks/${name}-${env}-${region}/terraform.tfstate"
region         = "${region}"
dynamodb_table = "${table}"
encrypt        = true
HCL
}

write_tfvars() {
  local dir="$1" name="$2" env="$3" region="$4"
  cat > "$dir/terraform.tfvars" <<HCL
project_name = "${name}"
environment  = "${env}"
aws_region   = "${region}"
HCL
}

write_readme() {
  local dir="$1"
  local rel="$(_relpath "$dir")"
  cat > "$dir/README.md" <<MD
# ${rel}

## 빠른 시작
\`\`\`bash
cd ${rel}
terraform init -backend-config=backend.hcl -reconfigure
terraform plan -out=plan.tfplan
terraform apply -auto-approve plan.tfplan
\`\`\`

## 참고
- 원격 상태 S3/DynamoDB가 미리 있어야 합니다.
- 공통 태그: Environment/Project/Component/ManagedBy (OPA 정책)
MD
}

# ───── 유틸: org에서 backend 네이밍 파생 ─────────────────────────────
derive_backend_from_org() {
  local env="$1" org="${2:-}"
  local bucket table
  if [[ -n "$org" ]]; then
    bucket="${env}-${org}"
    table="${env}-${org}-tf-lock"
  else
    bucket="stackkit-tfstate-${env}"
    table="${env}-tf-lock"
  fi
  echo "$bucket" "$table"
}

# ───── 명령: create ───────────────────────────────────────────────────
cmd_create() {
  need_cmd terraform
  local name="$1" env="$2" region="${3:-$DEFAULT_REGION}"
  shift 3 || true
  local state_bucket="" lock_table="" org=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --state-bucket) state_bucket="$2"; shift 2;;
      --lock-table)   lock_table="$2";   shift 2;;
      --org)          org="$2";          shift 2;;
      *)              shift 1;;
    esac
  done

  if [[ -z "$state_bucket" || -z "$lock_table" ]]; then
    read -r state_bucket lock_table < <(derive_backend_from_org "$env" "$org")
  fi

  local dir; dir="$(stack_dir "$name" "$env" "$region")"
  mkdir -p "$dir"

  log "스택 생성: $dir"
  write_versions_tf  "$dir"
  write_variables_tf "$dir"
  write_main_tf      "$dir"
  write_outputs_tf   "$dir"
  write_backend_hcl  "$dir" "$name" "$env" "$region" "$state_bucket" "$lock_table"
  write_tfvars       "$dir" "$name" "$env" "$region"
  write_readme       "$dir"

  ok  "필수 파일 생성 완료"
  echo "   - versions.tf, variables.tf, main.tf, outputs.tf, backend.hcl, terraform.tfvars, README.md"
  echo "   - state bucket: ${state_bucket}, lock table: ${lock_table}"
}

# ───── 명령: scaffold (레포 자동 감지로 여러 env 생성) ───────────────
cmd_scaffold() {
  need_cmd terraform
  local envs="dev,prod"
  local region="$DEFAULT_REGION"
  local org="" name="$REPO_NAME"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --envs)   envs="$2";   shift 2;;
      --region) region="$2"; shift 2;;
      --org)    org="$2";    shift 2;;
      --name)   name="$2";   shift 2;;
      *)        shift 1;;
    esac
  done

  IFS=',' read -r -a arr <<< "$envs"
  for e in "${arr[@]}"; do
    e="${e// /}"
    [[ -z "$e" ]] && continue
    cmd_create "$name" "$e" "$region" --org "$org"
  done
  ok "scaffold 완료: name=${name}, envs=${envs}, region=${region}, org=${org:-none}"
}

# ───── 명령: init ─────────────────────────────────────────────────────
cmd_init() {
  need_cmd terraform
  local name="$1" env="$2" region="${3:-$DEFAULT_REGION}"
  shift 3 || true
  local backend="true"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --backend) backend="$2"; shift 2;;
      *) shift 1;;
    esac
  done

  local dir; dir="$(stack_dir "$name" "$env" "$region")"
  [[ -d "$dir" ]] || fail "스택 디렉터리가 없습니다: $dir"

  log "terraform init ($dir)"
  if [[ "$backend" == "false" ]]; then
    (cd "$dir" && terraform init -backend=false -reconfigure)
  else
    (cd "$dir" && terraform init -backend-config=backend.hcl -reconfigure)
  fi
  ok "init 완료"
}

# ───── 내부: tfvars 선택 ─────────────────────────────────────────────
pick_tfvars() {
  local dir="$1" env="$2" custom="${3:-}"
  if [[ -n "$custom" && -f "$dir/$custom" ]]; then
    echo "$custom"; return
  fi
  if [[ -f "$dir/${env}.tfvars" ]]; then
    echo "${env}.tfvars"; return
  fi
  echo "terraform.tfvars"
}

# ───── 명령: plan ─────────────────────────────────────────────────────
cmd_plan() {
  need_cmd terraform
  local name="$1" env="$2" region="${3:-$DEFAULT_REGION}"
  shift 3 || true
  local tfvars=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tfvars) tfvars="$2"; shift 2;;
      *) shift 1;;
    esac
  done

  local dir; dir="$(stack_dir "$name" "$env" "$region")"
  [[ -d "$dir" ]] || fail "스택 디렉터리가 없습니다: $dir"
  (cd "$dir" && terraform init -backend-config=backend.hcl -reconfigure)

  local picked; picked="$(pick_tfvars "$dir" "$env" "$tfvars")"
  log "tfvars 사용: $picked"
  (cd "$dir" && terraform plan -var-file="$picked" -out=plan.tfplan)
  ok "plan 완료 → $dir/plan.tfplan"

  # tfplan.json 추출(OPA용)
  if command -v conftest >/dev/null 2>&1; then
    (cd "$dir" && terraform show -json plan.tfplan > tfplan.json)
    ok "tfplan.json 생성 (OPA용)"
  fi
}

# ───── 명령: apply ────────────────────────────────────────────────────
cmd_apply() {
  need_cmd terraform
  local name="$1" env="$2" region="${3:-$DEFAULT_REGION}"
  shift 3 || true
  local tfvars=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tfvars) tfvars="$2"; shift 2;;
      *) shift 1;;
    esac
  done

  local dir; dir="$(stack_dir "$name" "$env" "$region")"
  [[ -d "$dir" ]] || fail "스택 디렉터리가 없습니다: $dir"
  (cd "$dir" && terraform init -backend-config=backend.hcl -reconfigure)

  # plan이 없으면 생성
  if [[ ! -f "$dir/plan.tfplan" ]]; then
    local picked; picked="$(pick_tfvars "$dir" "$env" "$tfvars")"
    log "tfvars 사용: $picked"
    (cd "$dir" && terraform plan -var-file="$picked" -out=plan.tfplan)
  fi

  (cd "$dir" && terraform apply -auto-approve plan.tfplan)
  ok "apply 완료"
}

# ───── 명령: validate ────────────────────────────────────────────────
cmd_validate() {
  need_cmd terraform
  local name="$1" env="$2" region="${3:-$DEFAULT_REGION}"
  local dir; dir="$(stack_dir "$name" "$env" "$region")"
  [[ -d "$dir" ]] || fail "스택 디렉터리가 없습니다: $dir"

  log "fmt 검사"
  (cd "$dir" && terraform fmt -recursive -check) || fail "fmt 실패"

  log "init(backend=false) & validate"
  (cd "$dir" && terraform init -backend=false -reconfigure >/dev/null)
  (cd "$dir" && terraform validate) || fail "terraform validate 실패"

  # 쉘 가드
  local guard="$TOOLS_DIR/tf_forbidden.sh"
  [[ -x "$guard" ]] || fail "정책 가드 스크립트를 찾을 수 없습니다: $guard"
  ROOT="$TERRAFORM_ROOT" bash "$guard"
  ok "쉘 가드 통과"

  # (선택) conftest가 있으면 plan 후 정책 검증
  if command -v conftest >/dev/null 2>&1; then
    log "conftest 감지: plan → tfplan.json → OPA 검사"
    (cd "$dir" && terraform plan -out=plan.tfplan >/dev/null)
    (cd "$dir" && terraform show -json plan.tfplan > tfplan.json)
    conftest test -o table --policy "$POLICY_DIR" "$dir/tfplan.json"
    ok "OPA 정책 통과"
  else
    warn "conftest 미설치 – OPA 정책 검증은 건너뜀"
  fi

  ok "validate 완료"
}

# ───── 메인 디스패처 ─────────────────────────────────────────────────
main() {
  [[ $# -ge 1 ]] || { usage; exit 1; }
  local cmd="$1"; shift
  case "$cmd" in
    scaffold)
      cmd_scaffold "$@"
      ;;
    create)
      [[ $# -ge 2 ]] || { usage; exit 1; }
      cmd_create "$@"
      ;;
    init)
      [[ $# -ge 2 ]] || { usage; exit 1; }
      cmd_init "$@"
      ;;
    plan)
      [[ $# -ge 2 ]] || { usage; exit 1; }
      cmd_plan "$@"
      ;;
    apply)
      [[ $# -ge 2 ]] || { usage; exit 1; }
      cmd_apply "$@"
      ;;
    validate)
      [[ $# -ge 2 ]] || { usage; exit 1; }
      cmd_validate "$@"
      ;;
    *)
      usage; exit 1;;
  esac
}

main "$@"
