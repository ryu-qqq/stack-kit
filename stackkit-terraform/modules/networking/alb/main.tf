# Application Load Balancer
resource "aws_lb" "main" {
  name               = var.name
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = var.security_groups
  subnets            = var.subnets

  enable_deletion_protection       = var.enable_deletion_protection
  enable_cross_zone_load_balancing = var.enable_cross_zone_load_balancing
  enable_http2                     = var.enable_http2
  enable_waf_fail_open            = var.enable_waf_fail_open
  drop_invalid_header_fields      = var.drop_invalid_header_fields
  preserve_host_header            = var.preserve_host_header
  enable_xff_client_port          = var.enable_xff_client_port

  idle_timeout                     = var.idle_timeout
  desync_mitigation_mode          = var.desync_mitigation_mode
  xff_header_processing_mode      = var.xff_header_processing_mode

  # Access Logs Configuration
  dynamic "access_logs" {
    for_each = var.access_logs_enabled ? [1] : []
    content {
      bucket  = var.access_logs_bucket
      prefix  = var.access_logs_prefix
      enabled = var.access_logs_enabled
    }
  }

  # Connection Logs Configuration
  dynamic "connection_logs" {
    for_each = var.connection_logs_enabled ? [1] : []
    content {
      bucket  = var.connection_logs_bucket
      prefix  = var.connection_logs_prefix
      enabled = var.connection_logs_enabled
    }
  }

  tags = merge(
    var.tags,
    {
      Name = var.name
    }
  )
}

