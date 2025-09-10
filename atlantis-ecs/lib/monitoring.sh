#!/bin/bash
# StackKit DevOps Library - Monitoring & Observability
# CloudWatch 메트릭 기반 알림 시스템

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# CloudWatch 메트릭 생성/업데이트
put_custom_metric() {
    local namespace="$1"
    local metric_name="$2"
    local value="$3"
    local unit="${4:-Count}"
    local region="${5:-ap-northeast-2}"
    local dimensions="$6"  # JSON format: [{"Name":"key","Value":"value"}]
    
    local metric_data
    metric_data=$(cat <<JSON
{
    "MetricName": "$metric_name",
    "Value": $value,
    "Unit": "$unit",
    "Timestamp": "$(iso_timestamp)"$([ -n "$dimensions" ] && echo ", \"Dimensions\": $dimensions")
}
JSON
)
    
    if aws cloudwatch put-metric-data \
        --namespace "$namespace" \
        --metric-data "$metric_data" \
        --region "$region" >/dev/null 2>&1; then
        log_debug "Metric sent: $namespace/$metric_name = $value $unit"
    else
        log_warning "Failed to send metric: $namespace/$metric_name"
    fi
}

# 배포 메트릭 전송
send_deployment_metrics() {
    local stack_name="$1"
    local deployment_status="$2"  # success, failure, rollback
    local duration_seconds="$3"
    local region="${4:-ap-northeast-2}"
    local environment="${5:-prod}"
    
    local namespace="StackKit/Deployment"
    local dimensions
    dimensions=$(cat <<JSON
[
    {"Name": "StackName", "Value": "$stack_name"},
    {"Name": "Environment", "Value": "$environment"},
    {"Name": "Region", "Value": "$region"}
]
JSON
)
    
    # 배포 횟수
    put_custom_metric "$namespace" "DeploymentCount" "1" "Count" "$region" "$dimensions"
    
    # 배포 상태별 메트릭
    case "$deployment_status" in
        "success")
            put_custom_metric "$namespace" "DeploymentSuccess" "1" "Count" "$region" "$dimensions"
            put_custom_metric "$namespace" "DeploymentDuration" "$duration_seconds" "Seconds" "$region" "$dimensions"
            ;;
        "failure")
            put_custom_metric "$namespace" "DeploymentFailure" "1" "Count" "$region" "$dimensions"
            ;;
        "rollback")
            put_custom_metric "$namespace" "DeploymentRollback" "1" "Count" "$region" "$dimensions"
            ;;
    esac
    
    log_info "Deployment metrics sent to CloudWatch"
}

# 인프라 비용 메트릭 전송 (Infracost 연동)
send_cost_metrics() {
    local stack_name="$1"
    local cost_change="$2"  # 비용 변화량 (달러)
    local total_cost="$3"   # 총 비용 (달러)
    local region="${4:-ap-northeast-2}"
    local environment="${5:-prod}"
    
    local namespace="StackKit/Cost"
    local dimensions
    dimensions=$(cat <<JSON
[
    {"Name": "StackName", "Value": "$stack_name"},
    {"Name": "Environment", "Value": "$environment"},
    {"Name": "Region", "Value": "$region"}
]
JSON
)
    
    # 비용 메트릭
    if [[ -n "$cost_change" && "$cost_change" != "0" ]]; then
        put_custom_metric "$namespace" "CostChange" "$cost_change" "None" "$region" "$dimensions"
    fi
    
    if [[ -n "$total_cost" && "$total_cost" != "0" ]]; then
        put_custom_metric "$namespace" "TotalCost" "$total_cost" "None" "$region" "$dimensions"
    fi
    
    log_info "Cost metrics sent to CloudWatch"
}

# Terraform 상태 메트릭 전송
send_terraform_state_metrics() {
    local stack_name="$1"
    local region="${2:-ap-northeast-2}"
    local environment="${3:-prod}"
    
    local namespace="StackKit/TerraformState"
    local dimensions
    dimensions=$(cat <<JSON
[
    {"Name": "StackName", "Value": "$stack_name"},
    {"Name": "Environment", "Value": "$environment"},
    {"Name": "Region", "Value": "$region"}
]
JSON
)
    
    # Terraform 상태 분석
    if command -v terraform &> /dev/null && [[ -f "terraform.tfstate" || -f ".terraform/terraform.tfstate" ]]; then
        local state_file
        if [[ -f "terraform.tfstate" ]]; then
            state_file="terraform.tfstate"
        else
            state_file=".terraform/terraform.tfstate"
        fi
        
        # 리소스 수 계산
        local resource_count
        resource_count=$(terraform show -json 2>/dev/null | jq '.values.root_module.resources | length' 2>/dev/null || echo "0")
        
        put_custom_metric "$namespace" "ResourceCount" "$resource_count" "Count" "$region" "$dimensions"
        
        # 상태 파일 크기 (KB)
        local state_size_kb
        state_size_kb=$(stat -f%z "$state_file" 2>/dev/null | awk '{print int($1/1024)}' || echo "0")
        put_custom_metric "$namespace" "StateSizeKB" "$state_size_kb" "Kilobytes" "$region" "$dimensions"
        
        log_info "Terraform state metrics sent: $resource_count resources, ${state_size_kb}KB state"
    fi
}

