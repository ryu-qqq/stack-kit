# CloudFront Distribution Terraform Module

This module creates and manages an Amazon CloudFront distribution with comprehensive support for modern CloudFront features including multiple origins, cache behaviors, policies, and advanced security configurations.

## Features

- ✅ **Multiple Origins Support** - S3, ALB, and custom origins
- ✅ **Cache Behaviors & Policies** - Default and ordered cache behaviors with modern cache policies
- ✅ **Custom Error Pages** - Configurable error responses
- ✅ **Geo-restriction** - Geographic access control
- ✅ **WAF Integration** - Web Application Firewall support
- ✅ **Custom Domains & SSL** - Custom domain names with ACM certificates
- ✅ **Origin Access Control (OAC)** - Modern S3 access control (recommended over OAI)
- ✅ **Origin Access Identity (OAI)** - Legacy S3 access control for backward compatibility
- ✅ **Compression** - Automatic content compression
- ✅ **Logging** - Access logs to S3 and real-time logs to Kinesis
- ✅ **Monitoring** - CloudWatch monitoring and real-time metrics
- ✅ **Function Associations** - Lambda@Edge and CloudFront Functions
- ✅ **Security Headers** - Response headers policies for security
- ✅ **CORS Configuration** - Cross-Origin Resource Sharing policies

## Usage

### Basic S3 Origin with OAC (Recommended)

```hcl
module "cloudfront" {
  source = "./modules/networking/cloudfront"

  name    = "my-app-distribution"
  comment = "Distribution for my application"

  origins = [
    {
      origin_id                = "S3-my-bucket"
      domain_name              = "my-bucket.s3.amazonaws.com"
      origin_access_control_id = module.cloudfront.origin_access_control_ids["s3_oac"]
    }
  ]

  default_cache_behavior = {
    target_origin_id       = "S3-my-bucket"
    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id        = aws_cloudfront_cache_policy.optimized.id
  }

  create_origin_access_controls = {
    s3_oac = {
      name                              = "my-bucket-oac"
      description                       = "OAC for my S3 bucket"
      origin_access_control_origin_type = "s3"
      signing_behavior                  = "always"
      signing_protocol                  = "sigv4"
    }
  }

  viewer_certificate = {
    acm_certificate_arn      = aws_acm_certificate.example.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  aliases = ["www.example.com", "example.com"]

  tags = {
    Environment = "production"
    Application = "my-app"
  }
}
```

### Multi-Origin Distribution with ALB and S3

