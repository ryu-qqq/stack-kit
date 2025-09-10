# Environment Configuration Module for StackKit Infrastructure
# Centralizes environment-specific settings and provides standardized configuration
# across all infrastructure stacks and modules.

# ==============================================================================
# ENVIRONMENT CONFIGURATION DATA
# ==============================================================================

locals {
  # Environment-specific configurations
  environment_configs = {
    dev = {
      # Resource sizing
      instance_types = {
        small  = "t3.micro"
        medium = "t3.small" 
        large  = "t3.medium"
        xlarge = "t3.large"
      }
      
      # Database configurations
      database = {
        instance_class           = "db.t3.micro"
        allocated_storage       = 20
        backup_retention_period = 7
        multi_az               = false
        deletion_protection    = false
        skip_final_snapshot    = true
      }
      
      # Monitoring settings
      monitoring = {
        detailed_monitoring_enabled = false
        log_retention_days         = 7
        create_dashboards          = false
        alarm_evaluation_periods   = 3
        alarm_threshold_multiplier = 1.5
      }
      
      # Security settings
      security = {
        enable_encryption        = true
        force_ssl               = false
        enable_cloudtrail       = false
        vpc_enable_dns_hostnames = true
        vpc_enable_dns_support   = true
        enable_flow_logs        = false
      }
      
      # Cost optimization
      cost_optimization = {
        enable_spot_instances    = true
        enable_reserved_capacity = false
        auto_scaling_min_size    = 1
        auto_scaling_max_size    = 3
        auto_scaling_desired     = 1
      }
    }
    
    staging = {
      # Resource sizing
      instance_types = {
        small  = "t3.small"
        medium = "t3.medium"
        large  = "t3.large"
        xlarge = "t3.xlarge"
      }
      
      # Database configurations  
      database = {
        instance_class           = "db.t3.small"
        allocated_storage       = 50
        backup_retention_period = 14
        multi_az               = true
        deletion_protection    = true
        skip_final_snapshot    = false
      }
      
      # Monitoring settings
      monitoring = {
        detailed_monitoring_enabled = true
        log_retention_days         = 30
        create_dashboards          = true
        alarm_evaluation_periods   = 2
        alarm_threshold_multiplier = 1.2
      }
      
      # Security settings
      security = {
        enable_encryption        = true
        force_ssl               = true
        enable_cloudtrail       = true
        vpc_enable_dns_hostnames = true
        vpc_enable_dns_support   = true
        enable_flow_logs        = true
      }
      
      # Cost optimization
      cost_optimization = {
        enable_spot_instances    = false
        enable_reserved_capacity = true
        auto_scaling_min_size    = 2
        auto_scaling_max_size    = 6
        auto_scaling_desired     = 2
      }
    }
    
    prod = {
      # Resource sizing
      instance_types = {
        small  = "t3.medium"
        medium = "t3.large"
        large  = "t3.xlarge" 
        xlarge = "t3.2xlarge"
      }
      
      # Database configurations
      database = {
        instance_class           = "db.r5.large"
        allocated_storage       = 100
        backup_retention_period = 30
        multi_az               = true
        deletion_protection    = true
        skip_final_snapshot    = false
      }
      
      # Monitoring settings
      monitoring = {
        detailed_monitoring_enabled = true
        log_retention_days         = 90
        create_dashboards          = true
        alarm_evaluation_periods   = 2
        alarm_threshold_multiplier = 1.0
      }
      
      # Security settings
      security = {
        enable_encryption        = true
        force_ssl               = true
        enable_cloudtrail       = true
        vpc_enable_dns_hostnames = true
        vpc_enable_dns_support   = true
        enable_flow_logs        = true
      }
      
      # Cost optimization
      cost_optimization = {
        enable_spot_instances    = false
        enable_reserved_capacity = true
        auto_scaling_min_size    = 3
        auto_scaling_max_size    = 10
        auto_scaling_desired     = 3
      }
    }
  }
  
  # Network configurations per environment
  network_configs = {
    dev = {
      vpc_cidr             = "10.0.0.0/16"
      availability_zones   = 2
      public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
      private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
      database_subnet_cidrs = ["10.0.20.0/24", "10.0.21.0/24"]
      enable_nat_gateway   = false
      single_nat_gateway   = true
    }
    
    staging = {
      vpc_cidr             = "10.1.0.0/16"
      availability_zones   = 2
      public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
      private_subnet_cidrs = ["10.1.10.0/24", "10.1.11.0/24"]
      database_subnet_cidrs = ["10.1.20.0/24", "10.1.21.0/24"]
      enable_nat_gateway   = true
      single_nat_gateway   = true
    }
    
    prod = {
      vpc_cidr             = "10.2.0.0/16"
      availability_zones   = 3
      public_subnet_cidrs  = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
      private_subnet_cidrs = ["10.2.10.0/24", "10.2.11.0/24", "10.2.12.0/24"]
      database_subnet_cidrs = ["10.2.20.0/24", "10.2.21.0/24", "10.2.22.0/24"]
      enable_nat_gateway   = true
      single_nat_gateway   = false
    }
  }
  
  # Service-specific configurations
  service_configs = {
    dev = {
      # ECS configurations
      ecs = {
        cpu                = 256
        memory             = 512
        desired_count      = 1
        min_capacity       = 1
        max_capacity       = 3
        enable_auto_scaling = false
      }
      
      # Lambda configurations
      lambda = {
        timeout                = 30
        memory_size           = 128
        reserved_concurrency  = 10
        dead_letter_queue    = false
        enable_xray_tracing  = false
      }
      
      # Cache configurations
      cache = {
        node_type                 = "cache.t3.micro"
        num_cache_nodes          = 1
        parameter_group_family   = "redis6.x"
        at_rest_encryption_enabled = false
        transit_encryption_enabled = false
      }
    }
    
    staging = {
      # ECS configurations
      ecs = {
        cpu                = 512
        memory             = 1024
        desired_count      = 2
        min_capacity       = 2
        max_capacity       = 6
        enable_auto_scaling = true
      }
      
      # Lambda configurations
      lambda = {
        timeout                = 60
        memory_size           = 256
        reserved_concurrency  = 50
        dead_letter_queue    = true
        enable_xray_tracing  = true
      }
      
      # Cache configurations
      cache = {
        node_type                 = "cache.t3.small"
        num_cache_nodes          = 2
        parameter_group_family   = "redis6.x"
        at_rest_encryption_enabled = true
        transit_encryption_enabled = true
      }
    }
    
    prod = {
      # ECS configurations
      ecs = {
        cpu                = 1024
        memory             = 2048
        desired_count      = 3
        min_capacity       = 3
        max_capacity       = 10
        enable_auto_scaling = true
      }
      
      # Lambda configurations
      lambda = {
        timeout                = 120
        memory_size           = 512
        reserved_concurrency  = 100
        dead_letter_queue    = true
        enable_xray_tracing  = true
      }
      
      # Cache configurations
      cache = {
        node_type                 = "cache.r5.large"
        num_cache_nodes          = 3
        parameter_group_family   = "redis6.x"
        at_rest_encryption_enabled = true
        transit_encryption_enabled = true
      }
    }
  }
  
  # Current environment configuration
  current_env_config = local.environment_configs[var.environment]
  current_network_config = local.network_configs[var.environment]
  current_service_config = local.service_configs[var.environment]
  
  # Standard tags applied to all resources
  standard_tags = {
    Environment     = var.environment
    Project        = var.project_name
    ManagedBy      = "Terraform"
    CostCenter     = var.cost_center
    Owner          = var.owner_team
    CreatedDate    = formatdate("YYYY-MM-DD", timestamp())
    LastModified   = formatdate("YYYY-MM-DD'T'hh:mm:ssZ", timestamp())
  }
  
  # Merge with custom tags
  final_tags = merge(local.standard_tags, var.additional_tags)
}

