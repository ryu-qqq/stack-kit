# Basic CloudFront Distribution Configuration
variable "name" {
  description = "Name for the CloudFront distribution"
  type        = string
}

variable "comment" {
  description = "Any comment you want to include about the distribution"
  type        = string
  default     = "Managed by Terraform"
}

variable "enabled" {
  description = "Whether the distribution is enabled to accept end user requests for content"
  type        = bool
  default     = true
}

variable "default_root_object" {
  description = "The object that you want CloudFront to return when an end user requests the root URL"
  type        = string
  default     = "index.html"
}

variable "http_version" {
  description = "The maximum HTTP version to support on the distribution. Allowed values are http1.1 and http2"
  type        = string
  default     = "http2"
  validation {
    condition     = contains(["http1.1", "http2"], var.http_version)
    error_message = "Valid values are http1.1 or http2."
  }
}

variable "is_ipv6_enabled" {
  description = "Whether the IPv6 is enabled for the distribution"
  type        = bool
  default     = true
}

variable "price_class" {
  description = "The price class for this distribution. One of PriceClass_All, PriceClass_200, PriceClass_100"
  type        = string
  default     = "PriceClass_100"
  validation {
    condition     = contains(["PriceClass_All", "PriceClass_200", "PriceClass_100"], var.price_class)
    error_message = "Valid values are PriceClass_All, PriceClass_200, or PriceClass_100."
  }
}

variable "retain_on_delete" {
  description = "Disables the distribution instead of deleting it when destroying the resource through Terraform"
  type        = bool
  default     = false
}

variable "wait_for_deployment" {
  description = "If enabled, the resource will wait for the distribution status to change from InProgress to Deployed"
  type        = bool
  default     = true
}

variable "web_acl_id" {
  description = "If you're using AWS WAF to filter CloudFront requests, the Id of the AWS WAF web ACL"
  type        = string
  default     = null
}

variable "aliases" {
  description = "List of FQDN that you want to associate with this distribution"
  type        = list(string)
  default     = []
}

# Origins Configuration
variable "origins" {
  description = "List of origins for this distribution"
  type = list(object({
    origin_id                = string
    domain_name              = string
    origin_path              = optional(string, "")
    connection_attempts      = optional(number, 3)
    connection_timeout       = optional(number, 10)
    origin_access_control_id = optional(string, null)
    
    # Custom Origin Configuration
    custom_origin_config = optional(object({
      http_port                = optional(number, 80)
      https_port               = optional(number, 443)
      origin_protocol_policy   = string # http-only, https-only, match-viewer
      origin_ssl_protocols     = optional(list(string), ["TLSv1.2"])
      origin_keepalive_timeout = optional(number, 5)
      origin_read_timeout      = optional(number, 30)
    }), null)

    # S3 Origin Configuration
    s3_origin_config = optional(object({
      origin_access_identity = string
    }), null)

    # Custom Headers
    custom_headers = optional(map(string), {})

    # Origin Shield
    origin_shield = optional(object({
      enabled              = bool
      origin_shield_region = string
    }), null)
  }))
}

