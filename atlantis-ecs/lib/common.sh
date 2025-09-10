#!/bin/bash
# StackKit DevOps Library - Common Functions
# 공통 유틸리티 함수들

# Colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_debug() { [[ "${DEBUG:-}" == "true" ]] && echo -e "${CYAN}🔍 $1${NC}"; }

# Error handling with stack trace
error_exit() {
    local error_code=${2:-1}
    log_error "$1"
    
    # Print stack trace in debug mode
    if [[ "${DEBUG:-}" == "true" ]]; then
        local frame=0
        while caller $frame; do
            ((frame++))
        done
    fi
    
    exit "$error_code"
}

# Retry function with exponential backoff
retry_with_backoff() {
    local max_attempts=$1
    local delay=$2
    local command="${@:3}"
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if eval "$command"; then
            return 0
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            log_error "Command failed after $max_attempts attempts: $command"
            return 1
        fi
        
        log_warning "Attempt $attempt failed, retrying in ${delay}s..."
        sleep "$delay"
        delay=$((delay * 2))  # Exponential backoff
        ((attempt++))
    done
}

# Validate required tools
check_prerequisites() {
    local tools=("$@")
    local missing_tools=()
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        error_exit "Missing required tools: ${missing_tools[*]}"
    fi
}

# AWS credentials validation
validate_aws_credentials() {
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        error_exit "AWS credentials not configured. Run 'aws configure' or set environment variables."
    fi
    
    local account_id
    account_id=$(aws sts get-caller-identity --query Account --output text)
    local region
    region=$(aws configure get region || echo "${AWS_DEFAULT_REGION:-ap-northeast-2}")
    
    log_success "AWS Account: $account_id, Region: $region"
    echo "$account_id"
}

# Safe file operations with backup
safe_file_operation() {
    local operation=$1
    local source=$2
    local destination=${3:-}
    
    case "$operation" in
        "backup")
            if [[ -f "$source" ]]; then
                cp "$source" "${source}.backup.$(date +%Y%m%d_%H%M%S)"
                log_debug "Backup created: ${source}.backup.$(date +%Y%m%d_%H%M%S)"
            fi
            ;;
        "restore")
            local backup_file
            backup_file=$(ls "${source}.backup."* 2>/dev/null | tail -1)
            if [[ -f "$backup_file" ]]; then
                cp "$backup_file" "$source"
                log_info "Restored from backup: $backup_file"
            else
                log_warning "No backup file found for $source"
            fi
            ;;
        "atomic_write")
            local temp_file="${destination}.tmp.$$"
            cat > "$temp_file"
            mv "$temp_file" "$destination"
            log_debug "Atomic write completed: $destination"
            ;;
    esac
}

# JSON validation and processing
validate_json() {
    local json_string="$1"
    if echo "$json_string" | jq empty 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Generate secure random string
generate_secure_string() {
    local length=${1:-32}
    openssl rand -hex "$length"
}

# Time-based operations
timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

iso_timestamp() {
    date -u '+%Y-%m-%dT%H:%M:%SZ'
}

# Progress indicator
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    
    printf "\r["
    printf "%*s" $completed | tr ' ' '='
    printf "%*s" $((width - completed)) | tr ' ' '-'
    printf "] %d%% (%d/%d)" $percentage $current $total
}

# Cleanup trap handler
cleanup_on_exit() {
    local temp_files=("$@")
    for file in "${temp_files[@]}"; do
        [[ -f "$file" ]] && rm -f "$file"
    done
}

# Set common traps
set_cleanup_trap() {
    local temp_files=("$@")
    trap "cleanup_on_exit ${temp_files[*]}" EXIT INT TERM
}