# ECS Service Addon v1.0.0

A reusable ECS service addon for the StackKit composition system that provides production-ready containerized services with minimal configuration.

## Overview

This addon creates a complete ECS service with the following features:

- **Flexible Service Types**: Support for both API services (with ALB integration) and worker services
- **Shared Infrastructure Integration**: Seamlessly integrates with connectly-shared-infrastructure
- **Environment-Specific Scaling**: Different resource allocation for dev/staging/prod
- **Auto Scaling**: CPU and memory-based auto scaling with configurable targets
- **Security**: Proper IAM roles with least privilege principles
- **Observability**: CloudWatch logging and optional metrics
- **Health Checks**: Container and ALB health checks for API services
- **Service Discovery**: Optional service discovery integration
- **Zero-Downtime Deployments**: Rolling deployment strategy

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Shared VPC    │    │  Shared Cluster │    │  Shared ALB     │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │   Subnets   │◄┼────┼►│ ECS Service │◄┼────┼►│Target Groups│ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                        ┌─────────────────┐
                        │  CloudWatch     │
                        │  Logs & Metrics │
                        └─────────────────┘
```

## Prerequisites

1. **Shared Infrastructure**: Deploy connectly-shared-infrastructure first
2. **Container Image**: Your application container image in ECR or DockerHub
3. **Remote State**: S3 backend configured for accessing shared infrastructure state

## Quick Start

### 1. Add Addon to Your Project

```bash
# Using StackKit v2 CLI (when available)
./tools/stackkit-v2-cli.sh addon add compute/ecs --name my-api

# Or manually copy the addon
cp -r /path/to/stackkit/addons/compute/ecs ./infrastructure/addons/
```

### 2. Basic API Service Configuration

```hcl
# main.tf
module "api_service" {
  source = "./addons/compute/ecs"

  # Core Configuration
  project_name = "my-project"
  environment  = "dev"
  service_name = "api"
  service_type = "api"

  # Container Configuration
  container_image = "my-account.dkr.ecr.ap-northeast-2.amazonaws.com/my-api:latest"
  container_port  = 8080

  # Shared Infrastructure
  shared_state_bucket = "my-terraform-state-bucket"
  shared_state_key    = "shared/terraform.tfstate"

  # ALB Integration
  alb_listener_rule_priority = 100
  alb_listener_rule_conditions = [
    {
      path_pattern = {
        values = ["/api/*"]
      }
    }
  ]

  # Environment Variables
  environment_variables = {
    NODE_ENV = "development"
    PORT     = "8080"
  }

  tags = {
    Team        = "backend"
    Project     = "my-project"
    Environment = "dev"
  }
}
```

### 3. Worker Service Configuration

```hcl
module "worker_service" {
  source = "./addons/compute/ecs"

  # Core Configuration
  project_name = "my-project"
  environment  = "prod"
  service_name = "worker"
  service_type = "worker"

  # Container Configuration
  container_image = "my-account.dkr.ecr.ap-northeast-2.amazonaws.com/my-worker:latest"

  # Shared Infrastructure
  shared_state_bucket = "my-terraform-state-bucket"
  shared_state_key    = "shared/terraform.tfstate"

  # No ALB needed for workers
  enable_alb = false

  # Custom environment configuration
  environment_config = {
    prod = {
      cpu               = "2048"
      memory            = "4096"
      container_cpu     = 2048
      container_memory  = 4096
      desired_count     = 5
      min_capacity      = 3
      max_capacity      = 20
    }
  }

  tags = {
    Team        = "data"
    Project     = "my-project"
    Environment = "prod"
  }
}
```

## Configuration Reference

### Core Variables

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `project_name` | Name of the project | `string` | - | ✅ |
| `environment` | Environment (dev/staging/prod) | `string` | - | ✅ |
| `service_name` | Name of the ECS service | `string` | - | ✅ |
| `service_type` | Service type (api/worker) | `string` | `"api"` | - |
| `container_image` | Docker image URI | `string` | - | ✅ |
| `container_port` | Container port | `number` | `8080` | - |

### Environment-Specific Configuration

The addon includes built-in environment-specific resource allocation:

```hcl
# Default environment_config
{
  dev = {
    cpu               = "256"     # 0.25 vCPU
    memory            = "512"     # 512 MB
    container_cpu     = 256
    container_memory  = 512
    desired_count     = 1
    min_capacity      = 1
    max_capacity      = 2
  }
  staging = {
    cpu               = "512"     # 0.5 vCPU
    memory            = "1024"    # 1 GB
    container_cpu     = 512
    container_memory  = 1024
    desired_count     = 2
    min_capacity      = 1
    max_capacity      = 4
  }
  prod = {
    cpu               = "1024"    # 1 vCPU
    memory            = "2048"    # 2 GB
    container_cpu     = 1024
    container_memory  = 2048
    desired_count     = 3
    min_capacity      = 2
    max_capacity      = 10
  }
}
```

### Shared Infrastructure Integration

| Variable | Description | Default |
|----------|-------------|---------|
| `use_shared_infrastructure` | Use shared VPC, subnets, etc. | `true` |
| `shared_state_bucket` | S3 bucket for shared state | `""` |
| `shared_state_key` | S3 key for shared state | `"shared/terraform.tfstate"` |
| `use_shared_cluster` | Use shared ECS cluster | `true` |

### ALB Configuration (API Services)

| Variable | Description | Default |
|----------|-------------|---------|
| `enable_alb` | Enable ALB integration | `true` |
| `alb_listener_rule_priority` | ALB rule priority | `100` |
| `alb_listener_rule_conditions` | ALB routing conditions | `[]` |
| `alb_health_check_path` | Health check path | `"/health"` |

### Auto Scaling Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `enable_autoscaling` | Enable auto scaling | `true` |
| `autoscaling_cpu_target` | CPU target percentage | `70` |
| `autoscaling_memory_target` | Memory target percentage | `80` |
| `autoscaling_scale_in_cooldown` | Scale in cooldown (seconds) | `300` |
| `autoscaling_scale_out_cooldown` | Scale out cooldown (seconds) | `300` |

## Advanced Usage

### Custom IAM Policies

```hcl
module "api_service" {
  source = "./addons/compute/ecs"
  # ... other config

