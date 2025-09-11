# DynamoDB Database Addon v1.0.0

Serverless NoSQL database addon for the stackkit composition system. This module provides a production-ready DynamoDB table with global tables support, auto-scaling, comprehensive backup strategies, and environment-specific configurations.

## Features

- **Global Tables**: Multi-region replication for global applications
- **Auto-Scaling**: Automatic capacity management for provisioned mode
- **Environment-Aware**: Pay-per-request for dev, provisioned for production
- **Security**: Encryption at rest with KMS, deletion protection
- **Monitoring**: CloudWatch alarms, Contributor Insights
- **Backup Strategy**: AWS Backup integration with lifecycle management
- **Cost Optimization**: Environment-appropriate billing modes and table classes
- **Stream Processing**: Optional DynamoDB Streams for real-time processing

## Architecture

### Single Region Deployment
```
┌─────────────────────────────────────────────────────────────┐
│                    DynamoDB Table                          │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │   Primary   │  │     GSI      │  │      LSI         │   │
│  │    Table    │  │   Indexes    │  │    Indexes       │   │
│  └─────────────┘  └──────────────┘  └──────────────────┘   │
│                                                             │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │ Auto Scaling│  │   Streams    │  │    Backups       │   │
│  │ (Provisioned)│  │ (Optional)   │  │  (AWS Backup)    │   │
│  └─────────────┘  └──────────────┘  └──────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Global Tables Deployment
```
┌─────────────────────────────────────────────────────────────┐
│                     Primary Region                         │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │   Primary   │  │   KMS Key    │  │   CloudWatch     │   │
│  │    Table    │  │ (Encryption) │  │    Alarms        │   │
│  └─────────────┘  └──────────────┘  └──────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                    │            │            │
                    ▼            ▼            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Replica Regions                         │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │   Replica   │  │   Replica    │  │    Replica       │   │
│  │   Table 1   │  │   Table 2    │  │    Table 3       │   │
│  │ (us-east-1) │  │ (eu-west-1)  │  │ (ap-southeast-1) │   │
│  └─────────────┘  └──────────────┘  └──────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Usage

### Basic Usage

```hcl
module "user_table" {
  source = "./addons/database/dynamodb"

  # Remote state configuration
  shared_state_bucket = "your-terraform-state-bucket"
  shared_state_key    = "shared/terraform.tfstate"
  aws_region         = "ap-northeast-2"

  # Project configuration
  project_name = "myapp"
  environment  = "prod"
  table_name   = "users"

  # Table schema
  hash_key = "user_id"
  range_key = "created_at"
  
  attributes = [
    {
      name = "user_id"
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

  common_tags = {
    Owner = "backend-team"
    Cost  = "application"
  }
}
```

### Advanced Configuration with Global Tables

```hcl
module "global_user_table" {
  source = "./addons/database/dynamodb"

  # Remote state configuration
  shared_state_bucket = "mycompany-terraform-state"
  shared_state_key    = "shared/infrastructure.tfstate"
  aws_region         = "ap-northeast-2"

  # Project configuration
  project_name = "global-app"
  environment  = "prod"
  table_name   = "users"

  # Table schema
  hash_key  = "user_id"
  range_key = "created_at"
  
  attributes = [
    {
      name = "user_id"
      type = "S"
    },
    {
      name = "created_at"
      type = "S"
    },
    {
      name = "email"
      type = "S"
    },
    {
      name = "status"
      type = "S"
    }
  ]

  # Global Tables
  enable_global_tables = true
  replica_regions = [
    "us-east-1",
    "eu-west-1",
    "ap-southeast-1"
  ]

  # Billing configuration
  billing_mode   = "PROVISIONED"
  read_capacity  = 100
  write_capacity = 100

  # Global Secondary Indexes
  global_secondary_indexes = [
    {
      name               = "email-index"
      hash_key           = "email"
      range_key          = "created_at"
      projection_type    = "ALL"
      non_key_attributes = []
      read_capacity      = 50
      write_capacity     = 50
    },
    {
      name               = "status-index"
      hash_key           = "status"
      range_key          = "created_at"
      projection_type    = "INCLUDE"
      non_key_attributes = ["user_id", "email"]
      read_capacity      = 25
      write_capacity     = 25
    }
  ]

  # Time to Live
  ttl_enabled        = true
  ttl_attribute_name = "expires_at"

  # Streams
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  # Auto Scaling
  enable_autoscaling = true
  autoscaling_read_min_capacity  = 50
  autoscaling_read_max_capacity  = 1000
  autoscaling_write_min_capacity = 50
  autoscaling_write_max_capacity = 1000

  # Backup
  enable_backup = true
  backup_schedule = "cron(0 3 ? * * *)" # Daily at 3 AM
  backup_delete_after = 365 # 1 year retention

  # Performance
  enable_contributor_insights = true

  common_tags = {
    Owner       = "backend-team"
    Environment = "production"
    Cost        = "application"
    Global      = "true"
  }
}
```

