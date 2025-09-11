# Database Addons Collection v1.0.0

Complete database addon collection for the stackkit composition system. This collection provides production-ready database solutions that integrate seamlessly with connectly-shared-infrastructure.

## Available Database Addons

### 🗄️ MySQL RDS
Enterprise-grade MySQL database with Multi-AZ support, automated backups, and environment-specific configurations.

**Features:**
- Multi-AZ deployment for high availability
- Read replicas for performance scaling
- Automated backups with point-in-time recovery
- Enhanced monitoring and CloudWatch alarms
- Secrets Manager integration
- Environment-aware sizing

### ⚡ Redis ElastiCache
High-performance Redis caching solution with cluster mode support and comprehensive security.

**Features:**
- Standard and cluster mode configurations
- Auth tokens and encryption
- Multi-AZ deployment
- Auto-scaling for cluster mode
- CloudWatch monitoring
- Session persistence support

### 📊 DynamoDB
Serverless NoSQL database with global tables support and comprehensive backup strategies.

**Features:**
- Global tables for multi-region deployment
- Auto-scaling for provisioned mode
- DynamoDB Streams for event processing
- AWS Backup integration
- Point-in-time recovery
- Cost optimization features

## Quick Start

### Prerequisites

1. **Shared Infrastructure**: Deploy connectly-shared-infrastructure first
2. **Remote State**: Configure S3 backend for state management
3. **IAM Permissions**: Ensure deployment role has necessary permissions

### Basic Usage Pattern

```hcl
# Example: Deploy MySQL database
module "app_database" {
  source = "./addons/database/mysql-rds"

  # Required: Remote state configuration
  shared_state_bucket = "your-terraform-state-bucket"
  shared_state_key    = "shared/connectly-shared-infrastructure.tfstate"
  aws_region         = "ap-northeast-2"

  # Required: Project configuration
  project_name = "your-app"
  environment  = "prod"

  # Database-specific configuration
  database_name = "application"
  
  common_tags = {
    Owner = "platform-team"
    Cost  = "application"
  }
}
```

## Integration Architecture

```
┌─────────────────────────────────────────────────────────────┐
│              Connectly Shared Infrastructure                │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │     VPC     │  │   Subnets    │  │  Security Groups │   │
│  │             │  │              │  │                  │   │
│  └─────────────┘  └──────────────┘  └──────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                   Database Addons                          │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │ MySQL RDS   │  │    Redis     │  │    DynamoDB      │   │
│  │             │  │ ElastiCache  │  │                  │   │
│  └─────────────┘  └──────────────┘  └──────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                  Application Layer                         │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │  Backend    │  │   Frontend   │  │   Microservices  │   │
│  │  Services   │  │              │  │                  │   │
│  └─────────────┘  └──────────────┘  └──────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Environment Strategy

### Development
- **MySQL**: db.t3.micro, single AZ, 7-day backup retention
- **Redis**: cache.t3.micro, standard mode, no auth
- **DynamoDB**: Pay-per-request, no backup, no deletion protection

### Staging
- **MySQL**: db.t3.small, Multi-AZ, 14-day backup retention
- **Redis**: cache.t3.small, cluster mode, auth enabled
- **DynamoDB**: Pay-per-request, backup enabled, PITR enabled

### Production
- **MySQL**: db.r5.large+, Multi-AZ, read replicas, 30-day backup retention
- **Redis**: cache.r6g.large+, cluster mode, encryption, monitoring
- **DynamoDB**: Configurable billing, global tables, full backup strategy

## Security Features

### Encryption
- **At Rest**: KMS encryption for all databases
- **In Transit**: TLS/SSL for all connections
- **Key Management**: Custom KMS keys with rotation

### Access Control
- **VPC Isolation**: Private subnets only
- **Security Groups**: Minimal required access
- **IAM Integration**: Role-based access control
- **Secrets Management**: AWS Secrets Manager for credentials

### Compliance
- **Backup Encryption**: Encrypted backups
- **Audit Logging**: CloudTrail integration
- **Monitoring**: CloudWatch alarms and logging

## Monitoring Stack

### CloudWatch Integration
- **Metrics**: Performance, availability, and usage metrics
- **Alarms**: Proactive alerting for issues
- **Dashboards**: Centralized monitoring views
- **Logs**: Application and system logs

### Performance Insights
- **MySQL**: Query performance analysis
- **Redis**: Cache hit ratio and latency monitoring
- **DynamoDB**: Request patterns and throttling analysis

## Cost Optimization

### Right-sizing
- **Environment-based**: Appropriate sizing per environment
- **Auto-scaling**: Dynamic capacity adjustment
- **Reserved Instances**: Cost savings for predictable workloads

### Storage Optimization
- **Backup Retention**: Configurable retention policies
- **Storage Classes**: Infrequent access options
- **Compression**: Efficient data storage

## Deployment Examples

### Multi-Database Application
```hcl
# Primary database
module "mysql_primary" {
  source = "./addons/database/mysql-rds"
  
