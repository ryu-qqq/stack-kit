#!/usr/bin/env python3
"""
Enhanced Terraform State Backup Lambda Function for StackKit Infrastructure
Provides automated state file backup with advanced error handling and recovery capabilities.
"""

import boto3
import json
import logging
import os
import hashlib
import time
import traceback
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Tuple
from botocore.exceptions import ClientError, NoCredentialsError, BotoCoreError

# Setup enhanced logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables with defaults
PROJECT_NAME = os.environ.get('PROJECT_NAME', '${project_name}')
ENVIRONMENT = os.environ.get('ENVIRONMENT', '${environment}')
STATE_BUCKET = os.environ.get('STATE_BUCKET', '')
BACKUP_BUCKET = os.environ.get('BACKUP_BUCKET', '')
MAX_RETRIES = int(os.environ.get('MAX_RETRIES', '3'))
RETRY_DELAY = int(os.environ.get('RETRY_DELAY', '5'))
HEALTH_CHECK_ENABLED = os.environ.get('HEALTH_CHECK_ENABLED', 'true').lower() == 'true'

# AWS clients with retry configuration
boto3_config = boto3.session.Config(
    retries={
        'max_attempts': MAX_RETRIES,
        'mode': 'adaptive'
    },
    max_pool_connections=50
)

s3_client = boto3.client('s3', config=boto3_config)
sns_client = boto3.client('sns', config=boto3_config)
dynamodb_client = boto3.client('dynamodb', config=boto3_config)


class StateBackupError(Exception):
    """Custom exception for state backup operations."""
    pass


class StateValidationError(StateBackupError):
    """Exception for state file validation errors."""
    pass