# Default Cache Behavior Configuration
variable "default_cache_behavior" {
  description = "Default cache behavior for this distribution"
  type = object({
    target_origin_id         = string
    viewer_protocol_policy   = string # allow-all, https-only, redirect-to-https
    allowed_methods          = optional(list(string), ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"])
    cached_methods           = optional(list(string), ["GET", "HEAD"])
    compress                 = optional(bool, true)
    cache_policy_id          = optional(string, null)
    origin_request_policy_id = optional(string, null)
    response_headers_policy_id = optional(string, null)
    realtime_log_config_arn  = optional(string, null)
    smooth_streaming         = optional(bool, false)
    field_level_encryption_id = optional(string, null)
    
    # Legacy cache settings (used when cache_policy_id is null)
    default_ttl = optional(number, 86400)
    max_ttl     = optional(number, 31536000)
    min_ttl     = optional(number, 0)
    
    # Forwarded Values (legacy, used when cache_policy_id is null)
    forwarded_values = optional(object({
      query_string            = optional(bool, false)
      query_string_cache_keys = optional(list(string), [])
      headers                 = optional(list(string), [])
      cookies = object({
        forward           = string # none, whitelist, all
        whitelisted_names = optional(list(string), [])
      })
    }), null)
    
    # Function Associations
    lambda_function_associations = optional(list(object({
      event_type   = string # viewer-request, origin-request, viewer-response, origin-response
      lambda_arn   = string
      include_body = optional(bool, false)
    })), [])
    
    function_associations = optional(list(object({
      event_type   = string # viewer-request, viewer-response
      function_arn = string
    })), [])
    
    trusted_signers   = optional(list(string), [])
    trusted_key_groups = optional(list(string), [])
  })
}

# Ordered Cache Behaviors Configuration
variable "ordered_cache_behaviors" {
  description = "List of ordered cache behaviors for this distribution"
  type = list(object({
    path_pattern             = string
    target_origin_id         = string
    viewer_protocol_policy   = string
    allowed_methods          = optional(list(string), ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"])
    cached_methods           = optional(list(string), ["GET", "HEAD"])
    compress                 = optional(bool, true)
    cache_policy_id          = optional(string, null)
    origin_request_policy_id = optional(string, null)
    response_headers_policy_id = optional(string, null)
    realtime_log_config_arn  = optional(string, null)
    smooth_streaming         = optional(bool, false)
    field_level_encryption_id = optional(string, null)
    
    # Legacy cache settings
    default_ttl = optional(number, 86400)
    max_ttl     = optional(number, 31536000)
    min_ttl     = optional(number, 0)
    
    # Forwarded Values (legacy)
    forwarded_values = optional(object({
      query_string            = optional(bool, false)
      query_string_cache_keys = optional(list(string), [])
      headers                 = optional(list(string), [])
      cookies = object({
        forward           = string
        whitelisted_names = optional(list(string), [])
      })
    }), null)
    
    # Function Associations
    lambda_function_associations = optional(list(object({
      event_type   = string
      lambda_arn   = string
      include_body = optional(bool, false)
    })), [])
    
    function_associations = optional(list(object({
      event_type   = string
      function_arn = string
    })), [])
    
    trusted_signers   = optional(list(string), [])
    trusted_key_groups = optional(list(string), [])
  }))
  default = []
}

# Custom Error Response Configuration
variable "custom_error_responses" {
  description = "List of custom error responses for this distribution"
  type = list(object({
    error_code            = number
    response_code         = optional(number, null)
    response_page_path    = optional(string, null)
    error_caching_min_ttl = optional(number, 10)
  }))
  default = []
}

# Geo Restriction Configuration
variable "geo_restriction" {
  description = "Geographic restriction configuration"
  type = object({
    restriction_type = string # none, whitelist, blacklist
    locations        = optional(list(string), [])
  })
  default = null
}

# Viewer Certificate Configuration
variable "viewer_certificate" {
  description = "SSL certificate for the distribution"
  type = object({
    acm_certificate_arn            = optional(string, null)
    cloudfront_default_certificate = optional(bool, true)
    iam_certificate_id             = optional(string, null)
    minimum_protocol_version       = optional(string, "TLSv1.2_2021")
    ssl_support_method             = optional(string, null) # sni-only, vip
  })
  default = {
    cloudfront_default_certificate = true
  }
}

# Logging Configuration
variable "logging_config" {
  description = "Access logs configuration"
  type = object({
    bucket          = string
    include_cookies = optional(bool, false)
    prefix          = optional(string, "")
  })
  default = null
}

# Origin Access Controls
variable "create_origin_access_controls" {
  description = "Map of Origin Access Controls to create"
  type = map(object({
    name                              = string
    description                       = optional(string, "")
    origin_access_control_origin_type = string # s3
    signing_behavior                  = string # always, never, no-override
    signing_protocol                  = string # sigv4
  }))
  default = {}
}

# Origin Access Identities (Legacy)
variable "create_origin_access_identities" {
  description = "Map of Origin Access Identities to create"
  type        = map(string)
  default     = {}
}

# Cache Policies
variable "cache_policies" {
  description = "Map of cache policies to create"
  type = map(object({
    name        = string
    comment     = optional(string, "")
    default_ttl = optional(number, 86400)
    max_ttl     = optional(number, 31536000)
    min_ttl     = optional(number, 1)
    
    parameters_in_cache_key_and_forwarded_to_origin = object({
      enable_accept_encoding_brotli = optional(bool, true)
      enable_accept_encoding_gzip   = optional(bool, true)
      
      query_strings_config = object({
        query_string_behavior = string # none, whitelist, allExcept, all
        query_strings         = optional(list(string), null)
      })
      
      headers_config = object({
        header_behavior = string # none, whitelist, allViewer, allViewerAndWhitelistCloudFront, allExcept
        headers         = optional(list(string), null)
      })
      
      cookies_config = object({
        cookie_behavior = string # none, whitelist, allExcept, all
        cookies         = optional(list(string), null)
      })
    })
  }))
  default = {}
}

# Origin Request Policies
variable "origin_request_policies" {
  description = "Map of origin request policies to create"
  type = map(object({
    name    = string
    comment = optional(string, "")
    
    query_strings_config = object({
      query_string_behavior = string # none, whitelist, all
      query_strings         = optional(list(string), null)
    })
    
    headers_config = object({
      header_behavior = string # none, whitelist, allViewer, allViewerAndWhitelistCloudFront, allExcept
      headers         = optional(list(string), null)
    })
    
    cookies_config = object({
      cookie_behavior = string # none, whitelist, all
      cookies         = optional(list(string), null)
    })
  }))
  default = {}
}

# Response Headers Policies
variable "response_headers_policies" {
  description = "Map of response headers policies to create"
  type = map(object({
    name    = string
    comment = optional(string, "")
    
    cors_config = optional(object({
      access_control_allow_credentials = bool
      access_control_allow_headers     = list(string)
      access_control_allow_methods     = list(string)
      access_control_allow_origins     = list(string)
      access_control_expose_headers    = optional(list(string), null)
      access_control_max_age_sec       = optional(number, 600)
      origin_override                  = bool
    }), null)
    
    custom_headers_config = optional(object({
      items = list(object({
        header   = string
        override = bool
        value    = string
      }))
    }), null)
    
    remove_headers_config = optional(object({
      items = list(object({
        header = string
      }))
    }), null)
    
    security_headers_config = optional(object({
      content_security_policy = optional(object({
        content_security_policy = string
        override                = bool
      }), null)
      
      content_type_options = optional(object({
        override = bool
      }), null)
      
      frame_options = optional(object({
        frame_option = string # DENY, SAMEORIGIN
        override     = bool
      }), null)
      
      referrer_policy = optional(object({
        referrer_policy = string
        override        = bool
      }), null)
      
      strict_transport_security = optional(object({
        access_control_max_age_sec = number
        include_subdomains         = optional(bool, true)
        override                   = bool
        preload                    = optional(bool, false)
      }), null)
    }), null)
    
    server_timing_headers_config = optional(object({
      enabled       = bool
      sampling_rate = number
    }), null)
  }))
  default = {}
}

# Realtime Log Configs
variable "realtime_log_configs" {
  description = "Map of realtime log configs to create"
  type = map(object({
    name   = string
    fields = list(string)
    kinesis_stream_config = object({
      role_arn   = string
      stream_arn = string
    })
  }))
  default = {}
}

# Monitoring
variable "create_monitoring_subscription" {
  description = "Whether to create CloudFront monitoring subscription (additional charges apply)"
  type        = bool
  default     = false
}

# Tags
variable "tags" {
  description = "A map of tags to assign to all resources"
  type        = map(string)
  default     = {}
}