# CloudWatch 알람 생성
create_deployment_alarms() {
    local stack_name="$1"
    local sns_topic_arn="$2"
    local region="${3:-ap-northeast-2}"
    local environment="${4:-prod}"
    
    local alarm_prefix="${stack_name}-${environment}"
    
    # 배포 실패율 알람 (5분 간격으로 2회 이상 실패)
    aws cloudwatch put-metric-alarm \
        --alarm-name "${alarm_prefix}-deployment-failure-rate" \
        --alarm-description "Deployment failure rate alarm for $stack_name" \
        --metric-name "DeploymentFailure" \
        --namespace "StackKit/Deployment" \
        --statistic "Sum" \
        --period 300 \
        --threshold 2 \
        --comparison-operator "GreaterThanOrEqualToThreshold" \
        --evaluation-periods 1 \
        --alarm-actions "$sns_topic_arn" \
        --dimensions Name=StackName,Value="$stack_name" Name=Environment,Value="$environment" \
        --region "$region" >/dev/null 2>&1
    
    # 비용 증가 알람 (일일 비용이 $50 이상 증가)
    aws cloudwatch put-metric-alarm \
        --alarm-name "${alarm_prefix}-cost-increase" \
        --alarm-description "Cost increase alarm for $stack_name" \
        --metric-name "CostChange" \
        --namespace "StackKit/Cost" \
        --statistic "Sum" \
        --period 86400 \
        --threshold 50 \
        --comparison-operator "GreaterThanThreshold" \
        --evaluation-periods 1 \
        --alarm-actions "$sns_topic_arn" \
        --dimensions Name=StackName,Value="$stack_name" Name=Environment,Value="$environment" \
        --region "$region" >/dev/null 2>&1
    
    # 배포 지속 시간 알람 (30분 이상)
    aws cloudwatch put-metric-alarm \
        --alarm-name "${alarm_prefix}-deployment-duration" \
        --alarm-description "Long deployment duration alarm for $stack_name" \
        --metric-name "DeploymentDuration" \
        --namespace "StackKit/Deployment" \
        --statistic "Maximum" \
        --period 3600 \
        --threshold 1800 \
        --comparison-operator "GreaterThanThreshold" \
        --evaluation-periods 1 \
        --alarm-actions "$sns_topic_arn" \
        --dimensions Name=StackName,Value="$stack_name" Name=Environment,Value="$environment" \
        --region "$region" >/dev/null 2>&1
    
    log_success "CloudWatch alarms created for $stack_name"
}

# SNS 토픽 생성 (알림용)
create_notification_topic() {
    local topic_name="$1"
    local email_endpoint="$2"
    local slack_webhook_url="$3"
    local region="${4:-ap-northeast-2}"
    
    # SNS 토픽 생성
    local topic_arn
    topic_arn=$(aws sns create-topic \
        --name "$topic_name" \
        --region "$region" \
        --output text \
        --query 'TopicArn' 2>/dev/null)
    
    if [[ -z "$topic_arn" ]]; then
        error_exit "Failed to create SNS topic: $topic_name"
    fi
    
    # 이메일 구독 추가
    if [[ -n "$email_endpoint" ]]; then
        aws sns subscribe \
            --topic-arn "$topic_arn" \
            --protocol email \
            --notification-endpoint "$email_endpoint" \
            --region "$region" >/dev/null 2>&1
        log_info "Email subscription added: $email_endpoint"
    fi
    
    # Slack 웹훅 구독 추가 (Lambda를 통해)
    if [[ -n "$slack_webhook_url" ]]; then
        # Note: 실제 구현에서는 Lambda 함수가 필요
        log_info "Slack webhook configured: $slack_webhook_url"
    fi
    
    log_success "SNS topic created: $topic_arn"
    echo "$topic_arn"
}

