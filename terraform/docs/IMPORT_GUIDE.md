# 🔄 기존 인프라 Import 가이드

기존 AWS 리소스를 Atlantis AI Reviewer 인프라와 통합하는 방법을 안내합니다.

## 📋 지원되는 Import 시나리오

### 1. 기존 VPC 사용

**terraform.tfvars 설정**:
```hcl
# 기존 VPC 사용
use_existing_vpc = true
existing_vpc_id = "vpc-0123456789abcdef0"
existing_public_subnet_ids = ["subnet-0123456789abcdef0", "subnet-0abcdef123456789"]
existing_private_subnet_ids = ["subnet-0fedcba987654321", "subnet-0987654321fedcba"]
```

**장점**:
- 기존 네트워킹 인프라 재사용
- VPC 비용 절약
- 기존 보안 정책 유지

**주의사항**:
- 서브넷에 충분한 IP 주소가 있어야 함
- 필요한 라우팅 테이블 설정 확인
- 인터넷 게이트웨이/NAT 게이트웨이 존재 확인

### 2. 기존 S3 버킷 사용

**terraform.tfvars 설정**:
```hcl
# 기존 S3 버킷 사용
use_existing_s3_bucket = true
existing_s3_bucket_name = "my-existing-atlantis-bucket"
```

**사전 요구사항**:
- 버킷 버전닝 활성화
- 적절한 IAM 권한 설정
- 라이프사이클 정책 권장

```bash
# S3 버킷 설정 확인
aws s3api get-bucket-versioning --bucket my-existing-atlantis-bucket
aws s3api get-bucket-lifecycle-configuration --bucket my-existing-atlantis-bucket
```

### 3. 새 리소스 + 기존 VPC 조합 (권장)

가장 일반적인 사용 패턴입니다:

```hcl
# 기존 VPC 재사용하되, 새로운 Atlantis 전용 리소스 생성
use_existing_vpc = true
existing_vpc_id = "vpc-0123456789abcdef0"
existing_public_subnet_ids = ["subnet-pub1", "subnet-pub2"]
existing_private_subnet_ids = ["subnet-priv1", "subnet-priv2"]

# S3, ECS 등은 새로 생성
use_existing_s3_bucket = false
use_existing_ecs_cluster = false
```

## 🛠️ Import 도구 사용법

### 기본 Import 스크립트

```bash
# VPC import
./terraform/scripts/import-resources.sh \
  ../stacks/my-atlantis-dev-us-east-1 \
  vpc \
  module.vpc.aws_vpc.main \
  vpc-0123456789abcdef0

# S3 버킷 import
./terraform/scripts/import-resources.sh \
  ../stacks/my-atlantis-dev-us-east-1 \
  s3 \
  module.atlantis_outputs_bucket.aws_s3_bucket.main \
  my-existing-bucket
```

### 대화형 Import 워크플로우

1. **스택 생성** (기존 리소스 사용 설정)
2. **Terraform 초기화**
3. **Plan 실행** (오류 확인)
4. **Import 수행**
5. **Plan 재실행** (정합성 확인)
6. **Apply 실행**

```bash
# 1. 스택 생성
./new-stack.sh my-atlantis dev --template=atlantis-ai-reviewer

# 2. 설정 수정
cd ../stacks/my-atlantis-dev-ap-northeast-2
# terraform.tfvars에서 use_existing_vpc = true 설정

# 3. 초기화 및 Plan
terraform init -backend-config=backend.hcl
terraform plan  # Import가 필요한 리소스 확인

# 4. Import (필요한 경우)
terraform import 'data.aws_vpc.existing[0]' vpc-0123456789abcdef0

# 5. Plan 재실행
terraform plan  # 정합성 확인

# 6. Apply
terraform apply
```

## 📋 Import 체크리스트

### VPC Import 사전 확인

- [ ] VPC에 충분한 여유 IP 주소가 있는가?
- [ ] Public 서브넷이 인터넷 게이트웨이에 연결되어 있는가?
- [ ] Private 서브넷이 NAT 게이트웨이에 연결되어 있는가?
- [ ] 보안 그룹 규칙이 충돌하지 않는가?
- [ ] VPC DNS 호스트명/확인이 활성화되어 있는가?

