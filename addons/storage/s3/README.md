# S3 Enhanced Storage Addon

Version: **v1.0.0**

## Overview

The S3 Enhanced Storage Addon provides enterprise-grade S3 bucket configuration with advanced security, monitoring, lifecycle management, and cost optimization features. This addon extends the basic S3 functionality with production-ready enhancements for scalable applications.

## Features

### 🔐 Enhanced Security
- **Multi-layer encryption** with KMS support and bucket key optimization
- **Strict bucket policies** with environment-specific access controls
- **MFA delete protection** for critical data
- **Public access blocking** with granular controls
- **SSL/TLS enforcement** for all communications

### 💰 Cost Optimization
- **Intelligent Tiering** for automatic storage class optimization
- **Advanced lifecycle rules** with object size and tag filtering
- **Cross-region replication** with configurable storage classes
- **Incomplete multipart upload cleanup**
- **Bucket key optimization** for KMS cost reduction

### 📊 Monitoring & Analytics
- **Detailed CloudWatch metrics** for comprehensive monitoring
- **S3 analytics configuration** for storage optimization insights
- **Inventory reporting** for compliance and governance
- **Enhanced notifications** with Lambda, SQS, and SNS integration

### 🏛️ Compliance & Governance
- **Versioning with MFA delete** protection
- **Cross-region replication** for disaster recovery
- **Audit logging** integration ready
- **Retention policies** through lifecycle rules
- **Inventory tracking** for compliance reporting

## Usage

### Basic Configuration

```hcl
module "enhanced_s3_storage" {
  source = "./addons/storage/s3"

  project_name   = "myapp"
  environment    = "prod"
  bucket_purpose = "data"

  # Enable key features
  enable_enhanced_security    = true
  enable_intelligent_tiering  = true
  enable_detailed_monitoring  = true

  # Basic lifecycle rules
  lifecycle_rules = [
    {
      id     = "archive_old_data"
      status = "Enabled"
      transitions = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        },
        {
          days          = 90
          storage_class = "GLACIER"
        }
      ]
    }
  ]

  common_tags = {
    Project = "MyApp"
    Owner   = "DataTeam"
  }
}
```

### Advanced Configuration with Cross-Region Replication

```hcl
module "enhanced_s3_storage" {
  source = "./addons/storage/s3"

  project_name   = "myapp"
  environment    = "prod"
  bucket_purpose = "critical-data"

  # Security configuration
  enable_enhanced_security = true
  kms_key_alias           = "myapp-s3-key"
  mfa_delete_enabled      = true

  # Replication for disaster recovery
  replication_configuration = {
    rules = [
      {
        id                = "replicate-to-west"
        status            = "Enabled"
        destination_bucket = "arn:aws:s3:::myapp-prod-critical-data-replica"
        storage_class     = "STANDARD_IA"
        replica_kms_key_id = "arn:aws:kms:us-west-2:123456789012:key/12345678-1234-1234-1234-123456789012"
      }
    ]
  }

  # Environment-specific access controls
  environment_access_controls = {
    prod = {
      allowed_principals = [
        "arn:aws:iam::123456789012:role/MyAppProdRole"
      ]
      allowed_actions = [
        "s3:GetObject",
        "s3:PutObject"
      ]
      apply_to_objects = true
      conditions = [
        {
          test     = "StringEquals"
          variable = "s3:x-amz-server-side-encryption"
          values   = ["aws:kms"]
        }
      ]
    }
  }

  # Compliance features
  inventory_configuration = {
    name = "compliance-inventory"
    schedule = {
      frequency = "Daily"
    }
    destination = {
      bucket_arn = "arn:aws:s3:::myapp-compliance-reports"
      prefix     = "inventory/"
    }
  }

  common_tags = {
    Environment   = "prod"
    Compliance    = "SOX"
    DataClass     = "Critical"
    BackupPolicy  = "Required"
  }
}
```

### Web Application with Static Hosting

