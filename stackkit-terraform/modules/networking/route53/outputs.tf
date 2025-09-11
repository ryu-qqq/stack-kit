# Route53 DNS Management Module Outputs

# Delegation Set Outputs
output "delegation_set_id" {
  description = "The delegation set ID"
  value       = var.create_delegation_set ? aws_route53_delegation_set.main[0].id : null
}

output "delegation_set_name_servers" {
  description = "List of authoritative name servers for the delegation set"
  value       = var.create_delegation_set ? aws_route53_delegation_set.main[0].name_servers : null
}

output "delegation_set_reference_name" {
  description = "The reference name for the delegation set"
  value       = var.create_delegation_set ? aws_route53_delegation_set.main[0].reference_name : null
}

# Public Hosted Zone Outputs
output "public_zone_ids" {
  description = "Map of public zone names to their zone IDs"
  value = {
    for name, zone in aws_route53_zone.public : name => zone.zone_id
  }
}

output "public_zone_name_servers" {
  description = "Map of public zone names to their name servers"
  value = {
    for name, zone in aws_route53_zone.public : name => zone.name_servers
  }
}

output "public_zone_arns" {
  description = "Map of public zone names to their ARNs"
  value = {
    for name, zone in aws_route53_zone.public : name => zone.arn
  }
}

output "public_zones" {
  description = "Map of all public hosted zone details"
  value = {
    for name, zone in aws_route53_zone.public : name => {
      zone_id      = zone.zone_id
      name_servers = zone.name_servers
      arn          = zone.arn
      comment      = zone.comment
      tags         = zone.tags
    }
  }
}

# Private Hosted Zone Outputs
output "private_zone_ids" {
  description = "Map of private zone names to their zone IDs"
  value = {
    for name, zone in aws_route53_zone.private : name => zone.zone_id
  }
}

output "private_zone_arns" {
  description = "Map of private zone names to their ARNs"
  value = {
    for name, zone in aws_route53_zone.private : name => zone.arn
  }
}

output "private_zones" {
  description = "Map of all private hosted zone details"
  value = {
    for name, zone in aws_route53_zone.private : name => {
      zone_id = zone.zone_id
      arn     = zone.arn
      comment = zone.comment
      tags    = zone.tags
      vpc     = zone.vpc
    }
  }
}

# All Zones (Combined)
output "all_zone_ids" {
  description = "Map of all zone names to their zone IDs (public and private)"
  value = merge(
    { for name, zone in aws_route53_zone.public : name => zone.zone_id },
    { for name, zone in aws_route53_zone.private : name => zone.zone_id }
  )
}

# DNS Records Outputs
output "public_record_names" {
  description = "List of all public DNS record names created"
  value = [
    for record in aws_route53_record.public : record.name
  ]
}

output "private_record_names" {
  description = "List of all private DNS record names created"
  value = [
    for record in aws_route53_record.private : record.name
  ]
}

output "public_records" {
  description = "Map of all public DNS records created"
  value = {
    for key, record in aws_route53_record.public : key => {
      name    = record.name
      type    = record.type
      ttl     = record.ttl
      records = record.records
      fqdn    = record.fqdn
      zone_id = record.zone_id
    }
  }
}

output "private_records" {
  description = "Map of all private DNS records created"
  value = {
    for key, record in aws_route53_record.private : key => {
      name    = record.name
      type    = record.type
      ttl     = record.ttl
      records = record.records
      fqdn    = record.fqdn
      zone_id = record.zone_id
    }
  }
}

# Health Check Outputs
output "health_check_ids" {
  description = "Map of health check names to their IDs"
  value = {
    for name, hc in aws_route53_health_check.main : name => hc.id
  }
}

output "health_check_arns" {
  description = "Map of health check names to their ARNs"
  value = {
    for name, hc in aws_route53_health_check.main : name => hc.arn
  }
}

output "health_checks" {
  description = "Map of all health check details"
  value = {
    for name, hc in aws_route53_health_check.main : name => {
      id                   = hc.id
      arn                  = hc.arn
      type                 = hc.type
      fqdn                 = hc.fqdn
      port                 = hc.port
      resource_path        = hc.resource_path
      failure_threshold    = hc.failure_threshold
      request_interval     = hc.request_interval
      cloudwatch_alarm_arn = hc.cloudwatch_alarm_arn
      tags                 = hc.tags
    }
  }
}

# Query Logging Outputs
output "query_log_group_names" {
  description = "Map of query logging config names to their CloudWatch log group names"
  value = {
    for name, lg in aws_cloudwatch_log_group.dns_log_group : name => lg.name
  }
}

