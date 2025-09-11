# Lambda Processor Messaging Addon - Outputs
# Version: v1.0.0

# Lambda Function Information
output "function_arn" {
  description = "Lambda 함수 ARN"
  value       = aws_lambda_function.processor.arn
}

output "function_name" {
  description = "Lambda 함수 이름"
  value       = aws_lambda_function.processor.function_name
}

output "function_qualified_arn" {
  description = "Lambda 함수 Qualified ARN"
  value       = aws_lambda_function.processor.qualified_arn
}

output "function_version" {
  description = "Lambda 함수 버전"
  value       = aws_lambda_function.processor.version
}

output "function_last_modified" {
  description = "Lambda 함수 마지막 수정 시간"
  value       = aws_lambda_function.processor.last_modified
}

output "function_source_code_hash" {
  description = "Lambda 함수 소스 코드 해시"
  value       = aws_lambda_function.processor.source_code_hash
}

output "function_invoke_arn" {
  description = "Lambda 함수 호출 ARN"
  value       = aws_lambda_function.processor.invoke_arn
}

# IAM Information
output "iam_role_arn" {
  description = "Lambda 함수 IAM 역할 ARN"
  value       = aws_iam_role.lambda.arn
}

output "iam_role_name" {
  description = "Lambda 함수 IAM 역할 이름"
  value       = aws_iam_role.lambda.name
}

output "iam_policy_arn" {
  description = "메시지 처리 IAM 정책 ARN"
  value       = aws_iam_policy.message_processing.arn
}

# Event Source Mapping Information
output "sqs_event_source_mapping" {
  description = "SQS 이벤트 소스 매핑 정보"
  value = var.sqs_config != null ? {
    uuid              = aws_lambda_event_source_mapping.sqs[0].uuid
    function_name     = aws_lambda_event_source_mapping.sqs[0].function_name
    event_source_arn  = aws_lambda_event_source_mapping.sqs[0].event_source_arn
    batch_size        = aws_lambda_event_source_mapping.sqs[0].batch_size
    last_modified     = aws_lambda_event_source_mapping.sqs[0].last_modified
    state             = aws_lambda_event_source_mapping.sqs[0].state
    state_transition_reason = aws_lambda_event_source_mapping.sqs[0].state_transition_reason
  } : null
}

# CloudWatch Information
output "cloudwatch_log_group" {
  description = "CloudWatch 로그 그룹 정보"
  value = {
    name = aws_cloudwatch_log_group.lambda.name
    arn  = aws_cloudwatch_log_group.lambda.arn
  }
}

output "cloudwatch_alarms" {
  description = "생성된 CloudWatch 알람 정보"
  value = var.enable_monitoring ? {
    errors = {
      name = aws_cloudwatch_metric_alarm.lambda_errors[0].alarm_name
      arn  = aws_cloudwatch_metric_alarm.lambda_errors[0].arn
    }
    duration = {
      name = aws_cloudwatch_metric_alarm.lambda_duration[0].alarm_name
      arn  = aws_cloudwatch_metric_alarm.lambda_duration[0].arn
    }
    throttles = {
      name = aws_cloudwatch_metric_alarm.lambda_throttles[0].alarm_name
      arn  = aws_cloudwatch_metric_alarm.lambda_throttles[0].arn
    }
    concurrent_executions = var.monitoring_config.create_concurrency_alarm ? {
      name = aws_cloudwatch_metric_alarm.lambda_concurrent_executions[0].alarm_name
      arn  = aws_cloudwatch_metric_alarm.lambda_concurrent_executions[0].arn
    } : null
  } : null
}

output "dashboard_url" {
  description = "CloudWatch 대시보드 URL"
  value = var.create_dashboard ? "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.lambda_metrics[0].dashboard_name}" : null
}

# Lambda Permissions
output "lambda_permissions" {
  description = "생성된 Lambda 권한 정보"
  value = {
    sns_permissions = var.sns_config != null ? {
      for idx, permission in aws_lambda_permission.sns_invoke : idx => {
        statement_id = permission.statement_id
        source_arn   = permission.source_arn
      }
    } : {}
    
    eventbridge_permissions = var.eventbridge_config != null ? {
      for idx, permission in aws_lambda_permission.eventbridge_invoke : idx => {
        statement_id = permission.statement_id
        source_arn   = permission.source_arn
      }
    } : {}
  }
}