### Event-Driven Architecture with Streams

```hcl
module "orders_table" {
  source = "./addons/database/dynamodb"

  # Basic configuration
  shared_state_bucket = "your-state-bucket"
  project_name = "ecommerce"
  environment  = "prod"
  table_name   = "orders"

  # Schema
  hash_key = "order_id"
  attributes = [
    {
      name = "order_id"
      type = "S"
    }
  ]

  # Enable streams for event processing
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  # Point-in-time recovery for critical data
  point_in_time_recovery_enabled = true

  common_tags = {
    Component = "orders"
    Critical  = "true"
  }
}

# Lambda function to process stream events
resource "aws_lambda_function" "order_processor" {
  # Lambda configuration
  function_name = "order-stream-processor"
  
  # Event source mapping
  event_source_mapping {
    event_source_arn  = module.orders_table.table_stream_arn
    function_name     = aws_lambda_function.order_processor.arn
    starting_position = "LATEST"
  }
}
```

## Environment-Specific Defaults

### Development
- **Billing Mode**: Pay-per-request
- **Backup**: Disabled
- **Point-in-time Recovery**: Disabled
- **Deletion Protection**: Disabled

### Staging
- **Billing Mode**: Pay-per-request
- **Backup**: Enabled (daily)
- **Point-in-time Recovery**: Enabled
- **Deletion Protection**: Disabled

### Production
- **Billing Mode**: Pay-per-request (customizable to provisioned)
- **Backup**: Enabled (daily with long retention)
- **Point-in-time Recovery**: Enabled
- **Deletion Protection**: Enabled
- **Global Tables**: Available

## Global Tables Configuration

Global Tables provide multi-master, cross-region replication:

```hcl
# Enable global tables for production
enable_global_tables = true
replica_regions = [
  "us-east-1",      # Primary US region
  "eu-west-1",      # Europe region
  "ap-southeast-1"  # Asia Pacific region
]
```

### Benefits
- **Multi-region active-active**: Read and write from any region
- **Low latency**: Data close to users globally
- **Disaster recovery**: Automatic failover capabilities
- **Consistency**: Eventually consistent across regions

## Security Features

### Encryption
- **At Rest**: KMS encryption for all data
- **Custom KMS Keys**: Option to use existing or create new keys
- **Key Management**: Automatic key rotation support

### Access Control
- **IAM Integration**: Fine-grained access control
- **Resource Policies**: Table-level access policies
- **VPC Endpoints**: Private connectivity option

### Data Protection
- **Deletion Protection**: Prevent accidental table deletion
- **Point-in-time Recovery**: Restore to any point within 35 days
- **Backup Encryption**: Encrypted backups with KMS

## Monitoring and Alerting

### CloudWatch Alarms
- **Throttling**: Read/write throttle detection
- **Capacity**: Consumption monitoring for provisioned tables
- **Error Rate**: System error monitoring
- **Latency**: Performance monitoring

### Contributor Insights
- **Hot Partitions**: Identify uneven data distribution
- **Top Items**: Most accessed items analysis
- **Performance Optimization**: Query pattern insights

### Custom Metrics
```hcl
# Example: Custom alarm for high read latency
resource "aws_cloudwatch_metric_alarm" "read_latency" {
  alarm_name          = "high-read-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "SuccessfulRequestLatency"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Average"
  threshold           = "100"
  alarm_description   = "High read latency detected"

  dimensions = {
    TableName = module.user_table.table_name
    Operation = "Query"
  }
}
```

## Backup and Recovery

### AWS Backup Integration
- **Automated Backups**: Daily backup with configurable retention
- **Cross-region Copy**: Disaster recovery support
- **Lifecycle Management**: Automatic transition to cold storage
- **Compliance**: Meet regulatory requirements

### Point-in-time Recovery
- **35-day Window**: Restore to any second within 35 days
- **Zero Downtime**: No impact during backup operations
- **Granular Recovery**: Restore specific items if needed

### Backup Strategy Example
```hcl
# Production backup configuration
enable_backup = true
backup_schedule = "cron(0 2 ? * * *)"  # 2 AM daily
backup_cold_storage_after = 30          # Move to cold storage after 30 days
backup_delete_after = 2555               # Delete after 7 years (compliance)
```

## Performance Optimization

### Auto-scaling
- **Demand-based**: Automatic capacity adjustment
- **Target Tracking**: Maintain optimal utilization
- **Cost Effective**: Scale down during low usage

### Index Design
```hcl
# Efficient GSI design
global_secondary_indexes = [
  {
    name            = "status-date-index"
    hash_key        = "status"
    range_key       = "created_date"
    projection_type = "KEYS_ONLY"  # Minimize storage costs
  }
]
```

