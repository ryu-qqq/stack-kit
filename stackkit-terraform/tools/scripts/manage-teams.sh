#!/bin/bash
set -euo pipefail

# 🏢 StackKit Enterprise Team Management
# Advanced team operations: list, scale, rotate secrets, decommission

# Colors and logging
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; exit 1; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_enterprise() { echo -e "${PURPLE}🏢 $1${NC}"; }

show_banner() {
    echo -e "${PURPLE}"
    cat << "EOF"
 _____                      __  __             
|_   _|                    |  \/  |            
  | | ___  __ _ _ __ ___    | .  . | __ _ _ __   
  | |/ _ \/ _` | '_ ` _ \   | |\/| |/ _` | '__|  
  | |  __/ (_| | | | | | |  | |  | | (_| | |     
  \_/\___|\__,_|_| |_| |_|  \_|  |_/\__, |_|     
                                    __/ |       
                                   |___/        
🏢 Team Management Console
EOF
    echo -e "${NC}"
}

show_help() {
    cat << EOF
Usage: $0 <command> [options]

🏢 Enterprise team management operations

Commands:
    list                        List all teams and their status
    scale --team-name TEAM      Scale team resources
    rotate --team-name TEAM     Rotate team secrets
    budget --team-name TEAM     Manage team budgets
    decommission --team-name TEAM   Safely decommission a team
    diagnose --team-name TEAM   Diagnose team issues
    backup --team-name TEAM     Backup team state

Global Options:
    --enterprise-config PATH    Path to enterprise config file
    --aws-profile PROFILE       AWS CLI profile (default: default)
    --output FORMAT             Output format: table|json|yaml (default: table)

List Command:
    list [--status STATUS]      Filter by status: active|archived|all
    list [--cost-center CENTER] Filter by cost center

Scale Command Options:
    --atlantis-size SIZE        New Atlantis size: small|medium|large
    --atlantis-cpu CPU          Custom CPU units (overrides size)
    --atlantis-memory MEMORY    Custom memory MB (overrides size)

Rotate Command Options:
    --github-token TOKEN        New GitHub token
    --slack-webhook URL         New Slack webhook
    --infracost-key KEY         New Infracost key
    --all                       Rotate all secrets

Budget Command Options:
    --monthly-limit AMOUNT      Set monthly budget limit
    --alert-thresholds "50,80"  Alert percentages
    --cost-center CENTER        Update cost center

Decommission Command Options:
    --backup                    Backup resources before decommission
    --transfer-to TEAM          Transfer resources to another team
    --force                     Force decommission without prompts

Examples:
    # List all teams
    $0 list

    # Scale team Atlantis instance
    $0 scale --team-name platform --atlantis-size large

    # Rotate GitHub token for team
    $0 rotate --team-name platform --github-token ghp_new_token

    # Set team budget
    $0 budget --team-name platform --monthly-limit 5000 --alert-thresholds "75,90"

    # Diagnose team issues
    $0 diagnose --team-name platform

    # Safely decommission team
    $0 decommission --team-name old-team --backup --transfer-to platform

EOF
}

# Default values
COMMAND=""
TEAM_NAME=""
ENTERPRISE_CONFIG=""
AWS_PROFILE="default"
OUTPUT_FORMAT="table"

# Command-specific variables
ATLANTIS_SIZE=""
ATLANTIS_CPU=""
ATLANTIS_MEMORY=""
GITHUB_TOKEN=""
SLACK_WEBHOOK=""
INFRACOST_KEY=""
ROTATE_ALL=false
MONTHLY_LIMIT=""
ALERT_THRESHOLDS=""
COST_CENTER=""
STATUS_FILTER=""
BACKUP_TEAM=false
TRANSFER_TO=""
FORCE=false

# Parse arguments
if [[ $# -eq 0 ]]; then
    show_help
    exit 0
fi

COMMAND="$1"
shift

while [[ $# -gt 0 ]]; do
    case $1 in
        --team-name)
            TEAM_NAME="$2"
            shift 2
            ;;
        --enterprise-config)
            ENTERPRISE_CONFIG="$2"
            shift 2
            ;;
        --aws-profile)
            AWS_PROFILE="$2"
            shift 2
            ;;
        --output)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        --atlantis-size)
            ATLANTIS_SIZE="$2"
            shift 2
            ;;
        --atlantis-cpu)
            ATLANTIS_CPU="$2"
            shift 2
            ;;
        --atlantis-memory)
            ATLANTIS_MEMORY="$2"
            shift 2
            ;;
        --github-token)
            GITHUB_TOKEN="$2"
            shift 2
            ;;
        --slack-webhook)
            SLACK_WEBHOOK="$2"
            shift 2
            ;;
        --infracost-key)
            INFRACOST_KEY="$2"
            shift 2
            ;;
        --all)
            ROTATE_ALL=true
            shift
            ;;
        --monthly-limit)
            MONTHLY_LIMIT="$2"
            shift 2
            ;;
        --alert-thresholds)
            ALERT_THRESHOLDS="$2"
            shift 2
            ;;
        --cost-center)
            COST_CENTER="$2"
            shift 2
            ;;
        --status)
            STATUS_FILTER="$2"
            shift 2
            ;;
        --backup)
            BACKUP_TEAM=true
            shift
            ;;
        --transfer-to)
            TRANSFER_TO="$2"
            shift 2
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            ;;
    esac
done

# Load enterprise configuration
load_enterprise_config() {
    local config_paths=(
        "$ENTERPRISE_CONFIG"
        "../enterprise-config.yaml"
        "/tmp/stackkit-enterprise-*/enterprise-config.yaml"
    )
    
    for config_path in "${config_paths[@]}"; do
        if [[ -n "$config_path" && -f "$config_path" ]]; then
            ENTERPRISE_CONFIG="$config_path"
            break
        fi
    done
    
    if [[ -z "$ENTERPRISE_CONFIG" || ! -f "$ENTERPRISE_CONFIG" ]]; then
        log_error "Enterprise config not found. Run enterprise-bootstrap.sh first."
    fi
    
    # Parse enterprise configuration
    ORGANIZATION=$(grep "organization:" "$ENTERPRISE_CONFIG" | awk '{print $2}')
    MASTER_REGION=$(grep "master_region:" "$ENTERPRISE_CONFIG" | awk '{print $2}')
    ACCOUNT_ID=$(grep "account_id:" "$ENTERPRISE_CONFIG" | awk '{print $2}')
}

# List all teams
cmd_list() {
    log_info "Listing teams for organization: $ORGANIZATION"
    
    local table_name="stackkit-enterprise-$ORGANIZATION-teams"
    
    # Get all teams from DynamoDB
    local teams_data=$(aws dynamodb scan \
        --profile "$AWS_PROFILE" \
        --region "$MASTER_REGION" \
        --table-name "$table_name" \
        --query 'Items' \
        --output json)
    
    if [[ "$teams_data" == "[]" ]]; then
        log_warning "No teams found"
        return
    fi
    
    case $OUTPUT_FORMAT in
        "json")
            echo "$teams_data" | jq '.'
            ;;
        "yaml")
            echo "$teams_data" | jq -r 'to_entries[] | "- name: " + .value.id.S + "\n  team_id: " + .value.team_id.N + "\n  status: " + .value.status.S + "\n  cost_center: " + .value.cost_center.S + "\n  created: " + .value.created.S'
            ;;
        "table"|*)
            echo ""
            printf "%-20s %-5s %-15s %-15s %-10s %-20s %-12s\n" "TEAM NAME" "ID" "STATUS" "COST CENTER" "SIZE" "CREATED" "ATLANTIS URL"
            echo "$(printf '%*s' 120 | tr ' ' '-')"
            
            echo "$teams_data" | jq -r '.[] | 
                [.id.S, .team_id.N, .status.S, .cost_center.S, .atlantis_size.S, .created.S, 
                 ("https://" + .id.S + ".atlantis." + "'$ORGANIZATION'" + ".com")] | 
                @tsv' | \
            while IFS=$'\t' read -r name id status cost_center size created url; do
                # Check if team Atlantis is actually running
                if aws ecs describe-services \
                    --profile "$AWS_PROFILE" \
                    --region "$(echo "$teams_data" | jq -r ".[] | select(.id.S==\"$name\") | .aws_region.S")" \
                    --cluster "stackkit-team-$name-atlantis" \
                    --services "stackkit-team-$name-atlantis" \
                    --query 'services[0].runningCount' \
                    --output text &>/dev/null; then
                    status="running"
                else
                    status="stopped"
                fi
                
                printf "%-20s %-5s %-15s %-15s %-10s %-20s %-12s\n" \
                    "$name" "$id" "$status" "$cost_center" "$size" \
                    "$(date -d "$created" +"%Y-%m-%d" 2>/dev/null || echo "$created")" \
                    "$url"
            done
            echo ""
            ;;
    esac
    
    log_success "Team listing complete"
}

# Scale team resources
cmd_scale() {
    if [[ -z "$TEAM_NAME" ]]; then
        log_error "Team name is required for scale command (--team-name)"
    fi
    
    log_info "Scaling team: $TEAM_NAME"
    
    # Get current team configuration
    local table_name="stackkit-enterprise-$ORGANIZATION-teams"
    local team_config=$(aws dynamodb get-item \
        --profile "$AWS_PROFILE" \
        --region "$MASTER_REGION" \
        --table-name "$table_name" \
        --key '{"id":{"S":"'$TEAM_NAME'"}}' \
        --query 'Item' \
        --output json)
    
    if [[ "$team_config" == "null" ]]; then
        log_error "Team '$TEAM_NAME' not found"
    fi
    
    local current_size=$(echo "$team_config" | jq -r '.atlantis_size.S // "small"')
    local team_region=$(echo "$team_config" | jq -r '.aws_region.S // "us-east-1"')
    local environment=$(echo "$team_config" | jq -r '.environment.S // "prod"')
    
    log_info "Current size: $current_size"
    
    if [[ -n "$ATLANTIS_SIZE" ]]; then
        log_info "Scaling to: $ATLANTIS_SIZE"
        
        # Define task configurations
        case $ATLANTIS_SIZE in
            "small")
                CPU=256
                MEMORY=512
                DESIRED_COUNT=1
                ;;
            "medium")
                CPU=512
                MEMORY=1024
                DESIRED_COUNT=2
                ;;
            "large")
                CPU=1024
                MEMORY=2048
                DESIRED_COUNT=3
                ;;
            *)
                log_error "Invalid size. Use: small, medium, or large"
                ;;
        esac
    else
        # Use custom CPU/Memory if specified
        CPU=${ATLANTIS_CPU:-256}
        MEMORY=${ATLANTIS_MEMORY:-512}
        DESIRED_COUNT=1
        ATLANTIS_SIZE="custom"
    fi
    
    # Update ECS service
    local cluster_name="stackkit-team-$TEAM_NAME-atlantis"
    local service_name="stackkit-team-$TEAM_NAME-atlantis"
    
    # Create new task definition with updated resources
    local current_task_def=$(aws ecs describe-task-definition \
        --profile "$AWS_PROFILE" \
        --region "$team_region" \
        --task-definition "$service_name" \
        --query 'taskDefinition' \
        --output json)
    
    # Update CPU and memory in task definition
    local new_task_def=$(echo "$current_task_def" | jq --arg cpu "$CPU" --arg memory "$MEMORY" '
        del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .placementConstraints, .compatibilities, .registeredAt, .registeredBy) |
        .cpu = $cpu |
        .memory = $memory
    ')
    
    # Register new task definition
    local new_task_arn=$(aws ecs register-task-definition \
        --profile "$AWS_PROFILE" \
        --region "$team_region" \
        --cli-input-json "$new_task_def" \
        --query 'taskDefinition.taskDefinitionArn' \
        --output text)
    
    # Update service with new task definition and desired count
    aws ecs update-service \
        --profile "$AWS_PROFILE" \
        --region "$team_region" \
        --cluster "$cluster_name" \
        --service "$service_name" \
        --task-definition "$new_task_arn" \
        --desired-count "$DESIRED_COUNT" \
        > /dev/null
    
    # Update team configuration in DynamoDB
    aws dynamodb update-item \
        --profile "$AWS_PROFILE" \
        --region "$MASTER_REGION" \
        --table-name "$table_name" \
        --key '{"id":{"S":"'$TEAM_NAME'"}}' \
        --update-expression "SET atlantis_size = :size, last_modified = :timestamp" \
        --expression-attribute-values '{
            ":size": {"S": "'$ATLANTIS_SIZE'"},
            ":timestamp": {"S": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}
        }' \
        > /dev/null
    
    log_success "Team '$TEAM_NAME' scaled to $ATLANTIS_SIZE (CPU: $CPU, Memory: $MEMORY, Count: $DESIRED_COUNT)"
    log_info "Service update in progress. Check ECS console for deployment status."
}

# Rotate team secrets
cmd_rotate() {
    if [[ -z "$TEAM_NAME" ]]; then
        log_error "Team name is required for rotate command (--team-name)"
    fi
    
    log_info "Rotating secrets for team: $TEAM_NAME"
    
    # Get team configuration
    local table_name="stackkit-enterprise-$ORGANIZATION-teams"
    local team_config=$(aws dynamodb get-item \
        --profile "$AWS_PROFILE" \
        --region "$MASTER_REGION" \
        --table-name "$table_name" \
        --key '{"id":{"S":"'$TEAM_NAME'"}}' \
        --query 'Item' \
        --output json)
    
    if [[ "$team_config" == "null" ]]; then
        log_error "Team '$TEAM_NAME' not found"
    fi
    
    local team_region=$(echo "$team_config" | jq -r '.aws_region.S // "us-east-1"')
    local environment=$(echo "$team_config" | jq -r '.environment.S // "prod"')
    local secret_name="stackkit-team-$TEAM_NAME-atlantis-secrets"
    
    # Get current secrets
    local current_secrets=$(aws secretsmanager get-secret-value \
        --profile "$AWS_PROFILE" \
        --region "$team_region" \
        --secret-id "$secret_name" \
        --query 'SecretString' \
        --output text)
    
    local updated_secrets="$current_secrets"
    
    # Update specific secrets
    if [[ -n "$GITHUB_TOKEN" ]]; then
        log_info "Updating GitHub token"
        updated_secrets=$(echo "$updated_secrets" | jq --arg token "$GITHUB_TOKEN" '.github_token = $token')
    fi
    
    if [[ -n "$SLACK_WEBHOOK" ]]; then
        log_info "Updating Slack webhook"
        updated_secrets=$(echo "$updated_secrets" | jq --arg webhook "$SLACK_WEBHOOK" '.slack_webhook_url = $webhook')
    fi
    
    if [[ -n "$INFRACOST_KEY" ]]; then
        log_info "Updating Infracost API key"
        updated_secrets=$(echo "$updated_secrets" | jq --arg key "$INFRACOST_KEY" '.infracost_api_key = $key')
    fi
    
    if [[ $ROTATE_ALL == true ]]; then
        log_info "Rotating GitHub webhook secret"
        local new_webhook_secret=$(openssl rand -hex 32)
        updated_secrets=$(echo "$updated_secrets" | jq --arg secret "$new_webhook_secret" '.github_secret = $secret')
    fi
    
    # Update secrets in Secrets Manager
    aws secretsmanager update-secret \
        --profile "$AWS_PROFILE" \
        --region "$team_region" \
        --secret-id "$secret_name" \
        --secret-string "$updated_secrets" \
        > /dev/null
    
    # Restart ECS service to pick up new secrets
    local cluster_name="stackkit-team-$TEAM_NAME-atlantis"
    local service_name="stackkit-team-$TEAM_NAME-atlantis"
    
    aws ecs update-service \
        --profile "$AWS_PROFILE" \
        --region "$team_region" \
        --cluster "$cluster_name" \
        --service "$service_name" \
        --force-new-deployment \
        > /dev/null
    
    log_success "Secrets rotated for team '$TEAM_NAME'"
    log_warning "ECS service restarting to pick up new secrets"
}

# Manage team budgets
cmd_budget() {
    if [[ -z "$TEAM_NAME" ]]; then
        log_error "Team name is required for budget command (--team-name)"
    fi
    
    log_info "Managing budget for team: $TEAM_NAME"
    
    if [[ -n "$MONTHLY_LIMIT" ]]; then
        # Create/update budget
        local budget_name="stackkit-team-$TEAM_NAME-monthly-budget"
        
        local budget_config=$(cat << EOF
{
    "BudgetName": "$budget_name",
    "BudgetLimit": {
        "Amount": "$MONTHLY_LIMIT",
        "Unit": "USD"
    },
    "TimeUnit": "MONTHLY",
    "TimePeriod": {
        "Start": "$(date -u +"%Y-%m-01T00:00:00Z")",
        "End": "2030-01-01T00:00:00Z"
    },
    "CostFilters": {
        "TagKey": ["Team"],
        "TagValue": ["$TEAM_NAME"]
    },
    "BudgetType": "COST"
}
EOF
        )
        
        # Create budget notifications
        if [[ -n "$ALERT_THRESHOLDS" ]]; then
            IFS=',' read -ra THRESHOLDS <<< "$ALERT_THRESHOLDS"
            local notifications='[]'
            
            for threshold in "${THRESHOLDS[@]}"; do
                notifications=$(echo "$notifications" | jq --arg threshold "$threshold" '. += [{
                    "Notification": {
                        "NotificationType": "ACTUAL",
                        "ComparisonOperator": "GREATER_THAN",
                        "Threshold": ($threshold | tonumber),
                        "ThresholdType": "PERCENTAGE"
                    },
                    "Subscribers": [{
                        "SubscriptionType": "EMAIL",
                        "Address": "admin@'$ORGANIZATION'.com"
                    }]
                }]')
            done
            
            aws budgets put-budget \
                --profile "$AWS_PROFILE" \
                --account-id "$ACCOUNT_ID" \
                --budget "$budget_config" \
                --notifications-with-subscribers "$notifications" \
                > /dev/null
        else
            aws budgets put-budget \
                --profile "$AWS_PROFILE" \
                --account-id "$ACCOUNT_ID" \
                --budget "$budget_config" \
                > /dev/null
        fi
        
        log_success "Budget set for team '$TEAM_NAME': $MONTHLY_LIMIT USD/month"
    fi
    
    # Update cost center if provided
    if [[ -n "$COST_CENTER" ]]; then
        local table_name="stackkit-enterprise-$ORGANIZATION-teams"
        
        aws dynamodb update-item \
            --profile "$AWS_PROFILE" \
            --region "$MASTER_REGION" \
            --table-name "$table_name" \
            --key '{"id":{"S":"'$TEAM_NAME'"}}' \
            --update-expression "SET cost_center = :center" \
            --expression-attribute-values '{":center": {"S": "'$COST_CENTER'"}}' \
            > /dev/null
        
        log_success "Updated cost center for team '$TEAM_NAME': $COST_CENTER"
    fi
}

# Diagnose team issues
cmd_diagnose() {
    if [[ -z "$TEAM_NAME" ]]; then
        log_error "Team name is required for diagnose command (--team-name)"
    fi
    
    log_enterprise "Diagnosing team: $TEAM_NAME"
    
    # Get team configuration
    local table_name="stackkit-enterprise-$ORGANIZATION-teams"
    local team_config=$(aws dynamodb get-item \
        --profile "$AWS_PROFILE" \
        --region "$MASTER_REGION" \
        --table-name "$table_name" \
        --key '{"id":{"S":"'$TEAM_NAME'"}}' \
        --query 'Item' \
        --output json)
    
    if [[ "$team_config" == "null" ]]; then
        log_error "Team '$TEAM_NAME' not found"
    fi
    
    local team_region=$(echo "$team_config" | jq -r '.aws_region.S // "us-east-1"')
    local environment=$(echo "$team_config" | jq -r '.environment.S // "prod"')
    
    echo ""
    echo "🔍 TEAM DIAGNOSIS REPORT: $TEAM_NAME"
    echo "$(printf '%*s' 60 | tr ' ' '=')"
    
    # 1. Check ECS service status
    echo ""
    echo "📋 ECS Service Status:"
    local cluster_name="stackkit-team-$TEAM_NAME-atlantis"
    local service_name="stackkit-team-$TEAM_NAME-atlantis"
    
    if aws ecs describe-services \
        --profile "$AWS_PROFILE" \
        --region "$team_region" \
        --cluster "$cluster_name" \
        --services "$service_name" \
        --query 'services[0].[serviceName,status,runningCount,desiredCount,deploymentStatus]' \
        --output table &>/dev/null; then
        
        aws ecs describe-services \
            --profile "$AWS_PROFILE" \
            --region "$team_region" \
            --cluster "$cluster_name" \
            --services "$service_name" \
            --query 'services[0].[serviceName,status,runningCount,desiredCount]' \
            --output table
    else
        echo "  ❌ ECS service not found or not accessible"
    fi
    
    # 2. Check ALB health
    echo ""
    echo "🌐 Load Balancer Health:"
    local alb_name="stackkit-team-$TEAM_NAME-alb"
    
    if aws elbv2 describe-load-balancers \
        --profile "$AWS_PROFILE" \
        --region "$team_region" \
        --names "$alb_name" \
        --query 'LoadBalancers[0].[LoadBalancerName,State.Code,Scheme]' \
        --output table &>/dev/null; then
        
        aws elbv2 describe-load-balancers \
            --profile "$AWS_PROFILE" \
            --region "$team_region" \
            --names "$alb_name" \
            --query 'LoadBalancers[0].[LoadBalancerName,State.Code,DNSName]' \
            --output table
    else
        echo "  ❌ Load balancer not found or not accessible"
    fi
    
    # 3. Check recent logs
    echo ""
    echo "📝 Recent Logs (last 10 minutes):"
    local log_group="/ecs/stackkit-team-$TEAM_NAME-atlantis"
    
    if aws logs describe-log-groups \
        --profile "$AWS_PROFILE" \
        --region "$team_region" \
        --log-group-name-prefix "$log_group" \
        --query 'logGroups[0].logGroupName' \
        --output text &>/dev/null; then
        
        aws logs filter-log-events \
            --profile "$AWS_PROFILE" \
            --region "$team_region" \
            --log-group-name "$log_group" \
            --start-time "$(($(date +%s) * 1000 - 600000))" \
            --query 'events[-5:].message' \
            --output text
    else
        echo "  ❌ Log group not found"
    fi
    
    # 4. Check secrets
    echo ""
    echo "🔐 Secrets Status:"
    local secret_name="stackkit-team-$TEAM_NAME-atlantis-secrets"
    
    if aws secretsmanager describe-secret \
        --profile "$AWS_PROFILE" \
        --region "$team_region" \
        --secret-id "$secret_name" \
        --query '[Name,LastChangedDate,LastAccessedDate]' \
        --output table &>/dev/null; then
        
        echo "  ✅ Secrets accessible"
        aws secretsmanager describe-secret \
            --profile "$AWS_PROFILE" \
            --region "$team_region" \
            --secret-id "$secret_name" \
            --query '[Name,LastChangedDate]' \
            --output table
    else
        echo "  ❌ Secrets not accessible"
    fi
    
    echo ""
    echo "$(printf '%*s' 60 | tr ' ' '=')"
    log_success "Diagnosis completed for team: $TEAM_NAME"
}

# Main command dispatcher
show_banner

case $COMMAND in
    "list")
        load_enterprise_config
        cmd_list
        ;;
    "scale")
        load_enterprise_config
        cmd_scale
        ;;
    "rotate")
        load_enterprise_config
        cmd_rotate
        ;;
    "budget")
        load_enterprise_config
        cmd_budget
        ;;
    "diagnose")
        load_enterprise_config
        cmd_diagnose
        ;;
    *)
        log_error "Unknown command: $COMMAND. Use --help for available commands."
        ;;
esac