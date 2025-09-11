# Redis ElastiCache Addon v1.0.0

High-performance Redis caching addon for the stackkit composition system. This module provides a production-ready Redis ElastiCache cluster with cluster mode support, comprehensive security, and environment-specific configurations.

## Features

- **Dual Mode Support**: Standard replication and cluster mode configurations
- **Environment-Aware**: Automatic scaling and configuration based on environment
- **High Availability**: Multi-AZ deployment with automatic failover
- **Security**: Auth tokens, encryption at rest and in transit, VPC isolation
- **Monitoring**: CloudWatch alarms, log delivery, and performance metrics
- **Backup Strategy**: Automated snapshots with configurable retention
- **Cost Optimization**: Environment-appropriate node sizing and configurations

## Architecture

### Standard Mode (dev/small workloads)
```
┌─────────────────────────────────────────────────────────────┐
│                    Shared Infrastructure                    │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │     VPC     │  │   Subnets    │  │  Security Groups │   │
│  │             │  │ (Private)    │  │                  │   │
│  └─────────────┘  └──────────────┘  └──────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                     Redis Standard Mode                    │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │   Primary   │  │   Replica    │  │   Auth Token     │   │
│  │    Node     │  │    Node      │  │  (Secrets Mgr)   │   │
│  └─────────────┘  └──────────────┘  └──────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Cluster Mode (staging/production)
```
┌─────────────────────────────────────────────────────────────┐
│                    Shared Infrastructure                    │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │     VPC     │  │   Subnets    │  │  Security Groups │   │
│  │             │  │ (Private)    │  │                  │   │
│  └─────────────┘  └──────────────┘  └──────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                     Redis Cluster Mode                     │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │   Shard 1   │  │   Shard 2    │  │    Shard 3       │   │
│  │ P + R + R   │  │  P + R + R   │  │   P + R + R      │   │
│  └─────────────┘  └──────────────┘  └──────────────────┘   │
│                                                             │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │Configuration│  │   KMS Key    │  │   Auth Token     │   │
│  │  Endpoint   │  │ (Encryption) │  │  (Secrets Mgr)   │   │
│  └─────────────┘  └──────────────┘  └──────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Usage

### Basic Usage

```hcl
module "redis_cache" {
  source = "./addons/database/redis"

  # Remote state configuration
  shared_state_bucket = "your-terraform-state-bucket"
  shared_state_key    = "shared/terraform.tfstate"
  aws_region         = "ap-northeast-2"

  # Project configuration
  project_name = "myapp"
  environment  = "prod"

  common_tags = {
    Owner = "platform-team"
    Cost  = "shared"
  }
}
```

### Advanced Configuration

```hcl
module "redis_cache" {
  source = "./addons/database/redis"

  # Remote state configuration
  shared_state_bucket = "mycompany-terraform-state"
  shared_state_key    = "shared/infrastructure.tfstate"
  aws_region         = "ap-northeast-2"

  # Project configuration
  project_name = "ecommerce"
  environment  = "prod"
  
  # Cluster configuration
  cluster_mode_enabled = true
  num_node_groups     = 3
  replicas_per_node_group = 2
  node_type           = "cache.r6g.xlarge"
  
  # Security
  auth_token_enabled = true
  encryption_at_rest_enabled = true
  encryption_in_transit_enabled = true
  allowed_cidr_blocks = ["10.0.0.0/8"]
  
  # Backup strategy
  snapshot_retention_limit = 7
  snapshot_window         = "03:00-05:00"
  maintenance_window      = "sun:05:00-sun:06:00"
  
  # Monitoring
  create_cloudwatch_alarms = true
  
  # Custom parameters
  custom_parameters = [
    {
      name  = "timeout"
      value = "300"
    }
  ]

  # Log delivery
  log_delivery_configuration = [
    {
      destination      = "cloudwatch-logs"
      destination_type = "cloudwatch-logs"
      log_format       = "json"
      log_type         = "slow-log"
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
- **Node Type**: cache.t3.micro
- **Mode**: Standard (single node)
- **Multi-AZ**: Disabled
- **Cluster Mode**: Disabled

### Staging
- **Node Type**: cache.t3.small
- **Mode**: Cluster (2 shards, 1 replica each)
- **Multi-AZ**: Enabled
- **Cluster Mode**: Enabled

### Production
- **Node Type**: cache.r6g.large
- **Mode**: Cluster (3 shards, 2 replicas each)
- **Multi-AZ**: Enabled
- **Cluster Mode**: Enabled
- **Automatic Failover**: Enabled

## Integration with Shared Infrastructure

This addon requires shared infrastructure to be deployed first. The addon references:

```hcl
# Required from shared infrastructure
data.terraform_remote_state.shared.outputs.vpc_id
data.terraform_remote_state.shared.outputs.private_subnet_ids
data.terraform_remote_state.shared.outputs.cache_subnet_ids      # Optional
data.terraform_remote_state.shared.outputs.cache_security_group_id  # Optional
```

## Outputs

Key outputs for application integration:

```hcl
# Standard mode connection
output "primary_endpoint" {
  value = module.redis_cache.primary_endpoint_address
}

