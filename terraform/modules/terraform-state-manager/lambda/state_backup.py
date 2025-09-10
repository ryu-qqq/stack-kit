#!/usr/bin/env python3
"""
Terraform State Backup Lambda Function for StackKit Infrastructure
Provides automated state file backup and consistency validation.
"""

import boto3
import json
import logging
import os
import hashlib
from datetime import datetime
from typing import Dict, List, Optional, Any

# Setup logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
PROJECT_NAME = os.environ.get('PROJECT_NAME', '${project_name}')
ENVIRONMENT = os.environ.get('ENVIRONMENT', '${environment}')
STATE_BUCKET = os.environ.get('STATE_BUCKET', '')
BACKUP_BUCKET = os.environ.get('BACKUP_BUCKET', '')

# AWS clients
s3_client = boto3.client('s3')
sns_client = boto3.client('sns')


def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for Terraform state backup operations.
    
    Args:
        event: CloudWatch Events trigger or manual invocation
        context: Lambda context object
        
    Returns:
        Dict with operation status and details
    """
    
    try:
        logger.info(f"Starting Terraform state backup for {PROJECT_NAME}-{ENVIRONMENT}")
        
        # Validate configuration
        if not STATE_BUCKET:
            raise ValueError("STATE_BUCKET environment variable not configured")
        
        # Get list of state files
        state_files = list_state_files(STATE_BUCKET)
        logger.info(f"Found {len(state_files)} state files to backup")
        
        # Backup each state file
        backup_results = []
        for state_file in state_files:
            try:
                result = backup_state_file(state_file)
                backup_results.append(result)
                logger.info(f"Successfully backed up {state_file['key']}")
            except Exception as e:
                logger.error(f"Failed to backup {state_file['key']}: {str(e)}")
                backup_results.append({
                    'key': state_file['key'],
                    'status': 'failed',
                    'error': str(e)
                })
        
        # Generate backup report
        report = generate_backup_report(backup_results)
        
        # Send notification if configured
        if 'SNS_TOPIC_ARN' in os.environ:
            send_notification(report)
        
        logger.info("Terraform state backup completed successfully")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Backup completed successfully',
                'report': report
            })
        }
        
    except Exception as e:
        logger.error(f"Terraform state backup failed: {str(e)}")
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'message': 'Backup operation failed'
            })
        }


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
    
    for page in paginator.paginate(Bucket=bucket_name):
        if 'Contents' in page:
            for obj in page['Contents']:
                # Filter for .tfstate files
                if obj['Key'].endswith('.tfstate') or obj['Key'].endswith('.tfstate.backup'):
                    state_files.append({
                        'key': obj['Key'],
                        'size': obj['Size'],
                        'last_modified': obj['LastModified'],
                        'etag': obj['ETag'].strip('"')
                    })
    
    return state_files


def backup_state_file(state_file: Dict[str, Any]) -> Dict[str, Any]:
    """
    Backup a single Terraform state file with validation.
    
    Args:
        state_file: State file metadata dict
        
    Returns:
        Backup operation result
    """
    
    key = state_file['key']
    timestamp = datetime.utcnow().strftime('%Y%m%d-%H%M%S')
    
    # Generate backup key with timestamp
    backup_key = f"backups/{key}.{timestamp}"
    
    try:
        # Get the state file content
        response = s3_client.get_object(Bucket=STATE_BUCKET, Key=key)
        state_content = response['Body'].read()
        
        # Validate state file format
        validate_state_file(state_content, key)
        
        # Calculate checksums for integrity verification
        md5_hash = hashlib.md5(state_content).hexdigest()
        sha256_hash = hashlib.sha256(state_content).hexdigest()
        
        # Store backup with metadata
        backup_metadata = {
            'original-key': key,
            'backup-timestamp': timestamp,
            'original-size': str(len(state_content)),
            'original-etag': state_file['etag'],
            'md5-checksum': md5_hash,
            'sha256-checksum': sha256_hash,
            'project': PROJECT_NAME,
            'environment': ENVIRONMENT,
            'backup-type': 'automated'
        }
        
        s3_client.put_object(
            Bucket=STATE_BUCKET,
            Key=backup_key,
            Body=state_content,
            Metadata=backup_metadata,
            ServerSideEncryption='AES256',
            StorageClass='STANDARD_IA'  # Cost optimization for backups
        )
        
        # Cross-region backup if configured
        if BACKUP_BUCKET:
            cross_region_backup(state_content, backup_key, backup_metadata)
        
        return {
            'key': key,
            'backup_key': backup_key,
            'status': 'success',
            'size': len(state_content),
            'checksums': {
                'md5': md5_hash,
                'sha256': sha256_hash
            },
            'timestamp': timestamp
        }
        
    except Exception as e:
        logger.error(f"Failed to backup state file {key}: {str(e)}")
        raise


def validate_state_file(content: bytes, key: str) -> None:
    """
    Validate Terraform state file format and structure.
    
    Args:
        content: State file content as bytes
        key: State file key for error reporting
        
    Raises:
        ValueError: If state file is invalid
    """
    
    try:
        # Parse as JSON
        state_data = json.loads(content.decode('utf-8'))
        
        # Basic structure validation
        required_fields = ['version', 'terraform_version', 'serial']
        for field in required_fields:
            if field not in state_data:
                raise ValueError(f"Missing required field: {field}")
        
        # Validate version compatibility
        if 'version' in state_data and state_data['version'] < 3:
            logger.warning(f"State file {key} uses legacy format (version {state_data['version']})")
        
        # Check for resources
        if 'resources' in state_data and not isinstance(state_data['resources'], list):
            raise ValueError("Resources field must be a list")
        
        logger.info(f"State file {key} validation passed")
        
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON format in state file {key}: {str(e)}")
    except Exception as e:
        raise ValueError(f"State file validation failed for {key}: {str(e)}")


def cross_region_backup(content: bytes, backup_key: str, metadata: Dict[str, str]) -> None:
    """
    Create cross-region backup copy.
    
    Args:
        content: State file content
        backup_key: Backup object key
        metadata: Backup metadata
    """
    
    try:
        # Create backup client for different region
        backup_s3_client = boto3.client('s3', region_name=os.environ.get('BACKUP_REGION'))
        
        backup_s3_client.put_object(
            Bucket=BACKUP_BUCKET,
            Key=backup_key,
            Body=content,
            Metadata=metadata,
            ServerSideEncryption='AES256',
            StorageClass='STANDARD_IA'
        )
        
        logger.info(f"Cross-region backup completed for {backup_key}")
        
    except Exception as e:
        logger.error(f"Cross-region backup failed for {backup_key}: {str(e)}")
        raise


def generate_backup_report(results: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Generate comprehensive backup report.
    
    Args:
        results: List of backup operation results
        
    Returns:
        Backup report summary
    """
    
    successful_backups = [r for r in results if r.get('status') == 'success']
    failed_backups = [r for r in results if r.get('status') == 'failed']
    
    total_size = sum(r.get('size', 0) for r in successful_backups)
    
    report = {
        'timestamp': datetime.utcnow().isoformat() + 'Z',
        'project': PROJECT_NAME,
        'environment': ENVIRONMENT,
        'summary': {
            'total_files': len(results),
            'successful_backups': len(successful_backups),
            'failed_backups': len(failed_backups),
            'total_backup_size_bytes': total_size,
            'success_rate': len(successful_backups) / len(results) * 100 if results else 0
        },
        'successful_files': [
            {
                'original_key': r['key'],
                'backup_key': r['backup_key'],
                'size': r['size'],
                'timestamp': r['timestamp']
            } for r in successful_backups
        ],
        'failed_files': [
            {
                'key': r['key'],
                'error': r.get('error', 'Unknown error')
            } for r in failed_backups
        ]
    }
    
    return report


