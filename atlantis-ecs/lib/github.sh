#!/bin/bash
# StackKit DevOps Library - GitHub Integration Functions
# GitHub 리포지토리 설정 및 웹훅 관리

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# GitHub API 호출 함수
github_api_call() {
    local method="$1"
    local endpoint="$2"
    local token="$3"
    local data="$4"
    local accept_header="${5:-application/vnd.github.v3+json}"
    
    local curl_args=(
        -s
        -X "$method"
        -H "Authorization: token $token"
        -H "Accept: $accept_header"
        -H "Content-Type: application/json"
    )
    
    if [[ -n "$data" ]]; then
        curl_args+=(-d "$data")
    fi
    
    local response
    response=$(curl "${curl_args[@]}" "https://api.github.com$endpoint")
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        echo "$response"
    else
        log_error "GitHub API call failed: $method $endpoint"
        return 1
    fi
}

# 저장소 정보 조회
get_repository_info() {
    local repo_full_name="$1"  # owner/repo
    local token="$2"
    
    log_info "Fetching repository information: $repo_full_name"
    
    local response
    response=$(github_api_call "GET" "/repos/$repo_full_name" "$token")
    
    if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
        log_success "Repository found: $repo_full_name"
        echo "$response"
    else
        local error_message
        error_message=$(echo "$response" | jq -r '.message // "Unknown error"')
        error_exit "Repository not found or inaccessible: $repo_full_name ($error_message)"
    fi
}

# 웹훅 존재 확인
check_webhook_exists() {
    local repo_full_name="$1"
    local webhook_url="$2"
    local token="$3"
    
    log_info "Checking existing webhooks..."
    
    local webhooks
    webhooks=$(github_api_call "GET" "/repos/$repo_full_name/hooks" "$token")
    
    if echo "$webhooks" | jq -e ".[] | select(.config.url == \"$webhook_url\")" >/dev/null 2>&1; then
        local webhook_id
        webhook_id=$(echo "$webhooks" | jq -r ".[] | select(.config.url == \"$webhook_url\") | .id")
        log_info "Existing webhook found with ID: $webhook_id"
        echo "$webhook_id"
    else
        log_info "No existing webhook found for URL: $webhook_url"
        echo ""
    fi
}

# 웹훅 생성 또는 업데이트
create_or_update_webhook() {
    local repo_full_name="$1"
    local webhook_url="$2"
    local secret="$3"
    local token="$4"
    local events="${5:-push,pull_request,pull_request_review,issue_comment,pull_request_review_comment}"
    
    # 기존 웹훅 확인
    local existing_webhook_id
    existing_webhook_id=$(check_webhook_exists "$repo_full_name" "$webhook_url" "$token")
    
    # 웹훅 설정 JSON
    local webhook_config
    webhook_config=$(cat <<JSON
{
    "name": "web",
    "active": true,
    "events": [$(echo "$events" | sed 's/,/","/g' | sed 's/^/"/' | sed 's/$/"/')],
    "config": {
        "url": "$webhook_url",
        "content_type": "json",
        "secret": "$secret",
        "insecure_ssl": "0"
    }
}
JSON
)
    
    if [[ -n "$existing_webhook_id" ]]; then
        # 기존 웹훅 업데이트
        log_info "Updating existing webhook (ID: $existing_webhook_id)..."
        local response
        response=$(github_api_call "PATCH" "/repos/$repo_full_name/hooks/$existing_webhook_id" "$token" "$webhook_config")
        
        if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
            log_success "Webhook updated successfully"
            echo "$response" | jq -r '.id'
        else
            local error_message
            error_message=$(echo "$response" | jq -r '.message // "Unknown error"')
            error_exit "Failed to update webhook: $error_message"
        fi
    else
        # 새 웹훅 생성
        log_info "Creating new webhook..."
        local response
        response=$(github_api_call "POST" "/repos/$repo_full_name/hooks" "$token" "$webhook_config")
        
        if echo "$response" | jq -e '.id' >/dev/null 2>&1; then
            local webhook_id
            webhook_id=$(echo "$response" | jq -r '.id')
            log_success "Webhook created successfully (ID: $webhook_id)"
            echo "$webhook_id"
        else
            local error_message
            error_message=$(echo "$response" | jq -r '.message // "Unknown error"')
            error_exit "Failed to create webhook: $error_message"
        fi
    fi
}

