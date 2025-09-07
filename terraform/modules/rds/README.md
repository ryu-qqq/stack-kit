# RDS 모듈

AWS RDS 데이터베이스 인스턴스와 관련 리소스를 생성하고 관리하는 Terraform 모듈입니다.

## 기능

- RDS 인스턴스 생성 (MySQL, PostgreSQL, MariaDB, Oracle, SQL Server)
- Multi-AZ 배포 및 읽기 전용 복제본 지원
- 자동 백업 및 스냅샷 관리
- 포인트 인 타임 복구 (PITR)
- DB 서브넷 그룹 자동 생성
- 보안 그룹 관리 및 네트워크 격리
- 파라미터 그룹 및 옵션 그룹 커스터마이징
- 저장 시 및 전송 시 암호화
- CloudWatch 모니터링 및 성능 인사이트
- 자동 마이너 버전 업그레이드

## 사용법

### 기본 사용 (MySQL)

```hcl
module "mysql_database" {
  source = "../../modules/rds"
  
  project_name = "my-app"
  environment  = "dev"
  
  # 데이터베이스 설정
  engine         = "mysql"
  engine_version = "8.0.35"
  instance_class = "db.t3.micro"
  
  # 스토리지 설정
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type         = "gp3"
  storage_encrypted    = true
  
  # 데이터베이스 정보
  db_name  = "myapp"
  username = "admin"
  
  # 네트워킹
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  # 백업 설정
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  # 환경별 설정
  multi_az = var.environment == "prod"
  
  common_tags = {
    Project     = "my-app"
    Environment = "dev"
    Owner       = "platform"
  }
}
```

### 고급 설정 (PostgreSQL 프로덕션)

```hcl
module "postgres_production" {
  source = "../../modules/rds"
  
  project_name = "enterprise-app"
  environment  = "prod"
  
  # PostgreSQL 설정
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = "db.r6g.xlarge"  # 메모리 최적화
  
  # 고성능 스토리지
  allocated_storage     = 500
  max_allocated_storage = 2000
  storage_type         = "gp3"
  storage_encrypted    = true
  kms_key_id          = aws_kms_key.rds.arn
  
  # 데이터베이스 정보
  db_name  = "production_db"
  username = "app_admin"
  
  # 네트워킹 및 보안
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  # 고가용성 설정
  multi_az = true
  
  # 백업 및 복구
  backup_retention_period = 30
  backup_window          = "02:00-03:00"
  maintenance_window     = "sun:03:00-sun:04:00"
  delete_automated_backups = false
  
  # 성능 최적화
  performance_insights_enabled = true
  performance_insights_retention_period = 7
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn
  
  # 파라미터 그룹 커스텀 설정
  parameter_group_parameters = [
    {
      name  = "shared_preload_libraries"
      value = "pg_stat_statements,pg_stat_monitor"
    },
    {
      name  = "log_statement"
      value = "all"
    },
    {
      name  = "log_min_duration_statement"
      value = "1000"  # 1초 이상 쿼리만 로그
    }
  ]
  
  # 보안 그룹 규칙
  allowed_security_groups = [
    module.app_servers.security_group_id,
    module.admin_bastion.security_group_id
  ]
  
  allowed_cidr_blocks = []  # 프로덕션에서는 CIDR 차단
  
  common_tags = {
    Project      = "enterprise-app"
    Environment  = "prod"
    Component    = "database"
    CriticalData = "yes"
    Backup       = "required"
  }
}
```

### 읽기 전용 복제본

