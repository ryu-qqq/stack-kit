# S3 모듈

AWS S3 버킷과 관련 리소스를 생성하고 관리하는 Terraform 모듈입니다.

## 기능

- S3 버킷 생성 및 설정
- 서버 사이드 암호화 (SSE-S3, SSE-KMS)
- 버전 관리 및 MFA Delete
- 수명주기 정책 관리
- 퍼블릭 액세스 차단
- 정적 웹사이트 호스팅
- CloudFront 배포 통합
- 버킷 알림 및 이벤트
- CORS 설정

## 사용법

### 기본 사용 (프라이빗 스토리지)

```hcl
module "app_storage" {
  source = "../../modules/s3"
  
  project_name = "my-app"
  environment  = "dev"
  bucket_name  = "app-storage"
  
  # 보안 설정
  enable_versioning = true
  enable_encryption = true
  encryption_type   = "SSE-S3"
  
  # 퍼블릭 액세스 완전 차단
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  
  common_tags = {
    Project     = "my-app"
    Environment = "dev"
    Owner       = "platform"
  }
}
```

### 고급 설정 (KMS 암호화 + 수명주기)

```hcl
module "secure_storage" {
  source = "../../modules/s3"
  
  project_name = "enterprise-app"
  environment  = "prod"
  bucket_name  = "secure-documents"
  
  # 고급 보안 설정
  enable_versioning = true
  enable_encryption = true
  encryption_type   = "SSE-KMS"
  kms_key_id       = aws_kms_key.s3_key.arn
  
  # 수명주기 정책
  lifecycle_rules = [
    {
      id     = "transition_to_ia"
      status = "Enabled"
      
      transitions = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        },
        {
          days          = 90
          storage_class = "GLACIER"
        },
        {
          days          = 365
          storage_class = "DEEP_ARCHIVE"
        }
      ]
      
      expiration = {
        days = 2555  # 7년 후 삭제
      }
      
      noncurrent_version_expiration = {
        days = 90
      }
    }
  ]
  
  # 이전 버전 자동 정리
  noncurrent_version_transitions = [
    {
      days          = 30
      storage_class = "GLACIER"
    }
  ]
  
  common_tags = {
    Project      = "enterprise-app"
    Environment  = "prod"
    DataClass    = "confidential"
    Compliance   = "required"
  }
}
```

### 정적 웹사이트 호스팅

```hcl
module "website_bucket" {
  source = "../../modules/s3"
  
  project_name = "my-portfolio"
  environment  = "prod"
  bucket_name  = "website"
  
  # 웹사이트 호스팅 설정
  enable_website_hosting  = true
  website_index_document = "index.html"
  website_error_document = "error.html"
  
  # 퍼블릭 읽기 허용 (웹사이트용)
  enable_public_read      = true
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
  
  # CORS 설정 (필요시)
  cors_rules = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["GET", "HEAD"]
      allowed_origins = ["https://myportfolio.com", "https://www.myportfolio.com"]
      expose_headers  = ["ETag"]
      max_age_seconds = 3000
    }
  ]
  
  common_tags = {
    Project     = "my-portfolio"
    Environment = "prod"
    Purpose     = "website-hosting"
  }
}
```

### CloudFront와 함께 사용

```hcl
# S3 버킷 (프라이빗)
module "cdn_origin_bucket" {
  source = "../../modules/s3"
  
  project_name = "media-site"
  environment  = "prod"
  bucket_name  = "cdn-origin"
  
  # CloudFront에서만 액세스 허용
  enable_public_read = false
  
  # 버킷 정책으로 CloudFront OAC만 허용
  bucket_policy = templatefile("${path.module}/cloudfront-policy.json", {
    bucket_arn = "arn:aws:s3:::${local.bucket_name}"
    oac_arn    = aws_cloudfront_origin_access_control.main.arn
  })
  
  common_tags = local.common_tags
}

# CloudFront 배포
resource "aws_cloudfront_distribution" "main" {
  origin {
    domain_name              = module.cdn_origin_bucket.bucket_regional_domain_name
    origin_id               = "S3-${module.cdn_origin_bucket.bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.main.id
  }
  
  # ... CloudFront 설정
}
```

