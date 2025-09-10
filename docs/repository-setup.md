# 🔗 저장소 연결 가이드

Atlantis에 여러 저장소를 연결하고 관리하는 방법을 설명합니다.

## 🚀 단일 저장소 연결

### 기본 연결
```bash
# Atlantis 배포 완료 후 저장소 연결
cd atlantis-ecs
./connect.sh \
  --atlantis-url https://your-atlantis-url.com \
  --repo-name myorg/backend-infra \
  --github-token ghp_xxxxxxxxxxxxx
```

### 고급 연결 옵션
```bash
# 모든 옵션을 사용한 연결
./connect.sh \
  --atlantis-url https://atlantis.company.com \
  --repo-name myorg/infrastructure \
  --github-token ghp_xxxxxxxxxxxxx \
  --project-dir terraform/environments/prod \
  --secret-name prod-atlantis-secrets \
  --auto-plan \
  --enable-slack-notifications
```

## 📦 여러 저장소 일괄 연결

### 저장소 목록 파일 생성
```bash
# repos.txt 파일 생성
cat > repos.txt << EOF
mycompany/backend-infrastructure
mycompany/frontend-infrastructure
mycompany/data-platform
mycompany/monitoring-stack
mycompany/security-baseline
EOF
```

### 일괄 연결 스크립트
```bash
#!/bin/bash
# bulk-connect.sh

ATLANTIS_URL="https://atlantis.company.com"
GITHUB_TOKEN="ghp_xxxxxxxxxxxxx"
SECRET_NAME="prod-atlantis-secrets"

while read -r repo; do
    if [[ -n "$repo" && ! "$repo" =~ ^# ]]; then
        echo "🔗 연결 중: $repo"
        
        ./connect.sh \
            --atlantis-url "$ATLANTIS_URL" \
            --repo-name "$repo" \
            --github-token "$GITHUB_TOKEN" \
            --secret-name "$SECRET_NAME" \
            --auto-plan
        
        echo "✅ 완료: $repo"
        echo ""
    fi
done < repos.txt

echo "🎉 모든 저장소 연결 완료!"
```

### 실행
```bash
chmod +x bulk-connect.sh
./bulk-connect.sh
```

## 🏗️ 프로젝트 구조별 연결

### StackKit 표준 구조
```bash
# terraform/stacks 구조의 프로젝트
./connect.sh \
  --atlantis-url https://atlantis.company.com \
  --repo-name myorg/multi-stack-infra \
  --github-token ghp_xxx \
  --project-dir terraform/stacks/web-app-prod
```

### 모노레포 다중 프로젝트
```bash
# 하나의 저장소에 여러 Terraform 프로젝트가 있는 경우
projects=(
    "terraform/environments/dev"
    "terraform/environments/staging"
    "terraform/environments/prod"
)

for project in "${projects[@]}"; do
    ./connect.sh \
        --atlantis-url https://atlantis.company.com \
        --repo-name myorg/monorepo-infra \
        --github-token ghp_xxx \
        --project-dir "$project"
done
```

## ⚙️ 고급 설정

### 자동 Plan 설정
```bash
# 자동 Plan 활성화 (개발 환경)
./connect.sh \
  --atlantis-url https://atlantis.company.com \
  --repo-name myorg/dev-infra \
  --github-token ghp_xxx \
  --auto-plan \
  --auto-merge  # 주의: 개발 환경에서만 사용
```

### 환경별 다른 설정
```bash
# 환경별 설정 함수
connect_environment() {
    local env=$1
    local repo=$2
    local auto_options=""
    
    case $env in
        dev)
            auto_options="--auto-plan --auto-merge"
            ;;
        staging)
            auto_options="--auto-plan"
            ;;
        prod)
            auto_options=""  # 수동 승인 필요
            ;;
    esac
    
    ./connect.sh \
        --atlantis-url https://atlantis.company.com \
        --repo-name "$repo" \
        --github-token ghp_xxx \
        --project-dir "terraform/environments/$env" \
        $auto_options \
        --enable-slack-notifications
}

# 사용 예시
connect_environment "dev" "myorg/web-platform"
connect_environment "staging" "myorg/web-platform"
connect_environment "prod" "myorg/web-platform"
```