def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Enhanced Lambda handler with comprehensive error handling and recovery.
    
    Args:
        event: CloudWatch Events trigger or manual invocation
        context: Lambda context object
        
    Returns:
        Dict with operation status and detailed error information
    """
    
    operation_id = f"{PROJECT_NAME}-{ENVIRONMENT}-{datetime.utcnow().strftime('%Y%m%d-%H%M%S')}"
    
    try:
        logger.info(f"[{operation_id}] Starting enhanced Terraform state backup for {PROJECT_NAME}-{ENVIRONMENT}")
        
        # Pre-flight checks
        preflight_result = run_preflight_checks()
        if not preflight_result['success']:
            raise StateBackupError(f"Pre-flight checks failed: {preflight_result['error']}")
        
        # Health check if enabled
        if HEALTH_CHECK_ENABLED:
            health_status = perform_health_check()
            logger.info(f"[{operation_id}] Health check status: {health_status}")
        
        # Get list of state files with retry mechanism
        state_files = get_state_files_with_retry(STATE_BUCKET)
        logger.info(f"[{operation_id}] Found {len(state_files)} state files to backup")
        
        if not state_files:
            logger.warning(f"[{operation_id}] No state files found in bucket {STATE_BUCKET}")
            return create_response(200, "No state files to backup", {
                'operation_id': operation_id,
                'files_processed': 0
            })
        
        # Backup each state file with enhanced error handling
        backup_results = []
        for idx, state_file in enumerate(state_files, 1):
            file_operation_id = f"{operation_id}-file-{idx}"
            
            try:
                logger.info(f"[{file_operation_id}] Processing state file {state_file['key']} ({idx}/{len(state_files)})")
                result = backup_state_file_with_retry(state_file, file_operation_id)
                backup_results.append(result)
                logger.info(f"[{file_operation_id}] Successfully backed up {state_file['key']}")
                
                # Brief pause between files to avoid rate limiting
                if idx < len(state_files):
                    time.sleep(0.5)
                    
            except Exception as e:
                error_details = {
                    'key': state_file['key'],
                    'status': 'failed',
                    'error': str(e),
                    'error_type': type(e).__name__,
                    'operation_id': file_operation_id,
                    'timestamp': datetime.utcnow().isoformat() + 'Z'
                }
                
                logger.error(f"[{file_operation_id}] Failed to backup {state_file['key']}: {str(e)}")
                logger.error(f"[{file_operation_id}] Error traceback: {traceback.format_exc()}")
                backup_results.append(error_details)
        
        # Generate comprehensive backup report
        report = generate_enhanced_backup_report(backup_results, operation_id)
        
        # Store backup metadata for recovery purposes
        try:
            store_backup_metadata(operation_id, report)
        except Exception as e:
            logger.warning(f"[{operation_id}] Failed to store backup metadata: {str(e)}")
        
        # Send notification if configured
        try:
            if 'SNS_TOPIC_ARN' in os.environ:
                send_enhanced_notification(report, operation_id)
        except Exception as e:
            logger.warning(f"[{operation_id}] Failed to send notification: {str(e)}")
        
        # Determine overall success
        success_count = len([r for r in backup_results if r.get('status') == 'success'])
        status_code = 200 if success_count == len(backup_results) else 207  # Multi-status
        
        logger.info(f"[{operation_id}] Terraform state backup completed: {success_count}/{len(backup_results)} successful")
        
        return create_response(status_code, "Backup operation completed", {
            'operation_id': operation_id,
            'report': report
        })
        
    except Exception as e:
        error_msg = f"Critical backup failure: {str(e)}"
        logger.error(f"[{operation_id}] {error_msg}")
        logger.error(f"[{operation_id}] Critical error traceback: {traceback.format_exc()}")
        
        # Send critical error notification
        try:
            send_critical_error_notification(operation_id, str(e), traceback.format_exc())
        except Exception as notify_error:
            logger.error(f"[{operation_id}] Failed to send critical error notification: {str(notify_error)}")
        
        return create_response(500, error_msg, {
            'operation_id': operation_id,
            'error_type': type(e).__name__,
            'timestamp': datetime.utcnow().isoformat() + 'Z'
        })


def create_response(status_code: int, message: str, data: Dict[str, Any]) -> Dict[str, Any]:
    """Create standardized response format."""
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'X-Operation-Timestamp': datetime.utcnow().isoformat() + 'Z'
        },
        'body': json.dumps({
            'message': message,
            'data': data,
            'timestamp': datetime.utcnow().isoformat() + 'Z'
        }, default=str)
    }


def run_preflight_checks() -> Dict[str, Any]:
    """
    Perform comprehensive pre-flight checks before backup operations.
    
    Returns:
        Dict with check results
    """
    
    checks = {
        'bucket_access': False,
        'credentials': False,
        'configuration': False,
        'disk_space': False
    }
    
    errors = []
    
    try:
        # Check AWS credentials
        try:
            boto3.client('sts').get_caller_identity()
            checks['credentials'] = True
        except (NoCredentialsError, ClientError) as e:
            errors.append(f"Credentials check failed: {str(e)}")
        
        # Check configuration
        if not STATE_BUCKET:
            errors.append("STATE_BUCKET environment variable not configured")
        else:
            checks['configuration'] = True
        
        # Check S3 bucket access
        if STATE_BUCKET:
            try:
                s3_client.head_bucket(Bucket=STATE_BUCKET)
                checks['bucket_access'] = True
            except ClientError as e:
                errors.append(f"Cannot access state bucket {STATE_BUCKET}: {str(e)}")
        
        # Check available disk space (Lambda has /tmp with 10GB limit)
        import shutil
        total, used, free = shutil.disk_usage('/tmp')
        free_gb = free / (1024**3)
        if free_gb < 1.0:  # Less than 1GB free
            errors.append(f"Low disk space in /tmp: {free_gb:.2f}GB available")
        else:
            checks['disk_space'] = True
            
    except Exception as e:
        errors.append(f"Pre-flight check error: {str(e)}")
    
    success = all(checks.values()) and not errors
    
    return {
        'success': success,
        'checks': checks,
        'errors': errors,
        'timestamp': datetime.utcnow().isoformat() + 'Z'
    }


def perform_health_check() -> Dict[str, Any]:
    """
    Perform system health check including AWS service connectivity.
    
    Returns:
        Dict with health status
    """
    
    health_status = {
        's3_connectivity': False,
        'sns_connectivity': False,
        'dynamodb_connectivity': False,
        'lambda_memory': 0,
        'lambda_duration': 0
    }
    
    start_time = time.time()
    
    try:
        # Check S3 connectivity
        s3_client.list_buckets()
        health_status['s3_connectivity'] = True
    except Exception:
        pass
    
    try:
        # Check SNS connectivity
        sns_client.list_topics()
        health_status['sns_connectivity'] = True
    except Exception:
        pass
    
    try:
        # Check DynamoDB connectivity
        dynamodb_client.list_tables()
        health_status['dynamodb_connectivity'] = True
    except Exception:
        pass
    
    # Lambda runtime info
    import psutil
    memory_info = psutil.virtual_memory()
    health_status['lambda_memory'] = memory_info.available / (1024**2)  # MB
    health_status['lambda_duration'] = time.time() - start_time
    
    return health_status


def get_state_files_with_retry(bucket_name: str) -> List[Dict[str, Any]]:
    """
    List all Terraform state files with retry mechanism.
    
    Args:
        bucket_name: S3 bucket name containing state files
        
    Returns:
        List of state file objects with metadata
        
    Raises:
        StateBackupError: If unable to list files after retries
    """
    
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            return list_state_files(bucket_name)
        except ClientError as e:
            if attempt == MAX_RETRIES:
                raise StateBackupError(f"Failed to list state files after {MAX_RETRIES} attempts: {str(e)}")
            
            logger.warning(f"Attempt {attempt}/{MAX_RETRIES} failed to list state files: {str(e)}")
            time.sleep(RETRY_DELAY * attempt)  # Exponential backoff
    
    return []


def list_state_files(bucket_name: str) -> List[Dict[str, Any]]:
    """
    List all Terraform state files in the bucket.
    
    Args:
        bucket_name: S3 bucket name containing state files
        
    Returns:
        List of state file objects with metadata
    """
    
    state_files = []
    paginator = s3_client.get_paginator('list_objects_v2')
    
    try:
        for page in paginator.paginate(Bucket=bucket_name):
            if 'Contents' in page:
                for obj in page['Contents']:
                    # Filter for .tfstate files (exclude .tfstate.backup for now)
                    if obj['Key'].endswith('.tfstate') and not obj['Key'].endswith('.tfstate.backup'):
                        state_files.append({
                            'key': obj['Key'],
                            'size': obj['Size'],
                            'last_modified': obj['LastModified'],
                            'etag': obj['ETag'].strip('"'),
                            'storage_class': obj.get('StorageClass', 'STANDARD')
                        })
        
        return sorted(state_files, key=lambda x: x['last_modified'], reverse=True)
        
    except ClientError as e:
        logger.error(f"Failed to list objects in bucket {bucket_name}: {str(e)}")
        raise


def backup_state_file_with_retry(state_file: Dict[str, Any], operation_id: str) -> Dict[str, Any]:
    """
    Backup a single state file with retry mechanism.
    
    Args:
        state_file: State file metadata dict
        operation_id: Unique operation identifier
        
    Returns:
        Backup operation result
        
    Raises:
        StateBackupError: If backup fails after all retries
    """
    
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            return backup_state_file(state_file, operation_id)
        except Exception as e:
            if attempt == MAX_RETRIES:
                raise StateBackupError(f"Failed to backup {state_file['key']} after {MAX_RETRIES} attempts: {str(e)}")
            
            logger.warning(f"[{operation_id}] Attempt {attempt}/{MAX_RETRIES} failed: {str(e)}")
            time.sleep(RETRY_DELAY * attempt)  # Exponential backoff
    
    # This should never be reached, but just in case
    raise StateBackupError(f"Backup failed for unknown reason: {state_file['key']}")


def backup_state_file(state_file: Dict[str, Any], operation_id: str) -> Dict[str, Any]:
    """
    Backup a single Terraform state file with enhanced validation.
    
    Args:
        state_file: State file metadata dict
        operation_id: Unique operation identifier
        
    Returns:
        Backup operation result
    """
    
    key = state_file['key']
    timestamp = datetime.utcnow().strftime('%Y%m%d-%H%M%S')
    
    # Generate backup key with timestamp and operation ID
    backup_key = f"backups/{key}.{timestamp}.{operation_id[-8:]}"
    
    try:
        # Get the state file content
        logger.debug(f"[{operation_id}] Downloading state file {key}")
        response = s3_client.get_object(Bucket=STATE_BUCKET, Key=key)
        state_content = response['Body'].read()
        
        # Enhanced state file validation
        validation_result = validate_state_file_enhanced(state_content, key, operation_id)
        if not validation_result['valid']:
            raise StateValidationError(f"State file validation failed: {validation_result['error']}")
        
        # Calculate multiple checksums for integrity verification
        md5_hash = hashlib.md5(state_content).hexdigest()
        sha256_hash = hashlib.sha256(state_content).hexdigest()
        
        # Enhanced backup metadata
        backup_metadata = {
            'original-key': key,
            'backup-timestamp': timestamp,
            'operation-id': operation_id,
            'original-size': str(len(state_content)),
            'original-etag': state_file['etag'],
            'original-last-modified': state_file['last_modified'].isoformat(),
            'md5-checksum': md5_hash,
            'sha256-checksum': sha256_hash,
            'project': PROJECT_NAME,
            'environment': ENVIRONMENT,
            'backup-type': 'automated',
            'terraform-version': validation_result.get('terraform_version', 'unknown'),
            'state-version': str(validation_result.get('state_version', 'unknown')),
            'resource-count': str(validation_result.get('resource_count', 0))
        }
        
        # Store backup with enhanced metadata
        logger.debug(f"[{operation_id}] Storing backup as {backup_key}")
        s3_client.put_object(
            Bucket=STATE_BUCKET,
            Key=backup_key,
            Body=state_content,
            Metadata=backup_metadata,
            ServerSideEncryption='AES256',
            StorageClass='STANDARD_IA',  # Cost optimization for backups
            ContentType='application/json',
            CacheControl='max-age=31536000'  # 1 year
        )
        
        # Cross-region backup if configured
        cross_region_success = True
        if BACKUP_BUCKET:
            try:
                cross_region_backup_enhanced(state_content, backup_key, backup_metadata, operation_id)
            except Exception as e:
                logger.error(f"[{operation_id}] Cross-region backup failed, but local backup succeeded: {str(e)}")
                cross_region_success = False
        
        return {
            'key': key,
            'backup_key': backup_key,
            'status': 'success',
            'size': len(state_content),
            'checksums': {
                'md5': md5_hash,
                'sha256': sha256_hash
            },
            'timestamp': timestamp,
            'operation_id': operation_id,
            'cross_region_backup': cross_region_success,
            'validation_result': validation_result
        }
        
    except Exception as e:
        logger.error(f"[{operation_id}] Failed to backup state file {key}: {str(e)}")
        raise


def validate_state_file_enhanced(content: bytes, key: str, operation_id: str) -> Dict[str, Any]:
    """
    Enhanced Terraform state file validation with detailed analysis.
    
    Args:
        content: State file content as bytes
        key: State file key for error reporting
        operation_id: Operation identifier
        
    Returns:
        Dict with validation results and metadata
    """
    
    result = {
        'valid': False,
        'terraform_version': None,
        'state_version': None,
        'resource_count': 0,
        'warnings': [],
        'error': None
    }
    
    try:
        # Parse as JSON
        state_data = json.loads(content.decode('utf-8'))
        
        # Basic structure validation
        required_fields = ['version', 'terraform_version', 'serial']
        missing_fields = [field for field in required_fields if field not in state_data]
        
        if missing_fields:
            result['error'] = f"Missing required fields: {', '.join(missing_fields)}"
            return result
        
        # Extract metadata
        result['terraform_version'] = state_data.get('terraform_version')
        result['state_version'] = state_data.get('version')
        
        # Validate version compatibility
        if state_data.get('version', 0) < 3:
            result['warnings'].append(f"Legacy state format (version {state_data.get('version')})")
        
        # Validate and count resources
        if 'resources' in state_data:
            if not isinstance(state_data['resources'], list):
                result['error'] = "Resources field must be a list"
                return result
            result['resource_count'] = len(state_data['resources'])
        
        # Check for outputs
        if 'outputs' in state_data and not isinstance(state_data['outputs'], dict):
            result['warnings'].append("Outputs field should be a dictionary")
        
        # Validate serial number
        if not isinstance(state_data.get('serial'), int) or state_data.get('serial') < 0:
            result['warnings'].append("Serial number should be a non-negative integer")
        
        # Check for lineage (important for state consistency)
        if 'lineage' not in state_data:
            result['warnings'].append("Missing lineage field - state consistency may be compromised")
        
        result['valid'] = True
        logger.info(f"[{operation_id}] State file {key} validation passed with {len(result['warnings'])} warnings")
        
        return result
        
    except json.JSONDecodeError as e:
        result['error'] = f"Invalid JSON format: {str(e)}"
        return result
    except Exception as e:
        result['error'] = f"Validation error: {str(e)}"
        return result


def cross_region_backup_enhanced(content: bytes, backup_key: str, metadata: Dict[str, str], operation_id: str) -> None:
    """
    Enhanced cross-region backup with additional error handling.
    
    Args:
        content: State file content
        backup_key: Backup object key
        metadata: Backup metadata
        operation_id: Operation identifier
    """
    
    try:
        # Create backup client for different region
        backup_region = os.environ.get('BACKUP_REGION', 'us-west-2')
        backup_s3_client = boto3.client('s3', region_name=backup_region, config=boto3_config)
        
        # Add cross-region specific metadata
        enhanced_metadata = metadata.copy()
        enhanced_metadata.update({
            'backup-region': backup_region,
            'cross-region-timestamp': datetime.utcnow().isoformat() + 'Z'
        })
        
        backup_s3_client.put_object(
            Bucket=BACKUP_BUCKET,
            Key=backup_key,
            Body=content,
            Metadata=enhanced_metadata,
            ServerSideEncryption='AES256',
            StorageClass='STANDARD_IA'
        )
        
        logger.info(f"[{operation_id}] Cross-region backup completed for {backup_key} in {backup_region}")
        
    except Exception as e:
        logger.error(f"[{operation_id}] Cross-region backup failed for {backup_key}: {str(e)}")
        raise


def store_backup_metadata(operation_id: str, report: Dict[str, Any]) -> None:
    """
    Store backup operation metadata for recovery and audit purposes.
    
    Args:
        operation_id: Unique operation identifier
        report: Backup operation report
    """
    
    try:
        metadata_key = f"metadata/{operation_id}.json"
        
        s3_client.put_object(
            Bucket=STATE_BUCKET,
            Key=metadata_key,
            Body=json.dumps(report, default=str, indent=2),
            ContentType='application/json',
            ServerSideEncryption='AES256',
            StorageClass='STANDARD_IA'
        )
        
        logger.info(f"Backup metadata stored: {metadata_key}")
        
    except Exception as e:
        logger.error(f"Failed to store backup metadata: {str(e)}")
        raise


def generate_enhanced_backup_report(results: List[Dict[str, Any]], operation_id: str) -> Dict[str, Any]:
    """
    Generate comprehensive backup report with enhanced metrics.
    
    Args:
        results: List of backup operation results
        operation_id: Operation identifier
        
    Returns:
        Enhanced backup report
    """
    
    successful_backups = [r for r in results if r.get('status') == 'success']
    failed_backups = [r for r in results if r.get('status') == 'failed']
    
    total_size = sum(r.get('size', 0) for r in successful_backups)
    cross_region_failures = len([r for r in successful_backups if not r.get('cross_region_backup', True)])
    
    # Calculate validation statistics
    validation_warnings = []
    terraform_versions = {}
    state_versions = {}
    
    for result in successful_backups:
        if 'validation_result' in result:
            val_result = result['validation_result']
            validation_warnings.extend(val_result.get('warnings', []))
            
            tf_version = val_result.get('terraform_version')
            if tf_version:
                terraform_versions[tf_version] = terraform_versions.get(tf_version, 0) + 1
            
            state_version = val_result.get('state_version')
            if state_version:
                state_versions[str(state_version)] = state_versions.get(str(state_version), 0) + 1
    
    report = {
        'operation_id': operation_id,
        'timestamp': datetime.utcnow().isoformat() + 'Z',
        'project': PROJECT_NAME,
        'environment': ENVIRONMENT,
        'summary': {
            'total_files': len(results),
            'successful_backups': len(successful_backups),
            'failed_backups': len(failed_backups),
            'cross_region_failures': cross_region_failures,
            'total_backup_size_bytes': total_size,
            'total_backup_size_mb': round(total_size / (1024 * 1024), 2),
            'success_rate': (len(successful_backups) / len(results) * 100) if results else 0,
            'validation_warnings_count': len(validation_warnings)
        },
        'terraform_versions': terraform_versions,
        'state_versions': state_versions,
        'validation_warnings': list(set(validation_warnings)),  # Deduplicate warnings
        'successful_files': [
            {
                'original_key': r['key'],
                'backup_key': r['backup_key'],
                'size': r['size'],
                'size_mb': round(r['size'] / (1024 * 1024), 2),
                'timestamp': r['timestamp'],
                'cross_region_backup': r.get('cross_region_backup', False),
                'checksums': r.get('checksums', {}),
                'terraform_version': r.get('validation_result', {}).get('terraform_version'),
                'resource_count': r.get('validation_result', {}).get('resource_count', 0)
            } for r in successful_backups
        ],
        'failed_files': [
            {
                'key': r['key'],
                'error': r.get('error', 'Unknown error'),
                'error_type': r.get('error_type', 'UnknownError'),
                'operation_id': r.get('operation_id'),
                'timestamp': r.get('timestamp')
            } for r in failed_backups
        ]
    }
    
    return report


def send_enhanced_notification(report: Dict[str, Any], operation_id: str) -> None:
    """
    Send enhanced backup report notification with rich formatting.
    
    Args:
        report: Backup report to send
        operation_id: Operation identifier
    """
    
    try:
        sns_topic_arn = os.environ.get('SNS_TOPIC_ARN')
        if not sns_topic_arn:
            return
        
        summary = report['summary']
        
        # Determine severity based on results
        if summary['failed_backups'] > 0:
            severity = "🔴 ERROR"
        elif summary['cross_region_failures'] > 0 or summary['validation_warnings_count'] > 0:
            severity = "🟡 WARNING"
        else:
            severity = "🟢 SUCCESS"
        
        subject = f"{severity} Terraform State Backup - {PROJECT_NAME} {ENVIRONMENT.upper()}"
        
        message = f"""
