# ElastiCache 모듈

AWS ElastiCache Redis/Memcached 클러스터와 관련 리소스를 생성하고 관리하는 Terraform 모듈입니다.

## 기능

- ElastiCache 클러스터 생성 (Redis, Memcached)
- Multi-AZ 고가용성 및 자동 장애조치 지원
- 저장 시 및 전송 시 암호화
- 자동 백업 및 스냅샷 관리
- 서브넷 그룹 및 보안 그룹 자동 생성
- 파라미터 그룹 커스터마이징
- CloudWatch 모니터링 및 알람
- AUTH 토큰 기반 인증 (Redis)
- FIFO 및 일반 큐 지원

## 사용법

### 기본 사용 (Redis)

```hcl
module "redis_cache" {
  source = "../../modules/database/elasticache"
  
  project_name = "my-app"
  environment  = "dev"
  
  # 엔진 설정
  engine         = "redis"
  engine_version = "7.0"
  node_type      = "cache.t3.micro"
  num_cache_nodes = 1
  port           = 6379
  
  # 네트워킹
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  # 보안 설정
  allowed_security_groups = [
    module.app_servers.security_group_id
  ]
  
  # 백업 설정
  snapshot_retention_limit = 5
  snapshot_window         = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"
  
  # 암호화
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  
  common_tags = {
    Project     = "my-app"
    Environment = "dev"
    Owner       = "platform"
  }
}
```

### 고급 설정 (Redis 클러스터 모드)

```hcl
module "redis_cluster" {
  source = "../../modules/database/elasticache"
  
  project_name = "enterprise-app"
  environment  = "prod"
  
  # Redis 클러스터 설정
  engine         = "redis"
  engine_version = "7.0"
  node_type      = "cache.r6g.large"
  num_cache_nodes = 3  # Multi-AZ 클러스터
  port           = 6379
  
  # 네트워킹
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  # 고가용성 설정
  automatic_failover_enabled = true
  multi_az_enabled          = true
  
  # 백업 및 복구
  snapshot_retention_limit = 30
  snapshot_window         = "02:00-03:00"
  maintenance_window      = "sun:03:00-sun:04:00"
  
  # 보안 강화
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token_enabled        = true
  auth_token                = var.redis_auth_token
  
  # 커스텀 파라미터 그룹
  create_parameter_group = true
  parameter_group_family = "redis7.x"
  parameters = [
    {
      name  = "maxmemory-policy"
      value = "allkeys-lru"
    },
    {
      name  = "timeout"
      value = "300"
    }
  ]
  
  # 보안 그룹 설정
  allowed_security_groups = [
    module.app_servers.security_group_id
  ]
  
  # 모니터링 및 알람
  create_cloudwatch_alarms = true
  cpu_alarm_threshold      = 70
  memory_alarm_threshold   = 80
  alarm_actions = [aws_sns_topic.alerts.arn]
  
  common_tags = {
    Project      = "enterprise-app"
    Environment  = "prod"
    Component    = "cache"
    CriticalData = "yes"
  }
}
```

### Memcached 설정

```hcl
module "memcached_cache" {
  source = "../../modules/database/elasticache"
  
  project_name = "web-app"
  environment  = "staging"
  
  # Memcached 설정
  engine         = "memcached"
  engine_version = "1.6.12"
  node_type      = "cache.t3.medium"
  num_cache_nodes = 2
  port           = 11211
  
  # 네트워킹
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  # Memcached 파라미터
  create_parameter_group = true
  parameter_group_family = "memcached1.6"
  parameters = [
    {
      name  = "max_item_size"
      value = "1048576"  # 1MB
    }
  ]
  
  # 보안 설정
  allowed_security_groups = [
    module.web_servers.security_group_id
  ]
  
  # 유지보수
  maintenance_window = "sun:04:00-sun:05:00"
  
  common_tags = {
    Project     = "web-app"
    Environment = "staging"
    Purpose     = "session-storage"
  }
}
```

### 환경별 설정

```hcl
locals {
  cache_config = {
    dev = {
      node_type           = "cache.t3.micro"
      num_cache_nodes    = 1
      multi_az           = false
      backup_retention   = 1
      encryption_enabled = false
    }
    staging = {
      node_type           = "cache.t3.small"
      num_cache_nodes    = 2
      multi_az           = true
      backup_retention   = 7
      encryption_enabled = true
    }
    prod = {
      node_type           = "cache.r6g.large"
      num_cache_nodes    = 3
      multi_az           = true
      backup_retention   = 30
      encryption_enabled = true
    }
  }
}

module "environment_cache" {
  source = "../../modules/database/elasticache"
  
  project_name = "adaptive-app"
  environment  = var.environment
  
  # 환경별 동적 설정
  engine              = "redis"
  node_type          = local.cache_config[var.environment].node_type
  num_cache_nodes    = local.cache_config[var.environment].num_cache_nodes
  multi_az_enabled   = local.cache_config[var.environment].multi_az
  
  # 백업 설정
  snapshot_retention_limit = local.cache_config[var.environment].backup_retention
  
  # 암호화 설정
  at_rest_encryption_enabled = local.cache_config[var.environment].encryption_enabled
  transit_encryption_enabled = local.cache_config[var.environment].encryption_enabled
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  allowed_security_groups = [module.app_servers.security_group_id]
  
  common_tags = {
    Project     = "adaptive-app"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
```