```hcl
# 마스터 데이터베이스
module "master_db" {
  source = "../../modules/rds"
  
  project_name = "analytics"
  environment  = "prod"
  
  engine         = "mysql"
  engine_version = "8.0.35"
  instance_class = "db.r6g.large"
  
  # ... 기타 설정
  
  common_tags = local.common_tags
}

# 읽기 전용 복제본
module "read_replica" {
  source = "../../modules/rds"
  
  project_name = "analytics"
  environment  = "prod"
  
  # 읽기 복제본 설정
  replicate_source_db = module.master_db.db_instance_id
  instance_class     = "db.r6g.large"
  
  # 읽기 복제본용 별도 서브넷 (가능시)
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  # 백업은 마스터에서만
  backup_retention_period = 0
  
  # 읽기 전용 워크로드에 최적화
  parameter_group_parameters = [
    {
      name  = "read_only"
      value = "1"
    }
  ]
  
  common_tags = merge(local.common_tags, {
    Purpose = "read-replica"
  })
}
```

### 다중 데이터베이스 (마이크로서비스)

```hcl
locals {
  services = ["user", "order", "inventory", "payment"]
}

module "microservice_databases" {
  for_each = toset(local.services)
  source   = "../../modules/rds"
  
  project_name = "ecommerce"
  environment  = "prod"
  
  # 서비스별 데이터베이스
  db_name  = "${each.key}_service"
  username = "${each.key}_admin"
  
  # PostgreSQL 표준화
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = each.key == "order" ? "db.r6g.large" : "db.t4g.medium"
  
  # 스토리지 (주문 서비스는 더 큰 용량)
  allocated_storage = each.key == "order" ? 200 : 50
  max_allocated_storage = each.key == "order" ? 500 : 200
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  # 서비스별 보안 그룹 허용
  allowed_security_groups = [
    module.microservices[each.key].security_group_id
  ]
  
  # 프로덕션 설정
  multi_az = true
  backup_retention_period = 7
  
  common_tags = {
    Project     = "ecommerce"
    Environment = "prod"
    Service     = each.key
    Architecture = "microservices"
  }
}
```

## 입력 변수

| 변수명 | 설명 | 타입 | 기본값 | 필수 |
|--------|------|------|--------|------|
| `project_name` | 프로젝트 이름 | `string` | - | ✅ |
| `environment` | 환경 (dev, staging, prod) | `string` | - | ✅ |
| `engine` | 데이터베이스 엔진 | `string` | `"mysql"` | ❌ |
| `engine_version` | 엔진 버전 | `string` | `"8.0.35"` | ❌ |
| `instance_class` | RDS 인스턴스 클래스 | `string` | `"db.t3.micro"` | ❌ |
| `allocated_storage` | 초기 스토리지 크기 (GB) | `number` | `20` | ❌ |
| `max_allocated_storage` | 최대 스토리지 크기 (GB) | `number` | `100` | ❌ |
| `storage_type` | 스토리지 타입 | `string` | `"gp3"` | ❌ |
| `storage_encrypted` | 스토리지 암호화 활성화 | `bool` | `true` | ❌ |
| `kms_key_id` | KMS 키 ID | `string` | `null` | ❌ |
| `db_name` | 데이터베이스 이름 | `string` | - | ✅ |
| `username` | 마스터 사용자명 | `string` | - | ✅ |
| `password` | 마스터 비밀번호 (null시 자동생성) | `string` | `null` | ❌ |
| `vpc_id` | VPC ID | `string` | - | ✅ |
| `subnet_ids` | DB 서브넷 ID 리스트 | `list(string)` | - | ✅ |
| `multi_az` | Multi-AZ 배포 | `bool` | `false` | ❌ |
| `backup_retention_period` | 백업 보존 기간 (일) | `number` | `7` | ❌ |
| `backup_window` | 백업 윈도우 | `string` | `"03:00-04:00"` | ❌ |
| `maintenance_window` | 유지보수 윈도우 | `string` | `"sun:04:00-sun:05:00"` | ❌ |
| `publicly_accessible` | 퍼블릭 접근 허용 | `bool` | `false` | ❌ |
| `allowed_security_groups` | 접근 허용 보안 그룹 ID 리스트 | `list(string)` | `[]` | ❌ |
| `allowed_cidr_blocks` | 접근 허용 CIDR 블록 리스트 | `list(string)` | `[]` | ❌ |
| `parameter_group_parameters` | DB 파라미터 그룹 설정 | `list(object)` | `[]` | ❌ |
| `performance_insights_enabled` | 성능 인사이트 활성화 | `bool` | `false` | ❌ |
| `monitoring_interval` | 모니터링 간격 (초) | `number` | `0` | ❌ |
| `auto_minor_version_upgrade` | 자동 마이너 버전 업그레이드 | `bool` | `true` | ❌ |
| `deletion_protection` | 삭제 보호 | `bool` | `true` | ❌ |
| `final_snapshot_identifier` | 최종 스냅샷 식별자 | `string` | `null` | ❌ |
| `skip_final_snapshot` | 최종 스냅샷 건너뛰기 | `bool` | `false` | ❌ |
| `replicate_source_db` | 복제 소스 DB (읽기 복제본용) | `string` | `null` | ❌ |
| `common_tags` | 공통 태그 | `map(string)` | `{}` | ❌ |