## 입력 변수

| 변수명 | 설명 | 타입 | 기본값 | 필수 |
|--------|------|------|--------|------|
| `project_name` | 프로젝트 이름 | `string` | - | ✅ |
| `environment` | 환경 (dev, staging, prod) | `string` | - | ✅ |
| `bucket_name` | S3 버킷 이름 (접두사) | `string` | - | ✅ |
| `enable_versioning` | 버전 관리 활성화 | `bool` | `false` | ❌ |
| `enable_encryption` | 서버 사이드 암호화 | `bool` | `true` | ❌ |
| `encryption_type` | 암호화 타입 (SSE-S3, SSE-KMS) | `string` | `"SSE-S3"` | ❌ |
| `kms_key_id` | KMS 키 ID (SSE-KMS 사용시) | `string` | `null` | ❌ |
| `enable_public_read` | 퍼블릭 읽기 허용 | `bool` | `false` | ❌ |
| `block_public_acls` | 퍼블릭 ACL 차단 | `bool` | `true` | ❌ |
| `block_public_policy` | 퍼블릭 정책 차단 | `bool` | `true` | ❌ |
| `ignore_public_acls` | 퍼블릭 ACL 무시 | `bool` | `true` | ❌ |
| `restrict_public_buckets` | 퍼블릭 버킷 제한 | `bool` | `true` | ❌ |
| `enable_website_hosting` | 정적 웹사이트 호스팅 | `bool` | `false` | ❌ |
| `website_index_document` | 인덱스 문서 | `string` | `"index.html"` | ❌ |
| `website_error_document` | 오류 문서 | `string` | `"error.html"` | ❌ |
| `lifecycle_rules` | 수명주기 규칙 | `list(object)` | `[]` | ❌ |
| `cors_rules` | CORS 규칙 | `list(object)` | `[]` | ❌ |
| `bucket_policy` | 커스텀 버킷 정책 | `string` | `null` | ❌ |
| `notification_configurations` | 버킷 알림 설정 | `object` | `{}` | ❌ |
| `common_tags` | 공통 태그 | `map(string)` | `{}` | ❌ |

## 출력 값

| 출력명 | 설명 | 타입 |
|--------|------|------|
| `bucket_name` | 실제 S3 버킷 이름 | `string` |
| `bucket_arn` | S3 버킷 ARN | `string` |
| `bucket_domain_name` | S3 버킷 도메인 이름 | `string` |
| `bucket_regional_domain_name` | S3 버킷 리전별 도메인 이름 | `string` |
| `bucket_hosted_zone_id` | S3 버킷 호스트 존 ID | `string` |
| `website_endpoint` | 웹사이트 엔드포인트 | `string` |
| `website_domain` | 웹사이트 도메인 | `string` |

## 예제

### 애플리케이션 파일 스토리지

```hcl
module "app_files" {
  source = "../../modules/s3"
  
  project_name = "ecommerce"
  environment  = "prod"
  bucket_name  = "user-uploads"
  
  # 보안 우선 설정
  enable_versioning = true
  enable_encryption = true
  encryption_type   = "SSE-KMS"
  
  # 수명주기: 90일 후 IA, 1년 후 Glacier
  lifecycle_rules = [
    {
      id     = "optimize_storage"
      status = "Enabled"
      
      transitions = [
        {
          days          = 90
          storage_class = "STANDARD_IA"
        },
        {
          days          = 365
          storage_class = "GLACIER"
        }
      ]
    }
  ]
  
  common_tags = {
    Project     = "ecommerce"
    Environment = "prod"
    Purpose     = "user-uploads"
  }
}
```

### 로그 저장소

