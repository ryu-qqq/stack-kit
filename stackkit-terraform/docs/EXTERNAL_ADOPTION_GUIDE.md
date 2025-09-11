# StackKit Terraform 외부 도입 가이드

StackKit Terraform에 오신 것을 환영합니다! 이 가이드는 귀사가 StackKit의 검증된 인프라 패턴과 모듈을 자체 AWS 환경에 도입하는 데 도움이 될 것입니다.

## 📋 목차

1. [신규 회사를 위한 빠른 시작](#신규-회사를-위한-빠른-시작)
2. [전제 조건 및 종속성](#전제-조건-및-종속성)
3. [마이그레이션 전략](#마이그레이션-전략)
4. [맞춤화 가이드](#맞춤화-가이드)
5. [통합 패턴](#통합-패턴)
6. [엔터프라이즈 모범 사례](#엔터프라이즈-모범-사례)
7. [지원 및 유지보수](#지원-및-유지보수)

---

## 🚀 신규 회사를 위한 빠른 시작

### 1단계: 클론 및 초기 설정

```bash
# StackKit Terraform 레포지토리 클론
git clone https://github.com/your-org/stackkit-terraform.git
cd stackkit-terraform

# 회사별 브랜치 생성
git checkout -b company/your-company-name
```

### 2단계: 회사별 설정

1. **terraform.tfvars 템플릿 업데이트:**
```hcl
# terraform.tfvars.example -> terraform.tfvars
company_name    = "your-company"
environment     = "production"
aws_region      = "us-west-2"
project_prefix  = "yourco"

# 회사별 설정
domain_name     = "yourcompany.com"
contact_email   = "infrastructure@yourcompany.com"
```

2. **백엔드 상태 관리 구성:**
```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "yourco-terraform-state"
    key            = "infrastructure/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "yourco-terraform-locks"
    encrypt        = true
  }
}
```

### 3단계: 초기 배포

```bash
# Terraform 초기화
terraform init

# 인프라 계획
terraform plan -var-file="terraform.tfvars"

# 적용 (최소 구성 요소부터 시작)
terraform apply -target=module.networking
```

---

## 🔧 전제 조건 및 종속성

### 필수 도구 및 버전

| 도구 | 최소 버전 | 권장 버전 | 목적 |
|------|----------------|-------------------|---------|
| Terraform | 1.0.0 | 1.6.0+ | Infrastructure as Code |
| AWS CLI | 2.0.0 | 2.13.0+ | AWS API 상호작용 |
| kubectl | 1.23.0 | 1.28.0+ | Kubernetes 관리 |
| Helm | 3.8.0 | 3.13.0+ | Kubernetes 패키지 관리 |
| jq | 1.6 | 1.7+ | JSON 처리 |

### AWS 계정 설정

#### 1. AWS 계정 요구사항
- AWS Organization 설정 (멀티 계정 전략에 권장)
- 환경별 전용 AWS 계정:
  - `yourco-dev` (개발)
  - `yourco-staging` (스테이징)
  - `yourco-prod` (프로덕션)
  - `yourco-security` (보안 도구)
  - `yourco-shared` (공유 서비스)

#### 2. IAM 권한
다음 관리형 정책을 포함한 Terraform용 IAM 역할 생성:
- `PowerUserAccess` (개발용)
- 프로덕션용 사용자 정의 정책 (최소 권한 원칙)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "eks:*",
        "iam:*",
        "s3:*",
        "rds:*",
        "elasticache:*",
        "route53:*",
        "acm:*",
        "logs:*"
      ],
      "Resource": "*"
    }
  ]
}
```

#### 3. Required AWS Resources (Bootstrap)
```bash
# Create S3 bucket for Terraform state
aws s3 mb s3://yourco-terraform-state --region us-west-2

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name yourco-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
```

---

## 🔄 Migration Strategies

### Strategy 1: Greenfield Deployment (Recommended for New Infrastructure)

**Best for:** Companies starting fresh or willing to rebuild infrastructure

```bash
# Start with core networking
terraform apply -target=module.vpc
terraform apply -target=module.subnets

# Add compute resources
terraform apply -target=module.eks
terraform apply -target=module.node_groups

# Deploy applications
terraform apply -target=module.applications
```

**Timeline:** 2-4 weeks
**Risk Level:** Low
**Effort:** Medium

### Strategy 2: Import Existing Resources

**Best for:** Companies with existing AWS infrastructure to preserve

```bash
# Import existing VPC
terraform import module.vpc.aws_vpc.main vpc-12345678

# Import existing subnets
terraform import module.subnets.aws_subnet.private[0] subnet-12345678

# Generate configuration from existing resources
terraformer import aws --resources=vpc,subnet,eks --regions=us-west-2
```

**Timeline:** 4-8 weeks
**Risk Level:** Medium
**Effort:** High

### Strategy 3: Hybrid Approach (Gradual Migration)

**Best for:** Large enterprises with complex existing infrastructure

Phase 1: New components with StackKit
```bash
# Deploy new EKS cluster alongside existing infrastructure
terraform apply -target=module.new_eks_cluster
```

Phase 2: Migrate workloads gradually
```bash
# Migrate applications one by one
kubectl drain old-node-1
kubectl apply -f new-workload-configs/
```

Phase 3: Decommission old infrastructure
```bash
# Remove old resources after validation
terraform destroy -target=module.legacy_infrastructure
```

**Timeline:** 6-12 months
**Risk Level:** Low
**Effort:** High

---

## 🎨 Customization Guide

### Company-Specific Module Customization

#### 1. Naming Conventions
Create `locals.tf` with your company standards:

```hcl
locals {
  naming_convention = {
    prefix = var.company_name
    environment = var.environment
    separator = "-"
  }
  
  common_tags = {
    Company     = var.company_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = var.team_email
    CostCenter  = var.cost_center
  }
  
  # Generate consistent names
  cluster_name = "${local.naming_convention.prefix}${local.naming_convention.separator}${local.naming_convention.environment}${local.naming_convention.separator}eks"
}
```

#### 2. Custom Variables
Add company-specific variables to `variables.tf`:

```hcl
variable "company_name" {
  description = "Your company name"
  type        = string
}

variable "compliance_framework" {
  description = "Compliance framework (SOC2, HIPAA, PCI-DSS)"
  type        = list(string)
  default     = ["SOC2"]
}

variable "backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 30
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access resources"
  type        = list(string)
}
```

#### 3. Custom Modules
Create company-specific modules in `modules/custom/`:

```bash
mkdir -p modules/custom/compliance-monitoring
mkdir -p modules/custom/backup-automation
mkdir -p modules/custom/cost-optimization
```

Example custom module structure:
```
modules/custom/compliance-monitoring/
├── main.tf
├── variables.tf
├── outputs.tf
└── README.md
```

### Environment-Specific Configurations

#### Development Environment
```hcl
# environments/dev/terraform.tfvars
environment = "dev"
instance_types = ["t3.small", "t3.medium"]
min_size = 1
max_size = 5
enable_monitoring = false
backup_enabled = false
```

#### Production Environment
```hcl
# environments/prod/terraform.tfvars
environment = "prod"
instance_types = ["m5.large", "m5.xlarge"]
min_size = 3
max_size = 20
enable_monitoring = true
backup_enabled = true
encryption_enabled = true
```

---

## 🔗 Integration Patterns

### CI/CD Pipeline Integration

#### GitHub Actions Example

```yaml
# .github/workflows/terraform.yml
name: Terraform Infrastructure

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  terraform:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [dev, staging, prod]
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v2
      with:
        terraform_version: 1.6.0
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v2
      with:
        role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
        aws-region: ${{ vars.AWS_REGION }}
    
    - name: Terraform Init
      run: terraform init
      working-directory: environments/${{ matrix.environment }}
    
    - name: Terraform Plan
      run: terraform plan -var-file="terraform.tfvars"
      working-directory: environments/${{ matrix.environment }}
    
    - name: Terraform Apply
      if: github.ref == 'refs/heads/main'
      run: terraform apply -auto-approve -var-file="terraform.tfvars"
      working-directory: environments/${{ matrix.environment }}
```

#### Jenkins Pipeline Example

```groovy
pipeline {
    agent any
    
    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['dev', 'staging', 'prod'],
            description: 'Environment to deploy'
        )
        booleanParam(
            name: 'DESTROY',
            defaultValue: false,
            description: 'Destroy infrastructure'
        )
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Terraform Init') {
            steps {
                sh "cd environments/${params.ENVIRONMENT} && terraform init"
            }
        }
        
        stage('Terraform Plan') {
            steps {
                sh "cd environments/${params.ENVIRONMENT} && terraform plan -var-file=terraform.tfvars -out=tfplan"
            }
        }
        
        stage('Terraform Apply') {
            when {
                not { params.DESTROY }
            }
            steps {
                sh "cd environments/${params.ENVIRONMENT} && terraform apply tfplan"
            }
        }
        
        stage('Terraform Destroy') {
            when {
                params.DESTROY
            }
            steps {
                sh "cd environments/${params.ENVIRONMENT} && terraform destroy -auto-approve -var-file=terraform.tfvars"
            }
        }
    }
}
```

### Multi-Account AWS Strategy

#### Organization Structure
```
Root Organization Account
├── Security Account (yourco-security)
│   ├── AWS Config
│   ├── CloudTrail
│   └── Security Hub
├── Shared Services Account (yourco-shared)
│   ├── DNS (Route53)
│   ├── Container Registry (ECR)
│   └── CI/CD Tools
├── Development Account (yourco-dev)
├── Staging Account (yourco-staging)
└── Production Account (yourco-prod)
```

#### Cross-Account IAM Roles
```hcl
# Cross-account role for CI/CD
resource "aws_iam_role" "cicd_cross_account" {
  name = "CICD-CrossAccount-Role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.cicd_account_id}:root"
        }
      }
    ]
  })
}
```

### Existing Tool Integration

#### Monitoring Integration (Datadog/New Relic)
```hcl
# Datadog integration
resource "aws_iam_role" "datadog_integration" {
  name = "DatadogIntegrationRole"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::464622532012:root" # Datadog AWS Account
        }
      }
    ]
  })
}
```

#### Secret Management (Vault/AWS Secrets Manager)
```hcl
# External Secrets Operator for Kubernetes
resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  namespace  = "external-secrets-system"
  create_namespace = true
  
  values = [
    templatefile("${path.module}/values/external-secrets.yaml", {
      aws_region = var.aws_region
    })
  ]
}
```

---

## 🏢 Best Practices for Enterprise

### Security Considerations

#### 1. Network Security
```hcl
# Private subnets for sensitive workloads
module "vpc" {
  source = "./modules/vpc"
  
