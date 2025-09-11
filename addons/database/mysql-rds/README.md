# MySQL RDS Database Addon v1.0.0

Enterprise-grade MySQL RDS addon for the stackkit composition system. This module provides a production-ready MySQL database with comprehensive monitoring, backup strategies, and environment-specific configurations.

## Features

- **Environment-Aware Configuration**: Automatic scaling based on environment (dev/staging/prod)
- **High Availability**: Multi-AZ deployment for staging and production
- **Security**: Encryption at rest, VPC isolation, parameter group hardening
- **Monitoring**: Enhanced monitoring, Performance Insights, CloudWatch alarms
- **Backup Strategy**: Automated backups with configurable retention
- **Secrets Management**: Automatic credential management via AWS Secrets Manager
- **Read Replicas**: Optional read replicas for production workloads
- **Cost Optimization**: Environment-appropriate instance sizing

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Shared Infrastructure                    │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │     VPC     │  │   Subnets    │  │  Security Groups │   │
│  │             │  │ (Private/DB) │  │                  │   │
│  └─────────────┘  └──────────────┘  └──────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                    MySQL RDS Addon                         │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │ RDS Instance│  │   KMS Key    │  │ Secrets Manager  │   │
│  │  (Multi-AZ) │  │ (Encryption) │  │  (Credentials)   │   │
│  └─────────────┘  └──────────────┘  └──────────────────┘   │
│                                                             │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │Read Replica │  │   Monitoring │  │   CloudWatch     │   │
│  │ (Prod Only) │  │ (Enhanced)   │  │    Alarms        │   │
│  └─────────────┘  └──────────────┘  └──────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Usage

### Basic Usage

```hcl
module "mysql_db" {
  source = "./addons/database/mysql-rds"

  # Remote state configuration
  shared_state_bucket = "your-terraform-state-bucket"
  shared_state_key    = "shared/terraform.tfstate"
  aws_region         = "ap-northeast-2"

  # Project configuration
  project_name = "myapp"
  environment  = "prod"
  
  # Database configuration
  database_name   = "application"
  master_username = "dbadmin"

  common_tags = {
    Owner = "platform-team"
    Cost  = "shared"
  }
}
```

### Advanced Configuration

```hcl
module "mysql_db" {
  source = "./addons/database/mysql-rds"

  # Remote state configuration
  shared_state_bucket = "mycompany-terraform-state"
  shared_state_key    = "shared/infrastructure.tfstate"
  aws_region         = "ap-northeast-2"

  # Project configuration
  project_name = "ecommerce"
  environment  = "prod"
  
  # Custom instance configuration
  instance_class     = "db.r5.2xlarge"
  allocated_storage  = 500
  storage_type       = "io1"
  
  # High availability
  multi_az           = true
  create_read_replica = true
  read_replica_instance_class = "db.r5.xlarge"
  
  # Security
  allowed_cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12"]
  
  # Backup strategy
  backup_retention_period = 30
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  # Monitoring
  monitoring_interval = 15
  performance_insights_enabled = true
  create_cloudwatch_alarms = true
  
  # Custom parameters
  custom_parameters = [
    {
      name  = "innodb_lock_wait_timeout"
      value = "120"
    },
    {
      name  = "max_connections"
      value = "1000"
    }
  ]

  common_tags = {
    Owner       = "platform-team"
    Environment = "production"
    Cost        = "application"
  }
}
```

## Environment-Specific Defaults

### Development
- **Instance**: db.t3.micro
- **Storage**: 20GB
- **Multi-AZ**: Disabled
- **Backup**: 7 days retention

### Staging  
- **Instance**: db.t3.small
- **Storage**: 50GB
- **Multi-AZ**: Enabled
- **Backup**: 14 days retention

### Production
- **Instance**: db.r5.large
- **Storage**: 100GB
- **Multi-AZ**: Enabled
- **Backup**: 30 days retention
- **Deletion Protection**: Automatically enabled

## Integration with Shared Infrastructure

This addon requires shared infrastructure to be deployed first. The addon references:

```hcl
# Required from shared infrastructure
data.terraform_remote_state.shared.outputs.vpc_id
data.terraform_remote_state.shared.outputs.private_subnet_ids
data.terraform_remote_state.shared.outputs.database_subnet_ids  # Optional
data.terraform_remote_state.shared.outputs.database_security_group_id  # Optional
```

## Outputs

Key outputs for application integration:

```hcl
# Connection information
output "db_instance_endpoint" {
  value = module.mysql_db.db_instance_endpoint
}

output "database_name" {
  value = module.mysql_db.database_name
}

output "credentials_secret_arn" {
  value = module.mysql_db.credentials_secret_arn
}

# For read operations
output "read_replica_endpoint" {
  value = module.mysql_db.read_replica_endpoint
}
```