## 🔐 보안 및 권한 관리

### 저장소별 GitHub 토큰 분리
```bash
# 조직별 토큰 사용
declare -A ORG_TOKENS=(
    ["mycompany"]="ghp_token_for_mycompany"
    ["partner-org"]="ghp_token_for_partner"
    ["opensource"]="ghp_token_for_opensource"
)

connect_with_org_token() {
    local repo=$1
    local org=$(echo "$repo" | cut -d'/' -f1)
    local token="${ORG_TOKENS[$org]}"
    
    if [[ -z "$token" ]]; then
        echo "❌ $org 조직의 토큰이 설정되지 않았습니다"
        return 1
    fi
    
    ./connect.sh \
        --atlantis-url https://atlantis.company.com \
        --repo-name "$repo" \
        --github-token "$token"
}
```

### 접근 권한 검증
```bash
# 저장소 접근 권한 확인 스크립트
check_repo_access() {
    local repo=$1
    local token=$2
    
    echo "🔍 $repo 접근 권한 확인 중..."
    
    # 저장소 존재 확인
    if curl -s -H "Authorization: token $token" \
            "https://api.github.com/repos/$repo" | jq -e '.id' >/dev/null; then
        echo "✅ 저장소 접근 가능"
    else
        echo "❌ 저장소 접근 불가"
        return 1
    fi
    
    # 웹훅 설정 권한 확인
    if curl -s -H "Authorization: token $token" \
            "https://api.github.com/repos/$repo/hooks" | jq -e '. | length' >/dev/null; then
        echo "✅ 웹훅 설정 권한 있음"
    else
        echo "❌ 웹훅 설정 권한 없음"
        return 1
    fi
    
    return 0
}
```

## 📊 연결 상태 모니터링

### 연결된 저장소 목록 확인
```bash
# 웹훅 목록을 통한 연결 확인
check_connected_repos() {
    local atlantis_url=$1
    local github_token=$2
    
    echo "🔍 연결된 저장소 확인 중..."
    
    # GitHub API로 웹훅이 설정된 저장소 찾기
    for repo in $(gh repo list --json name,owner --jq '.[] | "\(.owner.login)/\(.name)"'); do
        webhooks=$(curl -s -H "Authorization: token $github_token" \
                   "https://api.github.com/repos/$repo/hooks" | \
                   jq -r ".[] | select(.config.url | contains(\"$atlantis_url\")) | .config.url")
        
        if [[ -n "$webhooks" ]]; then
            echo "✅ $repo"
        fi
    done
}
```

### 연결 상태 대시보드
```bash
# 간단한 상태 대시보드
create_status_dashboard() {
    cat > status.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Atlantis 저장소 연결 상태</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .connected { color: green; }
        .disconnected { color: red; }
        .warning { color: orange; }
    </style>
</head>
<body>
    <h1>🏗️ Atlantis 저장소 연결 상태</h1>
    <div id="status"></div>
    
    <script>
        // 실제 구현에서는 API를 호출하여 상태 확인
        const repos = [
            {name: "myorg/backend", status: "connected", lastActivity: "2시간 전"},
            {name: "myorg/frontend", status: "connected", lastActivity: "1일 전"},
            {name: "myorg/data", status: "warning", lastActivity: "3일 전"}
        ];
        
        const statusDiv = document.getElementById('status');
        repos.forEach(repo => {
            const div = document.createElement('div');
            div.className = repo.status;
            div.innerHTML = `${repo.name} - ${repo.status} (${repo.lastActivity})`;
            statusDiv.appendChild(div);
        });
    </script>
</body>
</html>
EOF
    
    echo "📊 status.html 생성 완료"
}
```

## 🔄 연결 관리 및 유지보수