# Function Configuration
output "function_configuration" {
  description = "Lambda 함수 설정 정보"
  value = {
    runtime                       = aws_lambda_function.processor.runtime
    handler                       = aws_lambda_function.processor.handler
    memory_size                   = aws_lambda_function.processor.memory_size
    timeout                       = aws_lambda_function.processor.timeout
    architectures                 = aws_lambda_function.processor.architectures
    package_type                  = aws_lambda_function.processor.package_type
    reserved_concurrent_executions = aws_lambda_function.processor.reserved_concurrent_executions
    vpc_configured                = var.vpc_config != null
    tracing_mode                  = var.tracing_mode
    layers_count                  = length(var.layers)
    environment_variables_count   = length(var.environment_variables)
    dead_letter_queue_configured  = var.dead_letter_queue_arn != null
  }
}

# Integration Configuration
output "integration_config" {
  description = "다른 서비스와의 통합을 위한 설정"
  value = {
    # For SNS topic subscription
    lambda_arn_for_sns = aws_lambda_function.processor.arn
    
    # For SQS event source mapping
    lambda_arn_for_sqs = aws_lambda_function.processor.arn
    
    # For EventBridge target
    lambda_arn_for_eventbridge = aws_lambda_function.processor.arn
    
    # For API Gateway integration
    lambda_invoke_arn = aws_lambda_function.processor.invoke_arn
    
    # CloudFormation stack outputs
    cloudformation_stack_outputs = {
      FunctionArn          = aws_lambda_function.processor.arn
      FunctionName         = aws_lambda_function.processor.function_name
      InvokeArn           = aws_lambda_function.processor.invoke_arn
      RoleArn             = aws_iam_role.lambda.arn
      LogGroupName        = aws_cloudwatch_log_group.lambda.name
    }
  }
}

# Processing Statistics
output "processing_stats" {
  description = "처리 통계 및 성능 정보"
  value = {
    configured_memory_mb           = var.memory_size
    configured_timeout_seconds     = var.timeout
    estimated_cold_start_time_ms   = var.runtime == "python3.11" ? 200 : var.runtime == "nodejs18.x" ? 150 : 300
    concurrent_execution_limit     = var.reserved_concurrent_executions
    sqs_batch_size                = var.sqs_config != null ? var.sqs_config.batch_size : null
    vpc_cold_start_penalty        = var.vpc_config != null ? "Additional 1-3 seconds" : "None"
    tracing_overhead              = var.tracing_mode == "Active" ? "Minor performance impact" : "None"
  }
}

# Security Information
output "security_configuration" {
  description = "보안 설정 정보"
  value = {
    encryption_at_rest    = var.kms_key_arn != null
    encryption_in_transit = true  # Always enabled for Lambda
    vpc_isolated         = var.vpc_config != null
    iam_role_arn         = aws_iam_role.lambda.arn
    execution_role_type  = "Custom"
    dlq_configured       = var.dead_letter_queue_arn != null
    tracing_enabled      = var.tracing_mode == "Active"
  }
}

# Cost Optimization Information
output "cost_optimization" {
  description = "비용 최적화 정보"
  value = {
    memory_size_mb               = var.memory_size
    timeout_seconds             = var.timeout
    estimated_monthly_requests  = "Variable based on usage"
    reserved_concurrency       = var.reserved_concurrent_executions != null ? var.reserved_concurrent_executions : "Unreserved"
    arm_architecture           = contains(var.architectures, "arm64") ? "Yes - 20% cost savings" : "No"
    log_retention_days         = var.log_retention_days
  }
}

# Debugging Information
output "debugging_info" {
  description = "디버깅을 위한 정보"
  value = {
    log_group_name       = aws_cloudwatch_log_group.lambda.name
    xray_tracing        = var.tracing_mode
    vpc_configuration   = var.vpc_config != null ? {
      subnet_count = length(var.vpc_config.subnet_ids)
      sg_count     = length(var.vpc_config.security_group_ids)
    } : null
    environment_variables = keys(var.environment_variables)
    layers              = var.layers
  }
}

# Regional Information
output "region" {
  description = "리소스가 생성된 AWS 리전"
  value       = data.aws_region.current.name
}

output "account_id" {
  description = "AWS 계정 ID"
  value       = data.aws_caller_identity.current.account_id
  sensitive   = true
}

# For terraform-aws-modules compatibility
output "lambda_function_arn" {
  description = "Lambda 함수 ARN (terraform-aws-modules 호환)"
  value       = aws_lambda_function.processor.arn
}

output "lambda_function_name" {
  description = "Lambda 함수 이름 (terraform-aws-modules 호환)"
  value       = aws_lambda_function.processor.function_name
}

output "lambda_role_arn" {
  description = "Lambda IAM 역할 ARN (terraform-aws-modules 호환)"
  value       = aws_iam_role.lambda.arn
}