### Best Practices
- **Composite Keys**: Distribute data across partitions
- **Sparse Indexes**: GSI with selective attributes
- **Projection Types**: Minimize projected attributes
- **Query Patterns**: Design for access patterns

## Cost Optimization

### Billing Modes
- **Pay-per-request**: Best for unpredictable workloads
- **Provisioned**: Cost-effective for consistent traffic
- **Auto-scaling**: Optimize provisioned mode costs

### Table Classes
```hcl
# Use Infrequent Access for archival data
table_class = "STANDARD_INFREQUENT_ACCESS"
```

### Storage Optimization
- **TTL**: Automatic data expiration
- **Compression**: Efficient data encoding
- **Projection**: Minimize GSI storage

## Integration Patterns

### Application Code Examples

#### Python (Boto3)
```python
import boto3
from botocore.exceptions import ClientError

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('myapp-prod-users')

# Put item
try:
    response = table.put_item(
        Item={
            'user_id': 'user123',
            'created_at': '2024-01-01T00:00:00Z',
            'email': 'user@example.com',
            'status': 'active'
        }
    )
except ClientError as e:
    print(f"Error: {e.response['Error']['Message']}")

# Query with GSI
response = table.query(
    IndexName='email-index',
    KeyConditionExpression=Key('email').eq('user@example.com')
)
```

#### Node.js (AWS SDK v3)
```javascript
import { DynamoDBClient, PutItemCommand, QueryCommand } from "@aws-sdk/client-dynamodb";

const client = new DynamoDBClient({ region: "ap-northeast-2" });

// Put item
const putCommand = new PutItemCommand({
  TableName: "myapp-prod-users",
  Item: {
    user_id: { S: "user123" },
    created_at: { S: "2024-01-01T00:00:00Z" },
    email: { S: "user@example.com" },
    status: { S: "active" }
  }
});

try {
  await client.send(putCommand);
} catch (error) {
  console.error("Error:", error);
}
```

#### Java (AWS SDK)
```java
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.*;

DynamoDbClient dynamoDb = DynamoDbClient.builder()
    .region(Region.AP_NORTHEAST_2)
    .build();

// Put item
PutItemRequest putRequest = PutItemRequest.builder()
    .tableName("myapp-prod-users")
    .item(Map.of(
        "user_id", AttributeValue.builder().s("user123").build(),
        "created_at", AttributeValue.builder().s("2024-01-01T00:00:00Z").build(),
        "email", AttributeValue.builder().s("user@example.com").build(),
        "status", AttributeValue.builder().s("active").build()
    ))
    .build();

dynamoDb.putItem(putRequest);
```

## Variables Reference

### Required Variables

| Variable | Type | Description |
|----------|------|-------------|
| `shared_state_bucket` | string | S3 bucket for shared infrastructure state |
| `project_name` | string | Name of the project |
| `environment` | string | Environment (dev/staging/prod) |
| `hash_key` | string | Partition key for the table |
| `attributes` | list(object) | Table attributes definition |

### Optional Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `table_name` | string | "main" | DynamoDB table name |
| `range_key` | string | null | Sort key for the table |
| `billing_mode` | string | "" | Billing mode (auto-selected by environment) |
| `enable_global_tables` | bool | false | Enable global tables |
| `replica_regions` | list(string) | [] | Replica regions for global tables |
| `ttl_enabled` | bool | false | Enable Time to Live |
| `stream_enabled` | bool | false | Enable DynamoDB Streams |

See `variables.tf` for complete variable documentation.

## Outputs Reference

### Table Information

| Output | Description |
|--------|-------------|
| `table_name` | DynamoDB table name |
| `table_arn` | Table ARN |
| `table_stream_arn` | Stream ARN (if enabled) |
| `hash_key` | Partition key |
| `range_key` | Sort key |

### Global Tables

| Output | Description |
|--------|-------------|
| `global_tables_enabled` | Whether global tables are enabled |
| `replica_regions` | List of replica regions |
| `table_endpoints` | Regional endpoints |

See `outputs.tf` for complete output documentation.

## Best Practices

### Schema Design
- Design for your access patterns, not normalization
- Use composite keys for data distribution
- Implement GSIs for alternative access patterns
- Consider LSIs for sort key variations

### Performance
- Avoid hot partitions through key design
- Use pagination for large result sets
- Implement exponential backoff for retries
- Monitor and optimize with Contributor Insights

### Cost Management
- Choose appropriate billing mode for workload
- Use TTL for automatic data expiration
- Optimize GSI projections
- Consider table classes for infrequent access

### Security
- Use IAM roles with least privilege
- Enable encryption at rest
- Implement VPC endpoints for private access
- Monitor access patterns

## Version History

- **v1.0.0**: Initial release with global tables support

## Support

For issues and questions:
- Check the [DynamoDB best practices guide](../../../docs/dynamodb-best-practices.md)
- Review [troubleshooting guide](../../../docs/troubleshooting.md)
- Open an issue in the project repository