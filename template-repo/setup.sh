#!/bin/bash

# StackKit Template Repository Setup Script
# 이 스크립트는 새로운 조직에서 StackKit Atlantis를 설정할 때 실행합니다

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Default values
ORG_NAME=""
GITHUB_TOKEN=""
OPENAI_API_KEY=""
SLACK_WEBHOOK=""
AWS_REGION="ap-northeast-2"
ENVIRONMENT="dev"
REPO_PATTERNS=""

print_banner() {
    echo -e "${BLUE}"
    echo "  ____  _             _    _  ___ _   "
    echo " / ___|| |_ __ _  ___| | _| |/ (_) |_ "
    echo " \\___ \\| __/ _\` |/ __| |/ / ' /| | __|"
    echo "  ___) | || (_| | (__|   <| . \\| | |_ "
    echo " |____/ \\__\\__,_|\\___|_|\\_\\_|\\_\\_|\\__|"
    echo "                                     "
    echo -e "${NC}${GREEN}🚀 Atlantis + AI Reviewer 템플릿 설정${NC}"
    echo ""
}

show_usage() {
    cat << EOF
🏗️ StackKit 템플릿 레포지토리 설정

이 스크립트는 새로운 조직에서 StackKit Atlantis 인프라를 빠르게 설정합니다.

Usage: $0 [options]

필수 옵션:
    -o, --org-name NAME         조직 이름 (예: mycompany)
    -g, --github-token TOKEN    GitHub Personal Access Token
    -k, --openai-key KEY        OpenAI API Key  
    -s, --slack-webhook URL     Slack Webhook URL

선택 옵션:
    -r, --region REGION         AWS 리전 (기본값: ap-northeast-2)
    -e, --environment ENV       환경 이름 (기본값: dev)
    -p, --repo-patterns PATTERNS 관리할 레포 패턴 (예: "github.com/myorg/*")
    -h, --help                  도움말 표시

예시:
    $0 -o mycompany -g ghp_xxxx -k sk-xxxx -s https://hooks.slack.com/xxxx

설정 후:
    1. config/config.yml 파일이 생성됩니다
    2. GitHub Secrets를 설정하세요
    3. GitHub Actions가 자동으로 인프라를 배포합니다
EOF
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -o|--org-name)
                ORG_NAME="$2"
                shift 2
                ;;
            -g|--github-token)
                GITHUB_TOKEN="$2"
                shift 2
                ;;
            -k|--openai-key)
                OPENAI_API_KEY="$2"
                shift 2
                ;;
            -s|--slack-webhook)
                SLACK_WEBHOOK="$2"
                shift 2
                ;;
            -r|--region)
                AWS_REGION="$2"
                shift 2
                ;;
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -p|--repo-patterns)
                REPO_PATTERNS="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                echo -e "${RED}❌ 알 수 없는 옵션: $1${NC}"
                show_usage
                exit 1
                ;;
        esac
    done
}

validate_inputs() {
    local errors=0
    
    if [[ -z "$ORG_NAME" ]]; then
        echo -e "${RED}❌ 조직 이름이 필요합니다 (-o 옵션)${NC}"
        errors=$((errors + 1))
    fi
    
    if [[ -z "$GITHUB_TOKEN" ]]; then
        echo -e "${RED}❌ GitHub 토큰이 필요합니다 (-g 옵션)${NC}"
        errors=$((errors + 1))
    fi
    
    if [[ -z "$OPENAI_API_KEY" ]]; then
        echo -e "${RED}❌ OpenAI API 키가 필요합니다 (-k 옵션)${NC}"
        errors=$((errors + 1))
    fi
    
    if [[ -z "$SLACK_WEBHOOK" ]]; then
        echo -e "${RED}❌ Slack Webhook URL이 필요합니다 (-s 옵션)${NC}"
        errors=$((errors + 1))
    fi
    
    if [[ $errors -gt 0 ]]; then
        echo -e "${RED}❌ $errors 개의 필수 인자가 누락되었습니다${NC}"
        echo ""
        show_usage
        exit 1
    fi
}

interactive_setup() {
    echo -e "${BLUE}📝 대화형 설정 모드${NC}"
    echo ""
    
    if [[ -z "$ORG_NAME" ]]; then
        read -p "조직 이름을 입력하세요 (예: mycompany): " ORG_NAME
    fi
    
    if [[ -z "$GITHUB_TOKEN" ]]; then
        read -s -p "GitHub Personal Access Token: " GITHUB_TOKEN
        echo
    fi
    
    if [[ -z "$OPENAI_API_KEY" ]]; then
        read -s -p "OpenAI API Key: " OPENAI_API_KEY
        echo
    fi
    
    if [[ -z "$SLACK_WEBHOOK" ]]; then
        read -p "Slack Webhook URL: " SLACK_WEBHOOK
    fi
    
    if [[ -z "$REPO_PATTERNS" ]]; then
        REPO_PATTERNS="github.com/${ORG_NAME}/*"
        read -p "관리할 레포 패턴 (기본값: $REPO_PATTERNS): " input_patterns
        if [[ -n "$input_patterns" ]]; then
            REPO_PATTERNS="$input_patterns"
        fi
    fi
}

