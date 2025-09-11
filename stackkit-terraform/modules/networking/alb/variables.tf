variable "name" {
  description = "Name of the Application Load Balancer"
  type        = string
}

variable "internal" {
  description = "If true, the LB will be internal"
  type        = bool
  default     = false
}

variable "security_groups" {
  description = "A list of security group IDs to assign to the LB"
  type        = list(string)
}

variable "subnets" {
  description = "A list of subnet IDs to attach to the LB"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID where the load balancer and other resources will be deployed"
  type        = string
}

# Load Balancer Configuration
variable "enable_deletion_protection" {
  description = "If true, deletion of the load balancer will be disabled via the AWS API"
  type        = bool
  default     = false
}

variable "enable_cross_zone_load_balancing" {
  description = "If true, cross-zone load balancing of the load balancer will be enabled"
  type        = bool
  default     = true
}

variable "enable_http2" {
  description = "Indicates whether HTTP/2 is enabled in application load balancers"
  type        = bool
  default     = true
}

variable "enable_waf_fail_open" {
  description = "Indicates whether to allow a WAF-enabled load balancer to route requests to targets if it is unable to forward the request to AWS WAF"
  type        = bool
  default     = false
}

variable "drop_invalid_header_fields" {
  description = "Indicates whether HTTP headers with header names that are not valid are removed by the load balancer (true) or routed to targets (false)"
  type        = bool
  default     = false
}

variable "preserve_host_header" {
  description = "Indicates whether the Application Load Balancer should preserve the Host header in the HTTP request and send it to the target without any change"
  type        = bool
  default     = false
}

variable "enable_xff_client_port" {
  description = "Indicates whether the X-Forwarded-For header should preserve the source port that the client used to connect to the load balancer in application load balancers"
  type        = bool
  default     = false
}

variable "idle_timeout" {
  description = "The time in seconds that the connection is allowed to be idle"
  type        = number
  default     = 60
}

variable "desync_mitigation_mode" {
  description = "Determines how the load balancer handles requests that might pose a security risk to an application due to HTTP desync"
  type        = string
  default     = "defensive"
  validation {
    condition     = contains(["monitor", "defensive", "strictest"], var.desync_mitigation_mode)
    error_message = "Valid values are monitor, defensive, or strictest."
  }
}

variable "xff_header_processing_mode" {
  description = "Determines how the load balancer modifies the X-Forwarded-For header in the HTTP request before sending the request to the target"
  type        = string
  default     = "append"
  validation {
    condition     = contains(["append", "preserve", "remove"], var.xff_header_processing_mode)
    error_message = "Valid values are append, preserve, or remove."
  }
}

# Access Logs Configuration
variable "access_logs_enabled" {
  description = "Boolean to enable / disable access_logs"
  type        = bool
  default     = false
}

variable "access_logs_bucket" {
  description = "The S3 bucket name to store the logs in"
  type        = string
  default     = ""
}

variable "access_logs_prefix" {
  description = "The S3 bucket prefix. Logs are stored in the root if not configured"
  type        = string
  default     = ""
}

# Connection Logs Configuration
variable "connection_logs_enabled" {
  description = "Boolean to enable / disable connection_logs"
  type        = bool
  default     = false
}

variable "connection_logs_bucket" {
  description = "The S3 bucket name to store the connection logs in"
  type        = string
  default     = ""
}

variable "connection_logs_prefix" {
  description = "The S3 bucket prefix for connection logs"
  type        = string
  default     = ""
}

# Target Groups Configuration
variable "target_groups" {
  description = "Map of target group configurations"
  type = map(object({
    name                              = string
    port                              = number
    protocol                          = string
    target_type                       = optional(string, "instance")
    deregistration_delay              = optional(number, 300)
    slow_start                        = optional(number, 0)
    load_balancing_algorithm_type     = optional(string, "round_robin")
    preserve_client_ip               = optional(string, null)
    protocol_version                 = optional(string, "HTTP1")
    health_check = object({
      enabled             = optional(bool, true)
      healthy_threshold   = optional(number, 2)
      unhealthy_threshold = optional(number, 2)
      timeout             = optional(number, 5)
      interval            = optional(number, 30)
      path                = optional(string, "/")
      matcher             = optional(string, "200")
      port                = optional(string, "traffic-port")
      protocol            = optional(string, "HTTP")
    })
    stickiness = optional(object({
      type            = string
      cookie_duration = optional(number, 86400)
      cookie_name     = optional(string, null)
      enabled         = optional(bool, true)
    }), null)
    tags = optional(map(string), {})
  }))
  default = {}
}

# Listeners Configuration
variable "create_http_listener" {
  description = "Whether to create HTTP listener"
  type        = bool
  default     = true
}

variable "http_listener_forward" {
  description = "Whether HTTP listener should forward to target group (true) or redirect to HTTPS (false)"
  type        = bool
  default     = false
}

variable "create_https_listener" {
  description = "Whether to create HTTPS listener"
  type        = bool
  default     = true
}

variable "ssl_policy" {
  description = "The name of the SSL Policy for the listener"
  type        = string
  default     = "ELBSecurityPolicy-TLS-1-2-2017-01"
}

variable "certificate_arn" {
  description = "The ARN of the default SSL server certificate"
  type        = string
  default     = ""
}

variable "additional_certificate_arns" {
  description = "List of additional SSL certificate ARNs for the HTTPS listener"
  type        = set(string)
  default     = []
}

variable "default_target_group" {
  description = "Key of the default target group for listeners"
  type        = string
  default     = ""
}

# Listener Rules Configuration
variable "listener_rules" {
  description = "Map of listener rule configurations"
  type = map(object({
    priority = number
    action = object({
      type               = string # forward, fixed-response, redirect
      target_group_key   = optional(string)
      fixed_response = optional(object({
        content_type = string
        message_body = optional(string)
        status_code  = string
      }))
      redirect = optional(object({
        host        = optional(string, "#{host}")
        path        = optional(string, "/#{path}")
        port        = optional(string, "#{port}")
        protocol    = optional(string, "#{protocol}")
        query       = optional(string, "#{query}")
        status_code = string
      }))
    })
    conditions = list(object({
      field             = string # path-pattern, host-header, http-header, query-string, http-request-method, source-ip
      values            = optional(list(string))
      http_header_name  = optional(string)
      query_string = optional(list(object({
        key   = optional(string)
        value = string
      })))
    }))
  }))
  default = {}
}

# Target Attachments Configuration
variable "target_attachments" {
  description = "Map of target attachments to target groups"
  type = map(object({
    target_group_key  = string
    target_id         = string
    port              = optional(number)
    availability_zone = optional(string)
  }))
  default = {}
}

# Tags
variable "tags" {
  description = "A map of tags to assign to the resource"
  type        = map(string)
  default     = {}
}