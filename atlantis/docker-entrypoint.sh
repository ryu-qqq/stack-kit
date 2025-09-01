#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Starting StackKit Atlantis AI-Powered Terraform Workflow..."

# 필수/선택 환경변수
: "${ATLANTIS_REPO_ALLOWLIST:?Set ATLANTIS_REPO_ALLOWLIST (e.g., github.com/your-org/*)}"
ATLANTIS_PORT="${ATLANTIS_PORT:-4141}"
DEFAULT_TF="${ATLANTIS_DEFAULT_TF_VERSION:-1.8.5}"
ATLANTIS_DATA_DIR="${ATLANTIS_DATA_DIR:-/atlantis-data}"

echo "📋 Configuration:"
echo "  - Port: ${ATLANTIS_PORT}"
echo "  - Default Terraform Version: ${DEFAULT_TF}"
echo "  - Data Directory: ${ATLANTIS_DATA_DIR}"
echo "  - Repo Allowlist: ${ATLANTIS_REPO_ALLOWLIST}"

# 데이터 디렉토리 확인 및 생성
if [[ ! -d "${ATLANTIS_DATA_DIR}" ]]; then
  echo "📁 Creating data directory: ${ATLANTIS_DATA_DIR}"
  mkdir -p "${ATLANTIS_DATA_DIR}"
fi

# 권한 확인
echo "🔐 Checking data directory permissions..."
if [[ -w "${ATLANTIS_DATA_DIR}" ]]; then
  echo "  ✅ Data directory is writable"
else
  echo "  ⚠️  Data directory is not writable, this may cause issues"
fi

# GitHub 인증(토큰 방식)
GH_ARGS=""
if [[ -n "${ATLANTIS_GH_USER:-}" && -n "${ATLANTIS_GH_TOKEN:-}" ]]; then
  echo "🔑 GitHub authentication configured for user: ${ATLANTIS_GH_USER}"
  GH_ARGS="--gh-user=${ATLANTIS_GH_USER} --gh-token=${ATLANTIS_GH_TOKEN}"
  if [[ -n "${ATLANTIS_GH_WEBHOOK_SECRET:-}" ]]; then
    echo "🔒 GitHub webhook secret configured"
    GH_ARGS="${GH_ARGS} --gh-webhook-secret=${ATLANTIS_GH_WEBHOOK_SECRET}"
  fi
else
  echo "⚠️  GitHub authentication not configured"
fi

# (선택) repo 서버 설정 파일
REPO_CFG_ARGS=""
if [[ -n "${ATLANTIS_REPO_CONFIG:-}" ]]; then
  echo "📄 Using repo config: ${ATLANTIS_REPO_CONFIG}"
  REPO_CFG_ARGS="--repo-config=${ATLANTIS_REPO_CONFIG}"
fi

# 추가 Atlantis 설정
EXTRA_ARGS=""
if [[ -n "${ATLANTIS_ATLANTIS_URL:-}" ]]; then
  echo "🌐 Atlantis URL: ${ATLANTIS_ATLANTIS_URL}"
  EXTRA_ARGS="${EXTRA_ARGS} --atlantis-url=${ATLANTIS_ATLANTIS_URL}"
fi

if [[ -n "${ATLANTIS_DISABLE_REPO_LOCKING:-}" ]]; then
  echo "🔓 Repository locking disabled"
  EXTRA_ARGS="${EXTRA_ARGS} --disable-repo-locking"
fi

# 도구 버전 확인
echo "🛠️  Installed tools:"
echo "  - Terraform: $(terraform version -json | jq -r '.terraform_version' 2>/dev/null || echo 'unknown')"
echo "  - AWS CLI: $(aws --version 2>&1 | head -n1 || echo 'not installed')"
echo "  - Infracost: $(infracost --version 2>/dev/null || echo 'not installed')"
echo "  - TFLint: $(tflint --version 2>/dev/null || echo 'not installed')"
echo "  - TFSec: $(tfsec --version 2>/dev/null || echo 'not installed')"

echo "🎯 Starting Atlantis server..."

# atlantis 실행
exec atlantis server \
  --port="${ATLANTIS_PORT}" \
  --autoinstall \
  --repo-allowlist="${ATLANTIS_REPO_ALLOWLIST}" \
  --default-tf-version="${DEFAULT_TF}" \
  --allow-repo-config \
  --data-dir="${ATLANTIS_DATA_DIR}" \
  ${GH_ARGS} \
  ${REPO_CFG_ARGS} \
  ${EXTRA_ARGS}
