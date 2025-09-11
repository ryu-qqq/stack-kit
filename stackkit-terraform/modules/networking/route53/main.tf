# Route53 DNS Management Module
# This module provides comprehensive Route53 DNS management including hosted zones, records, health checks, and DNSSEC

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Get current AWS caller identity for account ID
data "aws_caller_identity" "current" {}

# Get current AWS region
data "aws_region" "current" {}

# Delegation set for reusable name servers
resource "aws_route53_delegation_set" "main" {
  count           = var.create_delegation_set ? 1 : 0
  reference_name  = var.delegation_set_reference_name

  tags = merge(
    var.tags,
    {
      Name        = "${var.name_prefix}-delegation-set"
      Environment = var.environment
      Module      = "route53"
    }
  )
}

# Public hosted zones
resource "aws_route53_zone" "public" {
  for_each = var.public_zones

  name              = each.key
  comment           = each.value.comment
  delegation_set_id = var.create_delegation_set ? aws_route53_delegation_set.main[0].id : each.value.delegation_set_id
  force_destroy     = each.value.force_destroy

  dynamic "vpc" {
    for_each = each.value.associate_with_vpcs
    content {
      vpc_id     = vpc.value.vpc_id
      vpc_region = vpc.value.vpc_region
    }
  }

  tags = merge(
    var.tags,
    each.value.tags,
    {
      Name        = each.key
      Environment = var.environment
      Type        = "public"
      Module      = "route53"
    }
  )
}

# Private hosted zones
resource "aws_route53_zone" "private" {
  for_each = var.private_zones

  name          = each.key
  comment       = each.value.comment
  force_destroy = each.value.force_destroy

  dynamic "vpc" {
    for_each = each.value.vpcs
    content {
      vpc_id     = vpc.value.vpc_id
      vpc_region = vpc.value.vpc_region
    }
  }

  tags = merge(
    var.tags,
    each.value.tags,
    {
      Name        = each.key
      Environment = var.environment
      Type        = "private"
      Module      = "route53"
    }
  )
}

# DNS Records for Public Zones
resource "aws_route53_record" "public" {
  for_each = {
    for record in var.public_records : "${record.zone_name}-${record.name}-${record.type}" => record
  }

  zone_id         = aws_route53_zone.public[each.value.zone_name].zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = each.value.ttl
  records         = each.value.records
  health_check_id = lookup(each.value, "health_check_id", null)
  set_identifier  = lookup(each.value, "set_identifier", null)

  dynamic "alias" {
    for_each = lookup(each.value, "alias", null) != null ? [each.value.alias] : []
    content {
      name                   = alias.value.name
      zone_id                = alias.value.zone_id
      evaluate_target_health = alias.value.evaluate_target_health
    }
  }

  dynamic "weighted_routing_policy" {
    for_each = lookup(each.value, "weighted_routing_policy", null) != null ? [each.value.weighted_routing_policy] : []
    content {
      weight = weighted_routing_policy.value.weight
    }
  }

  dynamic "latency_routing_policy" {
    for_each = lookup(each.value, "latency_routing_policy", null) != null ? [each.value.latency_routing_policy] : []
    content {
      region = latency_routing_policy.value.region
    }
  }

  dynamic "geolocation_routing_policy" {
    for_each = lookup(each.value, "geolocation_routing_policy", null) != null ? [each.value.geolocation_routing_policy] : []
    content {
      continent   = lookup(geolocation_routing_policy.value, "continent", null)
      country     = lookup(geolocation_routing_policy.value, "country", null)
      subdivision = lookup(geolocation_routing_policy.value, "subdivision", null)
    }
  }

  dynamic "failover_routing_policy" {
    for_each = lookup(each.value, "failover_routing_policy", null) != null ? [each.value.failover_routing_policy] : []
    content {
      type = failover_routing_policy.value.type
    }
  }

  dynamic "multivalue_answer_routing_policy" {
    for_each = lookup(each.value, "multivalue_answer_routing_policy", null) != null ? [true] : []
    content {}
  }
}