def send_notification(report: Dict[str, Any]) -> None:
    """
    Send backup report notification.
    
    Args:
        report: Backup report to send
    """
    
    try:
        sns_topic_arn = os.environ.get('SNS_TOPIC_ARN')
        if not sns_topic_arn:
            return
        
        summary = report['summary']
        subject = f"Terraform State Backup Report - {PROJECT_NAME} {ENVIRONMENT.upper()}"
        
        message = f"""
Terraform State Backup Report
=============================

Project: {PROJECT_NAME}
Environment: {ENVIRONMENT}
Timestamp: {report['timestamp']}

Summary:
- Total Files: {summary['total_files']}
- Successful Backups: {summary['successful_backups']}
- Failed Backups: {summary['failed_backups']}
- Success Rate: {summary['success_rate']:.1f}%
- Total Backup Size: {summary['total_backup_size_bytes']:,} bytes

"""
        
        if summary['failed_backups'] > 0:
            message += "Failed Files:\n"
            for failed_file in report['failed_files']:
                message += f"- {failed_file['key']}: {failed_file['error']}\n"
        
        message += f"\nFull report available in CloudWatch logs."
        
        sns_client.publish(
            TopicArn=sns_topic_arn,
            Subject=subject,
            Message=message
        )
        
        logger.info("Backup notification sent successfully")
        
    except Exception as e:
        logger.error(f"Failed to send notification: {str(e)}")


if __name__ == "__main__":
    # For local testing
    test_event = {
        'source': 'aws.events',
        'detail-type': 'Scheduled Event'
    }
    
    result = handler(test_event, None)
    print(json.dumps(result, indent=2))