Terraform State Backup Report {severity}
==========================================

Operation ID: {operation_id}
Project: {PROJECT_NAME}
Environment: {ENVIRONMENT}
Timestamp: {report['timestamp']}

📊 SUMMARY
----------
• Total Files: {summary['total_files']}
• Successful Backups: {summary['successful_backups']}
• Failed Backups: {summary['failed_backups']}
• Cross-Region Failures: {summary['cross_region_failures']}
• Success Rate: {summary['success_rate']:.1f}%
• Total Backup Size: {summary['total_backup_size_mb']} MB
• Validation Warnings: {summary['validation_warnings_count']}

"""
        
        # Add Terraform version info
        if report['terraform_versions']:
            message += "🔧 TERRAFORM VERSIONS\n"
            message += "--------------------\n"
            for version, count in report['terraform_versions'].items():
                message += f"• {version}: {count} files\n"
            message += "\n"
        
        # Add validation warnings if any
        if report['validation_warnings']:
            message += "⚠️  VALIDATION WARNINGS\n"
            message += "----------------------\n"
            for warning in report['validation_warnings'][:5]:  # Limit to 5 warnings
                message += f"• {warning}\n"
            if len(report['validation_warnings']) > 5:
                message += f"... and {len(report['validation_warnings']) - 5} more warnings\n"
            message += "\n"
        
        # Add failed files if any
        if summary['failed_backups'] > 0:
            message += "❌ FAILED FILES\n"
            message += "---------------\n"
            for failed_file in report['failed_files'][:3]:  # Limit to 3 failures
                message += f"• {failed_file['key']}: {failed_file['error']}\n"
            if len(report['failed_files']) > 3:
                message += f"... and {len(report['failed_files']) - 3} more failures\n"
            message += "\n"
        
        message += f"📝 Full report and logs available in CloudWatch\n"
        message += f"🔍 Operation ID: {operation_id}"
        
        sns_client.publish(
            TopicArn=sns_topic_arn,
            Subject=subject,
            Message=message
        )
        
        logger.info(f"[{operation_id}] Enhanced backup notification sent successfully")
        
    except Exception as e:
        logger.error(f"[{operation_id}] Failed to send enhanced notification: {str(e)}")


def send_critical_error_notification(operation_id: str, error_message: str, traceback_info: str) -> None:
    """
    Send critical error notification for catastrophic failures.
    
    Args:
        operation_id: Operation identifier
        error_message: Error description
        traceback_info: Full traceback information
    """
    
    try:
        sns_topic_arn = os.environ.get('SNS_TOPIC_ARN')
        if not sns_topic_arn:
            return
        
        subject = f"🚨 CRITICAL: Terraform State Backup Failed - {PROJECT_NAME} {ENVIRONMENT.upper()}"
        
        message = f"""
