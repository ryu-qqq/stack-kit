# PROJECT_NAME_PLACEHOLDER Infrastructure

> 🚀 **StackKit v2** API Service Infrastructure Template  
> Complete REST API service infrastructure using Terraform and AWS

## 📋 Project Information

| | |
|---|---|
| **Project** | PROJECT_NAME_PLACEHOLDER |
| **Team** | TEAM_NAME_PLACEHOLDER |
| **Organization** | ORG_NAME_PLACEHOLDER |
| **Template** | API Service |
| **Terraform Version** | >= 1.0 |
| **AWS Provider** | ~> 5.0 |

## 🏗️ Architecture Overview

This template provisions a complete, production-ready REST API service infrastructure:

```
┌─────────────────────────────────────────────────────────────┐
│                          Internet                           │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                 CloudFront CDN                              │
│                (Optional SSL/TLS)                           │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│              Application Load Balancer                      │
│           (Health Checks, Auto Scaling)                     │
└─────────────────────┬───────────────────────────────────────┘
                      │
        ┌─────────────┼─────────────┐
        │             │             │
┌───────▼──────┐ ┌────▼─────┐ ┌────▼─────┐
│  ECS Task    │ │ ECS Task │ │ ECS Task │
│  (Fargate)   │ │(Fargate) │ │(Fargate) │
└──────────────┘ └──────────┘ └──────────┘
        │             │             │
        └─────────────┼─────────────┘
                      │
     ┌────────────────┼────────────────┐
     │                │                │
┌────▼────┐      ┌────▼────┐     ┌────▼────┐
│   RDS   │      │  Redis  │     │   S3    │
│Database │      │ Cache   │     │ Assets  │
└─────────┘      └─────────┘     └─────────┘
```

### 🔧 Core Components

- **🌐 Networking**: VPC with public/private/database subnets
- **⚖️ Load Balancing**: Application Load Balancer with health checks
- **💻 Compute**: ECS Fargate containers with auto-scaling
- **🗄️ Database**: PostgreSQL RDS with automated backups
- **⚡ Caching**: Redis ElastiCache for performance
- **💾 Storage**: S3 bucket for static assets
- **📊 Monitoring**: CloudWatch dashboards and alerts

## 🚀 Quick Start

### Prerequisites

