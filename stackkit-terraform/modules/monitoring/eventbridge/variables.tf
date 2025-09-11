variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "environment" {
  description = "환경 (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "환경은 dev, staging, prod 중 하나여야 합니다."
  }
}

# Event Bus Configuration
variable "create_custom_bus" {
  description = "커스텀 이벤트 버스 생성 여부"
  type        = bool
  default     = false
}

variable "bus_name" {
  description = "이벤트 버스 이름"
  type        = string
  default     = "default"
}

variable "event_source_name" {
  description = "이벤트 소스 이름 (커스텀 버스용)"
  type        = string
  default     = null
}

variable "kms_key_id" {
  description = "KMS 키 ID (이벤트 버스 암호화용)"
  type        = string
  default     = null
}

# Rules Configuration
variable "rules" {
  description = "EventBridge 규칙 설정 리스트"
  type = list(object({
    name                = string
    description         = string
    event_pattern       = optional(string)
    schedule_expression = optional(string)
    is_enabled         = optional(bool, true)
    targets = list(object({
      arn                   = string
      input                = optional(string)
      input_path           = optional(string)
      input_transformer = optional(object({
        input_paths    = map(string)
        input_template = string
      }))
      role_arn = optional(string)
      
      # Target-specific parameters
      sqs_parameters = optional(object({
        message_group_id = string
      }))
      
      ecs_parameters = optional(object({
        task_definition_arn = string
        launch_type         = optional(string, "FARGATE")
        platform_version    = optional(string)
        task_count          = optional(number, 1)
        network_configuration = optional(object({
          subnets          = list(string)
          security_groups  = optional(list(string))
          assign_public_ip = optional(bool)
        }))
      }))
      
      kinesis_parameters = optional(object({
        partition_key_path = string
      }))
      
      batch_parameters = optional(object({
        job_definition = string
        job_name      = string
      }))
      
      http_parameters = optional(object({
        path_parameter_values   = optional(map(string))
        query_string_parameters = optional(map(string))
        header_parameters       = optional(map(string))
      }))
      
      # Retry and DLQ
      retry_policy = optional(object({
        maximum_event_age_in_seconds = optional(number, 86400)
        maximum_retry_attempts       = optional(number, 185)
      }))
      
      dead_letter_queue_arn = optional(string)
    }))
  }))
  default = []

  validation {
    condition = alltrue([
      for rule in var.rules : (
        (rule.event_pattern != null && rule.schedule_expression == null) ||
        (rule.event_pattern == null && rule.schedule_expression != null)
      )
    ])
    error_message = "각 규칙은 event_pattern 또는 schedule_expression 중 하나만 가져야 합니다."
  }
}

# Connections for API Destinations
variable "connections" {
  description = "EventBridge 연결 설정 (API 대상용)"
  type = list(object({
    name               = string
    description        = optional(string)
    authorization_type = string
    auth_parameters = optional(object({
      api_key = optional(object({
        key   = string
        value = string
      }))
      basic = optional(object({
        username = string
        password = string
      }))
      oauth = optional(object({
        authorization_endpoint = string
        http_method           = string
        client_parameters = optional(object({
          client_id = string
        }))
        oauth_http_parameters = optional(object({
          body_parameters         = optional(map(string))
          header_parameters       = optional(map(string))
          query_string_parameters = optional(map(string))
        }))
      }))
      invocation_http_parameters = optional(object({
        body_parameters         = optional(map(string))
        header_parameters       = optional(map(string))
        query_string_parameters = optional(map(string))
      }))
    }))
  }))
  default = []

  validation {
    condition = alltrue([
      for conn in var.connections : contains(["API_KEY", "BASIC", "OAUTH_CLIENT_CREDENTIALS", "INVOCATION_HTTP_PARAMETERS"], conn.authorization_type)
    ])
    error_message = "인증 타입은 API_KEY, BASIC, OAUTH_CLIENT_CREDENTIALS, INVOCATION_HTTP_PARAMETERS 중 하나여야 합니다."
  }
}

# API Destinations
variable "api_destinations" {
  description = "EventBridge API 대상 설정"
  type = list(object({
    name                             = string
    description                      = optional(string)
    invocation_endpoint             = string
    http_method                     = string
    invocation_rate_limit_per_second = optional(number, 300)
    connection_name                 = optional(string)
    connection_arn                  = optional(string)
  }))
  default = []

  validation {
    condition = alltrue([
      for dest in var.api_destinations : contains(["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"], dest.http_method)
    ])
    error_message = "HTTP 메서드는 GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE 중 하나여야 합니다."
  }

  validation {
    condition = alltrue([
      for dest in var.api_destinations : (
        (dest.connection_name != null && dest.connection_arn == null) ||
        (dest.connection_name == null && dest.connection_arn != null)
      )
    ])
    error_message = "connection_name 또는 connection_arn 중 하나만 지정해야 합니다."
  }
}

# Archives
variable "archives" {
  description = "EventBridge 아카이브 설정"
  type = list(object({
    name           = string
    description    = optional(string)
    retention_days = optional(number, 0)  # 0 = indefinite
    event_pattern  = optional(string)
  }))
  default = []
}

# Replays
variable "replays" {
  description = "EventBridge 재생 설정"
  type = list(object({
    name             = string
    description      = optional(string)
    archive_name     = optional(string)
    event_source_arn = optional(string)
    event_start_time = string
    event_end_time   = string
    destination = object({
      arn        = string
      filter_arn = optional(string)
    })
  }))
  default = []

  validation {
    condition = alltrue([
      for replay in var.replays : (
        (replay.archive_name != null && replay.event_source_arn == null) ||
        (replay.archive_name == null && replay.event_source_arn != null)
      )
    ])
    error_message = "archive_name 또는 event_source_arn 중 하나만 지정해야 합니다."
  }
}

# Monitoring & Alarms
variable "create_cloudwatch_alarms" {
  description = "CloudWatch 알람 생성 여부"
  type        = bool
  default     = true
}

variable "invocation_alarm_threshold" {
  description = "호출 알람 임계값 (최소 호출 수)"
  type        = number
  default     = 1
}

variable "failure_alarm_threshold" {
  description = "실패 알람 임계값"
  type        = number
  default     = 1
}

variable "alarm_actions" {
  description = "알람 액션 ARN 리스트"
  type        = list(string)
  default     = []
}

variable "common_tags" {
  description = "모든 리소스에 적용할 공통 태그"
  type        = map(string)
  default     = {}
}