# Target Groups
resource "aws_lb_target_group" "main" {
  for_each = var.target_groups

  name        = each.value.name
  port        = each.value.port
  protocol    = each.value.protocol
  vpc_id      = var.vpc_id
  target_type = each.value.target_type

  # Health Check Configuration
  health_check {
    enabled             = each.value.health_check.enabled
    healthy_threshold   = each.value.health_check.healthy_threshold
    unhealthy_threshold = each.value.health_check.unhealthy_threshold
    timeout             = each.value.health_check.timeout
    interval            = each.value.health_check.interval
    path                = each.value.health_check.path
    matcher             = each.value.health_check.matcher
    port                = each.value.health_check.port
    protocol            = each.value.health_check.protocol
  }

  # Stickiness Configuration
  dynamic "stickiness" {
    for_each = each.value.stickiness != null ? [each.value.stickiness] : []
    content {
      type            = stickiness.value.type
      cookie_duration = stickiness.value.cookie_duration
      cookie_name     = stickiness.value.cookie_name
      enabled         = stickiness.value.enabled
    }
  }

  # Connection termination
  deregistration_delay               = each.value.deregistration_delay
  slow_start                        = each.value.slow_start
  load_balancing_algorithm_type     = each.value.load_balancing_algorithm_type
  preserve_client_ip               = each.value.preserve_client_ip
  protocol_version                 = each.value.protocol_version

  tags = merge(
    var.tags,
    each.value.tags,
    {
      Name = each.value.name
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# HTTP Listener (Redirect to HTTPS)
resource "aws_lb_listener" "http_redirect" {
  count             = var.create_http_listener ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = var.tags
}

# HTTP Listener (Forward to Target Group)
resource "aws_lb_listener" "http_forward" {
  count             = var.create_http_listener && var.http_listener_forward ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main[var.default_target_group].arn
  }

  tags = var.tags
}

# HTTPS Listener
resource "aws_lb_listener" "https" {
  count             = var.create_https_listener ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main[var.default_target_group].arn
  }

  tags = var.tags
}

# Additional SSL Certificates
resource "aws_lb_listener_certificate" "additional_certs" {
  for_each = var.additional_certificate_arns

  listener_arn    = aws_lb_listener.https[0].arn
  certificate_arn = each.value
}

# Listener Rules for HTTP
resource "aws_lb_listener_rule" "http" {
  for_each = var.create_http_listener && var.http_listener_forward ? var.listener_rules : {}

  listener_arn = aws_lb_listener.http_forward[0].arn
  priority     = each.value.priority

  action {
    type             = each.value.action.type
    target_group_arn = each.value.action.type == "forward" ? aws_lb_target_group.main[each.value.action.target_group_key].arn : null

    # Fixed Response
    dynamic "fixed_response" {
      for_each = each.value.action.type == "fixed-response" ? [each.value.action.fixed_response] : []
      content {
        content_type = fixed_response.value.content_type
        message_body = fixed_response.value.message_body
        status_code  = fixed_response.value.status_code
      }
    }

    # Redirect
    dynamic "redirect" {
      for_each = each.value.action.type == "redirect" ? [each.value.action.redirect] : []
      content {
        host        = redirect.value.host
        path        = redirect.value.path
        port        = redirect.value.port
        protocol    = redirect.value.protocol
        query       = redirect.value.query
        status_code = redirect.value.status_code
      }
    }
  }

  # Path Pattern Condition
  dynamic "condition" {
    for_each = each.value.conditions
    content {
      dynamic "path_pattern" {
        for_each = condition.value.field == "path-pattern" ? [condition.value] : []
        content {
          values = path_pattern.value.values
        }
      }

      dynamic "host_header" {
        for_each = condition.value.field == "host-header" ? [condition.value] : []
        content {
          values = host_header.value.values
        }
      }

      dynamic "http_header" {
        for_each = condition.value.field == "http-header" ? [condition.value] : []
        content {
          http_header_name = http_header.value.http_header_name
          values           = http_header.value.values
        }
      }

      dynamic "query_string" {
        for_each = condition.value.field == "query-string" ? condition.value.query_string : []
        content {
          key   = query_string.value.key
          value = query_string.value.value
        }
      }

      dynamic "http_request_method" {
        for_each = condition.value.field == "http-request-method" ? [condition.value] : []
        content {
          values = http_request_method.value.values
        }
      }

      dynamic "source_ip" {
        for_each = condition.value.field == "source-ip" ? [condition.value] : []
        content {
          values = source_ip.value.values
        }
      }
    }
  }

  tags = var.tags
}

# Listener Rules for HTTPS
resource "aws_lb_listener_rule" "https" {
  for_each = var.create_https_listener ? var.listener_rules : {}

  listener_arn = aws_lb_listener.https[0].arn
  priority     = each.value.priority

  action {
    type             = each.value.action.type
    target_group_arn = each.value.action.type == "forward" ? aws_lb_target_group.main[each.value.action.target_group_key].arn : null

    # Fixed Response
    dynamic "fixed_response" {
      for_each = each.value.action.type == "fixed-response" ? [each.value.action.fixed_response] : []
      content {
        content_type = fixed_response.value.content_type
        message_body = fixed_response.value.message_body
        status_code  = fixed_response.value.status_code
      }
    }

    # Redirect
    dynamic "redirect" {
      for_each = each.value.action.type == "redirect" ? [each.value.action.redirect] : []
      content {
        host        = redirect.value.host
        path        = redirect.value.path
        port        = redirect.value.port
        protocol    = redirect.value.protocol
        query       = redirect.value.query
        status_code = redirect.value.status_code
      }
    }
  }

  # Conditions
  dynamic "condition" {
    for_each = each.value.conditions
    content {
      dynamic "path_pattern" {
        for_each = condition.value.field == "path-pattern" ? [condition.value] : []
        content {
          values = path_pattern.value.values
        }
      }

      dynamic "host_header" {
        for_each = condition.value.field == "host-header" ? [condition.value] : []
        content {
          values = host_header.value.values
        }
      }

      dynamic "http_header" {
        for_each = condition.value.field == "http-header" ? [condition.value] : []
        content {
          http_header_name = http_header.value.http_header_name
          values           = http_header.value.values
        }
      }

      dynamic "query_string" {
        for_each = condition.value.field == "query-string" ? condition.value.query_string : []
        content {
          key   = query_string.value.key
          value = query_string.value.value
        }
      }

      dynamic "http_request_method" {
        for_each = condition.value.field == "http-request-method" ? [condition.value] : []
        content {
          values = http_request_method.value.values
        }
      }

      dynamic "source_ip" {
        for_each = condition.value.field == "source-ip" ? [condition.value] : []
        content {
          values = source_ip.value.values
        }
      }
    }
  }

  tags = var.tags
}

# Target Group Attachments
resource "aws_lb_target_group_attachment" "main" {
  for_each = var.target_attachments

  target_group_arn = aws_lb_target_group.main[each.value.target_group_key].arn
  target_id        = each.value.target_id
  port             = each.value.port
  availability_zone = each.value.availability_zone
}