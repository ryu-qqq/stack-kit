# Load Balancer Outputs
output "alb_id" {
  description = "The ID and ARN of the load balancer we created"
  value       = aws_lb.main.id
}

output "alb_arn" {
  description = "The ID and ARN of the load balancer we created"
  value       = aws_lb.main.arn
}

output "alb_arn_suffix" {
  description = "ARN suffix of our load balancer - can be used with CloudWatch"
  value       = aws_lb.main.arn_suffix
}

output "alb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "alb_canonical_hosted_zone_id" {
  description = "The canonical hosted zone ID of the load balancer (to be used in a Route 53 Alias record)"
  value       = aws_lb.main.zone_id
}

output "alb_hosted_zone_id" {
  description = "The canonical hosted zone ID of the load balancer (to be used in a Route 53 Alias record)"
  value       = aws_lb.main.zone_id
}

output "alb_security_groups" {
  description = "The security groups attached to the load balancer"
  value       = aws_lb.main.security_groups
}

output "alb_vpc_id" {
  description = "The VPC ID of the load balancer"
  value       = aws_lb.main.vpc_id
}

output "alb_subnets" {
  description = "The subnets attached to the load balancer"
  value       = aws_lb.main.subnets
}

output "alb_internal" {
  description = "Whether the load balancer is internal or external"
  value       = aws_lb.main.internal
}

# Target Group Outputs
output "target_group_arns" {
  description = "ARNs of the target groups. Useful for passing to your Auto Scaling group"
  value       = { for k, v in aws_lb_target_group.main : k => v.arn }
}

output "target_group_arn_suffixes" {
  description = "ARN suffixes of our target groups - can be used with CloudWatch"
  value       = { for k, v in aws_lb_target_group.main : k => v.arn_suffix }
}

output "target_group_names" {
  description = "Names of the target groups. Useful for passing to your CodeDeploy Deployment Group"
  value       = { for k, v in aws_lb_target_group.main : k => v.name }
}

output "target_group_health_check_paths" {
  description = "Health check paths of target groups"
  value       = { for k, v in aws_lb_target_group.main : k => v.health_check[0].path }
}

output "target_group_health_check_ports" {
  description = "Health check ports of target groups"
  value       = { for k, v in aws_lb_target_group.main : k => v.health_check[0].port }
}

# Listener Outputs
output "http_listener_arns" {
  description = "The ARNs of the HTTP load balancer listeners created"
  value = {
    redirect = var.create_http_listener && !var.http_listener_forward ? aws_lb_listener.http_redirect[0].arn : null
    forward  = var.create_http_listener && var.http_listener_forward ? aws_lb_listener.http_forward[0].arn : null
  }
}

output "https_listener_arn" {
  description = "The ARN of the HTTPS load balancer listener created"
  value       = var.create_https_listener ? aws_lb_listener.https[0].arn : null
}

output "listener_rule_arns" {
  description = "The ARNs of the listener rules"
  value = merge(
    { for k, v in aws_lb_listener_rule.http : "http_${k}" => v.arn },
    { for k, v in aws_lb_listener_rule.https : "https_${k}" => v.arn }
  )
}

# DNS and Load Balancer Information for Route 53
output "route53_alias_dns_name" {
  description = "DNS name for Route 53 alias record"
  value       = aws_lb.main.dns_name
}

output "route53_alias_zone_id" {
  description = "Zone ID for Route 53 alias record"
  value       = aws_lb.main.zone_id
}

# Load Balancer Attributes
output "access_logs_enabled" {
  description = "Whether access logs are enabled"
  value       = var.access_logs_enabled
}

output "access_logs_bucket" {
  description = "S3 bucket for access logs"
  value       = var.access_logs_bucket
}

output "connection_logs_enabled" {
  description = "Whether connection logs are enabled"
  value       = var.connection_logs_enabled
}

output "connection_logs_bucket" {
  description = "S3 bucket for connection logs"
  value       = var.connection_logs_bucket
}

# Security and Configuration
output "deletion_protection_enabled" {
  description = "Whether deletion protection is enabled"
  value       = aws_lb.main.enable_deletion_protection
}

output "cross_zone_load_balancing_enabled" {
  description = "Whether cross-zone load balancing is enabled"
  value       = aws_lb.main.enable_cross_zone_load_balancing
}

output "http2_enabled" {
  description = "Whether HTTP/2 is enabled"
  value       = aws_lb.main.enable_http2
}

# SSL Configuration
output "ssl_policy" {
  description = "The SSL policy used by the HTTPS listener"
  value       = var.create_https_listener ? var.ssl_policy : null
}

output "certificate_arn" {
  description = "The ARN of the SSL certificate used by the HTTPS listener"
  value       = var.create_https_listener ? var.certificate_arn : null
}

# Target Group Attachment Information
output "target_attachments" {
  description = "Information about target group attachments"
  value = {
    for k, v in aws_lb_target_group_attachment.main : k => {
      target_group_arn = v.target_group_arn
      target_id        = v.target_id
      port             = v.port
    }
  }
}