# 웹훅 테스트
test_webhook() {
    local repo_full_name="$1"
    local webhook_id="$2"
    local token="$3"
    
    log_info "Testing webhook..."
    
    local response
    response=$(github_api_call "POST" "/repos/$repo_full_name/hooks/$webhook_id/tests" "$token")
    
    # GitHub는 웹훅 테스트에 대해 빈 응답을 반환할 수 있음
    if [[ $? -eq 0 ]]; then
        log_success "Webhook test sent successfully"
    else
        log_warning "Webhook test may have failed"
    fi
}

# 브랜치 보호 규칙 설정
setup_branch_protection() {
    local repo_full_name="$1"
    local branch="$2"
    local token="$3"
    local require_atlantis="${4:-true}"
    
    log_info "Setting up branch protection for $branch..."
    
    local required_checks=""
    if [[ "$require_atlantis" == "true" ]]; then
        required_checks='"atlantis/plan"'
    fi
    
    local protection_config
    protection_config=$(cat <<JSON
{
    "required_status_checks": {
        "strict": true,
        "contexts": [$required_checks]
    },
    "enforce_admins": false,
    "required_pull_request_reviews": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews": true,
        "require_code_owner_reviews": false
    },
    "restrictions": null
}
JSON
)
    
    local response
    response=$(github_api_call "PUT" "/repos/$repo_full_name/branches/$branch/protection" "$token" "$protection_config")
    
    if echo "$response" | jq -e '.url' >/dev/null 2>&1; then
        log_success "Branch protection configured for $branch"
    else
        local error_message
        error_message=$(echo "$response" | jq -r '.message // "Unknown error"')
        log_warning "Failed to configure branch protection: $error_message"
    fi
}

# Atlantis 설정 파일 생성
generate_atlantis_config() {
    local repo_path="$1"
    local aws_region="$2"
    local terraform_version="${3:-1.7.5}"
    local enable_infracost="${4:-false}"
    
    local atlantis_config_path="$repo_path/atlantis.yaml"
    
    log_info "Generating Atlantis configuration..."
    
    local workflow_steps=()
    workflow_steps+=('        - init')
    workflow_steps+=('        - plan')
    
    if [[ "$enable_infracost" == "true" ]]; then
        workflow_steps+=('        - run: |')
        workflow_steps+=('            if command -v infracost >/dev/null 2>&1; then')
        workflow_steps+=('              infracost breakdown --path . --format json --out-file infracost.json')
        workflow_steps+=('              infracost comment github --path infracost.json --repo $GITHUB_REPOSITORY --pull-request $PULL_REQUEST_NUMBER --github-token $GITHUB_TOKEN')
        workflow_steps+=('            fi')
    fi
    
    cat > "$atlantis_config_path" <<YAML
version: 3
automerge: false
delete_source_branch_on_merge: false

projects:
- name: atlantis-ecs
  dir: .
  workspace: default
  terraform_version: v${terraform_version}
  autoplan:
    when_modified: ["*.tf", "*.tfvars", "*.hcl"]
    enabled: true
  apply_requirements:
    - approved
    - mergeable
  workflow: stackkit-workflow

workflows:
  stackkit-workflow:
    plan:
      steps:
$(printf '%s\n' "${workflow_steps[@]}")
    apply:
      steps:
        - apply

# StackKit 표준 환경변수
env:
  TF_STACK_REGION: ${aws_region}
  AWS_DEFAULT_REGION: ${aws_region}
YAML
    
    log_success "Atlantis configuration created: $atlantis_config_path"
}

