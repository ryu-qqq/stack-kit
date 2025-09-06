#!/usr/bin/env bash
set -euo pipefail

# 스크립트 기준으로 infra 루트 계산 (환경변수 ROOT로 덮어쓰기 가능)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

fail() { echo "❌ $1"; exit 1; }
ok()   { echo "✅ $1"; }

# 1) modules/ 내 provider/backend 금지
if grep -R --include="*.tf" -nE '^\s*provider\s+"aws"' "$ROOT/modules" 2>/dev/null; then
  fail "modules/ 에 provider 선언 금지"
fi
if grep -R --include="*.tf" -nE 'backend\s+"s3"' "$ROOT/modules" 2>/dev/null; then
  fail "modules/ 에 backend 선언 금지"
fi
ok "modules/ 경계 규칙 통과"

# 2) workspace 금지
if grep -R --include="*.tf" -n "terraform.workspace" "$ROOT" 2>/dev/null; then
  fail "terraform.workspace 사용 금지 (env 디렉터리로 분리)"
fi
ok "workspace 미사용 확인"

# 3) 이름조회(Data) 금지(SQS/SNS)
if grep -R --include="*.tf" -nE 'data\s+"aws_(sqs_queue|sns_topic)"' "$ROOT" 2>/dev/null; then
  fail "data.aws_* 이름조회 금지 (remote_state/변수로 대체)"
fi
ok "이름조회(Data) 금지 통과"

# 4) 필수 파일 5종 존재(prod 환경만 검사)
missing=0
while IFS= read -r -d '' sd; do
  for f in versions.tf backend.tf variables.tf main.tf outputs.tf; do
    [ -f "$sd/$f" ] || { echo "   - $sd/$f 누락"; missing=1; }
  done
done < <(find "$ROOT/stacks" -name "prod" -type d -print0 2>/dev/null)
[ $missing -eq 0 ] || fail "스택 필수 파일 누락"
ok "스택 필수 파일 확인"

# 5) SG 0.0.0.0/0 금지(예외: ALLOW_PUBLIC_EXEMPT 주석 포함 시 허용)
if grep -R --include="*.tf" -n "0.0.0.0/0" "$ROOT" 2>/dev/null | grep -vq "ALLOW_PUBLIC_EXEMPT"; then
  fail "보안그룹 0.0.0.0/0 금지 (예외는 ALLOW_PUBLIC_EXEMPT 주석 필수)"
fi
ok "SG 공개 규칙 통과"

echo "🎉 GUIDE.md 금지/구조 규칙 기본 통과"