```hcl
module "log_bucket" {
  source = "../../modules/s3"
  
  project_name = "monitoring"
  environment  = "prod"
  bucket_name  = "application-logs"
  
  # 로그용 최적화 설정
  enable_versioning = false  # 로그는 버전 불필요
  enable_encryption = true
  
  # 로그 보존 정책: 30일 후 IA, 90일 후 Glacier, 7년 후 삭제
  lifecycle_rules = [
    {
      id     = "log_retention"
      status = "Enabled"
      
      transitions = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        },
        {
          days          = 90
          storage_class = "GLACIER"
        }
      ]
      
      expiration = {
        days = 2555  # 7년 보존
      }
    }
  ]
  
  # 로그 저장용 폴더 구조 태깅
  common_tags = {
    Project     = "monitoring"
    Environment = "prod"
    DataType    = "logs"
    RetentionPeriod = "7-years"
  }
}
```

### 데이터 백업 저장소

```hcl
module "backup_bucket" {
  source = "../../modules/s3"
  
  project_name = "database"
  environment  = "prod"
  bucket_name  = "backups"
  
  # 백업용 고급 설정
  enable_versioning = true
  enable_encryption = true
  encryption_type   = "SSE-KMS"
  kms_key_id       = aws_kms_key.backup_key.arn
  
  # 백업 보존 정책: 즉시 IA, 30일 후 Glacier
  lifecycle_rules = [
    {
      id     = "backup_policy"
      status = "Enabled"
      
      transitions = [
        {
          days          = 0  # 즉시 IA로 이동
          storage_class = "STANDARD_IA"
        },
        {
          days          = 30
          storage_class = "GLACIER"
        }
      ]
      
      # 이전 버전은 7일 후 삭제
      noncurrent_version_expiration = {
        days = 7
      }
    }
  ]
  
  # 크로스 리전 복제 설정 (옵션)
  replication_configuration = {
    role = aws_iam_role.replication.arn
    
    rules = [
      {
        id     = "backup_replication"
        status = "Enabled"
        
        destination = {
          bucket        = "arn:aws:s3:::backup-replica-bucket"
          storage_class = "GLACIER"
        }
      }
    ]
  }
  
  common_tags = {
    Project      = "database"
    Environment  = "prod"
    Purpose      = "backup"
    CriticalData = "yes"
  }
}
```

## 보안 권장사항

### 1. 퍼블릭 액세스 차단

```hcl
# ✅ 좋은 예: 기본적으로 퍼블릭 액세스 차단
module "secure_bucket" {
  source = "../../modules/s3"
  
  # 퍼블릭 액세스 완전 차단
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ⚠️ 주의: 웹사이트 호스팅시에만 퍼블릭 허용
module "website_bucket" {
  source = "../../modules/s3"
  
  enable_website_hosting = true
  enable_public_read     = true  # 웹사이트에만 필요
  
  # 특정 도메인에서만 접근 허용
  cors_rules = [
    {
      allowed_origins = ["https://mysite.com"]
      allowed_methods = ["GET"]
    }
  ]
}
```

### 2. 암호화 설정

```hcl
# ✅ 좋은 예: KMS 암호화 사용
module "encrypted_bucket" {
  source = "../../modules/s3"
  
  enable_encryption = true
  encryption_type   = "SSE-KMS"
  kms_key_id       = aws_kms_key.s3_key.arn
}

# ❌ 피해야 할 예: 암호화 비활성화
# enable_encryption = false  # 보안상 위험
```

### 3. 액세스 패턴별 권한 설정

```hcl
# CloudFront OAC를 통한 접근만 허용
data "aws_iam_policy_document" "cloudfront_access" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    
    actions = ["s3:GetObject"]
    
    resources = ["${module.bucket.bucket_arn}/*"]
    
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.main.arn]
    }
  }
}

module "cdn_bucket" {
  source = "../../modules/s3"
  
  bucket_policy = data.aws_iam_policy_document.cloudfront_access.json
}
```

## 비용 최적화

### 스토리지 클래스 선택 가이드

