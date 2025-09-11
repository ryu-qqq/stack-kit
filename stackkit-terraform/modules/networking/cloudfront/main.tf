# CloudFront Distribution
resource "aws_cloudfront_distribution" "this" {
  comment             = var.comment
  default_root_object = var.default_root_object
  enabled             = var.enabled
  http_version        = var.http_version
  is_ipv6_enabled     = var.is_ipv6_enabled
  price_class         = var.price_class
  retain_on_delete    = var.retain_on_delete
  wait_for_deployment = var.wait_for_deployment
  web_acl_id          = var.web_acl_id

  # Origins
  dynamic "origin" {
    for_each = var.origins
    content {
      domain_name              = origin.value.domain_name
      origin_id                = origin.value.origin_id
      origin_path              = origin.value.origin_path
      connection_attempts      = origin.value.connection_attempts
      connection_timeout       = origin.value.connection_timeout
      origin_access_control_id = origin.value.origin_access_control_id

      dynamic "custom_origin_config" {
        for_each = origin.value.custom_origin_config != null ? [origin.value.custom_origin_config] : []
        content {
          http_port                = custom_origin_config.value.http_port
          https_port               = custom_origin_config.value.https_port
          origin_protocol_policy   = custom_origin_config.value.origin_protocol_policy
          origin_ssl_protocols     = custom_origin_config.value.origin_ssl_protocols
          origin_keepalive_timeout = custom_origin_config.value.origin_keepalive_timeout
          origin_read_timeout      = custom_origin_config.value.origin_read_timeout
        }
      }

      dynamic "s3_origin_config" {
        for_each = origin.value.s3_origin_config != null ? [origin.value.s3_origin_config] : []
        content {
          origin_access_identity = s3_origin_config.value.origin_access_identity
        }
      }

      dynamic "custom_header" {
        for_each = origin.value.custom_headers != null ? origin.value.custom_headers : {}
        content {
          name  = custom_header.key
          value = custom_header.value
        }
      }

      dynamic "origin_shield" {
        for_each = origin.value.origin_shield != null ? [origin.value.origin_shield] : []
        content {
          enabled              = origin_shield.value.enabled
          origin_shield_region = origin_shield.value.origin_shield_region
        }
      }
    }
  }

  # Default Cache Behavior
  default_cache_behavior {
    target_origin_id         = var.default_cache_behavior.target_origin_id
    viewer_protocol_policy   = var.default_cache_behavior.viewer_protocol_policy
    allowed_methods          = var.default_cache_behavior.allowed_methods
    cached_methods           = var.default_cache_behavior.cached_methods
    compress                 = var.default_cache_behavior.compress
    cache_policy_id          = var.default_cache_behavior.cache_policy_id
    origin_request_policy_id = var.default_cache_behavior.origin_request_policy_id
    response_headers_policy_id = var.default_cache_behavior.response_headers_policy_id
    realtime_log_config_arn  = var.default_cache_behavior.realtime_log_config_arn
    smooth_streaming         = var.default_cache_behavior.smooth_streaming
    field_level_encryption_id = var.default_cache_behavior.field_level_encryption_id

    # Legacy cache settings (when not using cache policies)
    default_ttl = var.default_cache_behavior.cache_policy_id == null ? var.default_cache_behavior.default_ttl : null
    max_ttl     = var.default_cache_behavior.cache_policy_id == null ? var.default_cache_behavior.max_ttl : null
    min_ttl     = var.default_cache_behavior.cache_policy_id == null ? var.default_cache_behavior.min_ttl : null

    dynamic "forwarded_values" {
      for_each = var.default_cache_behavior.cache_policy_id == null && var.default_cache_behavior.forwarded_values != null ? [var.default_cache_behavior.forwarded_values] : []
      content {
        query_string            = forwarded_values.value.query_string
        query_string_cache_keys = forwarded_values.value.query_string_cache_keys
        headers                 = forwarded_values.value.headers

        cookies {
          forward           = forwarded_values.value.cookies.forward
          whitelisted_names = forwarded_values.value.cookies.whitelisted_names
        }
      }
    }

    dynamic "lambda_function_association" {
      for_each = var.default_cache_behavior.lambda_function_associations != null ? var.default_cache_behavior.lambda_function_associations : []
      content {
        event_type   = lambda_function_association.value.event_type
        lambda_arn   = lambda_function_association.value.lambda_arn
        include_body = lambda_function_association.value.include_body
      }
    }

    dynamic "function_association" {
      for_each = var.default_cache_behavior.function_associations != null ? var.default_cache_behavior.function_associations : []
      content {
        event_type   = function_association.value.event_type
        function_arn = function_association.value.function_arn
      }
    }

    trusted_signers   = var.default_cache_behavior.trusted_signers
    trusted_key_groups = var.default_cache_behavior.trusted_key_groups
  }

  # Ordered Cache Behaviors
  dynamic "ordered_cache_behavior" {
    for_each = var.ordered_cache_behaviors
    content {
      path_pattern             = ordered_cache_behavior.value.path_pattern
      target_origin_id         = ordered_cache_behavior.value.target_origin_id
      viewer_protocol_policy   = ordered_cache_behavior.value.viewer_protocol_policy
      allowed_methods          = ordered_cache_behavior.value.allowed_methods
      cached_methods           = ordered_cache_behavior.value.cached_methods
      compress                 = ordered_cache_behavior.value.compress
      cache_policy_id          = ordered_cache_behavior.value.cache_policy_id
      origin_request_policy_id = ordered_cache_behavior.value.origin_request_policy_id
      response_headers_policy_id = ordered_cache_behavior.value.response_headers_policy_id
      realtime_log_config_arn  = ordered_cache_behavior.value.realtime_log_config_arn
      smooth_streaming         = ordered_cache_behavior.value.smooth_streaming
      field_level_encryption_id = ordered_cache_behavior.value.field_level_encryption_id

      # Legacy cache settings (when not using cache policies)
      default_ttl = ordered_cache_behavior.value.cache_policy_id == null ? ordered_cache_behavior.value.default_ttl : null
      max_ttl     = ordered_cache_behavior.value.cache_policy_id == null ? ordered_cache_behavior.value.max_ttl : null
      min_ttl     = ordered_cache_behavior.value.cache_policy_id == null ? ordered_cache_behavior.value.min_ttl : null

      dynamic "forwarded_values" {
        for_each = ordered_cache_behavior.value.cache_policy_id == null && ordered_cache_behavior.value.forwarded_values != null ? [ordered_cache_behavior.value.forwarded_values] : []
        content {
          query_string            = forwarded_values.value.query_string
          query_string_cache_keys = forwarded_values.value.query_string_cache_keys
          headers                 = forwarded_values.value.headers

          cookies {
            forward           = forwarded_values.value.cookies.forward
            whitelisted_names = forwarded_values.value.cookies.whitelisted_names
          }
        }
      }

      dynamic "lambda_function_association" {
        for_each = ordered_cache_behavior.value.lambda_function_associations != null ? ordered_cache_behavior.value.lambda_function_associations : []
        content {
          event_type   = lambda_function_association.value.event_type
          lambda_arn   = lambda_function_association.value.lambda_arn
          include_body = lambda_function_association.value.include_body
        }
      }

      dynamic "function_association" {
        for_each = ordered_cache_behavior.value.function_associations != null ? ordered_cache_behavior.value.function_associations : []
        content {
          event_type   = function_association.value.event_type
          function_arn = function_association.value.function_arn
        }
      }

      trusted_signers   = ordered_cache_behavior.value.trusted_signers
      trusted_key_groups = ordered_cache_behavior.value.trusted_key_groups
    }
  }

  # Custom Error Response
  dynamic "custom_error_response" {
    for_each = var.custom_error_responses
    content {
      error_code            = custom_error_response.value.error_code
      response_code         = custom_error_response.value.response_code
      response_page_path    = custom_error_response.value.response_page_path
      error_caching_min_ttl = custom_error_response.value.error_caching_min_ttl
    }
  }

  # Geo Restriction
  dynamic "restrictions" {
    for_each = var.geo_restriction != null ? [var.geo_restriction] : []
    content {
      geo_restriction {
        restriction_type = restrictions.value.restriction_type
        locations        = restrictions.value.locations
      }
    }
  }

  # Viewer Certificate
  viewer_certificate {
    acm_certificate_arn            = var.viewer_certificate.acm_certificate_arn
    cloudfront_default_certificate = var.viewer_certificate.cloudfront_default_certificate
    iam_certificate_id             = var.viewer_certificate.iam_certificate_id
    minimum_protocol_version       = var.viewer_certificate.minimum_protocol_version
    ssl_support_method             = var.viewer_certificate.ssl_support_method
  }

  # Logging Configuration
  dynamic "logging_config" {
    for_each = var.logging_config != null ? [var.logging_config] : []
    content {
      bucket          = logging_config.value.bucket
      include_cookies = logging_config.value.include_cookies
      prefix          = logging_config.value.prefix
    }
  }

  # Aliases
  aliases = var.aliases

  tags = merge(var.tags, {
    Name = var.name
  })
}

