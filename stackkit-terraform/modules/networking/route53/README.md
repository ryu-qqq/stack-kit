# Route53 DNS Management Module

This Terraform module provides comprehensive Amazon Route53 DNS management capabilities, including hosted zones, DNS records, health checks, DNSSEC, query logging, and advanced routing features.

## Features

- **Public and Private Hosted Zones**: Create and manage both public and private DNS zones
- **DNS Records**: Support for all record types (A, AAAA, CNAME, MX, TXT, SRV, PTR, etc.)
- **Alias Records**: AWS resource aliases with health check integration
- **Advanced Routing**: Weighted, latency-based, geolocation, failover, and multivalue routing
- **Health Checks**: HTTP/HTTPS, TCP, calculated, and CloudWatch metric health checks
- **DNSSEC**: DNS Security Extensions for public zones
- **Query Logging**: CloudWatch integration for DNS query analysis
- **Resolver Endpoints**: Hybrid DNS resolution for on-premises integration
- **Traffic Policies**: Advanced routing policies for complex DNS management
- **Cross-Account Support**: VPC association authorization for multi-account setups

## Usage

### Basic Public Zone

```hcl
module "route53" {
  source = "./modules/networking/route53"

  name_prefix = "myapp"
  environment = "prod"

  public_zones = {
    "example.com" = {
      comment = "Main production domain"
    }
  }

  public_records = [
    {
      zone_name = "example.com"
      name      = "www"
      type      = "A"
      ttl       = 300
      records   = ["192.0.2.1"]
    },
    {
      zone_name = "example.com"
      name      = "mail"
      type      = "MX"
      ttl       = 300
      records   = ["10 mail.example.com"]
    }
  ]

  tags = {
    Project = "MyApp"
    Owner   = "Platform Team"
  }
}
```

### Private Zone with VPC Association

```hcl
module "route53_private" {
  source = "./modules/networking/route53"

  name_prefix = "myapp"
  environment = "prod"

  private_zones = {
    "internal.local" = {
      comment = "Internal services"
      vpcs = [
        {
          vpc_id = "vpc-12345678"
        }
      ]
    }
  }

  private_records = [
    {
      zone_name = "internal.local"
      name      = "db"
      type      = "A"
      ttl       = 300
      records   = ["10.0.1.100"]
    }
  ]
}
```

### Advanced Configuration with Health Checks

```hcl
module "route53_advanced" {
  source = "./modules/networking/route53"

  name_prefix = "myapp"
  environment = "prod"

  public_zones = {
    "example.com" = {
      comment = "Production domain with health checks"
    }
  }

  health_checks = {
    "web-primary" = {
      type                     = "HTTPS"
      fqdn                     = "web1.example.com"
      port                     = 443
      resource_path           = "/health"
      failure_threshold       = 3
      request_interval        = 30
      measure_latency         = true
    }
    "web-secondary" = {
      type                     = "HTTPS"
      fqdn                     = "web2.example.com"
      port                     = 443
      resource_path           = "/health"
      failure_threshold       = 3
      request_interval        = 30
    }
  }

  public_records = [
    {
      zone_name       = "example.com"
      name            = "web"
      type            = "A"
      ttl             = 60
      records         = ["203.0.113.1"]
      health_check_id = module.route53_advanced.health_check_ids["web-primary"]
      set_identifier  = "primary"
      failover_routing_policy = {
        type = "PRIMARY"
      }
    },
    {
      zone_name       = "example.com"
      name            = "web"
      type            = "A"
      ttl             = 60
      records         = ["203.0.113.2"]
      health_check_id = module.route53_advanced.health_check_ids["web-secondary"]
      set_identifier  = "secondary"
      failover_routing_policy = {
        type = "SECONDARY"
      }
    }
  ]
}
```

### ALB Alias Record

```hcl
module "route53_alb" {
  source = "./modules/networking/route53"

  public_zones = {
    "example.com" = {}
  }

  public_records = [
    {
      zone_name = "example.com"
      name      = "app"
      type      = "A"
      alias = {
        name                   = "my-alb-123456789.us-west-2.elb.amazonaws.com"
        zone_id                = "Z1D633PJN98FT9"  # ALB zone ID for us-west-2
        evaluate_target_health = true
      }
    }
  ]
}
```

### DNSSEC Configuration