# DNS Records for Private Zones
resource "aws_route53_record" "private" {
  for_each = {
    for record in var.private_records : "${record.zone_name}-${record.name}-${record.type}" => record
  }

  zone_id         = aws_route53_zone.private[each.value.zone_name].zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = each.value.ttl
  records         = each.value.records
  health_check_id = lookup(each.value, "health_check_id", null)
  set_identifier  = lookup(each.value, "set_identifier", null)

  dynamic "alias" {
    for_each = lookup(each.value, "alias", null) != null ? [each.value.alias] : []
    content {
      name                   = alias.value.name
      zone_id                = alias.value.zone_id
      evaluate_target_health = alias.value.evaluate_target_health
    }
  }

  dynamic "weighted_routing_policy" {
    for_each = lookup(each.value, "weighted_routing_policy", null) != null ? [each.value.weighted_routing_policy] : []
    content {
      weight = weighted_routing_policy.value.weight
    }
  }

  dynamic "latency_routing_policy" {
    for_each = lookup(each.value, "latency_routing_policy", null) != null ? [each.value.latency_routing_policy] : []
    content {
      region = latency_routing_policy.value.region
    }
  }

  dynamic "geolocation_routing_policy" {
    for_each = lookup(each.value, "geolocation_routing_policy", null) != null ? [each.value.geolocation_routing_policy] : []
    content {
      continent   = lookup(geolocation_routing_policy.value, "continent", null)
      country     = lookup(geolocation_routing_policy.value, "country", null)
      subdivision = lookup(geolocation_routing_policy.value, "subdivision", null)
    }
  }

  dynamic "failover_routing_policy" {
    for_each = lookup(each.value, "failover_routing_policy", null) != null ? [each.value.failover_routing_policy] : []
    content {
      type = failover_routing_policy.value.type
    }
  }

  dynamic "multivalue_answer_routing_policy" {
    for_each = lookup(each.value, "multivalue_answer_routing_policy", null) != null ? [true] : []
    content {}
  }
}

# Health Checks
resource "aws_route53_health_check" "main" {
  for_each = var.health_checks

  type                            = each.value.type
  resource_path                   = lookup(each.value, "resource_path", null)
  failure_threshold               = lookup(each.value, "failure_threshold", 3)
  request_interval                = lookup(each.value, "request_interval", 30)
  port                            = lookup(each.value, "port", null)
  measure_latency                 = lookup(each.value, "measure_latency", false)
  invert_healthcheck              = lookup(each.value, "invert_healthcheck", false)
  disabled                        = lookup(each.value, "disabled", false)
  enable_sni                      = lookup(each.value, "enable_sni", true)
  search_string                   = lookup(each.value, "search_string", null)
  insufficient_data_health_status = lookup(each.value, "insufficient_data_health_status", "Failure")

  # For HTTP/HTTPS health checks
  fqdn = lookup(each.value, "fqdn", null)

  # For calculated health checks
  child_health_checks                 = lookup(each.value, "child_health_checks", null)
  child_health_threshold              = lookup(each.value, "child_health_threshold", null)
  cloudwatch_alarm_region             = lookup(each.value, "cloudwatch_alarm_region", null)
  cloudwatch_alarm_name               = lookup(each.value, "cloudwatch_alarm_name", null)
  reference_name                      = lookup(each.value, "reference_name", null)

  tags = merge(
    var.tags,
    lookup(each.value, "tags", {}),
    {
      Name        = each.key
      Environment = var.environment
      Module      = "route53"
    }
  )
}

# CloudWatch Log Group for DNS Query Logging
resource "aws_cloudwatch_log_group" "dns_log_group" {
  for_each = var.query_logging_configs

  name              = "/aws/route53/${each.key}"
  retention_in_days = each.value.retention_in_days
  kms_key_id        = lookup(each.value, "kms_key_id", null)

  tags = merge(
    var.tags,
    {
      Name        = "/aws/route53/${each.key}"
      Environment = var.environment
      Module      = "route53"
      Purpose     = "dns-query-logging"
    }
  )
}

