# Application Load Balancer (ALB) Terraform Module

This Terraform module creates an AWS Application Load Balancer (ALB) with comprehensive configuration options for production use.

## Features

- **Multi-protocol Support**: HTTP and HTTPS listeners with flexible configuration
- **Advanced Health Checks**: Configurable health check parameters per target group
- **SSL/TLS Management**: Support for multiple SSL certificates and security policies
- **Load Balancing Algorithms**: Round robin, least outstanding requests, and more
- **Sticky Sessions**: Application-controlled and duration-based stickiness
- **Access & Connection Logs**: Optional S3 logging for monitoring and compliance
- **Cross-Zone Load Balancing**: Enhanced availability and traffic distribution
- **Security Features**: WAF integration, header validation, and desync protection
- **Listener Rules**: Advanced routing based on host, path, headers, and more
- **Target Group Management**: Support for instances, IPs, Lambda functions, and ALBs

## Usage

### Basic Usage

```hcl
module "alb" {
  source = "../modules/networking/alb"

  name            = "my-app-alb"
  security_groups = [aws_security_group.alb.id]
  subnets         = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  vpc_id          = aws_vpc.main.id

  # Target groups
  target_groups = {
    app = {
      name     = "my-app-tg"
      port     = 80
      protocol = "HTTP"
      health_check = {
        path                = "/health"
        healthy_threshold   = 2
        unhealthy_threshold = 3
        timeout             = 5
        interval            = 30
        matcher             = "200"
      }
    }
  }

  # Listeners
  create_https_listener = true
  certificate_arn       = aws_acm_certificate.main.arn
  default_target_group  = "app"

  tags = {
    Environment = "production"
    Team        = "platform"
  }
}
```

### Advanced Usage with Multiple Target Groups and Rules

```hcl
module "alb" {
  source = "../modules/networking/alb"

  name            = "production-alb"
  security_groups = [aws_security_group.alb.id]
  subnets         = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  vpc_id          = aws_vpc.main.id

  # Load balancer configuration
  enable_deletion_protection       = true
  enable_cross_zone_load_balancing = true
  enable_http2                     = true
  idle_timeout                     = 60

  # Access logs
  access_logs_enabled = true
  access_logs_bucket  = "my-company-alb-logs"
  access_logs_prefix  = "production-alb"

  # Target groups
  target_groups = {
    web = {
      name     = "web-servers"
      port     = 80
      protocol = "HTTP"
      health_check = {
        path                = "/health"
        healthy_threshold   = 2
        unhealthy_threshold = 3
        timeout             = 5
        interval            = 30
        matcher             = "200"
      }
      stickiness = {
        type            = "lb_cookie"
        cookie_duration = 86400
        enabled         = true
      }
    }
    api = {
      name     = "api-servers"
      port     = 8080
      protocol = "HTTP"
      health_check = {
        path                = "/api/health"
        healthy_threshold   = 2
        unhealthy_threshold = 2
        timeout             = 10
        interval            = 30
        matcher             = "200"
      }
      load_balancing_algorithm_type = "least_outstanding_requests"
    }
    admin = {
      name     = "admin-panel"
      port     = 3000
      protocol = "HTTP"
      health_check = {
        path                = "/admin/status"
        healthy_threshold   = 2
        unhealthy_threshold = 5
        timeout             = 15
        interval            = 60
        matcher             = "200,301"
      }
    }
  }

  # Listeners
  create_http_listener  = true
  create_https_listener = true
  certificate_arn       = aws_acm_certificate.main.arn
  ssl_policy           = "ELBSecurityPolicy-TLS-1-2-2017-01"
  default_target_group = "web"

  additional_certificate_arns = [
    aws_acm_certificate.wildcard.arn
  ]

  # Listener rules
  listener_rules = {
    api_routing = {
      priority = 100
      action = {
        type             = "forward"
        target_group_key = "api"
      }
      conditions = [
        {
          field  = "path-pattern"
          values = ["/api/*"]
        }
      ]
    }
    admin_routing = {
      priority = 200
      action = {
        type             = "forward"
        target_group_key = "admin"
      }
      conditions = [
        {
          field  = "host-header"
          values = ["admin.example.com"]
        }
      ]
    }
    maintenance_page = {
      priority = 300
      action = {
        type = "fixed-response"
        fixed_response = {
          content_type = "text/html"
          message_body = "<h1>Maintenance Mode</h1><p>We'll be back soon!</p>"
          status_code  = "503"
        }
      }
      conditions = [
        {
          field  = "path-pattern"
          values = ["/maintenance"]
        }
      ]
    }
  }

  # Target attachments
  target_attachments = {
    web1 = {
      target_group_key = "web"
      target_id        = aws_instance.web1.id
      port             = 80
    }
    web2 = {
      target_group_key = "web"
      target_id        = aws_instance.web2.id
      port             = 80
    }
    api1 = {
      target_group_key = "api"
      target_id        = aws_instance.api1.id
      port             = 8080
    }
  }

  tags = {
    Environment = "production"
    Team        = "platform"
    CostCenter  = "engineering"
  }
}
```