CRITICAL TERRAFORM STATE BACKUP FAILURE
========================================

Operation ID: {operation_id}
Project: {PROJECT_NAME}
Environment: {ENVIRONMENT}
Timestamp: {datetime.utcnow().isoformat()}Z

🚨 ERROR DETAILS
---------------
{error_message}

📋 IMMEDIATE ACTIONS REQUIRED
----------------------------
1. Check CloudWatch logs for detailed error information
2. Verify AWS service status and permissions
3. Ensure state bucket accessibility
4. Consider manual backup of critical state files

⚠️  This is a critical system failure that may affect infrastructure operations.
Immediate investigation and remediation is required.

Operation ID for troubleshooting: {operation_id}
"""
        
        sns_client.publish(
            TopicArn=sns_topic_arn,
            Subject=subject,
            Message=message
        )
        
        logger.info(f"[{operation_id}] Critical error notification sent")
        
    except Exception as e:
        logger.error(f"[{operation_id}] Failed to send critical error notification: {str(e)}")


if __name__ == "__main__":
    # Enhanced local testing
    test_event = {
        'source': 'aws.events',
        'detail-type': 'Scheduled Event',
        'detail': {
            'test_mode': True
        }
    }
    
    class MockContext:
        def __init__(self):
            self.function_name = 'test-terraform-state-backup'
            self.function_version = '$LATEST'
            self.invoked_function_arn = 'arn:aws:lambda:us-east-1:123456789012:function:test'
            self.memory_limit_in_mb = 128
            self.remaining_time_in_millis = 300000
    
    result = handler(test_event, MockContext())
    print(json.dumps(result, indent=2, default=str))