# CloudWatch Log Resource Policy for Route53
resource "aws_cloudwatch_log_resource_policy" "route53_query_logging_policy" {
  count = length(var.query_logging_configs) > 0 ? 1 : 0

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "route53.amazonaws.com"
        }
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:/aws/route53/*"
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:route53:::hostedzone/*"
          }
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })

  policy_name = "${var.name_prefix}-route53-query-logging-policy"
}

# Query Logging Configuration
resource "aws_route53_query_log" "main" {
  for_each = var.query_logging_configs

  depends_on = [
    aws_cloudwatch_log_resource_policy.route53_query_logging_policy
  ]

  destination_arn = aws_cloudwatch_log_group.dns_log_group[each.key].arn
  zone_id         = each.value.zone_type == "public" ? aws_route53_zone.public[each.value.zone_name].zone_id : aws_route53_zone.private[each.value.zone_name].zone_id
}

# DNSSEC Key Signing Key (KSK)
resource "aws_route53_key_signing_key" "main" {
  for_each = var.dnssec_configs

  hosted_zone_id             = aws_route53_zone.public[each.value.zone_name].id
  key_management_service_arn = each.value.kms_key_arn
  name                       = each.value.name
  status                     = each.value.status
}

# DNSSEC
resource "aws_route53_hosted_zone_dnssec" "main" {
  for_each = var.dnssec_configs

  depends_on = [
    aws_route53_key_signing_key.main
  ]

  hosted_zone_id = aws_route53_key_signing_key.main[each.key].hosted_zone_id
  signing_status = each.value.signing_status
}

# VPC Association Authorization (for cross-account private zones)
resource "aws_route53_vpc_association_authorization" "main" {
  for_each = var.vpc_association_authorizations

  zone_id = each.value.zone_type == "public" ? aws_route53_zone.public[each.value.zone_name].zone_id : aws_route53_zone.private[each.value.zone_name].zone_id
  vpc_id  = each.value.vpc_id
}

# Resolver Rules (for hybrid DNS)
resource "aws_route53_resolver_rule" "main" {
  for_each = var.resolver_rules

  domain_name          = each.value.domain_name
  name                 = each.key
  rule_type            = each.value.rule_type
  resolver_endpoint_id = each.value.resolver_endpoint_id

  dynamic "target_ip" {
    for_each = lookup(each.value, "target_ips", [])
    content {
      ip   = target_ip.value.ip
      port = lookup(target_ip.value, "port", 53)
    }
  }

  tags = merge(
    var.tags,
    lookup(each.value, "tags", {}),
    {
      Name        = each.key
      Environment = var.environment
      Module      = "route53"
    }
  )
}

# Resolver Rule Associations
resource "aws_route53_resolver_rule_association" "main" {
  for_each = var.resolver_rule_associations

  resolver_rule_id = aws_route53_resolver_rule.main[each.value.resolver_rule_name].id
  vpc_id           = each.value.vpc_id
  name             = each.key
}

# Resolver Endpoints (for hybrid DNS)
resource "aws_route53_resolver_endpoint" "inbound" {
  for_each = var.resolver_endpoints.inbound

  name      = each.key
  direction = "INBOUND"

  security_group_ids = each.value.security_group_ids

  dynamic "ip_address" {
    for_each = each.value.ip_addresses
    content {
      subnet_id = ip_address.value.subnet_id
      ip        = lookup(ip_address.value, "ip", null)
    }
  }

  tags = merge(
    var.tags,
    lookup(each.value, "tags", {}),
    {
      Name        = each.key
      Environment = var.environment
      Direction   = "inbound"
      Module      = "route53"
    }
  )
}

resource "aws_route53_resolver_endpoint" "outbound" {
  for_each = var.resolver_endpoints.outbound

  name      = each.key
  direction = "OUTBOUND"

  security_group_ids = each.value.security_group_ids

  dynamic "ip_address" {
    for_each = each.value.ip_addresses
    content {
      subnet_id = ip_address.value.subnet_id
      ip        = lookup(ip_address.value, "ip", null)
    }
  }

  tags = merge(
    var.tags,
    lookup(each.value, "tags", {}),
    {
      Name        = each.key
      Environment = var.environment
      Direction   = "outbound"
      Module      = "route53"
    }
  )
}

# Traffic Policy (for advanced routing)
resource "aws_route53_traffic_policy" "main" {
  for_each = var.traffic_policies

  name     = each.key
  comment  = lookup(each.value, "comment", "Managed by Terraform")
  document = each.value.document
}

# Traffic Policy Instance
resource "aws_route53_traffic_policy_instance" "main" {
  for_each = var.traffic_policy_instances

  name                   = each.value.name
  traffic_policy_id      = aws_route53_traffic_policy.main[each.value.traffic_policy_name].id
  traffic_policy_version = each.value.traffic_policy_version
  hosted_zone_id         = each.value.zone_type == "public" ? aws_route53_zone.public[each.value.zone_name].zone_id : aws_route53_zone.private[each.value.zone_name].zone_id
  ttl                    = each.value.ttl
}