update_config_file() {
    echo -e "${BLUE}📝 config/config.yml 업데이트 중...${NC}"
    
    # config.yml 템플릿을 실제 값으로 업데이트
    sed -i.bak "s/name: \"mycompany\"/name: \"$ORG_NAME\"/" config/config.yml
    sed -i.bak "s/name: \"dev\"/name: \"$ENVIRONMENT\"/" config/config.yml
    sed -i.bak "s/region: \"ap-northeast-2\"/region: \"$AWS_REGION\"/" config/config.yml
    
    # 레포지토리 패턴 업데이트
    if [[ -n "$REPO_PATTERNS" ]]; then
        # YAML 배열 형식으로 변환
        IFS=',' read -ra PATTERNS <<< "$REPO_PATTERNS"
        pattern_yaml=""
        for pattern in "${PATTERNS[@]}"; do
            pattern_yaml+="    - \"${pattern}\"\n"
        done
        
        # repository_patterns 섹션 교체
        awk -v patterns="$pattern_yaml" '
        /repository_patterns:/ {
            print $0
            print patterns
            while(getline && match($0, /^    - /)) continue
            print $0
            next
        }
        {print}
        ' config/config.yml > config/config.yml.tmp && mv config/config.yml.tmp config/config.yml
    fi
    
    # 백업 파일 삭제
    rm -f config/config.yml.bak
    
    echo -e "${GREEN}✅ config/config.yml 파일이 업데이트되었습니다${NC}"
}