```hcl
# First create KMS key for DNSSEC
resource "aws_kms_key" "dnssec" {
  description             = "Route53 DNSSEC Key"
  customer_master_key_spec = "ECC_NIST_P256"
  key_usage               = "SIGN_VERIFY"
  deletion_window_in_days = 7
}

module "route53_dnssec" {
  source = "./modules/networking/route53"

  public_zones = {
    "example.com" = {
      comment = "Domain with DNSSEC"
    }
  }

  dnssec_configs = {
    "example-dnssec" = {
      zone_name   = "example.com"
      name        = "example.com"
      kms_key_arn = aws_kms_key.dnssec.arn
    }
  }
}
```

### Query Logging

```hcl
module "route53_logging" {
  source = "./modules/networking/route53"

  public_zones = {
    "example.com" = {}
  }

  query_logging_configs = {
    "example-logging" = {
      zone_name         = "example.com"
      zone_type         = "public"
      retention_in_days = 30
    }
  }
}
```

### Hybrid DNS with Resolver Endpoints

```hcl
module "route53_hybrid" {
  source = "./modules/networking/route53"

  resolver_endpoints = {
    inbound = {
      "main-inbound" = {
        security_group_ids = ["sg-12345678"]
        ip_addresses = [
          {
            subnet_id = "subnet-12345678"
          },
          {
            subnet_id = "subnet-87654321"
          }
        ]
      }
    }
    outbound = {
      "main-outbound" = {
        security_group_ids = ["sg-87654321"]
        ip_addresses = [
          {
            subnet_id = "subnet-12345678"
          },
          {
            subnet_id = "subnet-87654321"
          }
        ]
      }
    }
  }

  resolver_rules = {
    "onprem-rule" = {
      domain_name          = "onprem.local"
      rule_type            = "FORWARD"
      resolver_endpoint_id = "rslvr-out-12345678"  # Reference outbound endpoint
      target_ips = [
        {
          ip   = "192.168.1.10"
          port = 53
        }
      ]
    }
  }

  resolver_rule_associations = {
    "onprem-vpc-association" = {
      resolver_rule_name = "onprem-rule"
      vpc_id             = "vpc-12345678"
    }
  }
}
```

### Weighted Routing

```hcl
module "route53_weighted" {
  source = "./modules/networking/route53"

  public_zones = {
    "example.com" = {}
  }

  public_records = [
    {
      zone_name      = "example.com"
      name           = "api"
      type           = "A"
      ttl            = 60
      records        = ["203.0.113.1"]
      set_identifier = "server-1"
      weighted_routing_policy = {
        weight = 70
      }
    },
    {
      zone_name      = "example.com"
      name           = "api"
      type           = "A"
      ttl            = 60
      records        = ["203.0.113.2"]
      set_identifier = "server-2"
      weighted_routing_policy = {
        weight = 30
      }
    }
  ]
}
```

### Geolocation Routing

```hcl
module "route53_geo" {
  source = "./modules/networking/route53"

  public_zones = {
    "example.com" = {}
  }

  public_records = [
    {
      zone_name      = "example.com"
      name           = "www"
      type           = "A"
      ttl            = 300
      records        = ["203.0.113.1"]
      set_identifier = "us-east"
      geolocation_routing_policy = {
        continent = "NA"
      }
    },
    {
      zone_name      = "example.com"
      name           = "www"
      type           = "A"
      ttl            = 300
      records        = ["203.0.113.2"]
      set_identifier = "eu-west"
      geolocation_routing_policy = {
        continent = "EU"
      }
    }
  ]
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

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name_prefix | Prefix for naming resources | `string` | `"stackkit"` | no |
| environment | Environment name (e.g., dev, staging, prod) | `string` | `"dev"` | no |
| tags | A map of tags to apply to all resources | `map(string)` | `{}` | no |
| create_delegation_set | Whether to create a reusable delegation set | `bool` | `false` | no |
| delegation_set_reference_name | Reference name for the delegation set | `string` | `null` | no |
| public_zones | Map of public hosted zones to create | `map(object)` | `{}` | no |
| private_zones | Map of private hosted zones to create | `map(object)` | `{}` | no |
| public_records | List of DNS records to create in public zones | `list(object)` | `[]` | no |
| private_records | List of DNS records to create in private zones | `list(object)` | `[]` | no |
| health_checks | Map of health checks to create | `map(object)` | `{}` | no |
| query_logging_configs | Map of DNS query logging configurations | `map(object)` | `{}` | no |
| dnssec_configs | Map of DNSSEC configurations for public zones | `map(object)` | `{}` | no |
| resolver_endpoints | Configuration for resolver endpoints | `object` | `{}` | no |
| resolver_rules | Map of resolver rules for hybrid DNS resolution | `map(object)` | `{}` | no |
| traffic_policies | Map of traffic policies for advanced routing | `map(object)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| public_zone_ids | Map of public zone names to their zone IDs |
| public_zone_name_servers | Map of public zone names to their name servers |
| private_zone_ids | Map of private zone names to their zone IDs |
| health_check_ids | Map of health check names to their IDs |
| resolver_endpoint_ids | Map of resolver endpoint names to their IDs |
| zone_details | Detailed information about all zones for cross-module reference |