```hcl
module "cloudfront" {
  source = "./modules/networking/cloudfront"

  name    = "multi-origin-distribution"
  comment = "Distribution with ALB and S3 origins"

  origins = [
    {
      origin_id   = "ALB-api"
      domain_name = "api.example.com"
      custom_origin_config = {
        http_port                = 80
        https_port               = 443
        origin_protocol_policy   = "https-only"
        origin_ssl_protocols     = ["TLSv1.2"]
        origin_keepalive_timeout = 5
        origin_read_timeout      = 30
      }
      custom_headers = {
        "X-Custom-Header" = "value"
      }
    },
    {
      origin_id                = "S3-static"
      domain_name              = "static-assets.s3.amazonaws.com"
      origin_path              = "/assets"
      origin_access_control_id = module.cloudfront.origin_access_control_ids["s3_oac"]
      origin_shield = {
        enabled              = true
        origin_shield_region = "us-east-1"
      }
    }
  ]

  default_cache_behavior = {
    target_origin_id         = "ALB-api"
    viewer_protocol_policy   = "https-only"
    cache_policy_id          = module.cloudfront.cache_policy_ids["api_policy"]
    origin_request_policy_id = module.cloudfront.origin_request_policy_ids["api_request_policy"]
  }

  ordered_cache_behaviors = [
    {
      path_pattern           = "/api/*"
      target_origin_id       = "ALB-api"
      viewer_protocol_policy = "https-only"
      cache_policy_id        = module.cloudfront.cache_policy_ids["api_policy"]
      compress               = false
    },
    {
      path_pattern           = "/static/*"
      target_origin_id       = "S3-static"
      viewer_protocol_policy = "redirect-to-https"
      cache_policy_id        = module.cloudfront.cache_policy_ids["static_policy"]
      compress               = true
    }
  ]

  # Custom cache policies
  cache_policies = {
    api_policy = {
      name        = "api-cache-policy"
      comment     = "Cache policy for API endpoints"
      default_ttl = 0
      max_ttl     = 1
      min_ttl     = 0
      parameters_in_cache_key_and_forwarded_to_origin = {
        query_strings_config = {
          query_string_behavior = "all"
        }
        headers_config = {
          header_behavior = "whitelist"
          headers         = ["Authorization", "CloudFront-Viewer-Country"]
        }
        cookies_config = {
          cookie_behavior = "none"
        }
      }
    }
    static_policy = {
      name        = "static-cache-policy"
      comment     = "Cache policy for static assets"
      default_ttl = 86400
      max_ttl     = 31536000
      min_ttl     = 1
      parameters_in_cache_key_and_forwarded_to_origin = {
        query_strings_config = {
          query_string_behavior = "none"
        }
        headers_config = {
          header_behavior = "none"
        }
        cookies_config = {
          cookie_behavior = "none"
        }
      }
    }
  }

  create_origin_access_controls = {
    s3_oac = {
      name                              = "static-assets-oac"
      description                       = "OAC for static assets bucket"
      origin_access_control_origin_type = "s3"
      signing_behavior                  = "always"
      signing_protocol                  = "sigv4"
    }
  }

  custom_error_responses = [
    {
      error_code         = 404
      response_code      = 200
      response_page_path = "/index.html"
    },
    {
      error_code         = 403
      response_code      = 200
      response_page_path = "/index.html"
    }
  ]

  geo_restriction = {
    restriction_type = "whitelist"
    locations        = ["US", "CA", "GB", "DE"]
  }

  web_acl_id = aws_wafv2_web_acl.example.arn

  logging_config = {
    bucket          = "my-cloudfront-logs.s3.amazonaws.com"
    include_cookies = false
    prefix          = "access-logs/"
  }

  tags = {
    Environment = "production"
    Application = "my-app"
  }
}
```

### With Security Headers and CORS

```hcl
module "cloudfront" {
  source = "./modules/networking/cloudfront"

  name = "secure-distribution"

  origins = [
    {
      origin_id   = "S3-webapp"
      domain_name = "my-webapp.s3.amazonaws.com"
      origin_access_control_id = module.cloudfront.origin_access_control_ids["webapp_oac"]
    }
  ]

  default_cache_behavior = {
    target_origin_id           = "S3-webapp"
    viewer_protocol_policy     = "redirect-to-https"
    cache_policy_id            = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # AWS Managed CachingOptimized
    response_headers_policy_id = module.cloudfront.response_headers_policy_ids["security_headers"]
  }

  response_headers_policies = {
    security_headers = {
      name    = "security-headers-policy"
      comment = "Security headers for web application"
      
      cors_config = {
        access_control_allow_credentials = false
        access_control_allow_headers     = ["*"]
        access_control_allow_methods     = ["GET", "HEAD", "OPTIONS", "PUT", "PATCH", "POST", "DELETE"]
        access_control_allow_origins     = ["https://example.com"]
        access_control_max_age_sec       = 600
        origin_override                  = true
      }
      
      security_headers_config = {
        content_security_policy = {
          content_security_policy = "default-src 'self'; img-src 'self' data: https:; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'"
          override                = true
        }
        content_type_options = {
          override = true
        }
        frame_options = {
          frame_option = "DENY"
          override     = true
        }
        referrer_policy = {
          referrer_policy = "strict-origin-when-cross-origin"
          override        = true
        }
        strict_transport_security = {
          access_control_max_age_sec = 31536000
          include_subdomains         = true
          override                   = true
          preload                    = true
        }
      }
    }
  }

  create_origin_access_controls = {
    webapp_oac = {
      name                              = "webapp-oac"
      description                       = "OAC for webapp S3 bucket"
      origin_access_control_origin_type = "s3"
      signing_behavior                  = "always"
      signing_protocol                  = "sigv4"
    }
  }

  tags = {
    Environment = "production"
    Security    = "enhanced"
  }
}
```