output "query_log_group_arns" {
  description = "Map of query logging config names to their CloudWatch log group ARNs"
  value = {
    for name, lg in aws_cloudwatch_log_group.dns_log_group : name => lg.arn
  }
}

output "query_logging_config_ids" {
  description = "Map of query logging config names to their Route53 query log IDs"
  value = {
    for name, ql in aws_route53_query_log.main : name => ql.id
  }
}

# DNSSEC Outputs
output "dnssec_key_signing_keys" {
  description = "Map of DNSSEC configurations to their key signing key details"
  value = {
    for name, ksk in aws_route53_key_signing_key.main : name => {
      name                       = ksk.name
      status                     = ksk.status
      flag                       = ksk.flag
      signing_algorithm_mnemonic = ksk.signing_algorithm_mnemonic
      signing_algorithm_type     = ksk.signing_algorithm_type
      digest_algorithm_mnemonic  = ksk.digest_algorithm_mnemonic
      digest_algorithm_type      = ksk.digest_algorithm_type
      digest_value               = ksk.digest_value
      ds_record                  = ksk.ds_record
      dnskey_record              = ksk.dnskey_record
      key_tag                    = ksk.key_tag
      public_key                 = ksk.public_key
    }
  }
}

output "dnssec_status" {
  description = "Map of DNSSEC configurations to their signing status"
  value = {
    for name, dnssec in aws_route53_hosted_zone_dnssec.main : name => {
      hosted_zone_id = dnssec.hosted_zone_id
      signing_status = dnssec.signing_status
    }
  }
}

# Resolver Endpoint Outputs
output "resolver_endpoint_ids" {
  description = "Map of resolver endpoint names to their IDs"
  value = merge(
    { for name, ep in aws_route53_resolver_endpoint.inbound : "${name}-inbound" => ep.id },
    { for name, ep in aws_route53_resolver_endpoint.outbound : "${name}-outbound" => ep.id }
  )
}

output "resolver_endpoint_ips" {
  description = "Map of resolver endpoint names to their IP addresses"
  value = merge(
    { 
      for name, ep in aws_route53_resolver_endpoint.inbound : "${name}-inbound" => [
        for ip in ep.ip_address : ip.ip
      ]
    },
    { 
      for name, ep in aws_route53_resolver_endpoint.outbound : "${name}-outbound" => [
        for ip in ep.ip_address : ip.ip
      ]
    }
  )
}

# Resolver Rule Outputs
output "resolver_rule_ids" {
  description = "Map of resolver rule names to their IDs"
  value = {
    for name, rule in aws_route53_resolver_rule.main : name => rule.id
  }
}

output "resolver_rule_arns" {
  description = "Map of resolver rule names to their ARNs"
  value = {
    for name, rule in aws_route53_resolver_rule.main : name => rule.arn
  }
}

# Traffic Policy Outputs
output "traffic_policy_ids" {
  description = "Map of traffic policy names to their IDs"
  value = {
    for name, tp in aws_route53_traffic_policy.main : name => tp.id
  }
}

output "traffic_policy_versions" {
  description = "Map of traffic policy names to their current versions"
  value = {
    for name, tp in aws_route53_traffic_policy.main : name => tp.version
  }
}

output "traffic_policy_instance_ids" {
  description = "Map of traffic policy instance names to their IDs"
  value = {
    for name, tpi in aws_route53_traffic_policy_instance.main : name => tpi.id
  }
}

# Summary Outputs
output "zone_count" {
  description = "Total number of hosted zones created"
  value = {
    public  = length(aws_route53_zone.public)
    private = length(aws_route53_zone.private)
    total   = length(aws_route53_zone.public) + length(aws_route53_zone.private)
  }
}

output "record_count" {
  description = "Total number of DNS records created"
  value = {
    public  = length(aws_route53_record.public)
    private = length(aws_route53_record.private)
    total   = length(aws_route53_record.public) + length(aws_route53_record.private)
  }
}

output "health_check_count" {
  description = "Total number of health checks created"
  value = length(aws_route53_health_check.main)
}

# Zone details for cross-module reference
output "zone_details" {
  description = "Detailed information about all zones for cross-module reference"
  value = {
    public = {
      for name, zone in aws_route53_zone.public : name => {
        id           = zone.zone_id
        name         = zone.name
        name_servers = zone.name_servers
        arn          = zone.arn
        type         = "public"
      }
    }
    private = {
      for name, zone in aws_route53_zone.private : name => {
        id   = zone.zone_id
        name = zone.name
        arn  = zone.arn
        type = "private"
        vpcs = zone.vpc
      }
    }
  }
}