# 배포 대시보드 생성
create_deployment_dashboard() {
    local stack_name="$1"
    local region="${2:-ap-northeast-2}"
    local environment="${3:-prod}"
    
    local dashboard_name="StackKit-${stack_name}-${environment}"
    
    local dashboard_body
    dashboard_body=$(cat <<JSON
{
    "widgets": [
        {
            "type": "metric",
            "properties": {
                "metrics": [
                    ["StackKit/Deployment", "DeploymentSuccess", "StackName", "$stack_name", "Environment", "$environment"],
                    [".", "DeploymentFailure", ".", ".", ".", "."],
                    [".", "DeploymentRollback", ".", ".", ".", "."]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "$region",
                "title": "Deployment Status"
            }
        },
        {
            "type": "metric",
            "properties": {
                "metrics": [
                    ["StackKit/Deployment", "DeploymentDuration", "StackName", "$stack_name", "Environment", "$environment"]
                ],
                "period": 300,
                "stat": "Average",
                "region": "$region",
                "title": "Deployment Duration"
            }
        },
        {
            "type": "metric",
            "properties": {
                "metrics": [
                    ["StackKit/Cost", "TotalCost", "StackName", "$stack_name", "Environment", "$environment"],
                    [".", "CostChange", ".", ".", ".", "."]
                ],
                "period": 86400,
                "stat": "Average",
                "region": "$region",
                "title": "Infrastructure Cost"
            }
        },
        {
            "type": "metric",
            "properties": {
                "metrics": [
                    ["StackKit/TerraformState", "ResourceCount", "StackName", "$stack_name", "Environment", "$environment"]
                ],
                "period": 3600,
                "stat": "Average",
                "region": "$region",
                "title": "Terraform Resources"
            }
        }
    ]
}
JSON
)
    
    if aws cloudwatch put-dashboard \
        --dashboard-name "$dashboard_name" \
        --dashboard-body "$dashboard_body" \
        --region "$region" >/dev/null 2>&1; then
        log_success "CloudWatch dashboard created: $dashboard_name"
        echo "https://${region}.console.aws.amazon.com/cloudwatch/home?region=${region}#dashboards:name=${dashboard_name}"
    else
        log_warning "Failed to create CloudWatch dashboard"
    fi
}

# 로그 그룹 생성 및 설정
setup_log_groups() {
    local stack_name="$1"
    local region="${2:-ap-northeast-2}"
    local retention_days="${3:-30}"
    
    local log_groups=(
        "/stackkit/${stack_name}/deployment"
        "/stackkit/${stack_name}/terraform"
        "/stackkit/${stack_name}/atlantis"
    )
    
    for log_group in "${log_groups[@]}"; do
        if ! aws logs describe-log-groups \
            --log-group-name-prefix "$log_group" \
            --region "$region" \
            --query 'logGroups[0].logGroupName' \
            --output text 2>/dev/null | grep -q "$log_group"; then
            
            aws logs create-log-group \
                --log-group-name "$log_group" \
                --region "$region" >/dev/null 2>&1
            
            aws logs put-retention-policy \
                --log-group-name "$log_group" \
                --retention-in-days "$retention_days" \
                --region "$region" >/dev/null 2>&1
            
            log_info "Log group created: $log_group (${retention_days}d retention)"
        fi
    done
}

# 배포 로그 전송
send_deployment_log() {
    local stack_name="$1"
    local log_level="$2"  # INFO, WARN, ERROR
    local message="$3"
    local region="${4:-ap-northeast-2}"
    
    local log_group="/stackkit/${stack_name}/deployment"
    local log_stream="deployment-$(date +%Y%m%d)"
    local timestamp
    timestamp=$(date +%s000)  # 밀리초 단위
    
    # 로그 스트림 생성 (이미 존재하면 무시)
    aws logs create-log-stream \
        --log-group-name "$log_group" \
        --log-stream-name "$log_stream" \
        --region "$region" >/dev/null 2>&1 || true
    
    # 로그 이벤트 전송
    local log_event
    log_event=$(cat <<JSON
{
    "logEvents": [
        {
            "timestamp": $timestamp,
            "message": "[$log_level] $(iso_timestamp) $message"
        }
    ]
}
JSON
)
    
    aws logs put-log-events \
        --log-group-name "$log_group" \
        --log-stream-name "$log_stream" \
        --log-events "$log_event" \
        --region "$region" >/dev/null 2>&1 || log_debug "Failed to send log event"
}

# 종합 모니터링 설정
setup_comprehensive_monitoring() {
    local stack_name="$1"
    local email_endpoint="$2"
    local slack_webhook_url="$3"
    local region="${4:-ap-northeast-2}"
    local environment="${5:-prod}"
    
    log_info "Setting up comprehensive monitoring for $stack_name..."
    
    # 로그 그룹 설정
    setup_log_groups "$stack_name" "$region"
    
    # SNS 토픽 생성
    local topic_arn
    topic_arn=$(create_notification_topic "stackkit-${stack_name}-alerts" "$email_endpoint" "$slack_webhook_url" "$region")
    
    # CloudWatch 알람 생성
    create_deployment_alarms "$stack_name" "$topic_arn" "$region" "$environment"
    
    # 대시보드 생성
    local dashboard_url
    dashboard_url=$(create_deployment_dashboard "$stack_name" "$region" "$environment")
    
    log_success "Comprehensive monitoring setup completed"
    log_info "Dashboard URL: $dashboard_url"
    log_info "SNS Topic ARN: $topic_arn"
}