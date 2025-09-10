#!/bin/bash
# StackKit DevOps Library - Deployment Functions
# DynamoDB 기반 동시성 제어 및 자동 롤백 메커니즘

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# DynamoDB 기반 배포 잠금 관리
acquire_deployment_lock() {
    local stack_name="$1"
    local region="${2:-ap-northeast-2}"
    local timeout_minutes="${3:-30}"
    local lock_table="${4:-stackkit-deployment-locks}"
    
    local lock_id="deployment-${stack_name}"
    local expiry_time
    expiry_time=$(date -d "+${timeout_minutes} minutes" -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -v+${timeout_minutes}M '+%Y-%m-%dT%H:%M:%SZ')
    local current_time
    current_time=$(iso_timestamp)
    
    log_info "Acquiring deployment lock for stack: $stack_name"
    
    # 기존 잠금 확인 및 만료된 잠금 제거
    local existing_lock
    existing_lock=$(aws dynamodb get-item \
        --table-name "$lock_table" \
        --key "{\"LockID\": {\"S\": \"$lock_id\"}}" \
        --region "$region" \
        --output json 2>/dev/null || echo '{}')
    
    if [[ $(echo "$existing_lock" | jq -r '.Item // empty') ]]; then
        local lock_expiry
        lock_expiry=$(echo "$existing_lock" | jq -r '.Item.ExpiryTime.S // empty')
        
        if [[ -n "$lock_expiry" && "$lock_expiry" > "$current_time" ]]; then
            local locked_by
            locked_by=$(echo "$existing_lock" | jq -r '.Item.LockedBy.S // "unknown"')
            error_exit "Deployment already in progress. Locked by: $locked_by, Expires: $lock_expiry"
        else
            log_warning "Found expired lock, removing..."
            release_deployment_lock "$stack_name" "$region" "$lock_table"
        fi
    fi
    
    # 새 잠금 획득
    local locked_by="${USER:-$(whoami)}@$(hostname)"
    local lock_item
    lock_item=$(cat <<JSON
{
    "LockID": {"S": "$lock_id"},
    "LockedBy": {"S": "$locked_by"},
    "ExpiryTime": {"S": "$expiry_time"},
    "StackName": {"S": "$stack_name"},
    "CreatedAt": {"S": "$current_time"},
    "LockReason": {"S": "Atlantis deployment in progress"}
}
JSON
)
    
    if aws dynamodb put-item \
        --table-name "$lock_table" \
        --item "$lock_item" \
        --condition-expression "attribute_not_exists(LockID)" \
        --region "$region" >/dev/null 2>&1; then
        log_success "Deployment lock acquired successfully"
        echo "$lock_id"
    else
        error_exit "Failed to acquire deployment lock. Another deployment may be in progress."
    fi
}

# 배포 잠금 해제
release_deployment_lock() {
    local stack_name="$1"
    local region="${2:-ap-northeast-2}"
    local lock_table="${3:-stackkit-deployment-locks}"
    
    local lock_id="deployment-${stack_name}"
    
    log_info "Releasing deployment lock for stack: $stack_name"
    
    if aws dynamodb delete-item \
        --table-name "$lock_table" \
        --key "{\"LockID\": {\"S\": \"$lock_id\"}}" \
        --region "$region" >/dev/null 2>&1; then
        log_success "Deployment lock released successfully"
    else
        log_warning "Failed to release deployment lock (may not exist)"
    fi
}

# 배포 상태 추적
track_deployment_state() {
    local stack_name="$1"
    local state="$2"  # starting, planning, applying, completed, failed, rolled_back
    local region="${3:-ap-northeast-2}"
    local state_table="${4:-stackkit-deployment-states}"
    
    local deployment_id="${stack_name}-$(date +%Y%m%d-%H%M%S)"
    local current_time
    current_time=$(iso_timestamp)
    
    local state_item
    state_item=$(cat <<JSON
{
    "DeploymentID": {"S": "$deployment_id"},
    "StackName": {"S": "$stack_name"},
    "State": {"S": "$state"},
    "Timestamp": {"S": "$current_time"},
    "User": {"S": "${USER:-$(whoami)}"},
    "Host": {"S": "$(hostname)"},
    "GitCommit": {"S": "$(git rev-parse HEAD 2>/dev/null || echo 'unknown')"},
    "TTL": {"N": "$(date -d '+30 days' +%s 2>/dev/null || date -v+30d +%s)"}
}
JSON
)
    
    aws dynamodb put-item \
        --table-name "$state_table" \
        --item "$state_item" \
        --region "$region" >/dev/null 2>&1 || log_warning "Failed to track deployment state"
    
    log_debug "Deployment state tracked: $stack_name -> $state"
}

# Terraform 상태 백업
backup_terraform_state() {
    local stack_name="$1"
    local state_bucket="$2"
    local region="${3:-ap-northeast-2}"
    
    local backup_key="backups/${stack_name}/terraform.tfstate.$(date +%Y%m%d-%H%M%S)"
    local current_key="${stack_name}.tfstate"
    
    log_info "Creating Terraform state backup..."
    
    if aws s3 cp "s3://${state_bucket}/${current_key}" "s3://${state_bucket}/${backup_key}" --region "$region" 2>/dev/null; then
        log_success "State backup created: s3://${state_bucket}/${backup_key}"
        echo "$backup_key"
    else
        log_warning "Failed to create state backup (state may not exist yet)"
        echo ""
    fi
}