  shared_state_bucket = var.state_bucket
  project_name = "ecommerce"
  environment  = "prod"
  database_name = "orders"
  
  # Production configuration
  create_read_replica = true
  multi_az = true
}

# Cache layer
module "redis_cache" {
  source = "./addons/database/redis"
  
  shared_state_bucket = var.state_bucket
  project_name = "ecommerce"
  environment  = "prod"
  
  # Cluster mode for high performance
  cluster_mode_enabled = true
  num_node_groups = 3
}

# User session store
module "session_table" {
  source = "./addons/database/dynamodb"
  
  shared_state_bucket = var.state_bucket
  project_name = "ecommerce"
  environment  = "prod"
  table_name = "user-sessions"
  
  hash_key = "session_id"
  attributes = [
    { name = "session_id", type = "S" }
  ]
  
  # Enable TTL for automatic cleanup
  ttl_enabled = true
  ttl_attribute_name = "expires_at"
}
```

### Global Application
```hcl
# Global user data with DynamoDB Global Tables
module "global_users" {
  source = "./addons/database/dynamodb"
  
  shared_state_bucket = var.state_bucket
  project_name = "global-app"
  environment  = "prod"
  table_name = "users"
  
  # Global tables configuration
  enable_global_tables = true
  replica_regions = [
    "us-east-1",
    "eu-west-1", 
    "ap-northeast-2"
  ]
  
  # Schema design
  hash_key = "user_id"
  range_key = "created_at"
  attributes = [
    { name = "user_id", type = "S" },
    { name = "created_at", type = "S" },
    { name = "email", type = "S" }
  ]
  
  # Global secondary index for email lookups
  global_secondary_indexes = [
    {
      name = "email-index"
      hash_key = "email"
      range_key = "created_at"
      projection_type = "ALL"
      non_key_attributes = []
      read_capacity = 50
      write_capacity = 50
    }
  ]
}
```

## Best Practices

### Schema Design
- **MySQL**: Normalize for consistency, denormalize for performance
- **Redis**: Design for access patterns, use appropriate data types
- **DynamoDB**: Single table design, efficient partition key distribution

### Security
- **Least Privilege**: Minimal required permissions
- **Encryption**: Always enable encryption at rest and in transit
- **Secrets Rotation**: Regular credential rotation
- **Network Isolation**: Private subnets and security groups

### Performance
- **Connection Pooling**: Efficient connection management
- **Caching Strategy**: Redis for frequently accessed data
- **Index Design**: Optimize for query patterns
- **Monitoring**: Proactive performance monitoring

### Cost Management
- **Environment Sizing**: Appropriate resources per environment
- **Reserved Capacity**: Cost savings for stable workloads
- **Backup Optimization**: Efficient retention policies
- **Resource Tagging**: Comprehensive cost allocation

## Migration Guide

### From Existing Databases

1. **Assessment**: Analyze current database usage patterns
2. **Planning**: Design new architecture with addons
3. **Testing**: Deploy in staging environment
4. **Migration**: Use appropriate migration tools
5. **Validation**: Verify data integrity and performance

### Database Modernization

```hcl
# Legacy MySQL to modern setup
module "modernized_mysql" {
  source = "./addons/database/mysql-rds"
  
  # Modern configuration
  engine_version = "8.0.35"
  instance_class = "db.r5.large"
  multi_az = true
  
  # Enhanced monitoring
  monitoring_interval = 15
  performance_insights_enabled = true
  
  # Automated backups
  backup_retention_period = 30
  backup_window = "03:00-04:00"
}
```

## Troubleshooting

### Common Issues

1. **Connection Failures**
   - Check security group rules
   - Verify VPC connectivity
   - Validate credentials

2. **Performance Issues**
   - Review CloudWatch metrics
   - Analyze slow query logs
   - Check resource utilization

3. **Backup Failures**
   - Verify IAM permissions
   - Check backup window configuration
   - Review storage capacity

### Support Resources

- **Documentation**: Comprehensive README files for each addon
- **Examples**: Working examples in `/examples` directories
- **Monitoring**: CloudWatch dashboards and alarms
- **Logging**: Centralized log aggregation

## Version History

- **v1.0.0**: Initial release with MySQL RDS, Redis ElastiCache, and DynamoDB

## Contributing

1. Follow Terraform best practices
2. Update documentation for changes
3. Add examples for new features
4. Ensure backward compatibility
5. Test across environments

## Support

For issues and questions:
- Check individual addon README files
- Review troubleshooting guides
- Open issues in the project repository
- Consult AWS documentation for service-specific guidance