#!/usr/bin/env bash
set -euo pipefail

# 스크립트 기준으로 terraform 루트 계산 (ROOT로 덮어쓰기 가능)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"   # default: terraform

fail() { echo "❌ $1"; exit 1; }
ok()   { echo "✅ $1"; }

# --------- 규칙 1: modules/ 내 provider/backend 금지 ----------
if [ -d "$ROOT/modules" ]; then
  if grep -R --include="*.tf" -nE '^\s*provider\s+"aws"' "$ROOT/modules" >/dev/null 2>&1; then
    fail "modules/ 에 provider 선언 금지"
  fi
  if grep -R --include="*.tf" -nE 'backend\s+"s3"' "$ROOT/modules" >/dev/null 2>&1; then
    fail "modules/ 에 backend 선언 금지"
  fi
fi
ok "modules/ 경계 규칙 통과"

# --------- 규칙 2: terraform.workspace 금지 ----------
if grep -R --include="*.tf" -n "terraform.workspace" "$ROOT" >/dev/null 2>&1; then
  fail "terraform.workspace 사용 금지 (env 디렉터리 분리 전략 사용)"
fi
ok "workspace 미사용 확인"

# --------- 규칙 3: 이름조회(Data) 금지(SQS/SNS) ----------
if grep -R --include="*.tf" -nE 'data\s+"aws_(sqs_queue|sns_topic)"' "$ROOT" >/dev/null 2>&1; then
  fail "data.aws_* 이름조회 금지 (remote_state/변수/출력값으로 의존성 명시)"
fi
ok "이름조회(Data) 금지 통과"

# --------- 규칙 4: 스택 필수 파일(prod 스택만 검사) ----------
# 스택 디렉터리: backend.hcl 또는 backend.tf가 존재하는 디렉터리
mapfile -t STACK_DIRS < <(find "$ROOT/stacks" -maxdepth 4 \
  \( -name "backend.hcl" -o -name "backend.tf" \) -printf '%h\n' 2>/dev/null | sort -u)

is_prod_dir() {
  local d="$1"
  # 예: stacks/myapp-prod-ap-northeast-2, stacks/prod/xxx, stacks/xxx/prod
  [[ "$d" =~ /prod(/|$) ]] || [[ "$d" =~ -prod(-|$) ]]
}

missing=0
for sd in "${STACK_DIRS[@]:-}"; do
  if is_prod_dir "$sd"; then
    need=(versions.tf variables.tf main.tf outputs.tf)
    has_backend=0
    [ -f "$sd/backend.tf" ]  && has_backend=1
    [ -f "$sd/backend.hcl" ] && has_backend=1
    if [ $has_backend -eq 0 ]; then
      echo "   - $sd: backend.tf/backend.hcl 누락"; missing=1
    fi
    for f in "${need[@]}"; do
      [ -f "$sd/$f" ] || { echo "   - $sd/$f 누락"; missing=1; }
    done
  fi
done
[ $missing -eq 0 ] || fail "prod 스택 필수 파일 누락"
ok "prod 스택 필수 파일 확인(backend.hcl/backend.tf 허용)"

# --------- 규칙 5: SG 0.0.0.0/0 금지(예외 주석 허용) ----------
# 예외: 라인에 ALLOW_PUBLIC_EXEMPT 포함 시 통과
if grep -R --include="*.tf" -n "0.0.0.0/0" "$ROOT" 2>/dev/null | grep -vq "ALLOW_PUBLIC_EXEMPT"; then
  fail "보안그룹 0.0.0.0/0 금지 (예외는 ALLOW_PUBLIC_EXEMPT 주석 필수)"
fi
ok "SG 공개 규칙 통과"

echo "🎉 GUIDE 규칙 통과"
