#!/usr/bin/env bash
set -euo pipefail

# 기존 프로젝트에 StackKit Atlantis AI Reviewer 통합 스크립트
# 사용법: ./integrate-existing-project.sh --project-dir=/path/to/project [OPTIONS]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 기본값 설정
PROJECT_DIR=""
ATLANTIS_URL=""
IMPORT_EXISTING=false
DRY_RUN=false
BACKUP_DIR=""

show_usage() {
    cat << 'EOF'
🔗 기존 프로젝트에 StackKit Atlantis AI Reviewer 통합

사용법:
    ./integrate-existing-project.sh --project-dir=/path/to/project [OPTIONS]

필수 옵션:
    --project-dir=PATH         기존 Terraform 프로젝트 디렉토리

선택 옵션:
    --atlantis-url=URL         Atlantis 서버 URL (예: https://atlantis.example.com)
    --import-existing          기존 AWS 리소스 자동 import 시도
    --backup-dir=PATH          백업 디렉토리 (기본: ./backup-YYYYMMDD-HHMMSS)
    --dry-run                  실제 실행 없이 계획만 출력

예시:
    # 기본 통합
    ./integrate-existing-project.sh --project-dir=/home/user/my-terraform-project
    
    # 기존 리소스 import와 함께
    ./integrate-existing-project.sh \
        --project-dir=/home/user/my-terraform-project \
        --import-existing \
        --atlantis-url=https://atlantis.mycompany.com

기능:
    - atlantis.yaml 설정 파일 생성
    - 기존 Terraform 코드 StackKit 모듈로 마이그레이션 제안
    - 기존 AWS 리소스 자동 import (선택사항)
    - 백업 및 롤백 지원

EOF
}

# 인수 파싱
while [[ $# -gt 0 ]]; do
    case $1 in
        --project-dir=*)
            PROJECT_DIR="${1#*=}"
            shift
            ;;
        --atlantis-url=*)
            ATLANTIS_URL="${1#*=}"
            shift
            ;;
        --import-existing)
            IMPORT_EXISTING=true
            shift
            ;;
        --backup-dir=*)
            BACKUP_DIR="${1#*=}"
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            echo "❌ 알 수 없는 옵션: $1"
            show_usage
            exit 1
            ;;
    esac
done

# 필수 인수 검증
if [[ -z "$PROJECT_DIR" ]]; then
    echo "❌ --project-dir 옵션이 필요합니다."
    show_usage
    exit 1
fi

if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "❌ 프로젝트 디렉토리가 존재하지 않습니다: $PROJECT_DIR"
    exit 1
fi

# 절대 경로로 변환
PROJECT_DIR=$(realpath "$PROJECT_DIR")

# 백업 디렉토리 설정
if [[ -z "$BACKUP_DIR" ]]; then
    BACKUP_DIR="$PROJECT_DIR/backup-$(date +%Y%m%d-%H%M%S)"
fi

echo "🔗 기존 프로젝트 Atlantis 통합 시작"
echo "================================="
echo "프로젝트 디렉토리: $PROJECT_DIR"
echo "백업 디렉토리: $BACKUP_DIR"
echo "기존 리소스 Import: $IMPORT_EXISTING"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
    echo "🔍 DRY RUN 모드 - 실제 실행하지 않음"
    echo ""
fi

# Step 1: 프로젝트 분석
echo "🔍 Step 1: 기존 프로젝트 분석 중..."

cd "$PROJECT_DIR"

# Terraform 파일 확인
TF_FILES=$(find . -name "*.tf" -type f | head -10)
if [[ -z "$TF_FILES" ]]; then
    echo "❌ Terraform 파일(.tf)을 찾을 수 없습니다."
    exit 1
fi

echo "   📄 발견된 Terraform 파일들:"
echo "$TF_FILES" | sed 's/^/      /'

# 기존 상태 파일 확인
if [[ -f "terraform.tfstate" ]]; then
    echo "   📊 로컬 상태 파일 발견: terraform.tfstate"
    STATE_TYPE="local"
elif [[ -f ".terraform/terraform.tfstate" ]]; then
    echo "   📊 로컬 상태 파일 발견: .terraform/terraform.tfstate"
    STATE_TYPE="local"
else
    echo "   🌐 원격 상태 백엔드 사용 중"
    STATE_TYPE="remote"
fi

# 기존 리소스 분석
if [[ "$STATE_TYPE" == "local" || -f ".terraform/terraform.tfstate" ]]; then
    echo "   🔍 기존 리소스 분석 중..."
    if command -v terraform &> /dev/null && terraform show &> /dev/null; then
        RESOURCE_COUNT=$(terraform show -json 2>/dev/null | jq '.values.root_module.resources | length' 2>/dev/null || echo "0")
        echo "   📊 관리 중인 리소스 수: $RESOURCE_COUNT"
    fi
