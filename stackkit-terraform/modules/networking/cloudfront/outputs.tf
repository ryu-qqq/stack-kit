# CloudFront Distribution Outputs
output "distribution_id" {
  description = "The identifier for the distribution"
  value       = aws_cloudfront_distribution.this.id
}

output "distribution_arn" {
  description = "The ARN (Amazon Resource Name) for the distribution"
  value       = aws_cloudfront_distribution.this.arn
}

output "distribution_domain_name" {
  description = "The domain name corresponding to the distribution"
  value       = aws_cloudfront_distribution.this.domain_name
}

output "distribution_hosted_zone_id" {
  description = "The CloudFront Route 53 zone ID that can be used to route an Alias Resource Record Set to"
  value       = aws_cloudfront_distribution.this.hosted_zone_id
}

output "distribution_status" {
  description = "The current status of the distribution. Deployed if the distribution's information is fully propagated throughout the Amazon CloudFront system"
  value       = aws_cloudfront_distribution.this.status
}

output "distribution_etag" {
  description = "The current version of the distribution's information"
  value       = aws_cloudfront_distribution.this.etag
}

output "distribution_last_modified_time" {
  description = "The date and time the distribution was last modified"
  value       = aws_cloudfront_distribution.this.last_modified_time
}

output "distribution_in_progress_validation_batches" {
  description = "The number of invalidation batches currently in progress"
  value       = aws_cloudfront_distribution.this.in_progress_validation_batches
}

output "distribution_caller_reference" {
  description = "Internal value used by CloudFront to allow future updates to the distribution configuration"
  value       = aws_cloudfront_distribution.this.caller_reference
}

output "distribution_trusted_signers" {
  description = "List of nested attributes for active trusted signers"
  value       = aws_cloudfront_distribution.this.trusted_signers
}

output "distribution_trusted_key_groups" {
  description = "List of nested attributes for active trusted key groups"
  value       = aws_cloudfront_distribution.this.trusted_key_groups
}

# Origin Access Control Outputs
output "origin_access_controls" {
  description = "Map of Origin Access Controls created"
  value = {
    for k, v in aws_cloudfront_origin_access_control.this : k => {
      id   = v.id
      etag = v.etag
    }
  }
}

output "origin_access_control_ids" {
  description = "Map of Origin Access Control IDs"
  value = {
    for k, v in aws_cloudfront_origin_access_control.this : k => v.id
  }
}

# Origin Access Identity Outputs (Legacy)
output "origin_access_identities" {
  description = "Map of Origin Access Identities created"
  value = {
    for k, v in aws_cloudfront_origin_access_identity.this : k => {
      id                     = v.id
      caller_reference       = v.caller_reference
      cloudfront_access_identity_path = v.cloudfront_access_identity_path
      etag                   = v.etag
      iam_arn               = v.iam_arn
      s3_canonical_user_id   = v.s3_canonical_user_id
    }
  }
}

output "origin_access_identity_ids" {
  description = "Map of Origin Access Identity IDs"
  value = {
    for k, v in aws_cloudfront_origin_access_identity.this : k => v.id
  }
}

output "origin_access_identity_iam_arns" {
  description = "Map of Origin Access Identity IAM ARNs"
  value = {
    for k, v in aws_cloudfront_origin_access_identity.this : k => v.iam_arn
  }
}

output "origin_access_identity_s3_canonical_user_ids" {
  description = "Map of Origin Access Identity S3 canonical user IDs"
  value = {
    for k, v in aws_cloudfront_origin_access_identity.this : k => v.s3_canonical_user_id
  }
}

# Cache Policy Outputs
output "cache_policies" {
  description = "Map of Cache Policies created"
  value = {
    for k, v in aws_cloudfront_cache_policy.this : k => {
      id   = v.id
      etag = v.etag
    }
  }
}

output "cache_policy_ids" {
  description = "Map of Cache Policy IDs"
  value = {
    for k, v in aws_cloudfront_cache_policy.this : k => v.id
  }
}

# Origin Request Policy Outputs
output "origin_request_policies" {
  description = "Map of Origin Request Policies created"
  value = {
    for k, v in aws_cloudfront_origin_request_policy.this : k => {
      id   = v.id
      etag = v.etag
    }
  }
}

output "origin_request_policy_ids" {
  description = "Map of Origin Request Policy IDs"
  value = {
    for k, v in aws_cloudfront_origin_request_policy.this : k => v.id
  }
}

# Response Headers Policy Outputs
output "response_headers_policies" {
  description = "Map of Response Headers Policies created"
  value = {
    for k, v in aws_cloudfront_response_headers_policy.this : k => {
      id   = v.id
      etag = v.etag
    }
  }
}

output "response_headers_policy_ids" {
  description = "Map of Response Headers Policy IDs"
  value = {
    for k, v in aws_cloudfront_response_headers_policy.this : k => v.id
  }
}

# Realtime Log Config Outputs
output "realtime_log_configs" {
  description = "Map of Realtime Log Configs created"
  value = {
    for k, v in aws_cloudfront_realtime_log_config.this : k => {
      arn = v.arn
    }
  }
}

output "realtime_log_config_arns" {
  description = "Map of Realtime Log Config ARNs"
  value = {
    for k, v in aws_cloudfront_realtime_log_config.this : k => v.arn
  }
}

# Monitoring Subscription Output
output "monitoring_subscription" {
  description = "CloudFront monitoring subscription information"
  value       = var.create_monitoring_subscription ? aws_cloudfront_monitoring_subscription.this[0] : null
}

# Convenient Outputs for Common Use Cases
output "cloudfront_url" {
  description = "CloudFront distribution URL"
  value       = "https://${aws_cloudfront_distribution.this.domain_name}"
}

output "custom_domain_urls" {
  description = "List of custom domain URLs if aliases are configured"
  value       = [for alias in var.aliases : "https://${alias}"]
}

# For Route53 Alias Records
output "route53_alias_config" {
  description = "Configuration for Route53 alias record"
  value = {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}

# Security and Configuration Summary
output "security_summary" {
  description = "Security configuration summary"
  value = {
    viewer_protocol_policy    = var.default_cache_behavior.viewer_protocol_policy
    price_class              = var.price_class
    geo_restriction_enabled  = var.geo_restriction != null
    waf_enabled             = var.web_acl_id != null
    custom_ssl_enabled      = var.viewer_certificate.acm_certificate_arn != null
    logging_enabled         = var.logging_config != null
    monitoring_enabled      = var.create_monitoring_subscription
  }
}

# Origin Configuration Summary
output "origins_summary" {
  description = "Summary of origin configurations"
  value = {
    origin_count = length(var.origins)
    origin_ids   = [for origin in var.origins : origin.origin_id]
    origin_types = [
      for origin in var.origins : 
      origin.s3_origin_config != null ? "S3" : 
      origin.custom_origin_config != null ? "Custom" : "Unknown"
    ]
  }
}

# Cache Behavior Summary
output "cache_behavior_summary" {
  description = "Summary of cache behavior configurations"
  value = {
    default_cache_behavior = {
      target_origin_id       = var.default_cache_behavior.target_origin_id
      viewer_protocol_policy = var.default_cache_behavior.viewer_protocol_policy
      compress              = var.default_cache_behavior.compress
      cache_policy_enabled  = var.default_cache_behavior.cache_policy_id != null
    }
    ordered_cache_behaviors_count = length(var.ordered_cache_behaviors)
    path_patterns = [for behavior in var.ordered_cache_behaviors : behavior.path_pattern]
  }
}