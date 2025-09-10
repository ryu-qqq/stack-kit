# ==============================================================================
# EVENTBRIDGE MODULE OUTPUTS - Standardized Format
# ==============================================================================

# Core EventBridge Resources
output "event_bus_name" {
  description = "이벤트 버스 이름"
  value       = var.create_custom_bus ? aws_cloudwatch_event_bus.main[0].name : "default"
}

output "event_bus_arn" {
  description = "이벤트 버스 ARN"
  value       = var.create_custom_bus ? aws_cloudwatch_event_bus.main[0].arn : "arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:event-bus/default"
}

# Rules Information
output "rules" {
  description = "생성된 EventBridge 규칙 정보"
  value = {
    for idx, rule in aws_cloudwatch_event_rule.rules : idx => {
      name                = rule.name
      arn                = rule.arn
      description        = rule.description
      event_pattern      = rule.event_pattern
      schedule_expression = rule.schedule_expression
      is_enabled         = rule.is_enabled
      event_bus_name     = rule.event_bus_name
      
      # Target count for this rule
      target_count = length([
        for target in local.flattened_targets : target
        if target.rule_index == idx
      ])
    }
  }
}

# Targets Information
output "targets" {
  description = "생성된 EventBridge 타겟 정보"
  value = {
    for idx, target in aws_cloudwatch_event_target.targets : idx => {
      target_id      = target.target_id
      arn           = target.arn
      rule          = target.rule
      event_bus_name = target.event_bus_name
      input         = target.input
      input_path    = target.input_path
      role_arn      = target.role_arn
    }
  }
  sensitive = true
}

# Connection Information
output "connections" {
  description = "생성된 EventBridge 연결 정보"
  value = {
    for idx, conn in aws_cloudwatch_event_connection.connections : idx => {
      name               = conn.name
      arn               = conn.arn
      authorization_type = conn.authorization_type
      secret_arn        = conn.secret_arn
    }
  }
  sensitive = true
}

# API Destinations
output "api_destinations" {
  description = "생성된 API 대상 정보"
  value = {
    for idx, dest in aws_cloudwatch_event_api_destination.destinations : idx => {
      name                             = dest.name
      arn                             = dest.arn
      invocation_endpoint             = dest.invocation_endpoint
      http_method                     = dest.http_method
      invocation_rate_limit_per_second = dest.invocation_rate_limit_per_second
      connection_arn                  = dest.connection_arn
    }
  }
  sensitive = true
}

# Archives Information
output "archives" {
  description = "생성된 EventBridge 아카이브 정보"
  value = {
    for idx, archive in aws_cloudwatch_event_archive.archives : idx => {
      name             = archive.name
      arn             = archive.arn
      description     = archive.description
      retention_days  = archive.retention_days
      event_source_arn = archive.event_source_arn
    }
  }
}

# Replays Information  
output "replays" {
  description = "생성된 EventBridge 재생 정보"
  value = {
    for idx, replay in aws_cloudwatch_event_replay.replays : idx => {
      name             = replay.name
      arn             = replay.arn
      description     = replay.description
      event_source_arn = replay.event_source_arn
      state           = replay.state
      state_reason    = replay.state_reason
    }
  }
}

# Monitoring Resources
output "cloudwatch_alarms" {
  description = "생성된 CloudWatch 알람 정보"
  value = var.create_cloudwatch_alarms ? {
    invocation_alarms = {
      for idx, alarm in aws_cloudwatch_metric_alarm.rule_invocations : idx => {
        name = alarm.alarm_name
        arn  = alarm.arn
      }
    }
    failure_alarms = {
      for idx, alarm in aws_cloudwatch_metric_alarm.rule_failures : idx => {
        name = alarm.alarm_name
        arn  = alarm.arn
      }
    }
  } : {}
}

# Resource Summary for Integration
output "resource_summary" {
  description = "EventBridge 모듈 리소스 요약"
  value = {
    event_bus_name = var.create_custom_bus ? aws_cloudwatch_event_bus.main[0].name : "default"
    event_bus_arn  = var.create_custom_bus ? aws_cloudwatch_event_bus.main[0].arn : "arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:event-bus/default"
    
    # Resource counts
    rules_count           = length(aws_cloudwatch_event_rule.rules)
    targets_count         = length(aws_cloudwatch_event_target.targets)
    connections_count     = length(aws_cloudwatch_event_connection.connections)
    api_destinations_count = length(aws_cloudwatch_event_api_destination.destinations)
    archives_count        = length(aws_cloudwatch_event_archive.archives)
    replays_count         = length(aws_cloudwatch_event_replay.replays)
    
    # Capabilities
    custom_bus_enabled    = var.create_custom_bus
    monitoring_enabled    = var.create_cloudwatch_alarms
    api_destinations_used = length(var.api_destinations) > 0
    archives_enabled      = length(var.archives) > 0
    replays_enabled       = length(var.replays) > 0
    
    # Environment context
    project_name = var.project_name
    environment  = var.environment
  }
}

# Event Pattern Helper
output "event_patterns" {
  description = "EventBridge 이벤트 패턴 요약"
  value = {
    for idx, rule in var.rules : rule.name => {
      event_pattern       = rule.event_pattern
      schedule_expression = rule.schedule_expression
      pattern_type        = rule.event_pattern != null ? "event" : "schedule"
      target_count        = length(rule.targets)
      enabled             = rule.is_enabled
    }
  }
}

# Integration Points
output "integration_points" {
  description = "다른 모듈과의 통합 지점"
  value = {
    # For Lambda integration
    lambda_targets = [
      for target in local.flattened_targets : target.arn
      if can(regex("^arn:aws:lambda:", target.arn))
    ]
    
    # For SQS integration
    sqs_targets = [
      for target in local.flattened_targets : target.arn
      if can(regex("^arn:aws:sqs:", target.arn))
    ]
    
    # For SNS integration
    sns_targets = [
      for target in local.flattened_targets : target.arn
      if can(regex("^arn:aws:sns:", target.arn))
    ]
    
    # For ECS integration
    ecs_targets = [
      for target in local.flattened_targets : target.arn
      if can(regex("^arn:aws:ecs:", target.arn))
    ]
    
    # For Step Functions integration
    stepfunctions_targets = [
      for target in local.flattened_targets : target.arn
      if can(regex("^arn:aws:states:", target.arn))
    ]
  }
}

# Standard Module Metadata
output "module_metadata" {
  description = "모듈 메타데이터 (표준화된 형식)"
  value = {
    module_name    = "eventbridge"
    module_version = "1.0.0"
    resource_count = (var.create_custom_bus ? 1 : 0) + length(var.rules) + length(local.flattened_targets) + length(var.connections) + length(var.api_destinations) + length(var.archives) + length(var.replays)
    
    capabilities = compact([
      "event_routing",
      "rule_management",
      "target_management",
      var.create_custom_bus ? "custom_bus" : "default_bus",
      length(var.connections) > 0 ? "api_destinations" : null,
      length(var.archives) > 0 ? "event_archive" : null,
      length(var.replays) > 0 ? "event_replay" : null,
      var.create_cloudwatch_alarms ? "monitoring" : null
    ])
    
    supported_targets = [
      "lambda",
      "sqs",
      "sns",
      "ecs", 
      "kinesis",
      "batch",
      "api_gateway",
      "step_functions"
    ]
  }
}