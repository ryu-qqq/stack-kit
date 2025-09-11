# 사용자 맞춤 StackKit 구현 계획

## 🎯 사용자 인프라 스택
- **Compute**: ECS 
- **Services**: API
- **Databases**: MySQL(RDS), Redis, DynamoDB
- **Messaging**: SQS, SNS, Lambda
- **Storage**: S3
- **Monitoring**: CloudWatch, Prometheus

## 🏗️ 구현 전략: Interactive CLI + Addon System

### 1. Core Templates (필수 패턴)

#### **api-service** (가장 기본)
```
api-service-template/
├── environments/dev/
│   ├── main.tf
│   │   ├── ECS Cluster + Service
│   │   ├── ALB + Target Groups  
│   │   ├── VPC + Subnets (connectly-shared 참조)
│   │   └── Basic CloudWatch Logs
│   ├── variables.tf
│   └── terraform.tfvars.example
├── .github/workflows/
│   └── ci-cd.yml
└── README.md
```

#### **minimal** (완전 자유)
```
minimal-template/
├── environments/dev/
│   ├── backend.tf
│   ├── provider.tf  
│   ├── variables.tf
│   └── data.tf (connectly-shared 참조)
├── .github/workflows/
└── scripts/add-component.sh
```

### 2. Addon System (조합 가능한 컴포넌트)

```
stackkit-addons/
├── database/
│   ├── mysql-rds/
│   ├── redis/
│   └── dynamodb/
├── messaging/
│   ├── sqs/
│   ├── sns/
│   └── lambda/
├── storage/
│   └── s3/
└── monitoring/
    ├── cloudwatch-enhanced/
    └── prometheus-grafana/
```

### 3. Interactive CLI 

```bash
# 스마트한 프로젝트 생성
./stackkit-cli.sh create

? What's your service name? user-api
? Which template to start with?
  > api-service (ECS + ALB + CloudWatch)
    minimal (empty structure)

? Which databases do you need?
  ☑ MySQL (RDS) 
  ☑ Redis
  ☐ DynamoDB
  ☐ PostgreSQL

? Message queues needed?
  ☑ SQS
  ☑ SNS  
  ☐ Lambda processors

? Advanced monitoring?
  ☑ Enhanced CloudWatch
  ☑ Prometheus + Grafana
  ☐ X-Ray tracing

? Storage requirements?
  ☑ S3 bucket
  ☐ EFS file system

Creating user-api with:
✅ ECS API service
✅ MySQL RDS  
✅ Redis cluster
✅ SQS queues
✅ SNS topics
✅ S3 bucket
✅ Enhanced monitoring
```

## 🛠️ 구현 단계

### Phase 1: Core Templates (1주)
```bash
# 1.1 API 서비스 템플릿 생성
mkdir -p templates/api-service/environments/{dev,staging,prod}

# 1.2 기본 ECS + ALB 설정
cat > templates/api-service/environments/dev/main.tf << 'EOF'
# ECS Service with ALB
module "api_service" {
  source = "git::https://github.com/company/stackkit-terraform-modules.git//foundation/compute/ecs-service?ref=v1.0.0"
  
  project_name = var.project_name
  environment  = var.environment
  
  # Shared infrastructure 참조
  vpc_id      = data.terraform_remote_state.shared.outputs.vpc_id
  subnet_ids  = data.terraform_remote_state.shared.outputs.private_subnet_ids
  cluster_id  = data.terraform_remote_state.shared.outputs.ecs_cluster_id
  
  # Service configuration
  container_image = "${var.ecr_repository_url}:latest"
  container_port  = 8080
  desired_count   = var.environment == "prod" ? 3 : 1
  
  # ALB configuration  
  alb_subnet_ids = data.terraform_remote_state.shared.outputs.public_subnet_ids
  health_check_path = "/health"
  
  tags = local.common_tags
}
EOF
```

### Phase 2: Addon System (2주)  
```bash
# 2.1 데이터베이스 애드온
mkdir -p addons/database/{mysql-rds,redis,dynamodb}

# 2.2 MySQL RDS 애드온
cat > addons/database/mysql-rds/main.tf << 'EOF'
module "mysql_rds" {
  source = "git::https://github.com/company/stackkit-terraform-modules.git//foundation/database/rds?ref=v1.0.0"
  
  identifier = "${var.project_name}-${var.environment}-mysql"
  engine     = "mysql"
  engine_version = "8.0"
  
  instance_class = var.environment == "prod" ? "db.t3.medium" : "db.t3.micro"
  allocated_storage = var.environment == "prod" ? 100 : 20
  
  db_subnet_group_name = data.terraform_remote_state.shared.outputs.rds_subnet_group_name
  vpc_security_group_ids = [data.terraform_remote_state.shared.outputs.rds_security_group_id]
  
  tags = var.common_tags
}

output "mysql_endpoint" {
  value = module.mysql_rds.endpoint
}

output "mysql_port" {
  value = module.mysql_rds.port  
}
EOF

# 2.3 Redis 애드온
cat > addons/database/redis/main.tf << 'EOF'
module "redis" {
  source = "git::https://github.com/company/stackkit-terraform-modules.git//foundation/database/elasticache-redis?ref=v1.0.0"
  
  cluster_id = "${var.project_name}-${var.environment}-redis"
  node_type  = var.environment == "prod" ? "cache.t3.medium" : "cache.t3.micro"
  
  subnet_group_name = data.terraform_remote_state.shared.outputs.elasticache_subnet_group_name
  security_group_ids = [data.terraform_remote_state.shared.outputs.elasticache_security_group_id]
  
  tags = var.common_tags
}

output "redis_endpoint" {
  value = module.redis.cache_nodes[0].address
}
EOF
```