## 입력 변수

| 변수명 | 설명 | 타입 | 기본값 | 필수 |
|--------|------|------|--------|------|
| `project_name` | 프로젝트 이름 | `string` | - | ✅ |
| `environment` | 환경 (dev, staging, prod) | `string` | - | ✅ |
| `vpc_id` | VPC ID | `string` | - | ✅ |
| `subnet_ids` | 캐시 서브넷 그룹에 사용할 서브넷 ID 리스트 | `list(string)` | - | ✅ |
| `engine` | 캐시 엔진 (redis 또는 memcached) | `string` | `"redis"` | ❌ |
| `engine_version` | 엔진 버전 | `string` | `"7.0"` | ❌ |
| `node_type` | 노드 타입 | `string` | `"cache.t3.micro"` | ❌ |
| `num_cache_nodes` | 캐시 노드 개수 | `number` | `1` | ❌ |
| `port` | 포트 번호 | `number` | `6379` | ❌ |
| `allowed_security_groups` | 접근을 허용할 Security Group ID 리스트 | `list(string)` | `[]` | ❌ |
| `allowed_cidr_blocks` | 접근을 허용할 CIDR 블록 리스트 | `list(string)` | `[]` | ❌ |
| `create_parameter_group` | Parameter Group 생성 여부 | `bool` | `true` | ❌ |
| `parameter_group_family` | Parameter Group 패밀리 | `string` | `"redis7.x"` | ❌ |
| `parameters` | 캐시 Parameter 설정 리스트 | `list(object)` | `[]` | ❌ |
| `snapshot_retention_limit` | 스냅샷 보존 기간 (일) - Redis만 해당 | `number` | `5` | ❌ |
| `snapshot_window` | 스냅샷 시간대 (UTC) - Redis만 해당 | `string` | `"03:00-04:00"` | ❌ |
| `maintenance_window` | 유지보수 시간대 (UTC) | `string` | `"sun:04:00-sun:05:00"` | ❌ |
| `at_rest_encryption_enabled` | 저장 시 암호화 활성화 - Redis만 해당 | `bool` | `true` | ❌ |
| `transit_encryption_enabled` | 전송 시 암호화 활성화 - Redis만 해당 | `bool` | `true` | ❌ |
| `auth_token_enabled` | AUTH 토큰 활성화 - Redis만 해당 | `bool` | `false` | ❌ |
| `auth_token` | AUTH 토큰 - Redis만 해당 | `string` | `null` | ❌ |
| `automatic_failover_enabled` | 자동 장애 조치 활성화 - Redis만 해당 | `bool` | `true` | ❌ |
| `multi_az_enabled` | Multi-AZ 활성화 - Redis만 해당 | `bool` | `false` | ❌ |
| `create_cloudwatch_alarms` | CloudWatch 알람 생성 여부 | `bool` | `true` | ❌ |
| `cpu_alarm_threshold` | CPU 사용률 알람 임계값 (%) | `number` | `80` | ❌ |
| `memory_alarm_threshold` | 메모리 사용률 알람 임계값 (%) - Redis만 해당 | `number` | `80` | ❌ |
| `alarm_actions` | 알람 액션 ARN 리스트 | `list(string)` | `[]` | ❌ |
| `common_tags` | 모든 리소스에 적용할 공통 태그 | `map(string)` | `{}` | ❌ |

## 출력 값

| 출력명 | 설명 | 타입 |
|--------|------|------|
| `redis_replication_group_id` | Redis Replication Group ID | `string` |
| `redis_primary_endpoint` | Redis Primary Endpoint | `string` |
| `redis_reader_endpoint` | Redis Reader Endpoint | `string` |
| `redis_configuration_endpoint` | Redis Configuration Endpoint | `string` |
| `memcached_cluster_id` | Memcached Cluster ID | `string` |
| `memcached_configuration_endpoint` | Memcached Configuration Endpoint | `string` |
| `memcached_cluster_address` | Memcached Cluster Address | `string` |
| `cache_nodes` | 캐시 노드 정보 | `list` |
| `port` | 캐시 포트 | `number` |
| `engine` | 캐시 엔진 | `string` |
| `engine_version` | 엔진 버전 | `string` |
| `subnet_group_name` | 서브넷 그룹 이름 | `string` |
| `security_group_id` | Security Group ID | `string` |
| `parameter_group_id` | Parameter Group ID | `string` |

## 일반적인 사용 사례

### 1. 세션 스토리지

