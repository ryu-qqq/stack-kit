# Route53 DNS Management Module Variables

variable "name_prefix" {
  description = "Prefix for naming resources"
  type        = string
  default     = "stackkit"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "A map of tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Delegation Set Configuration
variable "create_delegation_set" {
  description = "Whether to create a reusable delegation set"
  type        = bool
  default     = false
}

variable "delegation_set_reference_name" {
  description = "Reference name for the delegation set"
  type        = string
  default     = null
}

# Public Hosted Zones
variable "public_zones" {
  description = "Map of public hosted zones to create"
  type = map(object({
    comment           = optional(string, "Managed by Terraform")
    delegation_set_id = optional(string, null)
    force_destroy     = optional(bool, false)
    associate_with_vpcs = optional(list(object({
      vpc_id     = string
      vpc_region = optional(string, null)
    })), [])
    tags = optional(map(string), {})
  }))
  default = {}
}

# Private Hosted Zones
variable "private_zones" {
  description = "Map of private hosted zones to create"
  type = map(object({
    comment       = optional(string, "Managed by Terraform")
    force_destroy = optional(bool, false)
    vpcs = list(object({
      vpc_id     = string
      vpc_region = optional(string, null)
    }))
    tags = optional(map(string), {})
  }))
  default = {}
}

# Public DNS Records
variable "public_records" {
  description = "List of DNS records to create in public zones"
  type = list(object({
    zone_name       = string
    name            = string
    type            = string
    ttl             = optional(number, 300)
    records         = optional(list(string), [])
    health_check_id = optional(string, null)
    set_identifier  = optional(string, null)
    
    # Alias configuration
    alias = optional(object({
      name                   = string
      zone_id                = string
      evaluate_target_health = optional(bool, false)
    }), null)
    
    # Routing policies
    weighted_routing_policy = optional(object({
      weight = number
    }), null)
    
    latency_routing_policy = optional(object({
      region = string
    }), null)
    
    geolocation_routing_policy = optional(object({
      continent   = optional(string, null)
      country     = optional(string, null)
      subdivision = optional(string, null)
    }), null)
    
    failover_routing_policy = optional(object({
      type = string # PRIMARY or SECONDARY
    }), null)
    
    multivalue_answer_routing_policy = optional(bool, false)
  }))
  default = []
}

# Private DNS Records
variable "private_records" {
  description = "List of DNS records to create in private zones"
  type = list(object({
    zone_name       = string
    name            = string
    type            = string
    ttl             = optional(number, 300)
    records         = optional(list(string), [])
    health_check_id = optional(string, null)
    set_identifier  = optional(string, null)
    
    # Alias configuration
    alias = optional(object({
      name                   = string
      zone_id                = string
      evaluate_target_health = optional(bool, false)
    }), null)
    
    # Routing policies
    weighted_routing_policy = optional(object({
      weight = number
    }), null)
    
    latency_routing_policy = optional(object({
      region = string
    }), null)
    
    geolocation_routing_policy = optional(object({
      continent   = optional(string, null)
      country     = optional(string, null)
      subdivision = optional(string, null)
    }), null)
    
    failover_routing_policy = optional(object({
      type = string # PRIMARY or SECONDARY
    }), null)
    
    multivalue_answer_routing_policy = optional(bool, false)
  }))
  default = []
}

# Health Checks
variable "health_checks" {
  description = "Map of health checks to create"
  type = map(object({
    type                                = string # HTTP, HTTPS, HTTP_STR_MATCH, HTTPS_STR_MATCH, TCP, CALCULATED, CLOUDWATCH_METRIC, RECOVERY_CONTROL
    fqdn                                = optional(string, null)
    port                                = optional(number, null)
    resource_path                       = optional(string, "/")
    failure_threshold                   = optional(number, 3)
    request_interval                    = optional(number, 30) # 10 or 30
    measure_latency                     = optional(bool, false)
    invert_healthcheck                  = optional(bool, false)
    disabled                            = optional(bool, false)
    enable_sni                          = optional(bool, true)
    search_string                       = optional(string, null)
    insufficient_data_health_status     = optional(string, "Failure") # Success, Failure, LastKnownStatus
    
    # For calculated health checks
    child_health_checks     = optional(list(string), null)
    child_health_threshold  = optional(number, null)
    
    # For CloudWatch alarm health checks
    cloudwatch_alarm_region = optional(string, null)
    cloudwatch_alarm_name   = optional(string, null)
    reference_name          = optional(string, null)
    
    tags = optional(map(string), {})
  }))
  default = {}
}

# Query Logging Configuration
variable "query_logging_configs" {
  description = "Map of DNS query logging configurations"
  type = map(object({
    zone_name         = string
    zone_type         = string # public or private
    retention_in_days = optional(number, 14)
    kms_key_id        = optional(string, null)
  }))
  default = {}
}

# DNSSEC Configuration
variable "dnssec_configs" {
  description = "Map of DNSSEC configurations for public zones"
  type = map(object({
    zone_name      = string
    name           = string
    kms_key_arn    = string
    status         = optional(string, "ACTIVE")
    signing_status = optional(string, "SIGNING")
  }))
  default = {}
}

# VPC Association Authorization
variable "vpc_association_authorizations" {
  description = "Map of VPC association authorizations for cross-account private zones"
  type = map(object({
    zone_name = string
    zone_type = string # public or private
    vpc_id    = string
  }))
  default = {}
}

# Resolver Rules (for hybrid DNS)
variable "resolver_rules" {
  description = "Map of resolver rules for hybrid DNS resolution"
  type = map(object({
    domain_name          = string
    rule_type            = string # FORWARD, SYSTEM, RECURSIVE
    resolver_endpoint_id = optional(string, null)
    target_ips = optional(list(object({
      ip   = string
      port = optional(number, 53)
    })), [])
    tags = optional(map(string), {})
  }))
  default = {}
}

# Resolver Rule Associations
variable "resolver_rule_associations" {
  description = "Map of resolver rule associations with VPCs"
  type = map(object({
    resolver_rule_name = string
    vpc_id             = string
  }))
  default = {}
}

# Resolver Endpoints
variable "resolver_endpoints" {
  description = "Configuration for resolver endpoints (inbound and outbound)"
  type = object({
    inbound = optional(map(object({
      security_group_ids = list(string)
      ip_addresses = list(object({
        subnet_id = string
        ip        = optional(string, null)
      }))
      tags = optional(map(string), {})
    })), {})
    
    outbound = optional(map(object({
      security_group_ids = list(string)
      ip_addresses = list(object({
        subnet_id = string
        ip        = optional(string, null)
      }))
      tags = optional(map(string), {})
    })), {})
  })
  default = {
    inbound  = {}
    outbound = {}
  }
}

# Traffic Policies
variable "traffic_policies" {
  description = "Map of traffic policies for advanced routing"
  type = map(object({
    comment  = optional(string, "Managed by Terraform")
    document = string # JSON document defining the traffic policy
  }))
  default = {}
}

# Traffic Policy Instances
variable "traffic_policy_instances" {
  description = "Map of traffic policy instances"
  type = map(object({
    name                   = string
    traffic_policy_name    = string
    traffic_policy_version = number
    zone_name              = string
    zone_type              = string # public or private
    ttl                    = number
  }))
  default = {}
}

# Common record type defaults
variable "default_ttl" {
  description = "Default TTL for DNS records"
  type        = number
  default     = 300
}

variable "enable_dnssec" {
  description = "Enable DNSSEC for public zones"
  type        = bool
  default     = false
}

variable "enable_query_logging" {
  description = "Enable DNS query logging"
  type        = bool
  default     = false
}