## Security Features

### Encryption
- Storage encryption using KMS
- Option to use custom KMS key or create new one
- Encryption in transit supported

### Network Security
- VPC isolation using shared infrastructure
- Security group with minimal required access
- Optional integration with shared security groups

### Credential Management
- Automatic password generation
- Secrets Manager integration
- No plaintext passwords in state

### Access Control
- Parameter group with security hardening
- Slow query logging enabled
- Connection monitoring

## Monitoring and Alerting

### CloudWatch Alarms
- CPU utilization monitoring
- Database connection count
- Free storage space alerts
- Customizable thresholds

### Enhanced Monitoring
- Configurable monitoring intervals
- Performance Insights integration
- Detailed system metrics

### Logging
- Slow query logging enabled
- Error log monitoring
- Query logging for production analysis

## Backup Strategy

### Automated Backups
- Environment-specific retention periods
- Point-in-time recovery capability
- Cross-region backup support

### Snapshot Management
- Final snapshot on deletion (configurable)
- Snapshot encryption
- Tag propagation to snapshots

## High Availability

### Multi-AZ Deployment
- Automatic failover capability
- Synchronous replication
- Zero-downtime patching

### Read Replicas
- Production workload support
- Read scaling capability
- Cross-AZ deployment

## Cost Optimization

### Instance Sizing
- Environment-appropriate defaults
- Auto-scaling storage
- Burstable performance for dev/staging

### Storage Optimization
- GP3 storage by default
- Configurable IOPS for high-performance workloads
- Storage auto-scaling prevention of outages

## Operational Procedures

### Deployment

1. **Deploy shared infrastructure first**
2. **Configure remote state backend**
3. **Deploy MySQL addon**
4. **Retrieve credentials from Secrets Manager**

### Maintenance

- **Automated minor version updates** (configurable)
- **Maintenance window** during low-traffic periods
- **Parameter group updates** without downtime

### Monitoring

- **CloudWatch dashboards** for key metrics
- **Alarm notifications** via SNS
- **Performance Insights** for query analysis

### Backup and Recovery

- **Automated daily backups**
- **Point-in-time recovery** capability
- **Cross-region backup** for disaster recovery

## Variables Reference

### Required Variables

| Variable | Type | Description |
|----------|------|-------------|
| `shared_state_bucket` | string | S3 bucket for shared infrastructure state |
| `project_name` | string | Name of the project |
| `environment` | string | Environment (dev/staging/prod) |

### Optional Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `database_name` | string | "main" | Database name |
| `master_username` | string | "admin" | Master username |
| `engine_version` | string | "8.0.35" | MySQL version |
| `instance_class` | string | "" | Instance class (auto-selected by environment) |
| `multi_az` | bool | null | Multi-AZ deployment (auto-configured) |
| `create_read_replica` | bool | false | Create read replica |
| `monitoring_interval` | number | 60 | Enhanced monitoring interval |

See `variables.tf` for complete variable documentation.

## Outputs Reference

### Connection Information

| Output | Description |
|--------|-------------|
| `db_instance_endpoint` | Primary database endpoint |
| `read_replica_endpoint` | Read replica endpoint (if created) |
| `credentials_secret_arn` | Secrets Manager ARN for credentials |
| `connection_string` | Full connection string |

### Security Information

| Output | Description |
|--------|-------------|
| `security_group_id` | Database security group ID |
| `kms_key_arn` | KMS key ARN for encryption |

See `outputs.tf` for complete output documentation.

## Examples

### Multi-Environment Setup

```bash
# Deploy development database
terraform apply -var="environment=dev" -var="project_name=myapp"

# Deploy staging database  
terraform apply -var="environment=staging" -var="project_name=myapp"

# Deploy production database with read replica
terraform apply -var="environment=prod" -var="project_name=myapp" -var="create_read_replica=true"
```

### Application Integration

```python
import boto3
import json

# Retrieve database credentials
secrets_client = boto3.client('secretsmanager')
secret_value = secrets_client.get_secret_value(SecretId='myapp-prod-mysql-credentials')
db_credentials = json.loads(secret_value['SecretString'])

# Connect to database
connection_string = f"mysql://{db_credentials['username']}:{db_credentials['password']}@{db_credentials['endpoint']}:{db_credentials['port']}/{db_credentials['dbname']}"
```

## Version History

- **v1.0.0**: Initial release with production-ready features

## Support

For issues and questions:
- Check the [troubleshooting guide](../../../docs/troubleshooting.md)
- Review [best practices](../../../docs/best-practices.md)
- Open an issue in the project repository