### With Lambda@Edge and CloudFront Functions

```hcl
module "cloudfront" {
  source = "./modules/networking/cloudfront"

  name = "function-enabled-distribution"

  origins = [
    {
      origin_id   = "S3-content"
      domain_name = "content.s3.amazonaws.com"
      origin_access_control_id = module.cloudfront.origin_access_control_ids["content_oac"]
    }
  ]

  default_cache_behavior = {
    target_origin_id       = "S3-content"
    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id        = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    
    lambda_function_associations = [
      {
        event_type   = "viewer-request"
        lambda_arn   = aws_lambda_function.auth_check.qualified_arn
        include_body = false
      },
      {
        event_type   = "origin-response"
        lambda_arn   = aws_lambda_function.add_headers.qualified_arn
        include_body = false
      }
    ]
    
    function_associations = [
      {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.url_rewrite.arn
      }
    ]
  }

  create_origin_access_controls = {
    content_oac = {
      name                              = "content-oac"
      description                       = "OAC for content S3 bucket"
      origin_access_control_origin_type = "s3"
      signing_behavior                  = "always"
      signing_protocol                  = "sigv4"
    }
  }

  tags = {
    Environment = "production"
    Functions   = "enabled"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0 |

## Resources Created

- `aws_cloudfront_distribution` - Main CloudFront distribution
- `aws_cloudfront_origin_access_control` - Origin Access Controls (OAC)
- `aws_cloudfront_origin_access_identity` - Origin Access Identities (OAI) - legacy
- `aws_cloudfront_cache_policy` - Custom cache policies
- `aws_cloudfront_origin_request_policy` - Custom origin request policies
- `aws_cloudfront_response_headers_policy` - Custom response headers policies
- `aws_cloudfront_realtime_log_config` - Real-time logging configuration
- `aws_cloudfront_monitoring_subscription` - CloudWatch monitoring subscription

## Important Notes

### Origin Access Control (OAC) vs Origin Access Identity (OAI)

This module supports both OAC (recommended) and OAI (legacy) for S3 origins:

- **OAC (Recommended)**: Use `origin_access_control_id` in your origin configuration
- **OAI (Legacy)**: Use `s3_origin_config.origin_access_identity` in your origin configuration

### Cache Policies vs Legacy Cache Settings

The module supports both modern cache policies and legacy cache settings:

- **Cache Policies (Recommended)**: Set `cache_policy_id` in cache behaviors
- **Legacy Settings**: When `cache_policy_id` is null, use `forwarded_values`, `default_ttl`, etc.

### Price Classes

Choose the appropriate price class based on your requirements:

- `PriceClass_All`: Use all edge locations (best performance, highest cost)
- `PriceClass_200`: Use North America, Europe, Asia, Middle East, and Africa
- `PriceClass_100`: Use North America and Europe only (lowest cost)

### SSL/TLS Configuration

For custom domains, ensure your ACM certificate is in the `us-east-1` region, as CloudFront only accepts certificates from this region.

## S3 Bucket Policy for OAC

When using Origin Access Control with S3, update your S3 bucket policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontServicePrincipal",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudfront.amazonaws.com"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::your-bucket-name/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "arn:aws:cloudfront::123456789012:distribution/DISTRIBUTION_ID"
        }
      }
    }
  ]
}
```

## Common Cache Policy IDs (AWS Managed)

You can use AWS managed cache policies instead of creating custom ones:

- **CachingOptimized**: `4135ea2d-6df8-44a3-9df3-4b5a84be39ad`
- **CachingDisabled**: `6fa7c45e-7de5-4e78-b93c-00f621dc77d5`
- **CachingOptimizedForUncompressedObjects**: `b2884449-e4de-46a7-ac36-70bc7f1ddd6d`
- **Elemental-MediaPackage**: `08627262-05a9-4f76-9ded-b50ca2e3a84f`