create_github_secrets_guide() {
    echo -e "${BLUE}📋 GitHub Secrets 설정 가이드 생성 중...${NC}"
    
    cat > GITHUB_SECRETS_GUIDE.md << EOF
# GitHub Secrets 설정 가이드

이 레포지토리에서 Atlantis 인프라를 배포하기 위해서는 다음 GitHub Secrets를 설정해야 합니다.

## 설정 방법

1. GitHub 레포지토리 → Settings → Secrets and variables → Actions
2. "New repository secret" 클릭하여 아래 시크릿들을 추가

## 필수 Secrets

### AWS 인증 정보
\`\`\`
Secret Name: AWS_ACCESS_KEY_ID
Secret Value: [AWS Access Key ID]
\`\`\`

\`\`\`
Secret Name: AWS_SECRET_ACCESS_KEY  
Secret Value: [AWS Secret Access Key]
\`\`\`

### OpenAI API Key
\`\`\`
Secret Name: OPENAI_API_KEY
Secret Value: $OPENAI_API_KEY
\`\`\`

### Slack Webhook URL
\`\`\`
Secret Name: SLACK_WEBHOOK_URL
Secret Value: $SLACK_WEBHOOK
\`\`\`

## 선택적 Secrets

### Infracost API Key (비용 추정용)
\`\`\`
Secret Name: INFRACOST_API_KEY
Secret Value: [Infracost API Key - https://www.infracost.io/]
\`\`\`

## Variables 설정

Variables 탭에서 다음을 설정하세요:

\`\`\`
Variable Name: AWS_REGION
Variable Value: $AWS_REGION
\`\`\`

## 설정 완료 후

1. 이 레포지토리의 main 브랜치에 커밋하면 GitHub Actions가 자동으로 실행됩니다
2. Actions 탭에서 배포 진행상황을 확인할 수 있습니다
3. 배포 완료 후 Atlantis URL이 출력됩니다

## 문제 해결

- AWS 권한 오류: IAM 사용자에게 AdministratorAccess 정책이 있는지 확인
- OpenAI API 오류: API 키가 유효하고 크레딧이 있는지 확인  
- Slack 알림 오류: Webhook URL이 올바른지 확인

## 다음 단계

인프라 배포가 완료되면:
1. 프로젝트 레포지토리를 생성하고 \`atlantis.yaml\` 파일을 추가하세요
2. Terraform 코드가 포함된 PR을 생성하여 AI 리뷰를 테스트하세요
EOF
    
    echo -e "${GREEN}✅ GITHUB_SECRETS_GUIDE.md 파일이 생성되었습니다${NC}"
}

create_readme() {
    echo -e "${BLUE}📋 README.md 업데이트 중...${NC}"
    
    cat > README.md << EOF
# 🏗️ $ORG_NAME Atlantis + AI Reviewer Infrastructure

이 레포지토리는 StackKit 템플릿을 사용하여 생성된 $ORG_NAME 조직의 Atlantis 인프라입니다.

## 🚀 배포된 구성요소

- **Atlantis Server**: ECS Fargate에서 실행되는 Terraform 자동화 서버
- **AI Reviewer**: OpenAI GPT-4 기반 Terraform 계획 검토 시스템  
- **인프라**: VPC, ALB, S3, SQS, Lambda를 포함한 완전한 AWS 인프라
- **보안**: Secrets Manager, IAM 역할, 보안 그룹을 통한 보안 설정

## 📋 현재 설정

- **조직**: $ORG_NAME
- **환경**: $ENVIRONMENT  
- **AWS 리전**: $AWS_REGION
- **관리 레포**: $REPO_PATTERNS

## 🔧 배포 방법

### 1. GitHub Secrets 설정

[GITHUB_SECRETS_GUIDE.md](./GITHUB_SECRETS_GUIDE.md) 파일을 참고하여 필요한 시크릿들을 설정하세요.

### 2. 자동 배포

main 브랜치에 커밋하면 GitHub Actions가 자동으로 인프라를 배포합니다:

\`\`\`bash
git add .
git commit -m "feat: configure $ORG_NAME atlantis infrastructure"
git push origin main
\`\`\`

### 3. 배포 확인

- GitHub Actions 탭에서 배포 진행상황 확인
- 완료 후 Summary에서 Atlantis URL 확인

## 🎯 프로젝트 레포지토리 설정

### atlantis.yaml 예시

프로젝트 레포지토리에 다음과 같은 \`atlantis.yaml\` 파일을 추가하세요:

\`\`\`yaml
version: 3
projects:
- name: my-project
  dir: terraform/
  workflow: stackkit-ai-review
  autoplan:
    enabled: true
    when_modified: ["**/*.tf", "**/*.tfvars"]

workflows:
  stackkit-ai-review:
    plan:
      steps:
      - init
      - plan
    apply:
      steps:
      - apply
\`\`\`

### 사용 방법

1. 프로젝트 레포에서 Terraform 코드 수정
2. Pull Request 생성
3. Atlantis가 자동으로 \`terraform plan\` 실행
4. AI Reviewer가 계획을 분석하고 Slack으로 리뷰 결과 전송
5. 승인 후 \`atlantis apply\` 코멘트로 배포

## 🔍 모니터링

### Slack 알림
- 계획 검토 결과
- 배포 성공/실패 알림
- 비용 경고 ($COST_THRESHOLD USD 초과시)

### CloudWatch 로그
- ECS 서비스: \`/ecs/${ORG_NAME}-atlantis-${ENVIRONMENT}\`
- Lambda: \`/aws/lambda/${ORG_NAME}-atlantis-${ENVIRONMENT}-ai-reviewer\`

## 🛠️ 고도화

이 레포지토리는 확장 가능하도록 설계되었습니다:

### 환경 추가
\`\`\`bash
cp -r terraform/environments/dev terraform/environments/staging
# staging 환경 설정 수정 후 배포
\`\`\`

### 정책 추가
\`config/policies/\` 디렉토리에 OPA 정책 파일 추가

### 모니터링 강화
\`terraform/modules/monitoring/\` 모듈 추가하여 대시보드 구성

## 📚 문서

- [StackKit 가이드](https://github.com/your-org/stackkit)
- [Atlantis 문서](https://www.runatlantis.io/docs/)
- [GitHub Secrets 설정](./GITHUB_SECRETS_GUIDE.md)

## 🆘 지원

문제가 발생하면:
1. GitHub Actions 로그 확인
2. CloudWatch 로그 확인  
3. [Issues](https://github.com/$ORG_NAME/atlantis-infrastructure/issues)에서 도움 요청

---
Generated by StackKit Template v2.1.0
EOF

    echo -e "${GREEN}✅ README.md 파일이 생성되었습니다${NC}"
}

print_completion_message() {
    echo ""
    echo -e "${GREEN}🎉 StackKit 템플릿 설정 완료!${NC}"
    echo ""
    echo -e "${BLUE}📋 다음 단계:${NC}"
    echo ""
    echo -e "1. ${YELLOW}GitHub Secrets 설정${NC}"
    echo -e "   📋 GITHUB_SECRETS_GUIDE.md 파일을 참고하여 GitHub Secrets 설정"
    echo ""
    echo -e "2. ${YELLOW}코드 커밋 및 푸시${NC}"
    echo -e "   ${PURPLE}git add .${NC}"
    echo -e "   ${PURPLE}git commit -m \"feat: configure $ORG_NAME atlantis infrastructure\"${NC}"
    echo -e "   ${PURPLE}git push origin main${NC}"
    echo ""
    echo -e "3. ${YELLOW}배포 확인${NC}"
    echo -e "   GitHub Actions 탭에서 배포 진행상황을 확인하세요"
    echo ""
    echo -e "4. ${YELLOW}프로젝트 레포지토리에 atlantis.yaml 추가${NC}"
    echo -e "   README.md 파일의 예시를 참고하세요"
    echo ""
    echo -e "${BLUE}🔗 유용한 링크:${NC}"
    echo -e "   - 문서: https://github.com/your-org/stackkit"
    echo -e "   - 지원: https://github.com/$ORG_NAME/atlantis-infrastructure/issues"
    echo ""
}

main() {
    print_banner
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # If no arguments provided, run interactive setup
    if [[ $# -eq 0 ]]; then
        interactive_setup
    fi
    
    # Validate inputs
    validate_inputs
    
    # Update configuration files
    update_config_file
    create_github_secrets_guide
    create_readme
    
    # Show completion message
    print_completion_message
}

# Run main function with all arguments
main "$@"