## 출력 값

| 출력명 | 설명 | 타입 |
|--------|------|------|
| `db_instance_id` | RDS 인스턴스 ID | `string` |
| `db_instance_arn` | RDS 인스턴스 ARN | `string` |
| `db_instance_endpoint` | 데이터베이스 엔드포인트 | `string` |
| `db_instance_port` | 데이터베이스 포트 | `number` |
| `db_instance_hosted_zone_id` | 호스트 존 ID | `string` |
| `db_subnet_group_name` | DB 서브넷 그룹 이름 | `string` |
| `db_parameter_group_name` | DB 파라미터 그룹 이름 | `string` |
| `db_security_group_id` | DB 보안 그룹 ID | `string` |
| `master_password` | 마스터 비밀번호 (sensitive) | `string` |
| `master_password_secret_arn` | 비밀번호 Secrets Manager ARN | `string` |

## 예제

### 개발 환경 (비용 최적화)

```hcl
module "dev_database" {
  source = "../../modules/rds"
  
  project_name = "my-app"
  environment  = "dev"
  
  # 소규모 인스턴스
  engine         = "mysql"
  engine_version = "8.0.35"
  instance_class = "db.t3.micro"
  
  # 최소 스토리지
  allocated_storage     = 20
  max_allocated_storage = 50
  
  db_name  = "dev_app"
  username = "dev_admin"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  # 개발용 설정
  multi_az = false
  backup_retention_period = 1  # 최소 백업
  deletion_protection = false  # 개발용이므로 삭제 허용
  
  # 개발팀 접근 허용
  allowed_security_groups = [
    module.dev_bastion.security_group_id
  ]
  
  common_tags = {
    Project     = "my-app"
    Environment = "dev"
    Purpose     = "development"
  }
}
```

### 스테이징 환경 (프로덕션 유사)

```hcl
module "staging_database" {
  source = "../../modules/rds"
  
  project_name = "my-app"
  environment  = "staging"
  
  # 프로덕션 유사 설정
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = "db.t3.medium"
  
  # 적당한 스토리지
  allocated_storage     = 100
  max_allocated_storage = 300
  storage_encrypted    = true
  
  db_name  = "staging_app"
  username = "staging_admin"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  # 고가용성 테스트
  multi_az = true
  backup_retention_period = 7
  
  # 모니터링 활성화
  performance_insights_enabled = true
  monitoring_interval = 60
  
  allowed_security_groups = [
    module.app_servers.security_group_id,
    module.staging_bastion.security_group_id
  ]
  
  common_tags = {
    Project     = "my-app"
    Environment = "staging"
    Purpose     = "pre-production-testing"
  }
}
```

### 프로덕션 환경 (최대 보안/성능)