# ==============================================================================
# SHARED RESOURCES (Optional)
# ==============================================================================

# KMS Key for cross-service encryption
resource "aws_kms_key" "env_key" {
  count = var.create_shared_kms_key ? 1 : 0
  
  description             = "${var.project_name} ${var.environment} environment encryption key"
  key_usage              = "ENCRYPT_DECRYPT"
  key_spec               = "SYMMETRIC_DEFAULT"
  key_rotation_enabled   = true
  deletion_window_in_days = var.environment == "prod" ? 30 : 7
  
  tags = merge(local.final_tags, {
    Name = "${var.project_name}-${var.environment}-shared-key"
  })
}

resource "aws_kms_alias" "env_key_alias" {
  count = var.create_shared_kms_key ? 1 : 0
  
  name          = "alias/${var.project_name}-${var.environment}-shared"
  target_key_id = aws_kms_key.env_key[0].key_id
}

# SNS Topic for environment-wide notifications
resource "aws_sns_topic" "env_notifications" {
  count = var.create_shared_sns_topic ? 1 : 0
  
  name         = "${var.project_name}-${var.environment}-notifications"
  display_name = "${var.project_name} ${upper(var.environment)} Environment Notifications"
  
  kms_master_key_id = var.create_shared_kms_key ? aws_kms_key.env_key[0].arn : null
  
  tags = merge(local.final_tags, {
    Name = "${var.project_name}-${var.environment}-notifications"
  })
}

# ==============================================================================
# DATA SOURCES
# ==============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}