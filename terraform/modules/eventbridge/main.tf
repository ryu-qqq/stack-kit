# EventBridge Custom Bus
resource "aws_cloudwatch_event_bus" "main" {
  count = var.create_custom_bus ? 1 : 0
  
  name              = "${var.project_name}-${var.environment}-${var.bus_name}"
  event_source_name = var.event_source_name
  kms_key_id       = var.kms_key_id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-${var.bus_name}"
  })
}

# EventBridge Rules
resource "aws_cloudwatch_event_rule" "rules" {
  count = length(var.rules)

  name           = "${var.project_name}-${var.environment}-${var.rules[count.index].name}"
  description    = var.rules[count.index].description
  event_bus_name = var.create_custom_bus ? aws_cloudwatch_event_bus.main[0].name : "default"
  
  event_pattern    = var.rules[count.index].event_pattern
  schedule_expression = var.rules[count.index].schedule_expression
  
  is_enabled = var.rules[count.index].is_enabled

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-${var.rules[count.index].name}"
  })
}

# EventBridge Targets
resource "aws_cloudwatch_event_target" "targets" {
  count = length(local.flattened_targets)

  rule           = aws_cloudwatch_event_rule.rules[local.flattened_targets[count.index].rule_index].name
  event_bus_name = var.create_custom_bus ? aws_cloudwatch_event_bus.main[0].name : "default"
  target_id      = local.flattened_targets[count.index].target_id
  arn           = local.flattened_targets[count.index].arn
  
  # Input transformation
  input                = local.flattened_targets[count.index].input
  input_path           = local.flattened_targets[count.index].input_path
  
  dynamic "input_transformer" {
    for_each = local.flattened_targets[count.index].input_transformer != null ? [local.flattened_targets[count.index].input_transformer] : []
    content {
      input_paths    = input_transformer.value.input_paths
      input_template = input_transformer.value.input_template
    }
  }

  # Role ARN for targets that need it
  role_arn = local.flattened_targets[count.index].role_arn

  # SQS target configuration
  dynamic "sqs_parameters" {
    for_each = local.flattened_targets[count.index].sqs_parameters != null ? [local.flattened_targets[count.index].sqs_parameters] : []
    content {
      message_group_id = sqs_parameters.value.message_group_id
    }
  }

  # ECS target configuration
  dynamic "ecs_parameters" {
    for_each = local.flattened_targets[count.index].ecs_parameters != null ? [local.flattened_targets[count.index].ecs_parameters] : []
    content {
      task_definition_arn = ecs_parameters.value.task_definition_arn
      launch_type         = ecs_parameters.value.launch_type
      platform_version    = ecs_parameters.value.platform_version
      task_count          = ecs_parameters.value.task_count
      
      dynamic "network_configuration" {
        for_each = ecs_parameters.value.network_configuration != null ? [ecs_parameters.value.network_configuration] : []
        content {
          subnets          = network_configuration.value.subnets
          security_groups  = network_configuration.value.security_groups
          assign_public_ip = network_configuration.value.assign_public_ip
        }
      }
    }
  }

  # Kinesis target configuration
  dynamic "kinesis_parameters" {
    for_each = local.flattened_targets[count.index].kinesis_parameters != null ? [local.flattened_targets[count.index].kinesis_parameters] : []
    content {
      partition_key_path = kinesis_parameters.value.partition_key_path
    }
  }

  # Batch target configuration
  dynamic "batch_parameters" {
    for_each = local.flattened_targets[count.index].batch_parameters != null ? [local.flattened_targets[count.index].batch_parameters] : []
    content {
      job_definition = batch_parameters.value.job_definition
      job_name      = batch_parameters.value.job_name
    }
  }

  # HTTP target configuration
  dynamic "http_parameters" {
    for_each = local.flattened_targets[count.index].http_parameters != null ? [local.flattened_targets[count.index].http_parameters] : []
    content {
      path_parameter_values   = http_parameters.value.path_parameter_values
      query_string_parameters = http_parameters.value.query_string_parameters
      header_parameters       = http_parameters.value.header_parameters
    }
  }

  # Retry policy
  dynamic "retry_policy" {
    for_each = local.flattened_targets[count.index].retry_policy != null ? [local.flattened_targets[count.index].retry_policy] : []
    content {
      maximum_event_age_in_seconds = retry_policy.value.maximum_event_age_in_seconds
      maximum_retry_attempts       = retry_policy.value.maximum_retry_attempts
    }
  }

  # Dead letter queue
  dynamic "dead_letter_config" {
    for_each = local.flattened_targets[count.index].dead_letter_queue_arn != null ? [1] : []
    content {
      arn = local.flattened_targets[count.index].dead_letter_queue_arn
    }
  }
}

# Flatten targets for easier processing
locals {
  flattened_targets = flatten([
    for rule_index, rule in var.rules : [
      for target_index, target in rule.targets : {
        rule_index                = rule_index
        target_id                 = "${rule.name}-target-${target_index}"
        arn                      = target.arn
        input                    = target.input
        input_path               = target.input_path
        input_transformer        = target.input_transformer
        role_arn                 = target.role_arn
        sqs_parameters          = target.sqs_parameters
        ecs_parameters          = target.ecs_parameters
        kinesis_parameters      = target.kinesis_parameters
        batch_parameters        = target.batch_parameters
        http_parameters         = target.http_parameters
        retry_policy            = target.retry_policy
        dead_letter_queue_arn   = target.dead_letter_queue_arn
      }
    ]
  ])
}