fi

echo "✅ 프로젝트 분석 완료"
echo ""

# Step 2: 백업 생성
echo "💾 Step 2: 프로젝트 백업 생성 중..."

if [[ "$DRY_RUN" != "true" ]]; then
    mkdir -p "$BACKUP_DIR"
    
    # 중요 파일들 백업
    cp -r . "$BACKUP_DIR/" 2>/dev/null || {
        echo "   ⚠️  일부 파일 백업 실패 (권한 문제일 수 있음)"
    }
    
    echo "   📁 백업 완료: $BACKUP_DIR"
else
    echo "   [DRY RUN] mkdir -p $BACKUP_DIR && cp -r . $BACKUP_DIR/"
fi

echo "✅ 백업 생성 완료"
echo ""

# Step 3: atlantis.yaml 생성
echo "⚙️  Step 3: atlantis.yaml 설정 파일 생성 중..."

ATLANTIS_CONFIG="$PROJECT_DIR/atlantis.yaml"

if [[ "$DRY_RUN" != "true" ]]; then
    # 프로젝트 이름 추출 (디렉토리명 기반)
    PROJECT_NAME=$(basename "$PROJECT_DIR")
    
    cat > "$ATLANTIS_CONFIG" << EOF
version: 3

# StackKit Atlantis AI Reviewer 설정
# Generated by integrate-existing-project.sh on $(date)

projects:
  - name: ${PROJECT_NAME}
    dir: .
    workflow: stackkit-ai-review
    
    # 자동 계획 설정
    autoplan:
      enabled: true
      when_modified: ["**/*.tf", "**/*.tfvars"]
    
    # Terraform 버전 (필요시 수정)
    terraform_version: v1.8.5
    
    # 적용 요구사항
    apply_requirements: [approved, mergeable]

# AI 리뷰가 포함된 워크플로우
workflows:
  stackkit-ai-review:
    plan:
      steps:
        - init
        - plan:
            extra_args: ["-input=false"]
        - run: |
            set -euo pipefail
            # Plan 결과를 JSON과 텍스트로 저장
            terraform show -json "\$PLANFILE" > tfplan.json
            terraform show "\$PLANFILE" > plan.txt
            
            # S3 업로드를 위한 경로 설정
            BUCKET="\${PLAN_BUCKET:-atlantis-plans}"
            PREFIX="\${BASE_REPO_OWNER}/\${BASE_REPO_NAME}/\${PULL_NUM}/${PROJECT_NAME}"
            
            # 변경사항 여부 확인
            HAS_CHANGES=\$(jq '(.resource_changes|length) > 0' tfplan.json)
            
            # 메타데이터 생성
            jq -n --arg repo "\${BASE_REPO_OWNER}/\${BASE_REPO_NAME}" \\
                  --arg pr "\$PULL_NUM" \\
                  --arg proj "${PROJECT_NAME}" \\
                  --arg action "plan" \\
                  --arg status "success" \\
                  --arg commit "\$HEAD_COMMIT" \\
                  --argjson has "\$HAS_CHANGES" \\
                  '{repo:\$repo,pr:(\$pr|tonumber),project:\$proj,action:\$action,status:\$status,commit:\$commit,has_changes:\$has}' \\
              > manifest.json
            
            # S3에 업로드 (AI 리뷰 트리거)
            aws s3 cp "\$PLANFILE"      "s3://\$BUCKET/\$PREFIX/tfplan.bin"
            aws s3 cp tfplan.json      "s3://\$BUCKET/\$PREFIX/tfplan.json"
            aws s3 cp plan.txt         "s3://\$BUCKET/\$PREFIX/plan.txt"
            aws s3 cp manifest.json    "s3://\$BUCKET/\$PREFIX/manifest.json"
            
            echo "📤 Plan 결과가 AI 리뷰를 위해 업로드되었습니다."
    
    apply:
      steps:
        - run: |
            set +e
            terraform apply -input=false -no-color "\$PLANFILE" | tee apply.txt
            STATUS=\$?
            set -e
            
            # Apply 결과도 S3에 업로드
            BUCKET="\${PLAN_BUCKET:-atlantis-plans}"
            PREFIX="\${BASE_REPO_OWNER}/\${BASE_REPO_NAME}/\${PULL_NUM}/${PROJECT_NAME}"
            
            jq -n --arg repo "\${BASE_REPO_OWNER}/\${BASE_REPO_NAME}" \\
                  --arg pr "\$PULL_NUM" \\
                  --arg proj "${PROJECT_NAME}" \\
                  --arg action "apply" \\
                  --arg status "\$([ \$STATUS -eq 0 ] && echo success || echo failure)" \\
                  --arg commit "\$HEAD_COMMIT" \\
                  '{repo:\$repo,pr:(\$pr|tonumber),project:\$proj,action:\$action,status:\$status,commit:\$commit}' \\
              > manifest.json
            
            aws s3 cp apply.txt      "s3://\$BUCKET/\$PREFIX/apply.txt"
            aws s3 cp manifest.json  "s3://\$BUCKET/\$PREFIX/manifest.json"
            
            exit \$STATUS