# Origin Access Control (OAC) - Recommended over Origin Access Identity (OAI)
resource "aws_cloudfront_origin_access_control" "this" {
  for_each = var.create_origin_access_controls

  name                              = each.value.name
  description                       = each.value.description
  origin_access_control_origin_type = each.value.origin_access_control_origin_type
  signing_behavior                  = each.value.signing_behavior
  signing_protocol                  = each.value.signing_protocol
}

# Origin Access Identity (Legacy - for backward compatibility)
resource "aws_cloudfront_origin_access_identity" "this" {
  for_each = var.create_origin_access_identities

  comment = each.value
}

# Cache Policy
resource "aws_cloudfront_cache_policy" "this" {
  for_each = var.cache_policies

  name        = each.value.name
  comment     = each.value.comment
  default_ttl = each.value.default_ttl
  max_ttl     = each.value.max_ttl
  min_ttl     = each.value.min_ttl

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = each.value.parameters_in_cache_key_and_forwarded_to_origin.enable_accept_encoding_brotli
    enable_accept_encoding_gzip   = each.value.parameters_in_cache_key_and_forwarded_to_origin.enable_accept_encoding_gzip

    query_strings_config {
      query_string_behavior = each.value.parameters_in_cache_key_and_forwarded_to_origin.query_strings_config.query_string_behavior
      dynamic "query_strings" {
        for_each = each.value.parameters_in_cache_key_and_forwarded_to_origin.query_strings_config.query_strings != null ? [each.value.parameters_in_cache_key_and_forwarded_to_origin.query_strings_config.query_strings] : []
        content {
          items = query_strings.value
        }
      }
    }

    headers_config {
      header_behavior = each.value.parameters_in_cache_key_and_forwarded_to_origin.headers_config.header_behavior
      dynamic "headers" {
        for_each = each.value.parameters_in_cache_key_and_forwarded_to_origin.headers_config.headers != null ? [each.value.parameters_in_cache_key_and_forwarded_to_origin.headers_config.headers] : []
        content {
          items = headers.value
        }
      }
    }

    cookies_config {
      cookie_behavior = each.value.parameters_in_cache_key_and_forwarded_to_origin.cookies_config.cookie_behavior
      dynamic "cookies" {
        for_each = each.value.parameters_in_cache_key_and_forwarded_to_origin.cookies_config.cookies != null ? [each.value.parameters_in_cache_key_and_forwarded_to_origin.cookies_config.cookies] : []
        content {
          items = cookies.value
        }
      }
    }
  }
}