# GitHub 액션 워크플로우 생성 (옵션)
generate_github_workflow() {
    local repo_path="$1"
    local stack_name="$2"
    local aws_region="$3"
    
    local workflow_dir="$repo_path/.github/workflows"
    local workflow_path="$workflow_dir/stackkit-ci.yml"
    
    mkdir -p "$workflow_dir"
    
    log_info "Generating GitHub Actions workflow..."
    
    cat > "$workflow_path" <<YAML
name: StackKit CI/CD

on:
  pull_request:
    branches: [main, master]
    paths: ['**.tf', '**.tfvars', '**.hcl']
  push:
    branches: [main, master]
    paths: ['**.tf', '**.tfvars', '**.hcl']

env:
  TF_STACK_NAME: ${stack_name}
  TF_STACK_REGION: ${aws_region}
  AWS_DEFAULT_REGION: ${aws_region}

jobs:
  terraform-check:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: 1.7.5
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        aws-access-key-id: \${{ secrets.ATLANTIS_AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: \${{ secrets.ATLANTIS_AWS_SECRET_ACCESS_KEY }}
        aws-region: \${{ env.AWS_DEFAULT_REGION }}
    
    - name: Terraform Format Check
      run: terraform fmt -check -recursive
    
    - name: Terraform Validate
      run: |
        terraform init -backend=false
        terraform validate
    
    - name: Security Scan
      uses: aquasecurity/tfsec-action@v1.0.3
      with:
        soft_fail: true

  infracost:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup Infracost
      uses: infracost/actions/setup@v2
      with:
        api-key: \${{ secrets.INFRACOST_API_KEY }}
    
    - name: Generate Infracost diff
      run: |
        infracost breakdown --path . --format json --out-file infracost-base.json
        infracost diff --path . --compare-to infracost-base.json --format json --out-file infracost-diff.json
    
    - name: Post Infracost comment
      run: |
        infracost comment github --path infracost-diff.json \\
          --repo \$GITHUB_REPOSITORY \\
          --github-token \${{ github.token }} \\
          --pull-request \${{ github.event.number }}
YAML
    
    log_success "GitHub Actions workflow created: $workflow_path"
}

# CODEOWNERS 파일 생성
generate_codeowners() {
    local repo_path="$1"
    local team_name="${2:-@devops-team}"
    
    local codeowners_path="$repo_path/.github/CODEOWNERS"
    
    mkdir -p "$(dirname "$codeowners_path")"
    
    log_info "Generating CODEOWNERS file..."
    
    cat > "$codeowners_path" <<CODEOWNERS
# StackKit Infrastructure Code Owners
# Global owners for infrastructure code
*.tf ${team_name}
*.tfvars ${team_name}
*.hcl ${team_name}
atlantis.yaml ${team_name}

# Deployment scripts
*.sh ${team_name}

# CI/CD workflows
.github/ ${team_name}
CODEOWNERS
    
    log_success "CODEOWNERS file created: $codeowners_path"
}

# 저장소 설정 종합 함수
setup_repository_integration() {
    local repo_full_name="$1"
    local repo_local_path="$2"
    local webhook_url="$3"
    local webhook_secret="$4"
    local github_token="$5"
    local aws_region="${6:-ap-northeast-2}"
    local terraform_version="${7:-1.7.5}"
    local enable_infracost="${8:-false}"
    local team_name="${9:-@devops-team}"
    
    log_info "Setting up comprehensive GitHub integration for $repo_full_name..."
    
    # 저장소 정보 확인
    get_repository_info "$repo_full_name" "$github_token" >/dev/null
    
    # 웹훅 설정
    local webhook_id
    webhook_id=$(create_or_update_webhook "$repo_full_name" "$webhook_url" "$webhook_secret" "$github_token")
    
    # 웹훅 테스트
    test_webhook "$repo_full_name" "$webhook_id" "$github_token"
    
    # 브랜치 보호 설정
    setup_branch_protection "$repo_full_name" "main" "$github_token" "true"
    
    # 로컬 설정 파일들 생성
    if [[ -d "$repo_local_path" ]]; then
        generate_atlantis_config "$repo_local_path" "$aws_region" "$terraform_version" "$enable_infracost"
        generate_github_workflow "$repo_local_path" "${repo_full_name##*/}" "$aws_region"
        generate_codeowners "$repo_local_path" "$team_name"
        
        log_info "Configuration files created in: $repo_local_path"
        log_info "Don't forget to commit and push these files:"
        log_info "  - atlantis.yaml"
        log_info "  - .github/workflows/stackkit-ci.yml"
        log_info "  - .github/CODEOWNERS"
    fi
    
    log_success "GitHub repository integration completed"
    log_info "Webhook ID: $webhook_id"
    log_info "Next steps:"
    log_info "  1. Commit and push the generated configuration files"
    log_info "  2. Create a test PR to verify Atlantis integration"
    log_info "  3. Check webhook delivery in GitHub repository settings"
}