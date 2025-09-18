# =======================================
# Application Load Balancer Module
# =======================================
# Load balancer configuration following StackKit standards

# Application Load Balancer
resource "aws_lb" "atlantis" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [local.alb_security_group_id]
  subnets            = local.public_subnet_ids

  enable_deletion_protection       = var.enable_deletion_protection
  enable_http2                     = true
  enable_cross_zone_load_balancing = true

  tags = local.common_tags
}

# Target Group for Atlantis service (standard deployment)
resource "aws_lb_target_group" "atlantis" {
  name        = "${local.name_prefix}-tg"
  port        = var.atlantis_port
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = var.health_check_interval
    path                = var.health_check_path
    matcher             = "200"
    protocol            = "HTTP"
  }

  # Faster deregistration for ECS tasks
  deregistration_delay = 30

  # Session stickiness for Atlantis UI
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true
  }

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# Blue Target Group for Blue/Green deployment
resource "aws_lb_target_group" "atlantis_blue" {
  name        = "${local.name_prefix}-tg-blue"
  port        = var.atlantis_port
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = var.health_check_interval
    path                = var.health_check_path
    matcher             = "200"
    protocol            = "HTTP"
  }

  deregistration_delay = 30

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true
  }

  tags = merge(
    local.common_tags,
    {
      Color = "blue"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Green Target Group for Blue/Green deployment
resource "aws_lb_target_group" "atlantis_green" {
  name        = "${local.name_prefix}-tg-green"
  port        = var.atlantis_port
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = var.health_check_interval
    path                = var.health_check_path
    matcher             = "200"
    protocol            = "HTTP"
  }

  deregistration_delay = 30

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true
  }

  tags = merge(
    local.common_tags,
    {
      Color = "green"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# HTTP Listener - redirects to HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.atlantis.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.atlantis.arn
  }

  tags = local.common_tags
}

# HTTPS Listener - conditional on certificate availability
resource "aws_lb_listener" "https" {
  count = var.certificate_arn != "" ? 1 : 0

  load_balancer_arn = aws_lb.atlantis.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.atlantis.arn
  }

  tags = local.common_tags
}

# Additional SSL certificates for multi-domain support
resource "aws_lb_listener_certificate" "additional" {
  for_each = toset(var.additional_certificate_arns)

  listener_arn    = aws_lb_listener.https[0].arn
  certificate_arn = each.value

  depends_on = [aws_lb_listener.https]
}
