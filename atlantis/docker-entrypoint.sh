#!/usr/bin/env bash
set -euo pipefail

# 필수/선택 환경변수
: "${ATLANTIS_REPO_ALLOWLIST:?Set ATLANTIS_REPO_ALLOWLIST (e.g., github.com/your-org/*)}"
ATLANTIS_PORT="${ATLANTIS_PORT:-4141}"
DEFAULT_TF="${ATLANTIS_DEFAULT_TF_VERSION:-1.8.5}"

# GitHub 인증(토큰 방식)
GH_ARGS=""
if [[ -n "${ATLANTIS_GH_USER:-}" && -n "${ATLANTIS_GH_TOKEN:-}" ]]; then
  GH_ARGS="--gh-user=${ATLANTIS_GH_USER} --gh-token=${ATLANTIS_GH_TOKEN}"
  if [[ -n "${ATLANTIS_GH_WEBHOOK_SECRET:-}" ]]; then
    GH_ARGS="${GH_ARGS} --gh-webhook-secret=${ATLANTIS_GH_WEBHOOK_SECRET}"
  fi
fi

# (선택) repo 서버 설정 파일
REPO_CFG_ARGS=""
if [[ -n "${ATLANTIS_REPO_CONFIG:-}" ]]; then
  REPO_CFG_ARGS="--repo-config=${ATLANTIS_REPO_CONFIG}"
fi

# atlantis 실행
exec atlantis server \
  --port="${ATLANTIS_PORT}" \
  --autoinstall \
  --repo-allowlist="${ATLANTIS_REPO_ALLOWLIST}" \
  --default-tf-version="${DEFAULT_TF}" \
  --allow-repo-config \
  ${GH_ARGS} \
  ${REPO_CFG_ARGS}