### Phase 3: Interactive CLI (1주)
```bash
#!/bin/bash
# stackkit-cli.sh

create_project() {
    echo "🚀 StackKit Interactive Project Creator"
    echo
    
    # 프로젝트 정보 수집
    read -p "Service name: " SERVICE_NAME
    read -p "Team: " TEAM_NAME
    
    # 템플릿 선택
    echo "Which template?"
    echo "1) api-service (ECS + ALB)"  
    echo "2) minimal (empty)"
    read -p "Choice [1]: " TEMPLATE_CHOICE
    TEMPLATE_CHOICE=${TEMPLATE_CHOICE:-1}
    
    case $TEMPLATE_CHOICE in
        1) TEMPLATE="api-service" ;;
        2) TEMPLATE="minimal" ;;
        *) TEMPLATE="api-service" ;;
    esac
    
    # 데이터베이스 선택
    echo
    echo "Which databases? (space-separated)"
    echo "Options: mysql redis dynamodb"
    read -p "Databases: " DATABASES
    
    # 메시징 선택  
    echo "Which messaging? (space-separated)"
    echo "Options: sqs sns lambda"
    read -p "Messaging: " MESSAGING
    
    # 모니터링 선택
    echo "Enhanced monitoring?"
    echo "1) CloudWatch only"
    echo "2) CloudWatch + Prometheus"
    read -p "Choice [1]: " MONITORING_CHOICE
    MONITORING_CHOICE=${MONITORING_CHOICE:-1}
    
    # 프로젝트 생성
    echo
    echo "🏗️ Creating $SERVICE_NAME with:"
    echo "  Template: $TEMPLATE"
    echo "  Databases: $DATABASES" 
    echo "  Messaging: $MESSAGING"
    echo "  Monitoring: $MONITORING_CHOICE"
    echo
    
    # 기본 구조 생성
    ./tools/create-project-infrastructure.sh \
        --project "$SERVICE_NAME" \
        --team "$TEAM_NAME" \
        --template "$TEMPLATE" \
        --copy-governance
    
    cd "${SERVICE_NAME}-infrastructure"
    
    # 애드온 추가
    for db in $DATABASES; do
        echo "Adding $db..."
        ./scripts/add-addon.sh database/$db
    done
    
    for msg in $MESSAGING; do
        echo "Adding $msg..."
        ./scripts/add-addon.sh messaging/$msg  
    done
    
    if [[ "$MONITORING_CHOICE" == "2" ]]; then
        echo "Adding Prometheus..."
        ./scripts/add-addon.sh monitoring/prometheus-grafana
    fi
    
    echo "✅ Project created: ${SERVICE_NAME}-infrastructure"
    echo "Next steps:"
    echo "  cd ${SERVICE_NAME}-infrastructure"
    echo "  # Customize variables in environments/dev/terraform.tfvars"
    echo "  terraform -chdir=environments/dev plan"
}

add_addon() {
    local addon_type=$1
    local addon_name=$2
    
    if [[ ! -d "addons/$addon_type/$addon_name" ]]; then
        echo "❌ Addon not found: $addon_type/$addon_name"
        return 1
    fi
    
    echo "📦 Adding $addon_type/$addon_name..."
    
    # 애드온 파일 복사
    cp -r "addons/$addon_type/$addon_name"/* environments/dev/
    
    # 변수 파일 병합 (있는 경우)
    if [[ -f "addons/$addon_type/$addon_name/variables.tf" ]]; then
        cat "addons/$addon_type/$addon_name/variables.tf" >> environments/dev/variables.tf
    fi
    
    echo "✅ Added $addon_name"
}

case "$1" in
    create)
        create_project
        ;;
    add)
        add_addon "$2" "$3"
        ;;
    *)
        echo "Usage: $0 {create|add}"
        echo "  create           - Interactive project creator"
        echo "  add TYPE NAME    - Add addon to existing project"
        ;;
esac
```

## 🎯 사용 시나리오

### 시나리오 1: 간단한 API 서비스
```bash
./stackkit-cli.sh create
Service name: user-api
Team: backend
Template: 1 (api-service)
Databases: mysql redis
Messaging: sqs
Monitoring: 1 (CloudWatch)

# → 5분 후 완성!
```

### 시나리오 2: 복잡한 이벤트 처리 서비스  
```bash
./stackkit-cli.sh create
Service name: notification-service  
Team: platform
Template: 2 (minimal)
Databases: dynamodb redis
Messaging: sqs sns lambda
Monitoring: 2 (Prometheus)

# → 맞춤형 서비스 완성!
```

### 시나리오 3: 기존 프로젝트에 컴포넌트 추가
```bash
cd user-api-infrastructure
../stackkit-cli.sh add database dynamodb
../stackkit-cli.sh add messaging sns
../stackkit-cli.sh add monitoring prometheus-grafana
```

## 🚀 즉시 시작 가능한 작업

1. **api-service 템플릿 생성** (오늘)
2. **MySQL + Redis 애드온** (내일)  
3. **Interactive CLI 기본** (이번 주)
4. **SQS/SNS/Lambda 애드온** (다음 주)
5. **Prometheus 모니터링** (다음 주)

어떤 것부터 시작해볼까요? 🔥