# Origin Request Policy
resource "aws_cloudfront_origin_request_policy" "this" {
  for_each = var.origin_request_policies

  name    = each.value.name
  comment = each.value.comment

  query_strings_config {
    query_string_behavior = each.value.query_strings_config.query_string_behavior
    dynamic "query_strings" {
      for_each = each.value.query_strings_config.query_strings != null ? [each.value.query_strings_config.query_strings] : []
      content {
        items = query_strings.value
      }
    }
  }

  headers_config {
    header_behavior = each.value.headers_config.header_behavior
    dynamic "headers" {
      for_each = each.value.headers_config.headers != null ? [each.value.headers_config.headers] : []
      content {
        items = headers.value
      }
    }
  }

  cookies_config {
    cookie_behavior = each.value.cookies_config.cookie_behavior
    dynamic "cookies" {
      for_each = each.value.cookies_config.cookies != null ? [each.value.cookies_config.cookies] : []
      content {
        items = cookies.value
      }
    }
  }
}

# Response Headers Policy
resource "aws_cloudfront_response_headers_policy" "this" {
  for_each = var.response_headers_policies

  name    = each.value.name
  comment = each.value.comment

  dynamic "cors_config" {
    for_each = each.value.cors_config != null ? [each.value.cors_config] : []
    content {
      access_control_allow_credentials = cors_config.value.access_control_allow_credentials
      access_control_allow_headers {
        items = cors_config.value.access_control_allow_headers
      }
      access_control_allow_methods {
        items = cors_config.value.access_control_allow_methods
      }
      access_control_allow_origins {
        items = cors_config.value.access_control_allow_origins
      }
      dynamic "access_control_expose_headers" {
        for_each = cors_config.value.access_control_expose_headers != null ? [cors_config.value.access_control_expose_headers] : []
        content {
          items = access_control_expose_headers.value
        }
      }
      access_control_max_age_sec = cors_config.value.access_control_max_age_sec
      origin_override            = cors_config.value.origin_override
    }
  }

  dynamic "custom_headers_config" {
    for_each = each.value.custom_headers_config != null ? [each.value.custom_headers_config] : []
    content {
      dynamic "items" {
        for_each = custom_headers_config.value.items
        content {
          header   = items.value.header
          override = items.value.override
          value    = items.value.value
        }
      }
    }
  }

  dynamic "remove_headers_config" {
    for_each = each.value.remove_headers_config != null ? [each.value.remove_headers_config] : []
    content {
      dynamic "items" {
        for_each = remove_headers_config.value.items
        content {
          header = items.value.header
        }
      }
    }
  }

  dynamic "security_headers_config" {
    for_each = each.value.security_headers_config != null ? [each.value.security_headers_config] : []
    content {
      dynamic "content_security_policy" {
        for_each = security_headers_config.value.content_security_policy != null ? [security_headers_config.value.content_security_policy] : []
        content {
          content_security_policy = content_security_policy.value.content_security_policy
          override                = content_security_policy.value.override
        }
      }
      dynamic "content_type_options" {
        for_each = security_headers_config.value.content_type_options != null ? [security_headers_config.value.content_type_options] : []
        content {
          override = content_type_options.value.override
        }
      }
      dynamic "frame_options" {
        for_each = security_headers_config.value.frame_options != null ? [security_headers_config.value.frame_options] : []
        content {
          frame_option = frame_options.value.frame_option
          override     = frame_options.value.override
        }
      }
      dynamic "referrer_policy" {
        for_each = security_headers_config.value.referrer_policy != null ? [security_headers_config.value.referrer_policy] : []
        content {
          referrer_policy = referrer_policy.value.referrer_policy
          override        = referrer_policy.value.override
        }
      }
      dynamic "strict_transport_security" {
        for_each = security_headers_config.value.strict_transport_security != null ? [security_headers_config.value.strict_transport_security] : []
        content {
          access_control_max_age_sec = strict_transport_security.value.access_control_max_age_sec
          include_subdomains         = strict_transport_security.value.include_subdomains
          override                   = strict_transport_security.value.override
          preload                    = strict_transport_security.value.preload
        }
      }
    }
  }

  dynamic "server_timing_headers_config" {
    for_each = each.value.server_timing_headers_config != null ? [each.value.server_timing_headers_config] : []
    content {
      enabled       = server_timing_headers_config.value.enabled
      sampling_rate = server_timing_headers_config.value.sampling_rate
    }
  }
}

# Realtime Log Config
resource "aws_cloudfront_realtime_log_config" "this" {
  for_each = var.realtime_log_configs

  name          = each.value.name
  fields        = each.value.fields
  kinesis_stream_config {
    role_arn   = each.value.kinesis_stream_config.role_arn
    stream_arn = each.value.kinesis_stream_config.stream_arn
  }
}

# Monitoring Subscription
resource "aws_cloudfront_monitoring_subscription" "this" {
  count = var.create_monitoring_subscription ? 1 : 0

  distribution_id = aws_cloudfront_distribution.this.id

  monitoring_subscription {
    realtime_metrics_subscription_config {
      realtime_metrics_subscription_status = "Enabled"
    }
  }
}