# S3 모듈

AWS S3 버킷을 생성하고 관리하는 Terraform 모듈입니다.

## 기능

- S3 버킷 생성 및 설정
- 버킷 정책 관리
- 서버 사이드 암호화
- 버전 관리
- 수명주기 정책
- 퍼블릭 액세스 차단
- CloudFront 통합 지원

## 사용법

### 기본 사용법

```hcl
module "s3_bucket" {
  source = "../../modules/s3"
  
  project_name = "my-app"
  environment  = "dev"
  bucket_name  = "storage"
  
  enable_versioning = true
  enable_encryption = true
  
  common_tags = {
    Project     = "my-app"
    Environment = "dev"
  }
}
```

### 정적 웹사이트 호스팅

```hcl
module "website_bucket" {
  source = "../../modules/s3"
  
  project_name = "my-app"
  environment  = "prod"
  bucket_name  = "website"
  
  enable_website_hosting = true
  website_index_document = "index.html"
  website_error_document = "error.html"
  
  enable_public_read = true
  
  common_tags = local.common_tags
}
```

## 입력 변수

| 변수명 | 설명 | 타입 | 기본값 | 필수 |
|--------|------|------|--------|------|
| `project_name` | 프로젝트 이름 | `string` | - | ✅ |
| `environment` | 환경 (dev/staging/prod) | `string` | - | ✅ |
| `bucket_name` | S3 버킷 이름 | `string` | - | ✅ |
| `enable_versioning` | 버전 관리 활성화 | `bool` | `false` | ❌ |
| `enable_encryption` | 서버 사이드 암호화 | `bool` | `true` | ❌ |
| `enable_public_read` | 퍼블릭 읽기 허용 | `bool` | `false` | ❌ |
| `enable_website_hosting` | 정적 웹사이트 호스팅 | `bool` | `false` | ❌ |

## 출력값

| 출력명 | 설명 |
|--------|------|
| `bucket_name` | S3 버킷 이름 |
| `bucket_arn` | S3 버킷 ARN |
| `bucket_domain_name` | S3 버킷 도메인 이름 |

## 보안

- 기본적으로 퍼블릭 액세스 차단
- 서버 사이드 암호화 기본 활성화
- 버킷 정책을 통한 세밀한 권한 제어