## Common Origin Request Policy IDs (AWS Managed)

- **CORS-S3Origin**: `88a5eaf4-2fd4-4709-b370-b4c650ea3fcf`
- **UserAgentRefererHeaders**: `acba4595-bd28-49b8-b9fe-13317c0390fa`
- **AllViewer**: `216adef6-5c7f-47e4-b989-5492eafa07d3`

## Examples Repository

For more comprehensive examples, see the `examples/` directory in this repository.

## Contributing

Please read the contributing guidelines before submitting pull requests.

## License

This module is licensed under the MIT License. See LICENSE for full details.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | Name for the CloudFront distribution | `string` | n/a | yes |
| origins | List of origins for this distribution | `list(object(...))` | n/a | yes |
| default_cache_behavior | Default cache behavior for this distribution | `object(...)` | n/a | yes |
| comment | Any comment you want to include about the distribution | `string` | `"Managed by Terraform"` | no |
| enabled | Whether the distribution is enabled to accept end user requests for content | `bool` | `true` | no |
| default_root_object | The object that you want CloudFront to return when an end user requests the root URL | `string` | `"index.html"` | no |
| http_version | The maximum HTTP version to support on the distribution | `string` | `"http2"` | no |
| is_ipv6_enabled | Whether the IPv6 is enabled for the distribution | `bool` | `true` | no |
| price_class | The price class for this distribution | `string` | `"PriceClass_100"` | no |
| retain_on_delete | Disables the distribution instead of deleting it when destroying the resource | `bool` | `false` | no |
| wait_for_deployment | If enabled, the resource will wait for the distribution status to change from InProgress to Deployed | `bool` | `true` | no |
| web_acl_id | If you're using AWS WAF to filter CloudFront requests, the Id of the AWS WAF web ACL | `string` | `null` | no |
| aliases | List of FQDN that you want to associate with this distribution | `list(string)` | `[]` | no |
| ordered_cache_behaviors | List of ordered cache behaviors for this distribution | `list(object(...))` | `[]` | no |
| custom_error_responses | List of custom error responses for this distribution | `list(object(...))` | `[]` | no |
| geo_restriction | Geographic restriction configuration | `object(...)` | `null` | no |
| viewer_certificate | SSL certificate for the distribution | `object(...)` | `{cloudfront_default_certificate = true}` | no |
| logging_config | Access logs configuration | `object(...)` | `null` | no |
| create_origin_access_controls | Map of Origin Access Controls to create | `map(object(...))` | `{}` | no |
| create_origin_access_identities | Map of Origin Access Identities to create | `map(string)` | `{}` | no |
| cache_policies | Map of cache policies to create | `map(object(...))` | `{}` | no |
| origin_request_policies | Map of origin request policies to create | `map(object(...))` | `{}` | no |
| response_headers_policies | Map of response headers policies to create | `map(object(...))` | `{}` | no |
| realtime_log_configs | Map of realtime log configs to create | `map(object(...))` | `{}` | no |
| create_monitoring_subscription | Whether to create CloudFront monitoring subscription | `bool` | `false` | no |
| tags | A map of tags to assign to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| distribution_id | The identifier for the distribution |
| distribution_arn | The ARN (Amazon Resource Name) for the distribution |
| distribution_domain_name | The domain name corresponding to the distribution |
| distribution_hosted_zone_id | The CloudFront Route 53 zone ID |
| distribution_status | The current status of the distribution |
| cloudfront_url | CloudFront distribution URL |
| custom_domain_urls | List of custom domain URLs if aliases are configured |
| origin_access_control_ids | Map of Origin Access Control IDs |
| origin_access_identity_ids | Map of Origin Access Identity IDs |
| cache_policy_ids | Map of Cache Policy IDs |
| origin_request_policy_ids | Map of Origin Request Policy IDs |
| response_headers_policy_ids | Map of Response Headers Policy IDs |
| route53_alias_config | Configuration for Route53 alias record |
| security_summary | Security configuration summary |
| origins_summary | Summary of origin configurations |
| cache_behavior_summary | Summary of cache behavior configurations |