```bash
# VPC 정보 확인
aws ec2 describe-vpcs --vpc-ids vpc-0123456789abcdef0
aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-0123456789abcdef0"
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=vpc-0123456789abcdef0"
```

### S3 Bucket Import 사전 확인

- [ ] 버킷 버전닝이 활성화되어 있는가?
- [ ] 적절한 라이프사이클 정책이 설정되어 있는가?
- [ ] 버킷 암호화가 설정되어 있는가?
- [ ] Cross-region 복제가 필요한가?

```bash
# S3 버킷 설정 확인
aws s3api get-bucket-versioning --bucket my-bucket
aws s3api get-bucket-encryption --bucket my-bucket
aws s3api get-bucket-lifecycle-configuration --bucket my-bucket
```

### ECS Cluster Import 사전 확인

- [ ] 클러스터에 충분한 용량이 있는가?
- [ ] 클러스터 설정이 Fargate를 지원하는가?
- [ ] 컨테이너 인사이트가 필요한가?

```bash
# ECS 클러스터 정보 확인
aws ecs describe-clusters --clusters my-cluster
aws ecs list-services --cluster my-cluster
```

## 🚨 주의사항 및 제한사항

### 일반적인 제한사항

1. **상태 파일 충돌**: 기존 Terraform 상태와 충돌할 수 있음
2. **권한 문제**: Import할 리소스에 대한 적절한 권한 필요
3. **설정 불일치**: 기존 리소스 설정이 템플릿과 다를 수 있음
4. **종속성 문제**: Import 순서가 중요함

### 복구 방법

**Import 실패 시**:
```bash
# 상태에서 리소스 제거
terraform state rm 'data.aws_vpc.existing[0]'

# 다시 Import 시도
terraform import 'data.aws_vpc.existing[0]' vpc-0123456789abcdef0
```

**설정 불일치 시**:
```bash
# 현재 상태 확인
terraform show

# 설정 파일 수정 후 Plan 재실행
terraform plan
```

## 📈 성능 최적화

### 비용 최적화

기존 리소스 재사용 시 비용 절약:
- **VPC 재사용**: $0/월 절약
- **NAT Gateway 재사용**: ~$45/월 절약
- **기존 S3 버킷**: ~$1-3/월 절약

### 관리 최적화

- 리소스 태깅 일관성 유지
- 모니터링 도구 통합
- 백업 정책 정렬

## 🔍 트러블슈팅

### 자주 발생하는 오류

1. **"Resource already exists"**
   - 해결: Import 후 plan 재실행

2. **"Invalid VPC ID"**
   - 해결: VPC ID 정확성 확인

3. **"Subnet not found"**
   - 해결: 서브넷 ID와 가용영역 확인

4. **"Access denied"**
   - 해결: IAM 권한 확인

### 디버깅 도구

```bash
# Terraform 상태 확인
terraform state list
terraform state show 'resource.address'

# AWS CLI로 리소스 확인  
aws ec2 describe-vpcs --vpc-ids vpc-xxxxx
aws s3api head-bucket --bucket bucket-name
aws ecs describe-clusters --clusters cluster-name

# Terraform 디버그 모드
TF_LOG=DEBUG terraform plan
```

## 💡 Best Practices

1. **단계별 접근**: 한 번에 하나씩 Import
2. **백업 먼저**: 중요한 리소스는 백업 후 Import
3. **테스트 환경**: 프로덕션 전에 개발 환경에서 테스트
4. **문서화**: Import 과정과 설정 변경사항 문서화
5. **롤백 계획**: Import 실패 시 롤백 계획 수립

## 🎯 실제 사용 사례

### 사례 1: 기존 네트워크 인프라 활용
```hcl
# 회사 표준 VPC 재사용
use_existing_vpc = true
existing_vpc_id = "vpc-company-standard"
# 나머지는 새로 생성
```

### 사례 2: 다중 환경 S3 버킷 통합
```hcl
# dev/staging은 공유 버킷 사용
use_existing_s3_bucket = true
existing_s3_bucket_name = "company-shared-atlantis-outputs"
```

### 사례 3: 점진적 마이그레이션
```bash
# Phase 1: VPC만 기존 것 사용
# Phase 2: S3도 기존 것으로 마이그레이션
# Phase 3: 완전히 기존 인프라로 통합
```