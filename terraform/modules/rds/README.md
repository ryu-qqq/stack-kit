# RDS 모듈

AWS RDS 인스턴스를 생성하고 관리하는 Terraform 모듈입니다.

## 기능

- RDS 인스턴스 생성 (MySQL, PostgreSQL, MariaDB 등)
- Multi-AZ 배포 지원
- 자동 백업 및 스냅샷
- 보안 그룹 관리
- 서브넷 그룹 설정
- 파라미터 그룹 커스터마이징
- 암호화 지원

## 사용법

```hcl
module "database" {
  source = "../../modules/rds"
  
  project_name = "my-app"
  environment  = "dev"
  
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"
  
  allocated_storage     = 20
  max_allocated_storage = 100
  
  db_name  = "myapp"
  username = "admin"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  backup_retention_period = 7
  multi_az               = false  # prod에서는 true
  
  common_tags = local.common_tags
}
```