```hcl
module "production_database" {
  source = "../../modules/rds"
  
  project_name = "my-app"
  environment  = "prod"
  
  # 고성능 설정
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = "db.r6g.2xlarge"
  
  # 대용량 암호화 스토리지
  allocated_storage     = 1000
  max_allocated_storage = 5000
  storage_type         = "gp3"
  storage_encrypted    = true
  kms_key_id          = aws_kms_key.rds_prod.arn
  
  db_name  = "production_app"
  username = "prod_admin"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  # 최대 고가용성
  multi_az = true
  backup_retention_period = 30
  backup_window          = "02:00-03:00"
  maintenance_window     = "sun:03:00-sun:04:00"
  
  # 완전한 모니터링
  performance_insights_enabled = true
  performance_insights_retention_period = 31
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_enhanced_monitoring.arn
  
  # 보안 강화
  deletion_protection = true
  publicly_accessible = false
  
  # 애플리케이션 서버에서만 접근
  allowed_security_groups = [
    module.app_servers.security_group_id
  ]
  
  # 성능 최적화 파라미터
  parameter_group_parameters = [
    {
      name  = "shared_preload_libraries"
      value = "pg_stat_statements"
    },
    {
      name  = "max_connections"
      value = "200"
    },
    {
      name  = "work_mem"
      value = "32768"  # 32MB
    }
  ]
  
  common_tags = {
    Project      = "my-app"
    Environment  = "prod"
    Component    = "database"
    CriticalData = "yes"
    Compliance   = "required"
  }
}
```

## 데이터베이스 엔진별 설정

### MySQL 최적화

```hcl
module "mysql_optimized" {
  source = "../../modules/rds"
  
  engine         = "mysql"
  engine_version = "8.0.35"
  
  parameter_group_parameters = [
    {
      name  = "innodb_buffer_pool_size"
      value = "{DBInstanceClassMemory*3/4}"
    },
    {
      name  = "max_connections"
      value = "150"
    },
    {
      name  = "innodb_log_file_size"
      value = "134217728"  # 128MB
    }
  ]
}
```

### PostgreSQL 최적화

```hcl
module "postgres_optimized" {
  source = "../../modules/rds"
  
  engine         = "postgres"
  engine_version = "15.4"
  
  parameter_group_parameters = [
    {
      name  = "shared_buffers"
      value = "{DBInstanceClassMemory/4}"
    },
    {
      name  = "effective_cache_size"
      value = "{DBInstanceClassMemory*3/4}"
    },
    {
      name  = "maintenance_work_mem"
      value = "2097152"  # 2GB
    },
    {
      name  = "checkpoint_completion_target"
      value = "0.9"
    }
  ]
}
```

## 보안 권장사항

### 1. 네트워크 격리

```hcl
# ✅ 좋은 예: 프라이빗 서브넷 + 보안 그룹
module "secure_database" {
  source = "../../modules/rds"
  
  # 프라이빗 서브넷에만 배치
  subnet_ids = module.vpc.private_subnet_ids
  publicly_accessible = false
  
  # 애플리케이션 서버에서만 접근
  allowed_security_groups = [
    module.app_servers.security_group_id
  ]
  
  # CIDR 블록 사용 피하기
  allowed_cidr_blocks = []  # 보안 그룹으로만 접근
}

# ❌ 피해야 할 예: 퍼블릭 접근
# publicly_accessible = true  # 보안상 위험
# allowed_cidr_blocks = ["0.0.0.0/0"]  # 매우 위험
```

### 2. 암호화 설정

```hcl
# ✅ 좋은 예: 완전한 암호화
module "encrypted_database" {
  source = "../../modules/rds"
  
  # 저장 시 암호화
  storage_encrypted = true
  kms_key_id       = aws_kms_key.rds.arn
  
  # 전송 시 암호화 (파라미터로 강제)
  parameter_group_parameters = [
    {
      name  = "rds.force_ssl"  # MySQL
      value = "1"
    }
    # 또는 PostgreSQL의 경우:
    # {
    #   name  = "ssl"
    #   value = "1"
    # }
  ]
}
```

### 3. 접근 제어 및 감사

