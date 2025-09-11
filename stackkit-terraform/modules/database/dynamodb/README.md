# DynamoDB 모듈

AWS DynamoDB 테이블을 생성하고 관리하는 Terraform 모듈입니다.

## 기능

- DynamoDB 테이블 생성 및 설정
- GSI (Global Secondary Index) 지원
- Auto Scaling 설정
- Point-in-time Recovery
- 서버 사이드 암호화
- 태그 관리

## 사용법

### 기본 사용법

```hcl
module "dynamodb" {
  source = "../../modules/dynamodb"
  
  project_name = "my-app"
  environment  = "dev"
  table_name   = "users"
  
  hash_key  = "id"
  range_key = "created_at"
  
  attributes = [
    {
      name = "id"
      type = "S"
    },
    {
      name = "created_at"
      type = "S"
    },
    {
      name = "email"
      type = "S"
    }
  ]
  
  global_secondary_indexes = [
    {
      name            = "EmailIndex"
      hash_key        = "email"
      projection_type = "ALL"
    }
  ]
  
  common_tags = {
    Project     = "my-app"
    Environment = "dev"
  }
}
```

### 고급 설정

```hcl
module "dynamodb_advanced" {
  source = "../../modules/dynamodb"
  
  project_name = "my-app"
  environment  = "prod"
  table_name   = "orders"
  
  billing_mode = "PROVISIONED"
  read_capacity  = 10
  write_capacity = 10
  
  hash_key = "order_id"
  
  attributes = [
    {
      name = "order_id"
      type = "S"
    }
  ]
  
  # Auto Scaling 활성화
  enable_autoscaling           = true
  autoscaling_read_target      = 70
  autoscaling_write_target     = 70
  autoscaling_read_min_capacity  = 5
  autoscaling_read_max_capacity  = 100
  autoscaling_write_min_capacity = 5
  autoscaling_write_max_capacity = 100
  
  # Point-in-time Recovery
  point_in_time_recovery_enabled = true
  
  # 암호화
  server_side_encryption_enabled = true
  
  # 삭제 보호
  deletion_protection_enabled = true
  
  common_tags = {
    Project     = "my-app"
    Environment = "prod"
    Criticality = "high"
  }
}
```

## 입력 변수

| 변수명 | 설명 | 타입 | 기본값 | 필수 |
|--------|------|------|--------|------|
| `project_name` | 프로젝트 이름 | `string` | - | ✅ |
| `environment` | 환경 (dev/staging/prod) | `string` | - | ✅ |
| `table_name` | DynamoDB 테이블 이름 | `string` | - | ✅ |
| `billing_mode` | 청구 모드 | `string` | `"PAY_PER_REQUEST"` | ❌ |
| `hash_key` | 해시 키 | `string` | - | ✅ |
| `range_key` | 레인지 키 | `string` | `null` | ❌ |
| `attributes` | 테이블 속성 | `list(object)` | `[]` | ✅ |
| `global_secondary_indexes` | GSI 설정 | `list(object)` | `[]` | ❌ |
| `local_secondary_indexes` | LSI 설정 | `list(object)` | `[]` | ❌ |
| `ttl_enabled` | TTL 활성화 | `bool` | `false` | ❌ |
| `ttl_attribute_name` | TTL 속성 이름 | `string` | `""` | ❌ |
| `enable_autoscaling` | Auto Scaling 활성화 | `bool` | `false` | ❌ |
| `point_in_time_recovery_enabled` | PITR 활성화 | `bool` | `false` | ❌ |
| `server_side_encryption_enabled` | 서버 사이드 암호화 | `bool` | `true` | ❌ |
| `deletion_protection_enabled` | 삭제 보호 | `bool` | `false` | ❌ |

## 출력값

| 출력명 | 설명 |
|--------|------|
| `table_name` | DynamoDB 테이블 이름 |
| `table_arn` | DynamoDB 테이블 ARN |
| `table_id` | DynamoDB 테이블 ID |
| `table_stream_arn` | DynamoDB Stream ARN |
| `table_stream_label` | DynamoDB Stream 레이블 |

## 예시

### 간단한 사용자 테이블

```hcl
module "users_table" {
  source = "../../modules/dynamodb"
  
  project_name = "myapp"
  environment  = "dev"
  table_name   = "users"
  
  hash_key = "user_id"
  
  attributes = [
    {
      name = "user_id"
      type = "S"
    }
  ]
  
  common_tags = local.common_tags
}
```

### 세션 저장용 테이블 (TTL 사용)

```hcl
module "sessions_table" {
  source = "../../modules/dynamodb"
  
  project_name = "myapp"
  environment  = "dev"
  table_name   = "sessions"
  
  hash_key = "session_id"
  
  attributes = [
    {
      name = "session_id"
      type = "S"
    }
  ]
  
  ttl_enabled        = true
  ttl_attribute_name = "expires_at"
  
  common_tags = local.common_tags
}
```

## 참고사항

- **청구 모드**: 기본값은 PAY_PER_REQUEST이며, 예측 가능한 워크로드의 경우 PROVISIONED 모드 고려
- **GSI 제한**: 테이블당 최대 20개 GSI 생성 가능
- **Auto Scaling**: PROVISIONED 모드에서만 사용 가능
- **Point-in-time Recovery**: 프로덕션 환경에서 권장
- **삭제 보호**: 중요한 데이터의 경우 `deletion_protection_enabled = true` 설정 권장

## 태그

모든 리소스에 다음 태그가 자동 적용됩니다:
- `Name`: `{project_name}-{environment}-{table_name}`
- 사용자 정의 태그 (`common_tags`)

## 버전 요구사항

- Terraform: >= 1.5.0
- AWS Provider: >= 5.0.0