  # Custom task role policies
  task_role_policies = {
    s3_access = {
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = ["s3:GetObject", "s3:PutObject"]
          Resource = "arn:aws:s3:::my-bucket/*"
        }
      ]
    }
  }

  # Managed policies
  task_role_managed_policies = [
    "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
  ]

  # S3 bucket access (simplified)
  s3_bucket_arns = [
    "arn:aws:s3:::my-app-bucket"
  ]
}
```

### Secrets Management

```hcl
module "api_service" {
  source = "./addons/compute/ecs"
  # ... other config

  # Environment variables
  environment_variables = {
    NODE_ENV = "production"
    PORT     = "8080"
  }

  # Secrets from Parameter Store or Secrets Manager
  secrets = {
    DATABASE_URL = "arn:aws:ssm:ap-northeast-2:123456789012:parameter/my-app/database-url"
    API_KEY      = "arn:aws:secretsmanager:ap-northeast-2:123456789012:secret:my-app/api-key"
  }
}
```

### EFS Volume Mounting

```hcl
module "api_service" {
  source = "./addons/compute/ecs"
  # ... other config

  volumes = [
    {
      name = "shared-storage"
      efs_volume_configuration = {
        file_system_id     = "fs-12345678"
        root_directory     = "/app/shared"
        transit_encryption = "ENABLED"
      }
    }
  ]
}
```

### Custom Health Checks

```hcl
module "api_service" {
  source = "./addons/compute/ecs"
  # ... other config

  # Container health check
  health_check_command      = "curl -f http://localhost:8080/api/health || exit 1"
  health_check_interval     = 30
  health_check_timeout      = 5
  health_check_retries      = 3
  health_check_start_period = 60

  # ALB health check
  alb_health_check_path                = "/api/health"
  alb_health_check_matcher             = "200,201"
  alb_health_check_healthy_threshold   = 2
  alb_health_check_unhealthy_threshold = 3
}
```

### Service Discovery

```hcl
module "api_service" {
  source = "./addons/compute/ecs"
  # ... other config

  enable_service_discovery = true
  # Uses shared infrastructure's service discovery namespace by default
}
```

## Outputs

The addon provides comprehensive outputs for integration with other resources:

### Service Information
- `service_name` - ECS service name
- `service_arn` - ECS service ARN
- `task_definition_arn` - Task definition ARN

### Network Information
- `security_group_id` - Service security group ID
- `target_group_arn` - ALB target group ARN (API services)
- `service_url` - Service URL (API services with ALB)

### IAM Information
- `execution_role_arn` - ECS execution role ARN
- `task_role_arn` - ECS task role ARN

### Monitoring Information
- `log_group_name` - CloudWatch log group name
- `log_group_arn` - CloudWatch log group ARN

## Best Practices

### 1. Resource Naming
- Use consistent naming: `${project_name}-${environment}-${service_name}`
- Keep service names short but descriptive
- Use kebab-case for multi-word names

### 2. Environment Configuration
- Start with default environment configs
- Override only when necessary for specific requirements
- Consider cost implications of resource sizing

### 3. Security
- Use secrets for sensitive data, never environment variables
- Grant minimal required permissions through IAM policies
- Enable execute command only for debugging (not production)

### 4. Monitoring
- Always include health checks for API services
- Set appropriate log retention periods
- Use CloudWatch metrics for monitoring

### 5. Deployment
- Use container image tags for version control
- Test in dev/staging before production deployment
- Monitor deployment health during rollouts

## Troubleshooting

### Common Issues

#### Service Won't Start
```bash
# Check CloudWatch logs
aws logs get-log-events \
  --log-group-name "/ecs/my-project/dev/api" \
  --log-stream-name "ecs/api/task-id"

# Check ECS service events
aws ecs describe-services \
  --cluster shared-cluster \
  --services my-project-dev-api
```

#### ALB Health Checks Failing
1. Verify health check path exists in your application
2. Check security group allows ALB → ECS communication
3. Verify container port configuration
4. Check application startup time vs. health check grace period

#### Auto Scaling Not Working
1. Verify CloudWatch metrics are being published
2. Check auto scaling policies and thresholds
3. Ensure sufficient capacity in target groups

### Debugging Commands

```bash
# Connect to running container (if execute command enabled)
aws ecs execute-command \
  --cluster shared-cluster \
  --task task-id \
  --container api \
  --interactive \
  --command "/bin/bash"

# View service metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=my-project-dev-api \
  --start-time 2023-01-01T00:00:00Z \
  --end-time 2023-01-01T23:59:59Z \
  --period 300 \
  --statistics Average
```

## Version History

### v1.0.0
- Initial release
- Support for API and worker services
- Shared infrastructure integration
- Environment-specific configuration
- Auto scaling capabilities
- ALB integration for API services
- CloudWatch logging
- Service discovery support

## Contributing

1. Follow existing code patterns and conventions
2. Update documentation for any new features
3. Test with multiple environment configurations
4. Ensure backward compatibility when possible

## License

This addon is part of the StackKit framework and follows the same licensing terms.