```hcl
module "session_cache" {
  source = "../../modules/database/elasticache"
  
  project_name = "web-app"
  environment  = "prod"
  
  engine         = "redis"
  node_type      = "cache.t3.medium"
  num_cache_nodes = 2
  
  # 세션 스토리지용 설정
  parameters = [
    {
      name  = "maxmemory-policy"
      value = "allkeys-lru"  # 세션 만료시 자동 삭제
    },
    {
      name  = "timeout"
      value = "0"  # 연결 타임아웃 비활성화
    }
  ]
}
```

### 2. 애플리케이션 캐시

```hcl
module "app_cache" {
  source = "../../modules/database/elasticache"
  
  project_name = "api-server"
  environment  = "prod"
  
  engine         = "redis"
  node_type      = "cache.r6g.large"
  num_cache_nodes = 3
  
  # 고성능 캐싱 설정
  parameters = [
    {
      name  = "maxmemory-policy"
      value = "volatile-lru"
    },
    {
      name  = "save"
      value = ""  # 디스크 저장 비활성화 (순수 캐시)
    }
  ]
  
  # 백업 비활성화 (캐시 용도)
  snapshot_retention_limit = 0
}
```

### 3. 데이터베이스 캐시

```hcl
module "db_cache" {
  source = "../../modules/database/elasticache"
  
  project_name = "ecommerce"
  environment  = "prod"
  
  engine         = "memcached"
  node_type      = "cache.r6g.xlarge"
  num_cache_nodes = 4
  
  # 데이터베이스 캐싱 최적화
  parameters = [
    {
      name  = "chunk_size"
      value = "48"
    },
    {
      name  = "max_item_size"
      value = "1048576"  # 1MB
    }
  ]
}
```

## 모범 사례

### 보안 설정

```hcl
# ✅ 좋은 예: 완전한 보안 설정
module "secure_cache" {
  source = "../../modules/database/elasticache"
  
  # 프라이빗 서브넷에만 배치
  subnet_ids = module.vpc.private_subnet_ids
  
  # 보안 그룹으로만 접근 제한
  allowed_security_groups = [
    module.app_servers.security_group_id
  ]
  allowed_cidr_blocks = []  # CIDR 블록 사용 안함
  
  # 암호화 활성화
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token_enabled        = true
  auth_token                = var.redis_auth_token
}

# ❌ 피해야 할 예: 보안이 약한 설정
# allowed_cidr_blocks = ["0.0.0.0/0"]  # 너무 광범위한 접근
# transit_encryption_enabled = false   # 평문 통신
```

### 성능 최적화

```hcl
# Redis 성능 최적화
module "optimized_redis" {
  source = "../../modules/database/elasticache"
  
  engine         = "redis"
  node_type      = "cache.r6g.large"  # 메모리 최적화 인스턴스
  
  parameters = [
    {
      name  = "maxmemory-policy"
      value = "allkeys-lru"
    },
    {
      name  = "tcp-keepalive"
      value = "60"
    },
    {
      name  = "timeout"
      value = "300"
    }
  ]
}
```

### 고가용성 설정

```hcl
module "ha_cache" {
  source = "../../modules/database/elasticache"
  
  engine              = "redis"
  num_cache_nodes    = 3  # 최소 2개 이상
  multi_az_enabled   = true
  automatic_failover_enabled = true
  
  # 백업 설정
  snapshot_retention_limit = 7
  snapshot_window         = "03:00-04:00"
}
```

## 문제 해결

### 일반적인 오류들

#### 1. "InsufficientCacheClusterCapacity"

```hcl
# 해결책: 다른 가용영역이나 인스턴스 타입 시도
module "cache" {
  source = "../../modules/database/elasticache"
  
  # 여러 AZ에 분산된 서브넷 사용
  subnet_ids = module.vpc.private_subnet_ids
  
  # 가용성이 높은 인스턴스 타입 사용
  node_type = "cache.t3.medium"  # t3.micro 대신
}
```

#### 2. "InvalidParameterValue" (파라미터 그룹)

```hcl
# 해결책: 엔진별 유효한 파라미터 사용
locals {
  redis_parameters = [
    {
      name  = "maxmemory-policy"
      value = "allkeys-lru"
    }
  ]
  
  memcached_parameters = [
    {
      name  = "chunk_size"
      value = "48"
    }
  ]
}

module "cache" {
  source = "../../modules/database/elasticache"
  
  parameters = var.engine == "redis" ? local.redis_parameters : local.memcached_parameters
}
```

## 제한 사항

- 엔진 타입 변경 시 클러스터 재생성 필요
- 노드 타입 변경 시 다운타임 발생 가능
- Memcached는 백업 및 복구 기능 미지원
- AUTH 토큰은 Redis에서만 지원
- Multi-AZ는 최소 2개 이상의 노드 필요

## 버전 요구사항

- Terraform: >= 1.5.0
- AWS Provider: >= 5.0.0

## 라이선스

이 모듈은 MIT 라이선스 하에 제공됩니다.