  enable_nat_gateway = true
  enable_vpn_gateway = false
  enable_flow_logs   = true
  
  # Network segmentation
  private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  database_subnet_cidrs = ["10.0.201.0/24", "10.0.202.0/24", "10.0.203.0/24"]
}

# Security groups with least privilege
resource "aws_security_group" "app" {
  name_prefix = "${local.cluster_name}-app-"
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

#### 2. Encryption at Rest and in Transit
```hcl
# EKS cluster with envelope encryption
resource "aws_eks_cluster" "main" {
  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn
    }
    resources = ["secrets"]
  }
}

# RDS with encryption
resource "aws_db_instance" "main" {
  storage_encrypted = true
  kms_key_id       = aws_kms_key.rds.arn
}
```

#### 3. IAM Best Practices
```hcl
# Service-specific IAM roles
resource "aws_iam_role" "app_role" {
  name = "${local.cluster_name}-app-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub": "system:serviceaccount:app:app-service-account"
          }
        }
      }
    ]
  })
}
```

### Compliance Frameworks

#### SOC 2 Compliance
```hcl
# Enable AWS Config for compliance monitoring
resource "aws_config_configuration_recorder" "main" {
  name     = "${var.company_name}-config-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

# CloudTrail for audit logging
resource "aws_cloudtrail" "main" {
  name                          = "${var.company_name}-cloudtrail"
  s3_bucket_name               = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail        = true
  enable_log_file_validation   = true
  
  kms_key_id = aws_kms_key.cloudtrail.arn
  
  event_selector {
    read_write_type           = "All"
    include_management_events = true
    
    data_resource {
      type   = "AWS::S3::Object"
      values = ["${aws_s3_bucket.sensitive_data.arn}/*"]
    }
  }
}
```

#### HIPAA Compliance
```hcl
# Dedicated tenancy for HIPAA workloads
resource "aws_instance" "hipaa_workload" {
  tenancy = "dedicated"
  
  root_block_device {
    encrypted = true
  }
  
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
}
```

### Cost Management

#### 1. Resource Tagging Strategy
```hcl
locals {
  cost_tags = {
    CostCenter    = var.cost_center
    Project       = var.project_name
    Environment   = var.environment
    Owner         = var.team_email
    AutoShutdown  = var.environment == "dev" ? "true" : "false"
  }
}

# Apply tags to all resources
resource "aws_instance" "example" {
  # ... other configuration
  
  tags = merge(local.common_tags, local.cost_tags, {
    Name = "${local.cluster_name}-instance"
  })
}
```

#### 2. Cost Optimization
```hcl
# Spot instances for non-critical workloads
resource "aws_eks_node_group" "spot" {
  capacity_type = "SPOT"
  
  instance_types = ["m5.large", "m5.xlarge", "m4.large"]
  
  scaling_config {
    desired_size = 2
    max_size     = 10
    min_size     = 0
  }
}

# Scheduled scaling for development environments
resource "aws_autoscaling_schedule" "scale_down" {
  count = var.environment == "dev" ? 1 : 0
  
  scheduled_action_name  = "scale-down-evening"
  min_size              = 0
  max_size              = 0
  desired_capacity      = 0
  recurrence            = "0 19 * * MON-FRI"
  autoscaling_group_name = aws_eks_node_group.main.resources[0].autoscaling_groups[0].name
}
```

#### 3. Budget Alerts
```hcl
resource "aws_budgets_budget" "monthly" {
  name         = "${var.company_name}-monthly-budget"
  budget_type  = "COST"
  limit_amount = var.monthly_budget_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  
  cost_filters = {
    Tag = {
      "Environment" = [var.environment]
    }
  }
  
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_email_addresses = [var.billing_alert_email]
  }
}
```

### Team Organization

#### 1. Repository Structure for Teams
```
stackkit-terraform/
├── teams/
│   ├── platform/          # Platform team resources
│   │   ├── networking/
│   │   ├── security/
│   │   └── monitoring/
│   ├── applications/      # Application teams
│   │   ├── team-a/
│   │   ├── team-b/
│   │   └── team-c/
│   └── shared/           # Shared resources
│       ├── dns/
│       ├── certificates/
│       └── container-registry/
├── modules/              # Reusable modules
└── environments/         # Environment-specific configs
```

#### 2. Team-Specific Access Control
```hcl
# Team-specific IAM policies
resource "aws_iam_policy" "team_a_policy" {
  name = "TeamAKubernetesAccess"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["eks:*"]
        Resource = [
          "arn:aws:eks:*:*:cluster/${local.cluster_name}",
          "arn:aws:eks:*:*:nodegroup/${local.cluster_name}/*"
        ]
        Condition = {
          StringEquals = {
            "eks:cluster-name": local.cluster_name
          }
        }
      }
    ]
  })
}
```

---

## 🛠 Support and Maintenance

### Keeping Modules Up to Date

#### 1. Version Pinning Strategy
```hcl
# Pin to specific versions in production
module "vpc" {
  source  = "git::https://github.com/your-org/stackkit-terraform.git//modules/vpc?ref=v1.2.3"
  
  # Module configuration
}

# Use latest in development
module "vpc" {
  source  = "git::https://github.com/your-org/stackkit-terraform.git//modules/vpc?ref=main"
  
  # Module configuration
}
```

#### 2. Update Process
```bash
# 1. Create update branch
git checkout -b updates/terraform-modules-v2.0.0

# 2. Update module versions
sed -i 's/v1\.2\.3/v2.0.0/g' environments/*/main.tf

# 3. Test in development first
cd environments/dev
terraform plan

# 4. Run tests
terraform apply -target=module.vpc
kubectl get nodes  # Verify connectivity

# 5. Apply to staging and production
cd ../staging && terraform apply
cd ../prod && terraform apply
```

#### 3. Automated Update Checks
```yaml
# .github/workflows/module-updates.yml
name: Check for Module Updates

on:
  schedule:
    - cron: '0 9 * * MON'  # Every Monday at 9 AM

jobs:
  check-updates:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    
    - name: Check for updates
      run: |
        # Custom script to check for new module versions
        ./scripts/check-module-updates.sh
        
    - name: Create PR if updates available
      uses: peter-evans/create-pull-request@v5
      with:
        token: ${{ secrets.GITHUB_TOKEN }}
        commit-message: "chore: update terraform modules"
        title: "Update Terraform modules to latest versions"
        body: "Automated PR to update Terraform modules"
```

### Community Contributions

#### 1. Contributing Back to StackKit
```bash
# Fork the main repository
git clone https://github.com/your-org/stackkit-terraform.git
cd stackkit-terraform

# Create feature branch
git checkout -b feature/new-rds-module

# Make changes and test
# ... development work ...

# Submit pull request
git push origin feature/new-rds-module
# Create PR on GitHub
```

#### 2. Sharing Company-Specific Modules
Consider open-sourcing generic modules that could benefit others:

```bash
# Example: Create a reusable compliance module
mkdir -p modules/compliance/
cat > modules/compliance/README.md << EOF
# Compliance Module

This module sets up compliance monitoring for SOC2/HIPAA requirements.

## Usage
\`\`\`hcl
module "compliance" {
  source = "./modules/compliance"
  
  compliance_framework = ["SOC2", "HIPAA"]
  notification_email   = "security@yourcompany.com"
}
\`\`\`
EOF
```

### Getting Help and Support

#### 1. Documentation and Resources
- **Internal Wiki**: Document your customizations and decisions
- **Runbooks**: Create operational procedures for common tasks
- **Architecture Decision Records (ADRs)**: Document important technical decisions

#### 2. Community Channels
- **GitHub Issues**: Report bugs and request features
- **Slack/Discord**: Join the StackKit community channel
- **Monthly Sync**: Participate in community calls

#### 3. Professional Support Options
- **Consulting Services**: Get help with complex migrations
- **Training Programs**: Upskill your team on StackKit patterns
- **Priority Support**: SLA-backed support for enterprise customers

#### 4. Internal Support Structure
```
Level 1: Team Self-Service
├── Documentation and runbooks
├── Automated testing and validation
└── Common issue troubleshooting

Level 2: Platform Team Support  
├── Complex configuration issues
├── Module development and customization
└── Integration problems

Level 3: External Support
├── StackKit community
├── AWS support (for AWS-specific issues)
└── Professional consulting services
```

#### 5. Monitoring and Alerting for Operations
```hcl
# Slack notifications for infrastructure issues
resource "aws_sns_topic" "alerts" {
  name = "${var.company_name}-infrastructure-alerts"
}

resource "aws_sns_topic_subscription" "slack" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "https"
  endpoint  = var.slack_webhook_url
}

# CloudWatch alarms for key metrics
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${local.cluster_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EKS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}
```

---

## 📞 Getting Started Checklist

Use this checklist to track your adoption progress:

### Pre-Migration Checklist
- [ ] AWS accounts set up (dev, staging, prod)
- [ ] IAM roles and permissions configured
- [ ] S3 bucket for Terraform state created
- [ ] DynamoDB table for state locking created
- [ ] CI/CD pipeline configured
- [ ] Team access and permissions defined

### Initial Setup Checklist
- [ ] Repository cloned and customized
- [ ] Company-specific variables configured
- [ ] Terraform backend configured
- [ ] Initial terraform plan successful
- [ ] Networking module deployed
- [ ] Security groups and IAM roles created

### Production Readiness Checklist
- [ ] Monitoring and alerting configured
- [ ] Backup and disaster recovery tested
- [ ] Security audit completed
- [ ] Cost management and budgets set up
- [ ] Documentation updated for your team
- [ ] Team training completed
- [ ] Support processes established

### Ongoing Maintenance Checklist
- [ ] Module update process documented
- [ ] Automated security scanning enabled
- [ ] Regular cost optimization reviews scheduled
- [ ] Disaster recovery procedures tested
- [ ] Team knowledge sharing sessions planned

---

## 🎯 Next Steps

1. **Start Small**: Begin with a development environment
2. **Learn by Doing**: Deploy basic networking and compute resources
3. **Iterate and Improve**: Gradually add complexity and customization
4. **Share Knowledge**: Document your learnings for your team
5. **Contribute Back**: Share improvements with the StackKit community

Welcome to the StackKit family! We're excited to see what you'll build with these infrastructure patterns.

---

*For questions, issues, or contributions, please visit our [GitHub repository](https://github.com/your-org/stackkit-terraform) or join our community channels.*