### 웹훅 상태 확인 및 복구
```bash
# 웹훅 상태 확인 스크립트
verify_webhook_health() {
    local repo=$1
    local github_token=$2
    local atlantis_url=$3
    
    echo "🩺 $repo 웹훅 상태 확인 중..."
    
    # 웹훅 목록 조회
    webhooks=$(curl -s -H "Authorization: token $github_token" \
               "https://api.github.com/repos/$repo/hooks" | \
               jq -r ".[] | select(.config.url | contains(\"$atlantis_url\"))")
    
    if [[ -z "$webhooks" ]]; then
        echo "❌ 웹훅이 설정되지 않음"
        return 1
    fi
    
    # 웹훅 활성 상태 확인
    active=$(echo "$webhooks" | jq -r '.active')
    if [[ "$active" != "true" ]]; then
        echo "⚠️ 웹훅이 비활성화됨"
        return 1
    fi
    
    # 최근 배송 상태 확인
    webhook_id=$(echo "$webhooks" | jq -r '.id')
    deliveries=$(curl -s -H "Authorization: token $github_token" \
                "https://api.github.com/repos/$repo/hooks/$webhook_id/deliveries" | \
                jq -r '.[0:5] | .[] | {delivered_at: .delivered_at, status_code: .status_code}')
    
    echo "📦 최근 배송 상태:"
    echo "$deliveries" | jq -r '"  \(.delivered_at): HTTP \(.status_code)"'
    
    return 0
}
```

### 연결 정리 및 재설정
```bash
# 모든 웹훅 제거 후 재설정
reset_repository_connection() {
    local repo=$1
    local github_token=$2
    local atlantis_url=$3
    
    echo "🔄 $repo 연결 재설정 중..."
    
    # 기존 웹훅 제거
    webhook_ids=$(curl -s -H "Authorization: token $github_token" \
                  "https://api.github.com/repos/$repo/hooks" | \
                  jq -r ".[] | select(.config.url | contains(\"$atlantis_url\")) | .id")
    
    for webhook_id in $webhook_ids; do
        curl -s -X DELETE \
             -H "Authorization: token $github_token" \
             "https://api.github.com/repos/$repo/hooks/$webhook_id"
        echo "🗑️ 웹훅 $webhook_id 제거됨"
    done
    
    # 새로운 연결 설정
    ./connect.sh \
        --atlantis-url "$atlantis_url" \
        --repo-name "$repo" \
        --github-token "$github_token"
    
    echo "✅ $repo 재연결 완료"
}
```

## 📝 베스트 프랙티스

### 1. 저장소 명명 규칙
```bash
# 권장 저장소 명명 규칙
organization/environment-service-infrastructure
# 예시:
# mycompany/prod-web-infrastructure
# mycompany/dev-data-infrastructure
# mycompany/shared-security-infrastructure
```

### 2. 브랜치 전략
```yaml
# atlantis.yaml에서 브랜치별 설정
version: 3
projects:
- name: production
  dir: .
  terraform_version: v1.7.5
  autoplan:
    when_modified: ["**/*.tf", "**/*.tfvars"]
    enabled: false  # 프로덕션은 수동 Plan
  apply_requirements: ["approved", "mergeable"]
  
- name: staging
  dir: .
  terraform_version: v1.7.5
  autoplan:
    when_modified: ["**/*.tf", "**/*.tfvars"]
    enabled: true   # 스테이징은 자동 Plan
  apply_requirements: ["mergeable"]
```

### 3. 팀별 접근 제어
```bash
# 팀별 저장소 그룹 관리
declare -A TEAM_REPOS=(
    ["backend-team"]="myorg/api-infra myorg/db-infra myorg/cache-infra"
    ["frontend-team"]="myorg/web-infra myorg/cdn-infra"
    ["data-team"]="myorg/data-platform myorg/analytics-infra"
    ["devops-team"]="myorg/shared-infra myorg/monitoring myorg/security"
)

connect_team_repos() {
    local team=$1
    local repos="${TEAM_REPOS[$team]}"
    
    echo "🏢 $team 저장소 연결 중..."
    
    for repo in $repos; do
        ./connect.sh \
            --atlantis-url https://atlantis.company.com \
            --repo-name "$repo" \
            --github-token "${TEAM_TOKENS[$team]}" \
            --enable-slack-notifications
    done
}
```

이러한 가이드라인을 따라 체계적으로 저장소를 관리하면 대규모 인프라 환경에서도 효율적인 Atlantis 운영이 가능합니다.