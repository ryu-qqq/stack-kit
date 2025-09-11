# ECS Module

A comprehensive Terraform module for deploying and managing Amazon Elastic Container Service (ECS) clusters, services, and related resources on AWS.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Usage](#usage)
  - [Basic Example](#basic-example)
  - [Advanced Example](#advanced-example)
- [Variables](#variables)
- [Outputs](#outputs)
- [Dependencies](#dependencies)
- [Requirements](#requirements)
- [Best Practices](#best-practices)
- [Common Use Cases](#common-use-cases)
- [Troubleshooting](#troubleshooting)

## Overview

This module provides a complete solution for running containerized applications on AWS ECS. It creates and manages:

- ECS Cluster with configurable capacity providers
- Task definitions with flexible container configurations
- ECS services with auto-scaling capabilities
- Security groups with customizable rules
- IAM roles and policies for task execution and application permissions
- Integration with Application Load Balancers and Service Discovery

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          VPC                                    │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    ECS Cluster                           │   │
│  │                                                          │   │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │   │
│  │  │   Service   │    │   Service   │    │   Service   │  │   │
│  │  │             │    │             │    │             │  │   │
│  │  │ ┌─────────┐ │    │ ┌─────────┐ │    │ ┌─────────┐ │  │   │
│  │  │ │  Task   │ │    │ │  Task   │ │    │ │  Task   │ │  │   │
│  │  │ │Container│ │    │ │Container│ │    │ │Container│ │  │   │
│  │  │ └─────────┘ │    │ └─────────┘ │    │ └─────────┘ │  │   │
│  │  └─────────────┘    └─────────────┘    └─────────────┘  │   │
│  │                                                          │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────┐    ┌──────────────────────────────────┐    │
│  │ Application     │    │          Security Group          │    │
│  │ Load Balancer   │◄───┤         (ECS Tasks)             │    │
│  └─────────────────┘    └──────────────────────────────────┘    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        IAM Roles                                │
│  ┌─────────────────────┐    ┌─────────────────────────────────┐ │
│  │  Execution Role     │    │        Task Role                │ │
│  │  - ECR Access       │    │  - Application Permissions     │ │
│  │  - CloudWatch Logs  │    │  - AWS Service Access          │ │
│  │  - Parameter Store  │    │  - Custom Policies             │ │
│  │  - Secrets Manager  │    │                                 │ │
│  └─────────────────────┘    └─────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                     Auto Scaling                                │
│                                                                 │
│  CPU Utilization ──┐                                           │
│                    ├─► Target Tracking ──► Scale Tasks         │
│  Memory Utilization┘                                           │
└─────────────────────────────────────────────────────────────────┘
```

## Features

### Core ECS Components
- **ECS Cluster**: Configurable with FARGATE, FARGATE_SPOT, or EC2 capacity providers
- **Task Definitions**: Support for multiple container configurations with volumes
- **Services**: Managed service deployment with health checks and rolling updates
- **Security Groups**: Customizable ingress/egress rules for network security

### Advanced Capabilities
- **Auto Scaling**: CPU and memory-based scaling with configurable targets
- **Load Balancer Integration**: Support for Application Load Balancer target groups
- **Service Discovery**: Integration with AWS Cloud Map for service discovery
- **Container Insights**: CloudWatch Container Insights for monitoring
- **EFS Support**: Elastic File System volume mounting capabilities
- **Execute Command**: AWS ECS Exec for container debugging

### IAM & Security
- **Execution Role**: Pre-configured with ECR, CloudWatch, Parameter Store, and Secrets Manager access
- **Task Role**: Customizable application-specific permissions
- **Security Groups**: Least-privilege network access controls
- **Secrets Management**: Integration with AWS Secrets Manager and Parameter Store

## Usage

### Basic Example

```hcl
module "ecs" {
  source = "path/to/modules/compute/ecs"

  # Required variables
  project_name = "my-app"
  environment  = "production"
  cluster_name = "web-cluster"
  vpc_id       = "vpc-12345678"
  subnet_ids   = ["subnet-12345678", "subnet-87654321"]

  # Container configuration
  container_definitions = [
    {
      name  = "web-app"
      image = "nginx:latest"
      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/my-app-production"
          "awslogs-region"        = "us-west-2"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ]

  # Security group rules
  security_group_rules = [
    {
      description = "HTTP access from ALB"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
    }
  ]

  common_tags = {
    Environment = "production"
    Project     = "my-app"
    Owner       = "devops-team"
  }
}
```

### Advanced Example

```hcl
module "ecs" {
  source = "path/to/modules/compute/ecs"

  # Basic configuration
  project_name = "microservices"
  environment  = "production"
  cluster_name = "api-cluster"
  vpc_id       = data.aws_vpc.main.id
  subnet_ids   = data.aws_subnets.private.ids

  # Cluster configuration
  enable_container_insights = true
  capacity_providers        = ["FARGATE", "FARGATE_SPOT"]
  
  default_capacity_provider_strategy = [
    {
      capacity_provider = "FARGATE"
      weight           = 1
      base             = 2
    },
    {
      capacity_provider = "FARGATE_SPOT"
      weight           = 2
      base             = 0
    }
  ]

  # Task configuration
  service_name              = "user-service"
  task_cpu                  = "512"
  task_memory               = "1024"
  requires_compatibilities  = ["FARGATE"]
  network_mode             = "awsvpc"

  # Service configuration
  desired_count     = 3
  assign_public_ip  = false
  launch_type       = "FARGATE"

  # Container definitions with multiple containers
  container_definitions = [
    {
      name      = "user-api"
      image     = "my-account.dkr.ecr.us-west-2.amazonaws.com/user-api:latest"
      cpu       = 256
      memory    = 512
      essential = true
      
      portMappings = [
        {
          containerPort = 3000
          protocol      = "tcp"
        }
      ]
      
      environment = [
        {
          name  = "NODE_ENV"
          value = "production"
        }
      ]
      
      secrets = [
        {
          name      = "DATABASE_URL"
          valueFrom = "arn:aws:secretsmanager:us-west-2:123456789:secret:prod/database-url"
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/microservices-production-user-api"
          "awslogs-region"        = "us-west-2"
          "awslogs-stream-prefix" = "ecs"
        }
      }
      
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    },
    {
      name      = "sidecar-proxy"
      image     = "envoyproxy/envoy:v1.18.3"
      cpu       = 128
      memory    = 256
      essential = false
      
      portMappings = [
        {
          containerPort = 9901
          protocol      = "tcp"
        }
      ]
    }
  ]

  # EFS Volume configuration
  volumes = [
    {
      name = "shared-data"
      efs_volume_configuration = {
        file_system_id = aws_efs_file_system.shared.id
        root_directory = "/app/data"
        transit_encryption = "ENABLED"
        authorization_config = {
          access_point_id = aws_efs_access_point.app.id
          iam            = "ENABLED"
        }
      }
    }
  ]

  # Load balancer integration
  load_balancer_config = [
    {
      target_group_arn = aws_lb_target_group.user_api.arn
      container_name   = "user-api"
      container_port   = 3000
    }
  ]

  # Service discovery
  service_discovery_config = {
    registry_arn   = aws_service_discovery_service.user_api.arn
    container_name = "user-api"
    container_port = 3000
  }

  # Auto scaling configuration
  enable_autoscaling        = true
  autoscaling_min_capacity  = 2
  autoscaling_max_capacity  = 20
  autoscaling_cpu_target    = 70
  autoscaling_memory_target = 80

  # Enhanced security
  security_group_rules = [
    {
      description     = "HTTP access from ALB"
      from_port       = 3000
      to_port         = 3000
      protocol        = "tcp"
      security_groups = [aws_security_group.alb.id]
    },
    {
      description     = "Envoy admin"
      from_port       = 9901
      to_port         = 9901
      protocol        = "tcp"
      security_groups = [aws_security_group.monitoring.id]
    }
  ]

  # Custom task role permissions
  task_role_policies = [
    {
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject"
      ]
      Resource = [
        "${aws_s3_bucket.app_data.arn}/*"
      ]
    }
  ]

  task_role_managed_policies = [
    "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  ]

  # Enable ECS Exec for debugging
  enable_execute_command = true

  common_tags = {
    Environment = "production"
    Service     = "user-service"
    Team        = "backend"
    CostCenter  = "engineering"
  }
}
```

## Variables

### Required Variables

| Name | Description | Type |
|------|-------------|------|
| `project_name` | Name of the project | `string` |
| `environment` | Environment name (e.g., dev, staging, prod) | `string` |
| `cluster_name` | Name of the ECS cluster | `string` |
| `vpc_id` | ID of the VPC where resources will be created | `string` |
| `subnet_ids` | List of subnet IDs for ECS service | `list(string)` |

### Optional Variables

#### Cluster Configuration
| Name | Description | Type | Default |
|------|-------------|------|---------|
| `enable_container_insights` | Enable CloudWatch Container Insights | `bool` | `true` |
| `capacity_providers` | List of capacity providers | `list(string)` | `["FARGATE", "FARGATE_SPOT"]` |
| `default_capacity_provider_strategy` | Default capacity provider strategy | `list(object)` | See example |

#### Task Definition
| Name | Description | Type | Default |
|------|-------------|------|---------|
| `create_task_definition` | Whether to create a task definition | `bool` | `true` |
| `service_name` | Name of the ECS service | `string` | `"app"` |
| `requires_compatibilities` | Set of launch types required by the task | `list(string)` | `["FARGATE"]` |
| `network_mode` | Docker networking mode | `string` | `"awsvpc"` |
| `task_cpu` | Number of CPU units used by the task | `string` | `"256"` |
| `task_memory` | Amount of memory used by the task (MiB) | `string` | `"512"` |
| `container_definitions` | Container definitions for the task | `any` | `[]` |
| `volumes` | Volume definitions for the task | `list(object)` | `[]` |

#### Service Configuration
| Name | Description | Type | Default |
|------|-------------|------|---------|
| `create_service` | Whether to create an ECS service | `bool` | `true` |
| `desired_count` | Number of task instances to run | `number` | `1` |
| `launch_type` | Launch type for the service | `string` | `"FARGATE"` |
| `capacity_provider_strategy` | Capacity provider strategy for service | `list(object)` | `[]` |
| `assign_public_ip` | Assign public IP to ENI | `bool` | `false` |
| `load_balancer_config` | Load balancer configuration | `list(object)` | `[]` |
| `service_discovery_config` | Service discovery configuration | `object` | `null` |
| `enable_execute_command` | Enable ECS Exec functionality | `bool` | `false` |

#### Auto Scaling
| Name | Description | Type | Default |
|------|-------------|------|---------|
| `enable_autoscaling` | Enable auto scaling for ECS service | `bool` | `false` |
| `autoscaling_min_capacity` | Minimum number of tasks | `number` | `1` |
| `autoscaling_max_capacity` | Maximum number of tasks | `number` | `10` |
| `autoscaling_cpu_target` | Target CPU utilization percentage | `number` | `70` |
| `autoscaling_memory_target` | Target memory utilization percentage | `number` | `80` |

#### Security & IAM
| Name | Description | Type | Default |
|------|-------------|------|---------|
| `security_group_rules` | Security group rules for ECS tasks | `list(object)` | `[]` |
| `task_role_policies` | Additional IAM policies for task role | `list(any)` | `[]` |
| `task_role_managed_policies` | IAM managed policy ARNs for task role | `list(string)` | `[]` |
| `common_tags` | Common tags to apply to all resources | `map(string)` | `{}` |

## Outputs

### Cluster Outputs
| Name | Description |
|------|-------------|
| `cluster_id` | ID of the ECS cluster |
| `cluster_name` | Name of the ECS cluster |
| `cluster_arn` | ARN of the ECS cluster |

### Task Definition Outputs
| Name | Description |
|------|-------------|
| `task_definition_arn` | ARN of the task definition |
| `task_definition_family` | Family of the task definition |
| `task_definition_revision` | Revision of the task definition |

### Service Outputs
| Name | Description |
|------|-------------|
| `service_id` | ID of the ECS service |
| `service_name` | Name of the ECS service |
| `service_arn` | ARN of the ECS service |

### Security Outputs
| Name | Description |
|------|-------------|
| `security_group_id` | ID of the ECS tasks security group |
| `security_group_arn` | ARN of the ECS tasks security group |

### IAM Outputs
| Name | Description |
|------|-------------|
| `execution_role_arn` | ARN of the ECS task execution role |
| `task_role_arn` | ARN of the ECS task role |
| `execution_role_name` | Name of the ECS task execution role |
| `task_role_name` | Name of the ECS task role |

## Dependencies

This module requires the following AWS resources to be available:

### Required Dependencies
- **VPC**: Virtual Private Cloud with subnets
- **Subnets**: Private or public subnets for task placement
- **Container Registry**: ECR repositories for container images

### Optional Dependencies
- **Application Load Balancer**: For HTTP/HTTPS traffic distribution
- **Target Groups**: For load balancer integration
- **Service Discovery**: AWS Cloud Map namespace and service
- **EFS File System**: For persistent storage needs
- **Secrets Manager**: For secure credential storage
- **Parameter Store**: For configuration management

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 0.14 |
| aws | >= 3.0 |

### Provider Configuration
```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

## Best Practices

### Security Best Practices

1. **Network Security**
   ```hcl
   # Use private subnets for ECS tasks
   subnet_ids = data.aws_subnets.private.ids
   
   # Restrict security group rules to minimum required access
   security_group_rules = [
     {
       description     = "HTTP from ALB only"
       from_port       = 80
       to_port         = 80
       protocol        = "tcp"
       security_groups = [aws_security_group.alb.id]  # Not 0.0.0.0/0
     }
   ]
   ```

2. **IAM Least Privilege**
   ```hcl
   # Only grant permissions your application actually needs
   task_role_policies = [
     {
       Effect = "Allow"
       Action = ["s3:GetObject"]  # Specific actions
       Resource = ["arn:aws:s3:::my-bucket/*"]  # Specific resources
     }
   ]
   ```

3. **Secrets Management**
   ```hcl
   # Use Secrets Manager or Parameter Store instead of environment variables
   container_definitions = [
     {
       secrets = [
         {
           name      = "DATABASE_PASSWORD"
           valueFrom = "arn:aws:secretsmanager:region:account:secret:db-password"
         }
       ]
     }
   ]
   ```

### Performance Best Practices

1. **Resource Sizing**
   ```hcl
   # Start with appropriate CPU/memory sizing
   task_cpu    = "512"   # 0.5 vCPU
   task_memory = "1024"  # 1 GB
   
   # Use CPU/memory reservations in container definitions
   container_definitions = [
     {
       cpu          = 256    # Reserve 50% of task CPU
       memoryReservation = 512  # Soft limit
       memory       = 1024   # Hard limit
     }
   ]
   ```

2. **Auto Scaling Configuration**
   ```hcl
   enable_autoscaling        = true
   autoscaling_cpu_target    = 70   # Conservative CPU target
   autoscaling_memory_target = 80   # Conservative memory target
   autoscaling_min_capacity  = 2    # Always have minimum capacity
   ```

3. **Health Checks**
   ```hcl
   container_definitions = [
     {
       healthCheck = {
         command     = ["CMD-SHELL", "curl -f http://localhost:3000/health"]
         interval    = 30
         timeout     = 5
         retries     = 3
         startPeriod = 60  # Allow time for application startup
       }
     }
   ]
   ```

### Cost Optimization

1. **Use Spot Capacity**
   ```hcl
   capacity_providers = ["FARGATE", "FARGATE_SPOT"]
   
   default_capacity_provider_strategy = [
     {
       capacity_provider = "FARGATE_SPOT"
       weight           = 2
     },
     {
       capacity_provider = "FARGATE"
       weight           = 1
       base             = 1  # Always have one on-demand task
     }
   ]
   ```

2. **Right-size Resources**
   ```hcl
   # Monitor and adjust based on actual usage
   task_cpu    = "256"   # Start small
   task_memory = "512"   # Scale up as needed
   ```

### Monitoring and Logging

1. **Container Insights**
   ```hcl
   enable_container_insights = true
   ```

2. **Structured Logging**
   ```hcl
   container_definitions = [
     {
       logConfiguration = {
         logDriver = "awslogs"
         options = {
           "awslogs-group"         = "/ecs/${var.project_name}-${var.environment}"
           "awslogs-region"        = data.aws_region.current.name
           "awslogs-stream-prefix" = "ecs"
         }
       }
     }
   ]
   ```

## Common Use Cases

### 1. Web Application with Load Balancer

```hcl
module "web_app" {
  source = "./modules/compute/ecs"
  
  project_name = "webapp"
  environment  = "prod"
  cluster_name = "web"
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnet_ids
  
  container_definitions = [
    {
      name  = "web"
      image = "nginx:latest"
      portMappings = [{
        containerPort = 80
        protocol      = "tcp"
      }]
    }
  ]
  
  load_balancer_config = [
    {
      target_group_arn = aws_lb_target_group.web.arn
      container_name   = "web"
      container_port   = 80
    }
  ]
  
  enable_autoscaling       = true
  autoscaling_min_capacity = 2
  autoscaling_max_capacity = 10
}
```

### 2. Microservice with Service Discovery

```hcl
module "user_service" {
  source = "./modules/compute/ecs"
  
  project_name = "microservices"
  environment  = "prod"
  cluster_name = "services"
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnet_ids
  
  service_name = "user-service"
  
  container_definitions = [
    {
      name  = "user-api"
      image = "my-repo/user-service:latest"
      portMappings = [{
        containerPort = 3000
        protocol      = "tcp"
      }]
    }
  ]
  
  service_discovery_config = {
    registry_arn = aws_service_discovery_service.users.arn
  }
  
  task_role_policies = [
    {
      Effect = "Allow"
      Action = ["dynamodb:*"]
      Resource = [aws_dynamodb_table.users.arn]
    }
  ]
}
```

### 3. Background Job Processor

```hcl
module "job_processor" {
  source = "./modules/compute/ecs"
  
  project_name = "analytics"
  environment  = "prod"
  cluster_name = "workers"
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnet_ids
  
  service_name = "job-processor"
  
  # No load balancer needed for background jobs
  create_service = true
  desired_count  = 3
  
  container_definitions = [
    {
      name  = "worker"
      image = "my-repo/job-processor:latest"
      environment = [
        {
          name  = "QUEUE_URL"
          value = aws_sqs_queue.jobs.url
        }
      ]
    }
  ]
  
  task_role_policies = [
    {
      Effect = "Allow"
      Action = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ]
      Resource = [aws_sqs_queue.jobs.arn]
    }
  ]
  
  enable_autoscaling        = true
  autoscaling_min_capacity  = 1
  autoscaling_max_capacity  = 20
  autoscaling_cpu_target    = 60  # Scale up earlier for job processing
}
```

### 4. Multi-Container Application with Shared Storage

```hcl
module "app_with_proxy" {
  source = "./modules/compute/ecs"
  
  project_name = "enterprise-app"
  environment  = "prod"
  cluster_name = "main"
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnet_ids
  
  task_cpu    = "1024"
  task_memory = "2048"
  
  container_definitions = [
    {
      name      = "app"
      image     = "my-repo/app:latest"
      cpu       = 512
      memory    = 1024
      essential = true
      portMappings = [{
        containerPort = 3000
        protocol      = "tcp"
      }]
      mountPoints = [{
        sourceVolume  = "shared-data"
        containerPath = "/app/data"
        readOnly     = false
      }]
    },
    {
      name      = "nginx"
      image     = "nginx:latest"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [{
        containerPort = 80
        protocol      = "tcp"
      }]
    }
  ]
  
  volumes = [
    {
      name = "shared-data"
      efs_volume_configuration = {
        file_system_id = aws_efs_file_system.app_data.id
      }
    }
  ]
  
  load_balancer_config = [
    {
      target_group_arn = aws_lb_target_group.app.arn
      container_name   = "nginx"
      container_port   = 80
    }
  ]
}
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Service Fails to Start

**Symptoms:**
- Tasks keep stopping and restarting
- Service never reaches desired count

**Possible Causes & Solutions:**

```bash
# Check service events
aws ecs describe-services --cluster <cluster-name> --services <service-name>

# Check task definition
aws ecs describe-task-definition --task-definition <family>:<revision>

# Check container logs
aws logs get-log-events --log-group-name /ecs/<log-group> --log-stream-name <stream>
```

**Common fixes:**
- Verify container image exists and is accessible
- Check IAM execution role has ECR permissions
- Ensure health check command is correct
- Verify CPU/memory limits are sufficient

#### 2. Load Balancer Health Checks Failing

**Symptoms:**
- Tasks running but marked unhealthy by ALB
- HTTP 502/503 errors

**Debug steps:**
```bash
# Check target group health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>

# Verify security group allows traffic from ALB
# Check container port mapping matches target group port
```

**Common fixes:**
- Update security group to allow ALB traffic
- Verify container health check endpoint
- Ensure port mapping is correct
- Check application startup time vs. health check grace period

#### 3. Auto Scaling Not Working

**Symptoms:**
- Tasks not scaling up under load
- CloudWatch alarms not triggering

**Debug steps:**
```bash
# Check auto scaling policies
aws application-autoscaling describe-scaling-policies --service-namespace ecs

# Check CloudWatch metrics
aws cloudwatch get-metric-statistics --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=<service> Name=ClusterName,Value=<cluster>
```

**Common fixes:**
- Verify Container Insights is enabled
- Check IAM permissions for auto scaling
- Ensure metrics are being published
- Verify scaling policy configuration

#### 4. Tasks Cannot Pull Container Images

**Symptoms:**
- Tasks fail with "CannotPullContainerError"

**Solutions:**
```hcl
# Ensure execution role has ECR permissions
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# For cross-account ECR access, add specific permissions
resource "aws_iam_role_policy" "cross_account_ecr" {
  name = "cross-account-ecr"
  role = aws_iam_role.ecs_execution_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ]
      Resource = "*"
    }]
  })
}
```

#### 5. Service Discovery Not Working

**Symptoms:**
- Services cannot resolve each other via DNS

**Debug steps:**
```bash
# Check service registry
aws servicediscovery list-services --filters Name=NAMESPACE_ID,Values=<namespace-id>

# Verify DNS resolution from within container
aws ecs execute-command --cluster <cluster> --task <task-id> --container <container> \
  --command "nslookup service-name.namespace.local"
```

**Common fixes:**
- Ensure service discovery is properly configured
- Verify namespace and service creation
- Check task role permissions for service discovery
- Confirm DNS resolution within VPC

### Monitoring and Debugging Commands

```bash
# Get service status
aws ecs describe-services --cluster <cluster> --services <service>

# List tasks
aws ecs list-tasks --cluster <cluster> --service-name <service>

# Describe task
aws ecs describe-tasks --cluster <cluster> --tasks <task-id>

# Get container logs
aws logs tail /ecs/<log-group> --follow

# Execute command in running container (if execute command is enabled)
aws ecs execute-command --cluster <cluster> --task <task-id> \
  --container <container> --interactive --command "/bin/bash"

# Check auto scaling activity
aws application-autoscaling describe-scaling-activities \
  --service-namespace ecs --resource-id service/<cluster>/<service>
```

### Performance Tuning

1. **CPU and Memory Optimization**
   - Monitor actual resource usage via Container Insights
   - Adjust task and container resource allocations
   - Consider using memory reservations vs hard limits

2. **Networking Performance**
   - Use placement groups for high-performance computing
   - Consider ENI trunking for network-intensive applications
   - Optimize security group rules

3. **Storage Performance**
   - Use provisioned IOPS for EBS volumes
   - Configure EFS performance mode appropriately
   - Consider container image optimization

### Cost Monitoring

```bash
# Check resource utilization
aws cloudwatch get-metric-statistics --namespace AWS/ECS \
  --metric-name CPUUtilization --start-time <start> --end-time <end>

# Monitor Fargate costs
aws ce get-cost-and-usage --time-period Start=<start>,End=<end> \
  --granularity MONTHLY --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE
```

---

## Support

For issues and feature requests, please:
1. Check the [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
2. Review CloudWatch logs and metrics
3. Check AWS service limits and quotas
4. Contact your DevOps team or infrastructure administrator

## Contributing

When contributing to this module:
1. Follow Terraform best practices
2. Update documentation for any variable changes
3. Test with multiple environments
4. Consider backward compatibility
5. Update examples if needed