## Supported Record Types

- **A**: Maps domain to IPv4 address
- **AAAA**: Maps domain to IPv6 address  
- **CNAME**: Maps domain to another domain
- **MX**: Mail exchange records
- **TXT**: Text records for verification and configuration
- **SRV**: Service records for service discovery
- **PTR**: Pointer records for reverse DNS
- **NS**: Name server records
- **SOA**: Start of authority (managed automatically)
- **CAA**: Certificate Authority Authorization
- **ALIAS**: AWS-specific alias records

## Health Check Types

- **HTTP/HTTPS**: Check HTTP endpoints
- **HTTP_STR_MATCH/HTTPS_STR_MATCH**: Check for specific content
- **TCP**: Check TCP connectivity
- **CALCULATED**: Combine multiple health checks
- **CLOUDWATCH_METRIC**: Use CloudWatch metrics
- **RECOVERY_CONTROL**: Route53 Application Recovery Controller

## Routing Policies

- **Simple**: Basic DNS resolution
- **Weighted**: Distribute traffic by weight
- **Latency-based**: Route to lowest latency endpoint
- **Geolocation**: Route based on user location
- **Geoproximity**: Route based on location and bias
- **Failover**: Primary/secondary failover
- **Multivalue**: Return multiple values with health checks

## Best Practices

1. **Use Health Checks**: Always use health checks for critical services
2. **Set Appropriate TTL**: Use shorter TTL for frequently changing records
3. **DNSSEC for Security**: Enable DNSSEC for public zones handling sensitive data
4. **Query Logging**: Enable for security monitoring and troubleshooting
5. **Private Zones**: Use for internal service discovery
6. **Alias Records**: Use for AWS resources to reduce costs and improve performance
7. **Tag Everything**: Use consistent tagging for cost tracking and management

## Security Considerations

- DNSSEC requires KMS key management
- Query logging may contain sensitive information
- Private zones should be limited to necessary VPCs
- Health check endpoints should be secured
- Cross-account VPC associations require proper IAM permissions

## Cost Optimization

- Use alias records for AWS resources (no charge for queries)
- Optimize health check frequency based on requirements
- Use appropriate TTL values to reduce query volume
- Consider query logging costs for high-traffic domains

## Troubleshooting

### Common Issues

1. **DNSSEC Key Issues**: Ensure KMS key has proper permissions and correct key spec
2. **Health Check Failures**: Verify security groups allow Route53 health checkers
3. **Private Zone Resolution**: Ensure VPC has DNS resolution and DNS hostnames enabled
4. **Cross-Account Access**: Verify IAM permissions for VPC association authorization

### Debugging Commands

```bash
# Test DNS resolution
dig @8.8.8.8 example.com

# Check health check status
aws route53 get-health-check --health-check-id <health-check-id>

# View query logs
aws logs filter-log-events --log-group-name /aws/route53/example.com
```

## Examples

See the `examples/` directory for complete usage examples:

- `basic/`: Simple public and private zones
- `advanced/`: Health checks and routing policies  
- `hybrid/`: On-premises DNS integration
- `multi-account/`: Cross-account zone management

## Contributing

When contributing to this module:

1. Update documentation for any new variables or outputs
2. Add examples for new features
3. Test with multiple AWS regions
4. Validate DNSSEC functionality with proper KMS setup
5. Check resolver endpoint functionality in hybrid scenarios