# Cluster mode connection
output "configuration_endpoint" {
  value = module.redis_cache.configuration_endpoint_address
}

# Auth token
output "auth_token_secret_arn" {
  value = module.redis_cache.auth_token_secret_arn
}

# Connection information
output "connection_info" {
  value = module.redis_cache.connection_info
}
```

## Security Features

### Authentication
- **Auth Tokens**: Automatically generated and stored in Secrets Manager
- **Token Rotation**: Supports manual token rotation
- **No Default Access**: Auth required by default

### Encryption
- **At Rest**: KMS encryption for stored data
- **In Transit**: TLS encryption for client connections
- **Custom KMS Keys**: Option to use existing or create new KMS keys

### Network Security
- **VPC Isolation**: Deployed in private subnets
- **Security Groups**: Minimal access rules
- **CIDR Restrictions**: Configurable allowed networks

## Monitoring and Alerting

### CloudWatch Alarms
- **CPU Utilization**: Monitors compute usage
- **Memory Utilization**: Tracks memory consumption
- **Connection Count**: Monitors active connections
- **Evictions**: Alerts on memory pressure

### Log Delivery
- **Slow Log**: Query performance monitoring
- **CloudWatch Integration**: Centralized log management
- **Custom Destinations**: Support for external log systems

### Metrics
- **Performance Insights**: Built-in Redis metrics
- **Custom Metrics**: Application-specific monitoring
- **Dashboard Integration**: CloudWatch dashboard support

## Backup and Recovery

### Automated Snapshots
- **Configurable Retention**: 1-35 days retention
- **Backup Window**: Non-peak hours scheduling
- **Cross-AZ Backup**: Multi-AZ snapshot storage

### Point-in-Time Recovery
- **Snapshot Restoration**: Full cluster restoration
- **Backup Validation**: Automated backup testing
- **Disaster Recovery**: Cross-region backup support

## High Availability

### Multi-AZ Deployment
- **Automatic Failover**: Sub-minute failover times
- **Read Replicas**: Load distribution across AZs
- **Zero-Downtime Updates**: Rolling updates for maintenance

### Cluster Mode Benefits
- **Horizontal Scaling**: Multiple shards for performance
- **Data Distribution**: Automatic sharding across nodes
- **Fault Tolerance**: Individual shard failure isolation

## Performance Optimization

### Node Types
- **Memory Optimized**: R6g instances for large datasets
- **Burstable Performance**: T3 instances for variable workloads
- **Network Optimized**: Enhanced networking for high throughput

### Configuration Tuning
- **Memory Policies**: Configurable eviction strategies
- **Connection Limits**: Optimized for concurrent access
- **Timeout Settings**: Application-specific tuning

## Operational Procedures

### Deployment

1. **Deploy shared infrastructure**
2. **Configure remote state**
3. **Deploy Redis addon**
4. **Retrieve auth token from Secrets Manager**

### Scaling

- **Vertical Scaling**: Change node types
- **Horizontal Scaling**: Add more shards (cluster mode)
- **Read Scaling**: Add replica nodes

### Maintenance

- **Automated Updates**: Engine version management
- **Maintenance Windows**: Scheduled during low-traffic
- **Rolling Updates**: Zero-downtime updates

### Monitoring

- **Real-time Metrics**: CloudWatch dashboards
- **Alerting**: SNS notification integration
- **Log Analysis**: Slow query identification

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
| `engine_version` | string | "7.0" | Redis engine version |
| `node_type` | string | "" | Node type (auto-selected by environment) |
| `cluster_mode_enabled` | bool | null | Enable cluster mode (auto-configured) |
| `auth_token_enabled` | bool | true | Enable auth token |
| `encryption_at_rest_enabled` | bool | true | Enable at-rest encryption |
| `encryption_in_transit_enabled` | bool | true | Enable in-transit encryption |

See `variables.tf` for complete variable documentation.

## Outputs Reference

### Connection Information

| Output | Description |
|--------|-------------|
| `primary_endpoint_address` | Primary endpoint (standard mode) |
| `configuration_endpoint_address` | Configuration endpoint (cluster mode) |
| `auth_token_secret_arn` | Secrets Manager ARN for auth token |
| `connection_string` | Complete connection string |

### Configuration Information

| Output | Description |
|--------|-------------|
| `cluster_mode_enabled` | Whether cluster mode is active |
| `num_cache_clusters` | Number of cache clusters |
| `encryption_at_rest_enabled` | Encryption status |

See `outputs.tf` for complete output documentation.

## Application Integration Examples

### Node.js with Redis Client

```javascript
const redis = require('redis');
const AWS = require('aws-sdk');