### Lambda Target Group Example

```hcl
module "alb" {
  source = "../modules/networking/alb"

  name            = "serverless-alb"
  security_groups = [aws_security_group.alb.id]
  subnets         = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  vpc_id          = aws_vpc.main.id

  target_groups = {
    lambda = {
      name        = "lambda-targets"
      target_type = "lambda"
      health_check = {
        enabled  = true
        matcher  = "200"
        path     = "/"
        protocol = "HTTP"
      }
    }
  }

  create_https_listener = true
  certificate_arn       = aws_acm_certificate.main.arn
  default_target_group  = "lambda"

  target_attachments = {
    function = {
      target_group_key = "lambda"
      target_id        = aws_lambda_function.app.arn
    }
  }

  tags = {
    Environment = "production"
    Type        = "serverless"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 4.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 4.0 |

## Resources

| Name | Type |
|------|------|
| [aws_lb.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.http_forward](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener.http_redirect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener_certificate.additional_certs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_certificate) | resource |
| [aws_lb_listener_rule.http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_listener_rule.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_target_group.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_lb_target_group_attachment.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group_attachment) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | Name of the Application Load Balancer | `string` | n/a | yes |
| security_groups | A list of security group IDs to assign to the LB | `list(string)` | n/a | yes |
| subnets | A list of subnet IDs to attach to the LB | `list(string)` | n/a | yes |
| vpc_id | VPC ID where the load balancer and other resources will be deployed | `string` | n/a | yes |
| access_logs_bucket | The S3 bucket name to store the logs in | `string` | `""` | no |
| access_logs_enabled | Boolean to enable / disable access_logs | `bool` | `false` | no |
| access_logs_prefix | The S3 bucket prefix. Logs are stored in the root if not configured | `string` | `""` | no |
| additional_certificate_arns | List of additional SSL certificate ARNs for the HTTPS listener | `set(string)` | `[]` | no |
| certificate_arn | The ARN of the default SSL server certificate | `string` | `""` | no |
| connection_logs_bucket | The S3 bucket name to store the connection logs in | `string` | `""` | no |
| connection_logs_enabled | Boolean to enable / disable connection_logs | `bool` | `false` | no |
| connection_logs_prefix | The S3 bucket prefix for connection logs | `string` | `""` | no |
| create_http_listener | Whether to create HTTP listener | `bool` | `true` | no |
| create_https_listener | Whether to create HTTPS listener | `bool` | `true` | no |
| default_target_group | Key of the default target group for listeners | `string` | `""` | no |
| desync_mitigation_mode | Determines how the load balancer handles requests that might pose a security risk | `string` | `"defensive"` | no |
| drop_invalid_header_fields | Indicates whether HTTP headers with header names that are not valid are removed by the load balancer | `bool` | `false` | no |
| enable_cross_zone_load_balancing | If true, cross-zone load balancing of the load balancer will be enabled | `bool` | `true` | no |
| enable_deletion_protection | If true, deletion of the load balancer will be disabled via the AWS API | `bool` | `false` | no |
| enable_http2 | Indicates whether HTTP/2 is enabled in application load balancers | `bool` | `true` | no |
| enable_waf_fail_open | Indicates whether to allow a WAF-enabled load balancer to route requests to targets if it is unable to forward the request to AWS WAF | `bool` | `false` | no |
| enable_xff_client_port | Indicates whether the X-Forwarded-For header should preserve the source port that the client used to connect to the load balancer | `bool` | `false` | no |
| http_listener_forward | Whether HTTP listener should forward to target group (true) or redirect to HTTPS (false) | `bool` | `false` | no |
| idle_timeout | The time in seconds that the connection is allowed to be idle | `number` | `60` | no |
| internal | If true, the LB will be internal | `bool` | `false` | no |
| listener_rules | Map of listener rule configurations | `map(object({...}))` | `{}` | no |
| preserve_host_header | Indicates whether the Application Load Balancer should preserve the Host header in the HTTP request | `bool` | `false` | no |
| ssl_policy | The name of the SSL Policy for the listener | `string` | `"ELBSecurityPolicy-TLS-1-2-2017-01"` | no |
| tags | A map of tags to assign to the resource | `map(string)` | `{}` | no |
| target_attachments | Map of target attachments to target groups | `map(object({...}))` | `{}` | no |
| target_groups | Map of target group configurations | `map(object({...}))` | `{}` | no |
| xff_header_processing_mode | Determines how the load balancer modifies the X-Forwarded-For header in the HTTP request | `string` | `"append"` | no |

## Outputs

| Name | Description |
|------|-------------|
| access_logs_bucket | S3 bucket for access logs |
| access_logs_enabled | Whether access logs are enabled |
| alb_arn | The ID and ARN of the load balancer we created |
| alb_arn_suffix | ARN suffix of our load balancer - can be used with CloudWatch |
| alb_canonical_hosted_zone_id | The canonical hosted zone ID of the load balancer (to be used in a Route 53 Alias record) |
| alb_dns_name | The DNS name of the load balancer |
| alb_hosted_zone_id | The canonical hosted zone ID of the load balancer (to be used in a Route 53 Alias record) |
| alb_id | The ID and ARN of the load balancer we created |
| alb_internal | Whether the load balancer is internal or external |
| alb_security_groups | The security groups attached to the load balancer |
| alb_subnets | The subnets attached to the load balancer |
| alb_vpc_id | The VPC ID of the load balancer |
| certificate_arn | The ARN of the SSL certificate used by the HTTPS listener |
| connection_logs_bucket | S3 bucket for connection logs |
| connection_logs_enabled | Whether connection logs are enabled |
| cross_zone_load_balancing_enabled | Whether cross-zone load balancing is enabled |
| deletion_protection_enabled | Whether deletion protection is enabled |
| http2_enabled | Whether HTTP/2 is enabled |
| http_listener_arns | The ARNs of the HTTP load balancer listeners created |
| https_listener_arn | The ARN of the HTTPS load balancer listener created |
| listener_rule_arns | The ARNs of the listener rules |
| route53_alias_dns_name | DNS name for Route 53 alias record |
| route53_alias_zone_id | Zone ID for Route 53 alias record |
| ssl_policy | The SSL policy used by the HTTPS listener |
| target_attachments | Information about target group attachments |
| target_group_arn_suffixes | ARN suffixes of our target groups - can be used with CloudWatch |
| target_group_arns | ARNs of the target groups. Useful for passing to your Auto Scaling group |
| target_group_health_check_paths | Health check paths of target groups |
| target_group_health_check_ports | Health check ports of target groups |
| target_group_names | Names of the target groups. Useful for passing to your CodeDeploy Deployment Group |

## Security Considerations

1. **Security Groups**: Ensure your security groups follow the principle of least privilege
2. **SSL/TLS**: Use the latest SSL policies for HTTPS listeners
3. **Access Logs**: Enable access logs for security monitoring and compliance
4. **WAF Integration**: Consider enabling WAF for additional protection
5. **Header Validation**: Enable `drop_invalid_header_fields` for enhanced security
6. **Desync Protection**: Configure appropriate `desync_mitigation_mode` based on your security requirements

## Best Practices

1. **Health Checks**: Configure appropriate health check intervals and thresholds
2. **Cross-Zone Load Balancing**: Enable for better fault tolerance
3. **Deletion Protection**: Enable for production load balancers
4. **Monitoring**: Use CloudWatch metrics and access logs for monitoring
5. **SSL Certificates**: Use ACM for automatic certificate renewal
6. **Target Groups**: Use separate target groups for different application tiers
7. **Listener Rules**: Order rules by specificity (most specific first)

## Examples

See the [examples](./examples/) directory for complete usage examples including:

- Basic web application load balancer
- Multi-tier application with API and web servers
- Serverless application with Lambda targets
- Blue/green deployment setup
- Advanced routing with multiple domains

## Contributing

When contributing to this module, please ensure:

1. All variables have descriptions and appropriate types
2. Add examples for new features
3. Update this README with any new configuration options
4. Test with multiple AWS regions and scenarios
5. Follow Terraform best practices for module design

## License

This module is released under the MIT License. See [LICENSE](LICENSE) for details.