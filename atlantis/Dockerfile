# Atlantis 기본 이미지 (v0.28.5로 업데이트)
FROM ghcr.io/runatlantis/atlantis:v0.28.5

USER root

# 도구 버전 고정
ARG TFLINT_VERSION=0.51.0
ARG TFSEC_VERSION=1.28.6
ARG CONFTEST_VERSION=0.53.0
ARG CHECKOV_VERSION=3.2.197
ARG INFRACOST_VERSION=0.10.38

# 필수 도구 설치: bash, curl, jq, git, unzip, python3/pip, awscli, checkov
RUN apk add --no-cache bash curl jq git openssh-client unzip python3 py3-pip ca-certificates \
 && pip3 install --no-cache-dir "awscli==1.32.110" "checkov==${CHECKOV_VERSION}"

# tflint
RUN curl -L "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_amd64.zip" -o /tmp/tflint.zip \
 && unzip /tmp/tflint.zip -d /usr/local/bin \
 && chmod +x /usr/local/bin/tflint \
 && rm -f /tmp/tflint.zip

# tfsec
RUN curl -L "https://github.com/aquasecurity/tfsec/releases/download/v${TFSEC_VERSION}/tfsec-linux-amd64" -o /usr/local/bin/tfsec \
 && chmod +x /usr/local/bin/tfsec

# conftest
RUN curl -L "https://github.com/open-policy-agent/conftest/releases/download/v${CONFTEST_VERSION}/conftest_Linux_x86_64.tar.gz" -o /tmp/conftest.tgz \
 && tar -xzf /tmp/conftest.tgz -C /usr/local/bin conftest \
 && chmod +x /usr/local/bin/conftest \
 && rm -f /tmp/conftest.tgz

# Infracost 설치 (비용 추정용)
RUN curl -L "https://github.com/infracost/infracost/releases/download/v${INFRACOST_VERSION}/infracost-linux-amd64.tar.gz" -o /tmp/infracost.tgz \
 && tar -xzf /tmp/infracost.tgz -C /usr/local/bin \
 && chmod +x /usr/local/bin/infracost \
 && rm -f /tmp/infracost.tgz

# 엔트리포인트 스크립트 추가
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# 헬스체크 추가 (Atlantis 서버가 정상적으로 응답하는지 확인)
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:4141/healthz || exit 1

USER atlantis

EXPOSE 4141

# 커스텀 엔트리포인트 사용 (기본 엔트리포인트 우회)
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