// Get auth token from Secrets Manager
const secretsManager = new AWS.SecretsManager({region: 'ap-northeast-2'});
const secret = await secretsManager.getSecretValue({SecretId: 'myapp-prod-redis-auth-token'}).promise();
const authInfo = JSON.parse(secret.SecretString);

// Connect to Redis
const client = redis.createClient({
  host: authInfo.endpoint,
  port: 6379,
  password: authInfo.auth_token,
  tls: true // for encryption in transit
});
```

### Python with Redis-py

```python
import redis
import boto3
import json

# Get auth token
secrets_client = boto3.client('secretsmanager', region_name='ap-northeast-2')
secret_value = secrets_client.get_secret_value(SecretId='myapp-prod-redis-auth-token')
auth_info = json.loads(secret_value['SecretString'])

# Connect to Redis
r = redis.Redis(
    host=auth_info['endpoint'],
    port=6379,
    password=auth_info['auth_token'],
    ssl=True,
    decode_responses=True
)
```

### Java with Jedis

```java
import redis.clients.jedis.Jedis;
import redis.clients.jedis.JedisPool;
import redis.clients.jedis.JedisPoolConfig;

// Configure SSL connection
JedisPoolConfig poolConfig = new JedisPoolConfig();
JedisPool pool = new JedisPool(poolConfig, endpoint, 6379, 2000, authToken, true);

try (Jedis jedis = pool.getResource()) {
    jedis.set("key", "value");
    String value = jedis.get("key");
}
```

## Best Practices

### Security
- Always enable auth tokens for production
- Use encryption in transit and at rest
- Limit CIDR blocks to minimum required
- Regularly rotate auth tokens

### Performance
- Use cluster mode for high-throughput workloads
- Monitor memory usage and configure appropriate eviction policies
- Implement connection pooling in applications
- Use appropriate node types for workload characteristics

### Cost Optimization
- Use T3 instances for development and variable workloads
- Implement appropriate snapshot retention policies
- Monitor unused capacity and right-size nodes
- Consider reserved instances for production workloads

## Version History

- **v1.0.0**: Initial release with cluster mode support

## Support

For issues and questions:
- Check the [troubleshooting guide](../../../docs/troubleshooting.md)
- Review [Redis best practices](../../../docs/redis-best-practices.md)
- Open an issue in the project repository