```hcl
# 자주 접근하는 데이터
storage_class = "STANDARD"

# 가끔 접근하는 데이터 (30일 후)
storage_class = "STANDARD_IA"

# 아카이브 데이터 (즉시 복구 불필요)
storage_class = "GLACIER"

# 장기 아카이브 (12시간 후 복구 가능)
storage_class = "DEEP_ARCHIVE"
```

### 환경별 비용 최적화

```hcl
locals {
  storage_config = {
    dev = {
      versioning     = false
      ia_transition  = 7    # 개발용은 빠르게 IA로
      glacier_days   = 30
      expiration     = 90   # 90일 후 삭제
    }
    staging = {
      versioning     = true
      ia_transition  = 30
      glacier_days   = 90
      expiration     = 365
    }
    prod = {
      versioning     = true
      ia_transition  = 90
      glacier_days   = 365
      expiration     = 2555  # 7년 보존
    }
  }
}

module "optimized_bucket" {
  source = "../../modules/s3"
  
  enable_versioning = local.storage_config[var.environment].versioning
  
  lifecycle_rules = [
    {
      id     = "cost_optimization"
      status = "Enabled"
      
      transitions = [
        {
          days          = local.storage_config[var.environment].ia_transition
          storage_class = "STANDARD_IA"
        },
        {
          days          = local.storage_config[var.environment].glacier_days
          storage_class = "GLACIER"
        }
      ]
      
      expiration = {
        days = local.storage_config[var.environment].expiration
      }
    }
  ]
}
```

## 모니터링 및 알림

### CloudWatch 메트릭 활용

```hcl
# S3 버킷 메트릭 구성
resource "aws_s3_bucket_metric" "main" {
  bucket = module.s3_bucket.bucket_name
  name   = "main"
}

# CloudWatch 알람
resource "aws_cloudwatch_metric_alarm" "bucket_size" {
  alarm_name          = "${module.s3_bucket.bucket_name}-size-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name        = "BucketSizeBytes"
  namespace          = "AWS/S3"
  period             = "86400"  # 24시간
  statistic          = "Average"
  threshold          = "10737418240"  # 10GB
  alarm_description  = "This metric monitors s3 bucket size"
  
  dimensions = {
    BucketName  = module.s3_bucket.bucket_name
    StorageType = "StandardStorage"
  }
}
```

## 문제 해결

### 일반적인 오류들

#### 1. "BucketAlreadyExists"

```hcl
# 해결책: 고유한 버킷 이름 사용
resource "random_id" "bucket_suffix" {
  byte_length = 8
}

module "s3_bucket" {
  source = "../../modules/s3"
  
  bucket_name = "my-app-${random_id.bucket_suffix.hex}"
}
```

#### 2. "AccessDenied" (퍼블릭 액세스 차단시)

```hcl
# 해결책: 적절한 퍼블릭 액세스 설정
module "website_bucket" {
  source = "../../modules/s3"
  
  enable_website_hosting = true
  enable_public_read     = true
  
  # 웹사이트 호스팅시 퍼블릭 액세스 허용
  block_public_acls       = false
  block_public_policy     = false
  restrict_public_buckets = false
}
```

#### 3. "InvalidBucketName"

```hcl
# 해결책: S3 버킷 명명 규칙 준수
# - 3-63자 길이
# - 소문자, 숫자, 하이픈만 사용
# - 하이픈으로 시작/끝 불가
# - IP 주소 형식 불가

locals {
  valid_bucket_name = replace(lower("${var.project_name}-${var.environment}-${var.bucket_name}"), "_", "-")
}
```

## 제약사항

- 버킷 이름은 전 세계적으로 고유해야 함
- 리전당 버킷 개수 제한: 100개 (증가 요청 가능)
- 객체당 최대 크기: 5TB
- 단일 PUT 요청: 최대 5GB

## 버전 요구사항

- Terraform: >= 1.5.0
- AWS Provider: >= 5.0.0

## 라이선스

이 모듈은 MIT 라이선스 하에 제공됩니다.