EOF

    echo "   📝 atlantis.yaml 생성 완료"
else
    echo "   [DRY RUN] atlantis.yaml 생성: $ATLANTIS_CONFIG"
fi

echo "✅ Atlantis 설정 완료"
echo ""

# Step 4: 기존 리소스 Import (선택사항)
if [[ "$IMPORT_EXISTING" == "true" ]]; then
    echo "📦 Step 4: 기존 AWS 리소스 Import 분석 중..."
    
    if [[ "$DRY_RUN" != "true" ]]; then
        # Terraform 상태에서 리소스 목록 추출
        if command -v terraform &> /dev/null; then
            echo "   🔍 현재 Terraform 상태 분석 중..."
            
            # terraform state list로 관리 중인 리소스 확인
            if terraform state list &> /dev/null; then
                MANAGED_RESOURCES=$(terraform state list)
                echo "   📊 현재 관리 중인 리소스들:"
                echo "$MANAGED_RESOURCES" | sed 's/^/      /'
                
                echo ""
                echo "   💡 기존 리소스가 이미 Terraform으로 관리되고 있습니다."
                echo "      추가 import가 필요한 리소스가 있다면 다음 스크립트를 사용하세요:"
                echo "      $PROJECT_ROOT/terraform/scripts/import-resources.sh"
            else
                echo "   ⚠️  Terraform 상태를 읽을 수 없습니다."
                echo "      수동으로 리소스를 import해야 할 수 있습니다."
            fi
        fi
    else
        echo "   [DRY RUN] Terraform 상태 분석 및 리소스 import 제안"
    fi
    
    echo "✅ 리소스 Import 분석 완료"
else
    echo "⏭️  Step 4: 기존 리소스 Import 건너뛰기"
fi

echo ""

# Step 5: StackKit 모듈 마이그레이션 제안
echo "🔄 Step 5: StackKit 모듈 마이그레이션 제안 생성 중..."

MIGRATION_GUIDE="$PROJECT_DIR/STACKKIT_MIGRATION_GUIDE.md"

if [[ "$DRY_RUN" != "true" ]]; then
    cat > "$MIGRATION_GUIDE" << 'EOF'
# StackKit 모듈 마이그레이션 가이드

이 가이드는 기존 Terraform 코드를 StackKit 모듈로 마이그레이션하는 방법을 제안합니다.

## 🎯 마이그레이션 혜택

- **표준화된 모듈**: 검증된 AWS 모범 사례 적용
- **자동화된 태깅**: 일관된 리소스 태깅
- **환경별 설정**: dev/staging/prod 환경 분리
- **보안 강화**: KMS 암호화, IAM 최소 권한 등

## 📋 마이그레이션 단계

### 1. 현재 리소스 분석
```bash
# 현재 관리 중인 리소스 확인
terraform state list

# 각 리소스의 상세 정보 확인
terraform show
```

### 2. StackKit 모듈 매핑

다음은 일반적인 리소스와 StackKit 모듈의 매핑입니다:

| 기존 리소스 | StackKit 모듈 | 예시 |
|------------|---------------|------|
| `aws_vpc.*` | `modules/vpc` | VPC, 서브넷, IGW, NAT |
| `aws_instance.*` | `modules/ec2` | EC2 인스턴스, ASG |
| `aws_db_instance.*` | `modules/rds` | RDS 데이터베이스 |
| `aws_elasticache_*` | `modules/elasticache` | Redis, Memcached |
| `aws_dynamodb_table.*` | `modules/dynamodb` | DynamoDB 테이블 |
| `aws_lambda_function.*` | `modules/lambda` | Lambda 함수 |
| `aws_sqs_queue.*` | `modules/sqs` | SQS 큐 |
| `aws_sns_topic.*` | `modules/sns` | SNS 토픽 |

### 3. 단계별 마이그레이션 계획

#### Phase 1: 네트워킹 (낮은 위험)
```hcl
# 기존 VPC 리소스를 StackKit VPC 모듈로 교체
module "vpc" {
  source = "../../modules/vpc"
  
  project_name = "your-project"
  environment  = "dev"
  vpc_cidr     = "10.0.0.0/16"
  
  # 기존 설정에 맞게 조정
  availability_zones = ["us-east-1a", "us-east-1c"]
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]
}
```