# 자동 롤백 메커니즘
perform_rollback() {
    local stack_name="$1"
    local backup_key="$2"
    local state_bucket="$3"
    local region="${4:-ap-northeast-2}"
    
    if [[ -z "$backup_key" ]]; then
        log_error "No backup available for rollback"
        return 1
    fi
    
    log_warning "Performing automatic rollback..."
    track_deployment_state "$stack_name" "rolling_back" "$region"
    
    # 상태 파일 복원
    local current_key="${stack_name}.tfstate"
    if aws s3 cp "s3://${state_bucket}/${backup_key}" "s3://${state_bucket}/${current_key}" --region "$region"; then
        log_success "Terraform state restored from backup"
    else
        error_exit "Failed to restore Terraform state from backup"
    fi
    
    # Terraform 롤백 실행
    if terraform plan -detailed-exitcode >/dev/null 2>&1; then
        local exit_code=$?
        if [[ $exit_code -eq 2 ]]; then
            log_info "Changes detected, applying rollback..."
            if terraform apply -auto-approve; then
                log_success "Rollback completed successfully"
                track_deployment_state "$stack_name" "rolled_back" "$region"
                return 0
            else
                log_error "Rollback failed during terraform apply"
                track_deployment_state "$stack_name" "rollback_failed" "$region"
                return 1
            fi
        else
            log_info "No changes needed for rollback"
            track_deployment_state "$stack_name" "rolled_back" "$region"
            return 0
        fi
    else
        log_error "Terraform plan failed during rollback"
        track_deployment_state "$stack_name" "rollback_failed" "$region"
        return 1
    fi
}

# 배포 실행 with 자동 롤백
execute_deployment() {
    local stack_name="$1"
    local region="${2:-ap-northeast-2}"
    local auto_rollback="${3:-true}"
    local state_bucket="$4"
    local lock_table="${5:-stackkit-deployment-locks}"
    
    local deployment_lock=""
    local backup_key=""
    
    # 배포 잠금 획득
    deployment_lock=$(acquire_deployment_lock "$stack_name" "$region" "30" "$lock_table")
    
    # 정리 트랩 설정
    trap "release_deployment_lock '$stack_name' '$region' '$lock_table'" EXIT INT TERM
    
    # 배포 상태 추적 시작
    track_deployment_state "$stack_name" "starting" "$region"
    
    # Terraform 상태 백업
    if [[ -n "$state_bucket" ]]; then
        backup_key=$(backup_terraform_state "$stack_name" "$state_bucket" "$region")
    fi
    
    # Terraform 초기화
    log_info "Initializing Terraform..."
    if ! terraform init -upgrade; then
        track_deployment_state "$stack_name" "failed" "$region"
        error_exit "Terraform initialization failed"
    fi
    
    # Terraform Plan
    log_info "Creating Terraform plan..."
    track_deployment_state "$stack_name" "planning" "$region"
    
    if ! terraform plan -out=tfplan; then
        track_deployment_state "$stack_name" "failed" "$region"
        error_exit "Terraform plan failed"
    fi
    
    # Plan 검증
    local plan_changes
    plan_changes=$(terraform show -json tfplan | jq '.resource_changes | length')
    
    if [[ "$plan_changes" -eq 0 ]]; then
        log_info "No changes detected, skipping apply"
        track_deployment_state "$stack_name" "completed" "$region"
        return 0
    fi
    
    log_info "Plan shows $plan_changes resource changes"
    
    # Terraform Apply
    log_info "Applying Terraform changes..."
    track_deployment_state "$stack_name" "applying" "$region"
    
    if terraform apply -auto-approve tfplan; then
        log_success "Deployment completed successfully"
        track_deployment_state "$stack_name" "completed" "$region"
        
        # 성공 시 이전 백업들 정리 (최근 5개만 유지)
        if [[ -n "$state_bucket" && -n "$backup_key" ]]; then
            cleanup_old_backups "$stack_name" "$state_bucket" "$region" 5
        fi
        
        return 0
    else
        log_error "Deployment failed during terraform apply"
        track_deployment_state "$stack_name" "failed" "$region"
        
        # 자동 롤백 수행
        if [[ "$auto_rollback" == "true" && -n "$backup_key" && -n "$state_bucket" ]]; then
            log_warning "Auto-rollback enabled, attempting rollback..."
            if perform_rollback "$stack_name" "$backup_key" "$state_bucket" "$region"; then
                return 2  # 롤백 성공
            else
                return 3  # 롤백 실패
            fi
        fi
        
        return 1
    fi
}

# 오래된 백업 정리
cleanup_old_backups() {
    local stack_name="$1"
    local state_bucket="$2"
    local region="$3"
    local keep_count="${4:-5}"
    
    log_info "Cleaning up old backups (keeping latest $keep_count)..."
    
    local backup_prefix="backups/${stack_name}/"
    local old_backups
    old_backups=$(aws s3api list-objects-v2 \
        --bucket "$state_bucket" \
        --prefix "$backup_prefix" \
        --query "reverse(sort_by(Contents, &LastModified))[${keep_count}:].Key" \
        --output text \
        --region "$region" 2>/dev/null || echo "")
    
    if [[ -n "$old_backups" && "$old_backups" != "None" ]]; then
        for backup_key in $old_backups; do
            aws s3 rm "s3://${state_bucket}/${backup_key}" --region "$region" >/dev/null 2>&1
            log_debug "Removed old backup: $backup_key"
        done
        log_info "Cleaned up old backups"
    fi
}

# 배포 상태 조회
get_deployment_status() {
    local stack_name="$1"
    local region="${2:-ap-northeast-2}"
    local state_table="${3:-stackkit-deployment-states}"
    
    aws dynamodb query \
        --table-name "$state_table" \
        --index-name "StackName-Timestamp-index" \
        --key-condition-expression "StackName = :stack_name" \
        --expression-attribute-values "{\":stack_name\": {\"S\": \"$stack_name\"}}" \
        --scan-index-forward false \
        --limit 10 \
        --region "$region" \
        --output table 2>/dev/null || log_warning "Failed to query deployment status"
}