```hcl
module "audited_database" {
  source = "../../modules/rds"
  
  # 성능 인사이트로 쿼리 모니터링
  performance_insights_enabled = true
  monitoring_interval = 60
  
  # 로그 활성화
  parameter_group_parameters = [
    {
      name  = "log_statement"      # PostgreSQL
      value = "all"
    },
    {
      name  = "log_min_duration_statement"
      value = "1000"  # 1초 이상 쿼리
    },
    {
      name  = "log_connections"
      value = "1"
    },
    {
      name  = "log_disconnections"
      value = "1"
    }
  ]
}
```

## 성능 최적화

### 인스턴스 클래스 선택 가이드

```hcl
# 버스트 가능 (개발/소규모)
instance_class = "db.t3.micro"   # 2 vCPU, 1GB RAM
instance_class = "db.t3.small"   # 2 vCPU, 2GB RAM
instance_class = "db.t3.medium"  # 2 vCPU, 4GB RAM

# 범용 (프로덕션 일반)
instance_class = "db.m6g.large"    # 2 vCPU, 8GB RAM
instance_class = "db.m6g.xlarge"   # 4 vCPU, 16GB RAM
instance_class = "db.m6g.2xlarge"  # 8 vCPU, 32GB RAM

# 메모리 최적화 (대용량 데이터)
instance_class = "db.r6g.large"    # 2 vCPU, 16GB RAM
instance_class = "db.r6g.xlarge"   # 4 vCPU, 32GB RAM
instance_class = "db.r6g.2xlarge"  # 8 vCPU, 64GB RAM

# 컴퓨팅 최적화 (CPU 집약적)
instance_class = "db.c6g.large"    # 2 vCPU, 4GB RAM
instance_class = "db.c6g.xlarge"   # 4 vCPU, 8GB RAM
```

### 환경별 성능 최적화

```hcl
locals {
  db_config = {
    dev = {
      instance_class = "db.t3.micro"
      multi_az      = false
      backup_days   = 1
      monitoring    = false
    }
    staging = {
      instance_class = "db.t3.medium"
      multi_az      = true
      backup_days   = 7
      monitoring    = true
    }
    prod = {
      instance_class = "db.r6g.xlarge"
      multi_az      = true
      backup_days   = 30
      monitoring    = true
    }
  }
}

module "optimized_database" {
  source = "../../modules/rds"
  
  instance_class              = local.db_config[var.environment].instance_class
  multi_az                   = local.db_config[var.environment].multi_az
  backup_retention_period    = local.db_config[var.environment].backup_days
  performance_insights_enabled = local.db_config[var.environment].monitoring
}
```

## 백업 및 복구 전략

### 백업 설정

```hcl
module "backup_optimized_db" {
  source = "../../modules/rds"
  
  # 백업 윈도우 (트래픽이 적은 시간)
  backup_retention_period = 30
  backup_window          = "02:00-03:00"  # UTC
  
  # 포인트 인 타임 복구 활성화
  backup_retention_period = 7  # 최소 1일 이상 설정 필요
  
  # 최종 스냅샷 보존 (삭제 시)
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project_name}-${var.environment}-final-snapshot"
  
  # 자동 백업 삭제 방지
  delete_automated_backups = false
}
```

### 크로스 리전 백업

```hcl
# 메인 데이터베이스
module "primary_database" {
  source = "../../modules/rds"
  
  # ... 기본 설정
  
  # 백업에서 복제본 생성 허용
  backup_retention_period = 7
}

# 다른 리전의 읽기 복제본 (재해 복구용)
module "disaster_recovery_replica" {
  source = "../../modules/rds"
  
  providers = {
    aws = aws.disaster_recovery_region
  }
  
  # 크로스 리전 복제본
  replicate_source_db = module.primary_database.db_instance_arn
  
  # DR 리전 설정
  vpc_id     = module.dr_vpc.vpc_id
  subnet_ids = module.dr_vpc.private_subnet_ids
}
```

## 모니터링 및 알람