- [Terraform](https://terraform.io/downloads.html) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) configured
- [StackKit CLI v2](../tools/stackkit-v2-cli.sh) (recommended)

### Option 1: Using StackKit CLI (Recommended)

```bash
# Create new project from this template
stackkit new --template api-service \
  --name PROJECT_NAME_PLACEHOLDER \
  --team TEAM_NAME_PLACEHOLDER \
  --org ORG_NAME_PLACEHOLDER

# Validate configuration
stackkit validate

# Deploy to development
stackkit deploy --env dev
```

### Option 2: Manual Setup

```bash
# Clone this repository
git clone <your-repo-url>
cd PROJECT_NAME_PLACEHOLDER-infrastructure

# Update configuration files
# 1. Update terraform.tfvars files in environments/
# 2. Configure backend settings in main.tf
# 3. Set up secrets in AWS Secrets Manager

# Initialize and deploy
cd environments/dev
terraform init
terraform plan
terraform apply
```

## 📁 Directory Structure

```
PROJECT_NAME_PLACEHOLDER-infrastructure/
├── 📁 environments/          # Environment-specific configurations
│   ├── 📁 dev/              # Development environment
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   ├── 📁 staging/          # Staging environment
│   └── 📁 prod/             # Production environment
├── 📁 modules/              # Local project modules (if needed)
├── 📁 .github/workflows/    # CI/CD pipelines
│   └── terraform-ci.yml
├── 📁 scripts/              # Helper scripts
├── main.tf                  # Main Terraform configuration
├── variables.tf             # Variable definitions
├── outputs.tf               # Output definitions
├── atlantis.yaml           # Atlantis GitOps configuration
├── .pre-commit-config.yaml # Pre-commit hooks
└── README.md               # This file
```

## ⚙️ Configuration

### Environment Variables

Each environment (`dev`, `staging`, `prod`) has its own `terraform.tfvars` file:

```hcl
# Basic Configuration
project_name = "PROJECT_NAME_PLACEHOLDER"
environment  = "dev"
team         = "TEAM_NAME_PLACEHOLDER"

# Container Configuration
container_image = "your-app:latest"
container_port  = 8080
container_cpu   = 256
container_memory = 512

# Database Configuration (optional)
enable_database = true
db_engine      = "postgres"
db_instance_class = "db.t3.micro"

# Additional features
enable_redis     = false
enable_s3_bucket = false
```

### Secrets Management

Store sensitive values in AWS Secrets Manager:

```bash
# Database password
aws secretsmanager create-secret \
  --name "PROJECT_NAME_PLACEHOLDER-dev-db-password" \
  --description "Database password for PROJECT_NAME_PLACEHOLDER dev" \
  --secret-string "your-secure-password"

# API keys
aws secretsmanager create-secret \
  --name "PROJECT_NAME_PLACEHOLDER-dev-api-key" \
  --description "API key for PROJECT_NAME_PLACEHOLDER dev" \
  --secret-string "your-api-key"
```

### Backend Configuration

Configure Terraform backend in each environment:

```hcl
# environments/dev/backend.tf
terraform {
  backend "s3" {
    bucket         = "ORG_NAME_PLACEHOLDER-terraform-state"
    key            = "PROJECT_NAME_PLACEHOLDER/dev/terraform.tfstate"
    region         = "REGION_PLACEHOLDER"
    encrypt        = true
    dynamodb_table = "ORG_NAME_PLACEHOLDER-terraform-locks"
  }
}
```

## 🚢 Deployment

### Development Environment

```bash
# Automatic deployment via Git
git add .
git commit -m "Add new feature"
git push origin feature/new-feature
# Creates PR → Atlantis runs plan → Review → Merge → Auto-deploy

# Manual deployment
cd environments/dev
terraform init
terraform plan
terraform apply
```

### Production Environment

Production deployments require manual approval:

1. **Merge to main** → Triggers automatic plan
2. **Review plan** in GitHub Actions
3. **Approve deployment** in GitHub Environment
4. **Monitor** deployment progress

### Using Atlantis (GitOps)

This template includes Atlantis configuration for GitOps workflows:

```bash
# Comment on PR to trigger operations
atlantis plan
atlantis apply

# Environment-specific operations
atlantis plan -p PROJECT_NAME_PLACEHOLDER-dev
atlantis apply -p PROJECT_NAME_PLACEHOLDER-prod
```

## 📊 Monitoring & Observability

### CloudWatch Dashboards

Automatically created dashboards include:

- **Application Metrics**: Request count, latency, error rate
- **Infrastructure Metrics**: CPU, memory, network utilization
- **Database Metrics**: Connections, queries, performance
- **Load Balancer Metrics**: Target health, request distribution

### Alerts

Configure alerts for critical metrics:

```hcl
alert_topic_arn = "arn:aws:sns:region:account:PROJECT_NAME_PLACEHOLDER-alerts"
```

### Logs

All application logs are centralized in CloudWatch:

- **Application Logs**: `/aws/ecs/PROJECT_NAME_PLACEHOLDER`
- **Load Balancer Logs**: S3 bucket (if enabled)
- **Database Logs**: CloudWatch Logs groups

## 🔧 Customization

### Adding New Modules

1. Create module in `modules/` directory
2. Reference in `main.tf`
3. Add variables and outputs
4. Update documentation

### Environment-Specific Settings

Customize per environment in `terraform.tfvars`:

```hcl
# Development: Minimal resources
container_cpu = 256
desired_count = 1
enable_autoscaling = false

# Production: High availability
container_cpu = 1024
desired_count = 3
enable_autoscaling = true
min_capacity = 3
max_capacity = 20
```

### Advanced Features

Enable optional components:

```hcl
# Redis caching
enable_redis = true
redis_node_type = "cache.r6g.large"

# S3 assets bucket
enable_s3_bucket = true
s3_enable_versioning = true

# Database read replicas
enable_read_replica = true
```

## 🛠️ Development Workflow

### Local Development

```bash
# Format code
terraform fmt -recursive

# Validate configuration
terraform validate

# Run security scan
tfsec .

# Check costs
infracost breakdown --path environments/dev
```

### Pre-commit Hooks

Install pre-commit hooks for code quality:

```bash
pip install pre-commit
pre-commit install
```

### Testing

```bash
# Test specific environment
cd environments/dev
terraform plan -detailed-exitcode

# Integration tests (if available)
./scripts/test-integration.sh
```

## 📚 Documentation

### Additional Resources

- [StackKit v2 Documentation](https://github.com/company/stackkit-terraform-modules)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)

### Team Resources

- **Runbook**: `docs/runbook.md`
- **Architecture Decisions**: `docs/adr/`
- **Troubleshooting**: `docs/troubleshooting.md`

## 🚨 Troubleshooting

### Common Issues

**State Lock Issues**
```bash
# Force unlock (use carefully)
terraform force-unlock <lock-id>
```

**Module Version Conflicts**
```bash
# Update modules
stackkit update --modules all
terraform init -upgrade
```

**Access Denied Errors**
```bash
# Check AWS credentials
aws sts get-caller-identity
aws iam get-user
```

### Getting Help

1. **Check logs** in CloudWatch
2. **Review terraform plan** output
3. **Contact team**: TEAM_NAME_PLACEHOLDER
4. **Create issue** in repository

## 🔄 Maintenance

### Regular Tasks

- **Weekly**: Review CloudWatch alerts and metrics
- **Monthly**: Update Terraform modules and providers
- **Quarterly**: Security audit and access review

### Updating Dependencies

```bash
# Update StackKit modules
stackkit update --modules all

# Update Terraform providers
terraform init -upgrade
```

### Backup and Recovery

- **State files**: Backed up to S3 with versioning
- **Database**: Automated daily backups (7-30 days retention)
- **Code**: Version controlled in Git

---

## 🏷️ Tags

All resources are automatically tagged with:

- `Project`: PROJECT_NAME_PLACEHOLDER
- `Environment`: dev/staging/prod
- `Team`: TEAM_NAME_PLACEHOLDER
- `ManagedBy`: terraform
- `Template`: api-service
- `CreatedBy`: stackkit-v2

---

**Generated by StackKit v2** | **Template Version**: 2.0.0 | **Last Updated**: $(date +%Y-%m-%d)