```hcl
module "website_storage" {
  source = "./addons/storage/s3"

  project_name   = "mywebapp"
  environment    = "prod"
  bucket_purpose = "website"

  # Website configuration
  website_configuration = {
    index_document = {
      suffix = "index.html"
    }
    error_document = {
      key = "error.html"
    }
  }

  # CORS for web applications
  cors_configuration = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["GET", "POST"]
      allowed_origins = ["https://mywebapp.com"]
      expose_headers  = ["ETag"]
      max_age_seconds = 3000
    }
  ]

  # CDN-friendly lifecycle
  lifecycle_rules = [
    {
      id     = "optimize_web_assets"
      status = "Enabled"
      filter = {
        prefix = "assets/"
      }
      transitions = [
        {
          days          = 7
          storage_class = "STANDARD_IA"
        }
      ]
    }
  ]

  common_tags = {
    Application = "Website"
    CDN         = "CloudFront"
  }
}
```

## Environment-Specific Defaults

The addon automatically applies environment-specific defaults when `apply_environment_defaults = true`:

### Development Environment
- Shorter retention periods
- Basic monitoring
- Cost-optimized storage classes
- Relaxed security for testing

### Production Environment
- Extended retention periods
- Enhanced monitoring and alerting
- Multi-region replication options
- Strict security controls
- Compliance features enabled

## Integration with Other Modules

### CloudWatch Monitoring Integration

```hcl
module "s3_storage" {
  source = "./addons/storage/s3"
  # ... configuration
}

module "cloudwatch_monitoring" {
  source = "./addons/monitoring/cloudwatch"
  
  # Use S3 outputs for monitoring
  s3_bucket_name = module.s3_storage.bucket_id
  s3_bucket_arn  = module.s3_storage.bucket_arn
  
  # ... other configuration
}
```

### Lambda Function Integration

```hcl
module "s3_storage" {
  source = "./addons/storage/s3"
  
  notification_configuration = {
    lambda_notifications = [
      {
        function_arn  = module.lambda_processor.function_arn
        events        = ["s3:ObjectCreated:*"]
        filter_prefix = "uploads/"
      }
    ]
  }
}
```

## Input Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `project_name` | Name of the project | `string` | - | yes |
| `environment` | Environment name (dev, staging, prod) | `string` | - | yes |
| `bucket_purpose` | Purpose of the bucket | `string` | - | yes |
| `enable_enhanced_security` | Enable enhanced security features | `bool` | `true` | no |
| `enable_intelligent_tiering` | Enable S3 Intelligent Tiering | `bool` | `false` | no |
| `kms_key_alias` | KMS key alias for encryption | `string` | `null` | no |
| `replication_configuration` | Cross-region replication config | `object` | `null` | no |
| `lifecycle_rules` | Advanced lifecycle rules | `list(object)` | `[]` | no |

[See variables.tf for complete list]

## Outputs

| Name | Description |
|------|-------------|
| `bucket_id` | The ID of the S3 bucket |
| `bucket_arn` | The ARN of the S3 bucket |
| `encryption_configuration` | Encryption configuration details |
| `compliance_features` | Summary of enabled compliance features |
| `cost_optimization_features` | Summary of cost optimization features |

[See outputs.tf for complete list]

## Best Practices

### 🔐 Security
1. **Always enable enhanced security** in production environments
2. **Use KMS encryption** for sensitive data
3. **Implement environment-specific access controls**
4. **Enable MFA delete** for critical buckets
5. **Regular access audits** using CloudTrail integration

### 💰 Cost Optimization
1. **Enable Intelligent Tiering** for variable access patterns
2. **Configure lifecycle rules** based on data access patterns
3. **Use bucket keys** for KMS cost optimization
4. **Monitor storage analytics** for optimization opportunities
5. **Clean up incomplete uploads** automatically

### 📊 Monitoring
1. **Enable detailed monitoring** for production workloads
2. **Set up inventory reporting** for compliance
3. **Configure notifications** for critical events
4. **Use analytics** to optimize storage classes
5. **Regular compliance reporting**

## Version History

### v1.0.0
- Initial release with enhanced security features
- Intelligent tiering support
- Cross-region replication
- Advanced lifecycle management
- Comprehensive monitoring integration
- Compliance and governance features

## Support

For issues, feature requests, or questions:
1. Check existing documentation
2. Review Terraform AWS provider documentation
3. Create issues in the project repository
4. Follow AWS S3 best practices guide

## License

This addon is part of the StackKit Terraform framework and follows the same licensing terms.