### CloudWatch 알람 설정

```hcl
# CPU 사용률 알람
resource "aws_cloudwatch_metric_alarm" "database_cpu_high" {
  alarm_name          = "${module.database.db_instance_id}-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name        = "CPUUtilization"
  namespace          = "AWS/RDS"
  period             = "300"
  statistic          = "Average"
  threshold          = "80"
  alarm_description  = "This metric monitors rds cpu utilization"
  
  dimensions = {
    DBInstanceIdentifier = module.database.db_instance_id
  }
  
  alarm_actions = [aws_sns_topic.alerts.arn]
}

# 연결 수 알람
resource "aws_cloudwatch_metric_alarm" "database_connections" {
  alarm_name          = "${module.database.db_instance_id}-connection-count"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name        = "DatabaseConnections"
  namespace          = "AWS/RDS"
  period             = "300"
  statistic          = "Average"
  threshold          = "80"
  
  dimensions = {
    DBInstanceIdentifier = module.database.db_instance_id
  }
}

# 디스크 사용률 알람  
resource "aws_cloudwatch_metric_alarm" "database_disk_space" {
  alarm_name          = "${module.database.db_instance_id}-free-storage-space"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name        = "FreeStorageSpace"
  namespace          = "AWS/RDS"
  period             = "300"
  statistic          = "Average"
  threshold          = "2000000000"  # 2GB
  
  dimensions = {
    DBInstanceIdentifier = module.database.db_instance_id
  }
}
```

## 문제 해결

### 일반적인 오류들

#### 1. "InvalidDBInstanceState"

```hcl
# 해결책: 인스턴스 상태 확인 후 작업
resource "null_resource" "wait_for_db" {
  depends_on = [module.database]
  
  provisioner "local-exec" {
    command = <<-EOT
      aws rds wait db-instance-available \
        --db-instance-identifier ${module.database.db_instance_id}
    EOT
  }
}
```

#### 2. "DBSubnetGroupDoesNotCoverEnoughAZs"

```hcl
# 해결책: 최소 2개 가용영역의 서브넷 제공
module "database" {
  source = "../../modules/rds"
  
  # 최소 2개 AZ의 서브넷 필요
  subnet_ids = module.vpc.private_subnet_ids  # 2개 이상의 서브넷
}
```

#### 3. "InvalidParameterValue" (파라미터 그룹)

```hcl
# 해결책: 엔진별 유효한 파라미터 사용
locals {
  mysql_parameters = [
    {
      name  = "innodb_buffer_pool_size"
      value = "{DBInstanceClassMemory*3/4}"
    }
  ]
  
  postgres_parameters = [
    {
      name  = "shared_buffers"
      value = "{DBInstanceClassMemory/4}"
    }
  ]
}

module "database" {
  source = "../../modules/rds"
  
  parameter_group_parameters = var.engine == "mysql" ? local.mysql_parameters : local.postgres_parameters
}
```

#### 4. "InsufficientDBInstanceCapacity"

```hcl
# 해결책: 다른 AZ 또는 인스턴스 타입 시도
module "database" {
  source = "../../modules/rds"
  
  # 여러 AZ에 분산된 서브넷 사용
  subnet_ids = module.vpc.private_subnet_ids
  
  # 가용성이 높은 인스턴스 타입 사용
  instance_class = "db.t3.medium"  # t3.micro 대신
}
```

## 제약사항

- 인스턴스 클래스 변경 시 재시작 필요
- 스토리지 크기는 증가만 가능 (감소 불가)
- Multi-AZ 활성화 시 약간의 성능 오버헤드 발생
- 읽기 복제본은 동일한 엔진/버전만 가능
- 파라미터 그룹 변경 시 재시작 또는 재부팅 필요할 수 있음

## 버전 요구사항

- Terraform: >= 1.5.0
- AWS Provider: >= 5.0.0

## 라이선스

이 모듈은 MIT 라이선스 하에 제공됩니다.