# EventBridge Connection (for API destinations)
resource "aws_cloudwatch_event_connection" "connections" {
  count = length(var.connections)

  name               = "${var.project_name}-${var.environment}-${var.connections[count.index].name}"
  description        = var.connections[count.index].description
  authorization_type = var.connections[count.index].authorization_type

  dynamic "auth_parameters" {
    for_each = var.connections[count.index].auth_parameters != null ? [var.connections[count.index].auth_parameters] : []
    content {
      dynamic "api_key" {
        for_each = auth_parameters.value.api_key != null ? [auth_parameters.value.api_key] : []
        content {
          key   = api_key.value.key
          value = api_key.value.value
        }
      }
      
      dynamic "basic" {
        for_each = auth_parameters.value.basic != null ? [auth_parameters.value.basic] : []
        content {
          username = basic.value.username
          password = basic.value.password
        }
      }
      
      dynamic "oauth" {
        for_each = auth_parameters.value.oauth != null ? [auth_parameters.value.oauth] : []
        content {
          authorization_endpoint = oauth.value.authorization_endpoint
          http_method           = oauth.value.http_method
          
          dynamic "client_parameters" {
            for_each = oauth.value.client_parameters != null ? [oauth.value.client_parameters] : []
            content {
              client_id = client_parameters.value.client_id
            }
          }
          
          dynamic "oauth_http_parameters" {
            for_each = oauth.value.oauth_http_parameters != null ? [oauth.value.oauth_http_parameters] : []
            content {
              body_parameters    = oauth_http_parameters.value.body_parameters
              header_parameters  = oauth_http_parameters.value.header_parameters
              query_string_parameters = oauth_http_parameters.value.query_string_parameters
            }
          }
        }
      }
      
      dynamic "invocation_http_parameters" {
        for_each = auth_parameters.value.invocation_http_parameters != null ? [auth_parameters.value.invocation_http_parameters] : []
        content {
          body_parameters         = invocation_http_parameters.value.body_parameters
          header_parameters       = invocation_http_parameters.value.header_parameters
          query_string_parameters = invocation_http_parameters.value.query_string_parameters
        }
      }
    }
  }
}

# EventBridge API Destination
resource "aws_cloudwatch_event_api_destination" "destinations" {
  count = length(var.api_destinations)

  name                             = "${var.project_name}-${var.environment}-${var.api_destinations[count.index].name}"
  description                      = var.api_destinations[count.index].description
  invocation_endpoint             = var.api_destinations[count.index].invocation_endpoint
  http_method                     = var.api_destinations[count.index].http_method
  invocation_rate_limit_per_second = var.api_destinations[count.index].invocation_rate_limit_per_second
  connection_arn                  = var.api_destinations[count.index].connection_name != null ? aws_cloudwatch_event_connection.connections[index(var.connections[*].name, var.api_destinations[count.index].connection_name)].arn : var.api_destinations[count.index].connection_arn
}

# EventBridge Archive
resource "aws_cloudwatch_event_archive" "archives" {
  count = length(var.archives)

  name             = "${var.project_name}-${var.environment}-${var.archives[count.index].name}"
  description      = var.archives[count.index].description
  event_source_arn = var.create_custom_bus ? aws_cloudwatch_event_bus.main[0].arn : "arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:event-bus/default"
  retention_days   = var.archives[count.index].retention_days
  event_pattern    = var.archives[count.index].event_pattern
}

# EventBridge Replay
resource "aws_cloudwatch_event_replay" "replays" {
  count = length(var.replays)

  name         = "${var.project_name}-${var.environment}-${var.replays[count.index].name}"
  description  = var.replays[count.index].description
  event_source_arn = var.replays[count.index].archive_name != null ? aws_cloudwatch_event_archive.archives[index(var.archives[*].name, var.replays[count.index].archive_name)].arn : var.replays[count.index].event_source_arn
  
  dynamic "destination" {
    for_each = [var.replays[count.index].destination]
    content {
      arn                 = destination.value.arn
      filter_arn         = destination.value.filter_arn
    }
  }
  
  event_start_time = var.replays[count.index].event_start_time
  event_end_time   = var.replays[count.index].event_end_time
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "rule_invocations" {
  count = var.create_cloudwatch_alarms ? length(var.rules) : 0

  alarm_name          = "${var.project_name}-${var.environment}-${var.rules[count.index].name}-invocations"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Invocations"
  namespace           = "AWS/Events"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.invocation_alarm_threshold
  alarm_description   = "This metric monitors EventBridge rule invocations"
  alarm_actions       = var.alarm_actions

  dimensions = {
    RuleName = aws_cloudwatch_event_rule.rules[count.index].name
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "rule_failures" {
  count = var.create_cloudwatch_alarms ? length(var.rules) : 0

  alarm_name          = "${var.project_name}-${var.environment}-${var.rules[count.index].name}-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "FailedInvocations"
  namespace           = "AWS/Events"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.failure_alarm_threshold
  alarm_description   = "This metric monitors EventBridge rule failures"
  alarm_actions       = var.alarm_actions

  dimensions = {
    RuleName = aws_cloudwatch_event_rule.rules[count.index].name
  }

  tags = var.common_tags
}

# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}