#### Phase 2: 컴퓨팅 (중간 위험)
```hcl
# EC2 인스턴스를 StackKit EC2 모듈로 교체
module "web_servers" {
  source = "../../modules/ec2"
  
  project_name  = "your-project"
  environment   = "dev"
  instance_type = "t3.micro"
  
  vpc_id    = module.vpc.vpc_id
  subnet_id = module.vpc.public_subnet_ids[0]
}
```

#### Phase 3: 데이터베이스 (높은 위험)
```hcl
# RDS를 StackKit RDS 모듈로 교체 (주의: 데이터 백업 필수)
module "database" {
  source = "../../modules/rds"
  
  project_name     = "your-project"
  environment      = "dev"
  engine           = "mysql"
  engine_version   = "8.0"
  instance_class   = "db.t3.micro"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
}
```

### 4. 마이그레이션 실행

#### 안전한 마이그레이션 절차:

1. **백업 생성**
   ```bash
   # 현재 상태 백업
   terraform state pull > backup.tfstate
   
   # 중요 데이터 백업 (RDS 스냅샷 등)
   aws rds create-db-snapshot --db-instance-identifier mydb --db-snapshot-identifier mydb-migration-backup
   ```

2. **Import 기존 리소스**
   ```bash
   # StackKit import 스크립트 사용
   ../stackkit/terraform/scripts/import-resources.sh . vpc module.vpc.aws_vpc.main vpc-12345678
   ```

3. **단계별 적용**
   ```bash
   # Phase별로 나누어 적용
   terraform plan -target=module.vpc
   terraform apply -target=module.vpc
   ```

4. **검증**
   ```bash
   # 리소스 상태 확인
   terraform state list
   terraform plan  # No changes가 나와야 함
   ```

### 5. 롤백 계획

문제 발생 시 롤백 절차:

```bash
# 1. 상태 파일 복원
terraform state push backup.tfstate

# 2. 이전 설정으로 복원
git checkout HEAD~1 -- *.tf

# 3. 적용
terraform plan
terraform apply
```

## 🛠️ 유용한 도구

- **State 조작**: `terraform state mv`, `terraform state rm`
- **Import**: `terraform import`
- **StackKit Import**: `../stackkit/terraform/scripts/import-resources.sh`

## 📞 지원

마이그레이션 중 문제가 발생하면:
1. 백업에서 복원
2. StackKit 문서 참조
3. 팀 채널에서 도움 요청

---
*이 가이드는 integrate-existing-project.sh에 의해 자동 생성되었습니다.*
EOF

    echo "   📖 마이그레이션 가이드 생성: $MIGRATION_GUIDE"
else
    echo "   [DRY RUN] 마이그레이션 가이드 생성: $MIGRATION_GUIDE"
fi

echo "✅ 마이그레이션 제안 완료"
echo ""

# 완료 메시지
echo "🎉 기존 프로젝트 Atlantis 통합 완료!"
echo "=================================="

if [[ "$DRY_RUN" != "true" ]]; then
    echo ""
    echo "📋 생성된 파일들:"
    echo "   - atlantis.yaml: Atlantis 설정 파일"
    echo "   - STACKKIT_MIGRATION_GUIDE.md: 모듈 마이그레이션 가이드"
    echo "   - $BACKUP_DIR/: 프로젝트 백업"
    echo ""
    echo "📋 다음 단계:"
    echo "1. 🔗 GitHub Repository에 Webhook 설정"
    if [[ -n "$ATLANTIS_URL" ]]; then
        echo "   - Payload URL: $ATLANTIS_URL/events"
    else
        echo "   - Payload URL: <ATLANTIS_SERVER_URL>/events"
    fi
    echo "   - Content type: application/json"
    echo "   - Secret: (AWS Secrets Manager의 atlantis/webhook-secret)"
    echo "   - Events: Pull requests, Issue comments, Push"
    echo ""
    echo "2. 📄 변경사항을 Git에 커밋"
    echo "   git add atlantis.yaml STACKKIT_MIGRATION_GUIDE.md"
    echo "   git commit -m 'Add Atlantis AI Reviewer integration'"
    echo ""
    echo "3. 🧪 테스트 PR 생성하여 동작 확인"
    echo ""
    echo "4. 📖 마이그레이션 가이드 검토"
    echo "   cat STACKKIT_MIGRATION_GUIDE.md"
    echo ""
    echo "💡 유용한 명령어:"
    echo "   - 롤백: cp -r $BACKUP_DIR/* ."
    echo "   - 리소스 Import: $PROJECT_ROOT/terraform/scripts/import-resources.sh"
elif [[ "$DRY_RUN" == "true" ]]; then
    echo ""
    echo "🔍 DRY RUN 완료 - 실제 실행하려면 --dry-run 옵션을 제거하세요"
fi

echo ""
echo "📚 자세한 문서: $PROJECT_ROOT/README.md"
