"""
Unified AI-Reviewer Lambda Function - Enhanced Version with OpenAI
Handles Terraform plan reviews, apply completions, and failure analysis
Supports SQS message routing, comprehensive error handling, and Infracost integration
Uses OpenAI GPT models for cost-effective AI analysis
"""

import json
import os
import boto3
import requests
from typing import Dict, List, Optional, Tuple
from datetime import datetime
from enum import Enum
import re
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Message types for SQS routing
class MessageType(Enum):
    PLAN_REVIEW = "PLAN_REVIEW"
    APPLY_COMPLETION = "APPLY_COMPLETION"
    PLAN_FAILURE = "PLAN_FAILURE"
    UNKNOWN = "UNKNOWN"

# Plan failure categories
class FailureCategory(Enum):
    AUTHENTICATION_ERROR = "AUTHENTICATION_ERROR"
    RESOURCE_NOT_FOUND = "RESOURCE_NOT_FOUND"
    CONFIGURATION_ERROR = "CONFIGURATION_ERROR"
    NETWORK_ERROR = "NETWORK_ERROR"
    RESOURCE_CONFLICT = "RESOURCE_CONFLICT"
    STATE_ERROR = "STATE_ERROR"
    PROVIDER_ERROR = "PROVIDER_ERROR"
    GENERAL_ERROR = "GENERAL_ERROR"

# Data classes for structured analysis
class TerraformPlanAnalysis:
    def __init__(self):
        self.resources_to_create = 0
        self.resources_to_update = 0
        self.resources_to_delete = 0
        self.module_count = 0
        
        self.create_actions = []
        self.update_actions = []
        self.delete_actions = []
        
        self.security_issues = []
        self.estimated_monthly_cost = 0.0
        
        # Enhanced data for comprehensive analysis
        self.infracost_data = None
        self.plan_text = None
        self.infracost_analysis = None
    
    def has_changes(self) -> bool:
        return self.resources_to_create > 0 or self.resources_to_update > 0 or self.resources_to_delete > 0
    
    def is_high_risk(self) -> bool:
        actual_cost = self.estimated_monthly_cost
        if self.infracost_analysis and hasattr(self.infracost_analysis, 'total_monthly_cost'):
            try:
                actual_cost = float(self.infracost_analysis.total_monthly_cost)
            except (ValueError, TypeError):
                pass
        
        return (self.resources_to_delete > 0 or 
                len(self.security_issues) > 0 or 
                actual_cost > 200.0)
    
    def get_severity(self) -> str:
        if self.is_high_risk():
            return "HIGH"
        elif self.resources_to_create > 5 or self.resources_to_update > 10:
            return "MEDIUM"
        else:
            return "LOW"
    
    def get_total_changes(self) -> int:
        return self.resources_to_create + self.resources_to_update + self.resources_to_delete

class InfracostAnalysis:
    def __init__(self):
        self.total_monthly_cost = "0"
        self.currency = "USD"
        self.projects = []
        self.summary = ""
        self.has_breakdown = False

class ProjectCost:
    def __init__(self):
        self.name = ""
        self.monthly_cost = ""
        self.currency = "USD"
        self.resources = []

class TerraformApplyResult:
    def __init__(self):
        self.success = False
        self.project_name = "Unknown"
        self.environment = "Unknown"
        self.timestamp = datetime.now()
        
        self.resources_created = 0
        self.resources_updated = 0
        self.resources_destroyed = 0
        
        self.error_message = None
        self.output_log = None
    
    def get_total_changes(self) -> int:
        return self.resources_created + self.resources_updated + self.resources_destroyed
    
    def has_changes(self) -> bool:
        return self.get_total_changes() > 0
    
    def is_success_with_changes(self) -> bool:
        return self.success and self.has_changes()
    
    def get_status_emoji(self) -> str:
        if self.success:
            return "✅" if self.has_changes() else "ℹ️"
        else:
            return "❌"
    
    def get_status_text(self) -> str:
        if self.success:
            return "Apply 완료" if self.has_changes() else "변경사항 없음"
        else:
            return "Apply 실패"

class TerraformPlanFailure:
    def __init__(self):
        self.project_name = ""
        self.environment = ""
        self.timestamp = datetime.now()
        self.error_message = ""
        self.error_output = ""
        self.failure_category = FailureCategory.GENERAL_ERROR.value
        self.troubleshooting_guide = ""

class UnifiedTerraformReviewer:
    def __init__(self):
        self.s3_client = boto3.client('s3')
        self.secrets_client = boto3.client('secretsmanager')
        self.s3_bucket = os.environ['S3_BUCKET']
        self.secrets_arn = os.environ['SECRETS_MANAGER_ARN']
        self.github_secrets_arn = os.environ['GITHUB_SECRETS_ARN']
        
        # Load secrets
        self.secrets = self._load_secrets()
        self.github_secrets = self._load_github_secrets()
        
    def _load_secrets(self) -> Dict:
        """Load AI reviewer secrets from Secrets Manager"""
        try:
            response = self.secrets_client.get_secret_value(SecretId=self.secrets_arn)
            return json.loads(response['SecretString'])
        except Exception as e:
            logger.error(f"Failed to load AI reviewer secrets: {e}")
            return {}
    
    def _load_github_secrets(self) -> Dict:
        """Load GitHub secrets from Secrets Manager"""
        try:
            response = self.secrets_client.get_secret_value(SecretId=self.github_secrets_arn)
            return json.loads(response['SecretString'])
        except Exception as e:
            logger.error(f"Failed to load GitHub secrets: {e}")
            return {}
    
    def determine_message_type(self, event: Dict) -> Tuple[MessageType, Dict]:
        """Determine message type for SQS routing"""
        try:
            # Handle SQS messages with Records
            if 'Records' in event:
                for record in event['Records']:
                    # Check for SQS message attributes
                    if 'messageAttributes' in record:
                        msg_type = record.get('messageAttributes', {}).get('MessageType', {}).get('stringValue')
                        if msg_type == 'PLAN_REVIEW':
                            return MessageType.PLAN_REVIEW, record
                        elif msg_type == 'APPLY_COMPLETION':
                            return MessageType.APPLY_COMPLETION, record
                        elif msg_type == 'PLAN_FAILURE':
                            return MessageType.PLAN_FAILURE, record
                    
                    # Check message group ID for FIFO queues
                    if 'attributes' in record:
                        group_id = record.get('attributes', {}).get('MessageGroupId', '')
                        if 'plan' in group_id.lower():
                            return MessageType.PLAN_REVIEW, record
                        elif 'apply' in group_id.lower():
                            return MessageType.APPLY_COMPLETION, record
                    
                    # Try to parse message body
                    if 'body' in record:
                        body = json.loads(record['body']) if isinstance(record['body'], str) else record['body']
                        
                        # Check for S3 event in message body
                        if 'Records' in body and body['Records']:
                            s3_record = body['Records'][0]
                            if 's3' in s3_record:
                                object_key = s3_record['s3']['object']['key']
                                return self._classify_by_object_key(object_key), record
                        
                        # Check for direct event type
                        if 'eventType' in body:
                            event_type = body['eventType']
                            if event_type == 'plan_created':
                                return MessageType.PLAN_REVIEW, record
                            elif event_type == 'apply_completed':
                                return MessageType.APPLY_COMPLETION, record
                            elif event_type == 'plan_failed':
                                return MessageType.PLAN_FAILURE, record
                        
                        # Check object key in body
                        if 'objectKey' in body:
                            return self._classify_by_object_key(body['objectKey']), record
            
            # Direct S3 event (legacy)
            if 'Records' in event and event['Records'] and 's3' in event['Records'][0]:
                object_key = event['Records'][0]['s3']['object']['key']
                return self._classify_by_object_key(object_key), event['Records'][0]
            
            return MessageType.UNKNOWN, {}
            
        except Exception as e:
            logger.error(f"Error determining message type: {e}")
            return MessageType.UNKNOWN, {}
    
    def _classify_by_object_key(self, object_key: str) -> MessageType:
        """Classify message type by S3 object key patterns"""
        if ('/plans/' in object_key or object_key.endswith('.tfplan') or 
            'plan-' in object_key or 'manifest.json' in object_key):
            return MessageType.PLAN_REVIEW
        elif ('/applies/' in object_key or '/outputs/' in object_key or 
              object_key.endswith('.apply') or 'apply-' in object_key):
            return MessageType.APPLY_COMPLETION
        else:
            return MessageType.UNKNOWN
    
    def download_s3_object(self, object_key: str) -> str:
        """Download object from S3 bucket"""
        try:
            response = self.s3_client.get_object(Bucket=self.s3_bucket, Key=object_key)
            return response['Body'].read().decode('utf-8')
        except Exception as e:
            logger.error(f"Failed to download S3 object {object_key}: {e}")
            return ""
    
    def extract_object_key(self, message_data: Dict) -> Optional[str]:
        """Extract S3 object key from message data"""
        try:
            # Standard S3 event notification
            if 'Records' in message_data:
                records = message_data['Records']
                if records and 's3' in records[0]:
                    return records[0]['s3']['object']['key']
            
            # Custom message format
            if 'objectKey' in message_data:
                return message_data['objectKey']
            
            # Direct object key
            if 'key' in message_data:
                return message_data['key']
            
            return None
            
        except Exception as e:
            logger.error(f"Failed to extract object key: {e}")
            return None
    
    # Plan Review Processing
    def process_plan_review(self, message_data: Dict) -> Dict:
        """Process Terraform plan review"""
        try:
            logger.info("Processing plan review")
            
            # Extract object key from message
            if isinstance(message_data.get('body'), str):
                body = json.loads(message_data['body'])
            else:
                body = message_data.get('body', message_data)
            
            object_key = self.extract_object_key(body)
            if not object_key:
                logger.error("No object key found in plan review message")
                return {"error": "No object key found"}
            
            logger.info(f"Processing plan file: {object_key}")
            
            # Check if this is a failure case by looking for manifest
            base_path = object_key.replace("/manifest.json", "")
            
            # Download manifest to determine plan status
            manifest_content = self.download_s3_object(object_key)
            if manifest_content:
                manifest = json.loads(manifest_content)
                plan_status = manifest.get('status', 'success')
                
                if plan_status == 'failure':
                    return self.process_plan_failure(base_path, manifest)
            
            # Download comprehensive plan data
            plan_content = self.download_s3_object(base_path + "/tfplan.json")
            plan_text = self.download_s3_object(base_path + "/plan.txt")
            infracost_data = self.download_s3_object(base_path + "/infracost.json")
            
            # Analyze plan
            analysis = self.analyze_terraform_plan(plan_content)
            analysis.infracost_data = infracost_data
            analysis.infracost_analysis = self.parse_infracost_data(infracost_data)
            analysis.plan_text = plan_text
            
            # Update cost with Infracost data
            if analysis.infracost_analysis and analysis.infracost_analysis.has_breakdown:
                try:
                    analysis.estimated_monthly_cost = float(analysis.infracost_analysis.total_monthly_cost)
                except (ValueError, TypeError):
                    logger.warning("Could not parse Infracost total cost")
            
            # Generate comprehensive AI review
            review = self.generate_enhanced_plan_review(analysis)
            
            # Send notifications
            self.send_plan_review_notification(analysis, review, object_key)
            
            return {
                "status": "success",
                "message": "Plan review completed",
                "analysis": {
                    "total_changes": analysis.get_total_changes(),
                    "severity": analysis.get_severity(),
                    "security_issues": len(analysis.security_issues),
                    "estimated_cost": analysis.estimated_monthly_cost
                }
            }
            
        except Exception as e:
            logger.error(f"Failed to process plan review: {e}")
            return {"error": str(e)}
    
    def process_plan_failure(self, base_path: str, manifest: Dict) -> Dict:
        """Process Terraform plan failure"""
        try:
            logger.info(f"Processing plan failure for path: {base_path}")
            
            failure = TerraformPlanFailure()
            failure.project_name = manifest.get('project', 'Unknown')
            failure.environment = self.extract_environment_from_path(base_path)
            
            # Download plan output to analyze failure
            plan_output = self.download_s3_object(base_path + "/plan.txt")
            failure.error_output = plan_output
            failure.error_message = self.extract_plan_error_message(plan_output)
            failure.failure_category = self.categorize_plan_failure(plan_output)
            failure.troubleshooting_guide = self.generate_troubleshooting_guide(
                failure.failure_category, failure.error_message
            )
            
            # Generate AI-powered failure analysis
            ai_analysis = self.generate_plan_failure_analysis(failure)
            
            # Send failure notification
            self.send_plan_failure_notification(failure, ai_analysis, base_path)
            
            return {
                "status": "failure",
                "message": "Plan failure processed",
                "failure_category": failure.failure_category,
                "error": failure.error_message
            }
            
        except Exception as e:
            logger.error(f"Failed to process plan failure: {e}")
            return {"error": str(e)}
    
    def process_apply_completion(self, message_data: Dict) -> Dict:
        """Process Terraform apply completion"""
        try:
            logger.info("Processing apply completion")
            
            # Extract object key
            if isinstance(message_data.get('body'), str):
                body = json.loads(message_data['body'])
            else:
                body = message_data.get('body', message_data)
            
            object_key = self.extract_object_key(body)
            if not object_key:
                logger.error("No object key found in apply completion message")
                return {"error": "No object key found"}
            
            # Download and analyze apply result
            apply_content = self.download_s3_object(object_key)
            apply_result = self.analyze_apply_result(apply_content, object_key)
            
            # Generate AI summary
            ai_summary = self.generate_apply_summary(apply_result)
            
            # Send completion notification
            self.send_apply_completion_notification(apply_result, ai_summary, object_key)
            
            return {
                "status": "success",
                "message": "Apply completion processed",
                "result": {
                    "success": apply_result.success,
                    "total_changes": apply_result.get_total_changes(),
                    "project": apply_result.project_name,
                    "environment": apply_result.environment
                }
            }
            
        except Exception as e:
            logger.error(f"Failed to process apply completion: {e}")
            return {"error": str(e)}
    
    # Enhanced Analysis Methods
    def analyze_terraform_plan(self, plan_content: str) -> TerraformPlanAnalysis:
        """Analyze Terraform plan with comprehensive analysis"""
        try:
            if not plan_content.strip():
                return TerraformPlanAnalysis()
                
            plan_json = json.loads(plan_content)
            analysis = TerraformPlanAnalysis()
            
            # Extract basic plan information
            if 'resource_changes' in plan_json:
                resource_changes = plan_json['resource_changes']
                
                for change in resource_changes:
                    actions = change.get('change', {}).get('actions', [])
                    resource_type = change.get('type', '')
                    resource_name = change.get('name', '')
                    resource_address = change.get('address', f"{resource_type}.{resource_name}")
                    
                    if 'create' in actions:
                        analysis.resources_to_create += 1
                        analysis.create_actions.append(resource_address)
                    elif 'update' in actions:
                        analysis.resources_to_update += 1
                        analysis.update_actions.append(resource_address)
                    elif 'delete' in actions:
                        analysis.resources_to_delete += 1
                        analysis.delete_actions.append(resource_address)
            
            # Extract configuration information
            if 'configuration' in plan_json:
                config = plan_json['configuration']
                if 'root_module' in config and 'module_calls' in config['root_module']:
                    analysis.module_count = len(config['root_module']['module_calls'])
            
            # Enhanced security analysis
            analysis.security_issues = self.detect_security_issues(plan_json)
            
            # Cost estimation
            analysis.estimated_monthly_cost = self.estimate_cost(analysis)
            
            logger.info(f"Plan analysis complete: {analysis.get_total_changes()} changes, {len(analysis.security_issues)} security issues")
            return analysis
            
        except Exception as e:
            logger.error(f"Failed to analyze Terraform plan: {e}")
            return TerraformPlanAnalysis()
    
    def parse_infracost_data(self, infracost_json: str) -> Optional[InfracostAnalysis]:
        """Parse Infracost data for cost analysis"""
        if not infracost_json or not infracost_json.strip():
            return None
        
        try:
            infracost_data = json.loads(infracost_json)
            analysis = InfracostAnalysis()
            
            # Parse total monthly cost
            if 'totalMonthlyCost' in infracost_data:
                analysis.total_monthly_cost = infracost_data['totalMonthlyCost']
                analysis.has_breakdown = True
            
            # Parse currency
            if 'currency' in infracost_data:
                analysis.currency = infracost_data['currency']
            
            # Parse projects
            if 'projects' in infracost_data and isinstance(infracost_data['projects'], list):
                for project_data in infracost_data['projects']:
                    project = ProjectCost()
                    project.name = project_data.get('name', 'Unknown')
                    
                    if 'breakdown' in project_data and 'totalMonthlyCost' in project_data['breakdown']:
                        project.monthly_cost = project_data['breakdown']['totalMonthlyCost']
                    
                    project.currency = analysis.currency
                    analysis.projects.append(project)
            
            # Create summary
            if analysis.has_breakdown:
                analysis.summary = f"Total monthly cost: {analysis.total_monthly_cost} {analysis.currency} across {len(analysis.projects)} project(s)"
            else:
                analysis.summary = "Cost estimation not available"
            
            logger.info(f"Infracost analysis parsed: {analysis.summary}")
            return analysis
            
        except Exception as e:
            logger.error(f"Error parsing Infracost data: {e}")
            return None
    
    def detect_security_issues(self, plan_json: Dict) -> List[str]:
        """Detect security issues in Terraform plan"""
        issues = []
        
        if 'resource_changes' not in plan_json:
            return issues
        
        for change in plan_json['resource_changes']:
            resource_type = change.get('type', '')
            change_details = change.get('change', {})
            resource_name = change.get('address', change.get('name', ''))
            
            # Check for public access in security groups
            if resource_type == 'aws_security_group' and 'after' in change_details:
                after = change_details['after']
                if 'ingress' in after and isinstance(after['ingress'], list):
                    for ingress in after['ingress']:
                        if 'cidr_blocks' in ingress and isinstance(ingress['cidr_blocks'], list):
                            for cidr in ingress['cidr_blocks']:
                                if cidr == "0.0.0.0/0":
                                    issues.append(f"공개 인바운드 규칙 감지: {resource_name}")
            
            # Check for unencrypted storage
            if resource_type in ['aws_s3_bucket', 'aws_rds_instance'] and 'after' in change_details:
                after = change_details['after']
                if not after.get('encryption') and not after.get('server_side_encryption_configuration'):
                    issues.append(f"암호화되지 않은 스토리지: {resource_name}")
            
            # Check for public S3 buckets
            if resource_type == 'aws_s3_bucket_public_access_block' and 'after' in change_details:
                after = change_details['after']
                if (not after.get('block_public_acls') or 
                    not after.get('block_public_policy') or
                    not after.get('ignore_public_acls') or 
                    not after.get('restrict_public_buckets')):
                    issues.append(f"S3 버킷 공개 액세스 설정 위험: {resource_name}")
        
        return issues
    
    def estimate_cost(self, analysis: TerraformPlanAnalysis) -> float:
        """Estimate monthly cost based on resource changes"""
        cost = 0.0
        cost += analysis.resources_to_create * 10.0  # $10 per new resource average
        cost += analysis.resources_to_update * 2.0   # $2 per updated resource
        return round(cost, 2)
    
    def analyze_apply_result(self, apply_content: str, object_key: str) -> TerraformApplyResult:
        """Analyze Terraform apply result"""
        result = TerraformApplyResult()
        
        try:
            # Try to parse as JSON first
            apply_json = json.loads(apply_content)
            
            if 'apply_result' in apply_json:
                apply_result = apply_json['apply_result']
                result.success = apply_result.get('status') == 'success'
                result.resources_created = apply_result.get('created', 0)
                result.resources_updated = apply_result.get('updated', 0)
                result.resources_destroyed = apply_result.get('destroyed', 0)
        
        except json.JSONDecodeError:
            # Fall back to text parsing
            result = self.parse_text_apply_output(apply_content)
        
        # Extract project info from object key
        key_parts = object_key.split('/')
        result.project_name = key_parts[1] if len(key_parts) > 1 else "Unknown"
        result.environment = key_parts[2] if len(key_parts) > 2 else "Unknown"
        
        # Determine overall status from text
        if "Apply complete!" in apply_content or "No changes" in apply_content:
            result.success = True
        elif "Error:" in apply_content or "failed" in apply_content:
            result.success = False
            result.error_message = self.extract_error_message(apply_content)
        
        return result
    
    def parse_text_apply_output(self, apply_content: str) -> TerraformApplyResult:
        """Parse text-based apply output"""
        result = TerraformApplyResult()
        
        lines = apply_content.split('\n')
        for line in lines:
            line = line.strip()
            
            if "Apply complete!" in line and "Resources:" in line:
                parts = line.split("Resources:")
                if len(parts) > 1:
                    resource_info = parts[1].strip()
                    
                    if "added" in resource_info:
                        result.resources_created = self.extract_number(resource_info, "added")
                    if "changed" in resource_info:
                        result.resources_updated = self.extract_number(resource_info, "changed")
                    if "destroyed" in resource_info:
                        result.resources_destroyed = self.extract_number(resource_info, "destroyed")
                
                result.success = True
            
            if "Error:" in line or "failed" in line:
                result.success = False
                result.error_message = line
        
        return result
    
    def extract_number(self, text: str, keyword: str) -> int:
        """Extract number before keyword from text"""
        try:
            keyword_index = text.find(keyword)
            if keyword_index == -1:
                return 0
            
            before_keyword = text[:keyword_index].strip()
            words = before_keyword.split()
            
            if words:
                last_word = words[-1]
                return int(re.sub(r'[^0-9]', '', last_word))
        except (ValueError, IndexError):
            pass
        
        return 0
    
    def extract_error_message(self, apply_content: str) -> str:
        """Extract error message from apply output"""
        lines = apply_content.split('\n')
        error_msg = []
        
        in_error = False
        for line in lines:
            if line.strip().startswith("Error:"):
                in_error = True
                error_msg.append(line.strip())
            elif in_error and line.strip():
                error_msg.append(line.strip())
            elif in_error and not line.strip():
                break
        
        return '\n'.join(error_msg) if error_msg else "Unknown error"
    
    # Plan Failure Analysis
    def extract_environment_from_path(self, base_path: str) -> str:
        """Extract environment from S3 path"""
        path_parts = base_path.split('/')
        for part in path_parts:
            if part in ['dev', 'prod', 'staging', 'test']:
                return part
        return "unknown"
    
    def extract_plan_error_message(self, plan_output: str) -> str:
        """Extract error message from plan output"""
        if not plan_output:
            return "No error output available"
        
        lines = plan_output.split('\n')
        error_msg = []
        
        in_error = False
        for line in lines:
            if ("Error:" in line or "Failed:" in line or "╷" in line):
                in_error = True
                error_msg.append(line.strip())
            elif in_error and ("╵" in line):
                break
            elif in_error and line.strip():
                error_msg.append(line.strip())
        
        if not error_msg:
            # Fallback to first error line
            for line in lines:
                if "error" in line.lower() or "failed" in line.lower():
                    error_msg.append(line.strip())
                    break
        
        return '\n'.join(error_msg) if error_msg else "Unknown error"
    
    def categorize_plan_failure(self, plan_output: str) -> str:
        """Categorize plan failure type"""
        output_lower = plan_output.lower()
        
        # Authentication/Authorization issues
        if any(term in output_lower for term in ["accessdenied", "unauthorized", "credentials", "authentication"]):
            return FailureCategory.AUTHENTICATION_ERROR.value
        
        # Resource not found
        if any(term in output_lower for term in ["does not exist", "not found", "invalidresourceid", "nosuchbucket"]):
            return FailureCategory.RESOURCE_NOT_FOUND.value
        
        # Configuration errors
        if any(term in output_lower for term in ["invalid", "syntax", "configuration", "argument"]):
            return FailureCategory.CONFIGURATION_ERROR.value
        
        # Network issues
        if any(term in output_lower for term in ["timeout", "connection", "network", "unreachable"]):
            return FailureCategory.NETWORK_ERROR.value
        
        # Resource conflicts
        if any(term in output_lower for term in ["already exists", "conflict", "limit exceeded", "quota"]):
            return FailureCategory.RESOURCE_CONFLICT.value
        
        # State/Backend issues
        if any(term in output_lower for term in ["state", "backend", "lock", "dynamodb"]):
            return FailureCategory.STATE_ERROR.value
        
        # Provider issues
        if any(term in output_lower for term in ["provider", "plugin"]):
            return FailureCategory.PROVIDER_ERROR.value
        
        return FailureCategory.GENERAL_ERROR.value
    
    def generate_troubleshooting_guide(self, failure_category: str, error_message: str) -> str:
        """Generate troubleshooting guide based on failure category"""
        guides = {
            FailureCategory.AUTHENTICATION_ERROR.value: """## 🔑 인증 오류 해결 가이드

**원인**: AWS 인증 정보가 잘못되었거나 만료됨

**해결 방법**:
1. AWS CLI 설정 확인: `aws configure list`
2. IAM 역할/정책 권한 확인
3. Atlantis 서버의 환경 변수 확인 (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
4. AssumeRole 설정이 있다면 역할 신뢰 관계 확인""",

            FailureCategory.RESOURCE_NOT_FOUND.value: """## 🔍 리소스 없음 오류 해결 가이드

**원인**: 참조하려는 AWS 리소스가 존재하지 않음

**해결 방법**:
1. AWS 콘솔에서 리소스 존재 여부 확인
2. 올바른 리전(region)에서 작업하고 있는지 확인
3. 리소스 ID나 이름이 정확한지 확인
4. `terraform import` 명령으로 기존 리소스 가져오기""",

            FailureCategory.CONFIGURATION_ERROR.value: """## ⚙️ 설정 오류 해결 가이드

**원인**: Terraform 설정 파일에 문법 오류 또는 잘못된 인수

**해결 방법**:
1. `terraform validate` 명령으로 설정 검증
2. `terraform fmt` 명령으로 포맷 정리
3. 필수 인수(argument)가 누락되었는지 확인
4. Terraform 공식 문서에서 리소스 설정 방법 확인""",

            FailureCategory.STATE_ERROR.value: """## 📊 상태 오류 해결 가이드

**원인**: Terraform 상태 파일 또는 백엔드 문제

**해결 방법**:
1. `terraform init -reconfigure` 로 백엔드 재설정
2. 상태 잠금이 있다면 `terraform force-unlock` 고려
3. S3 백엔드 접근 권한 확인
4. DynamoDB 테이블 상태 잠금 확인"""
        }
        
        return guides.get(failure_category, """## ❓ 일반 오류 해결 가이드

**기본 해결 방법**:
1. 오류 메시지를 자세히 읽고 문제 파악
2. `terraform plan -detailed-exitcode` 로 상세 정보 확인
3. Terraform 공식 문서 및 커뮤니티 검색
4. 로그 레벨을 높여서 자세한 디버그 정보 확인: `TF_LOG=DEBUG`""")
    
    # AI Review Generation
    def generate_enhanced_plan_review(self, analysis: TerraformPlanAnalysis) -> str:
        """Generate enhanced AI review with comprehensive analysis"""
        try:
            if 'openai_api_key' in self.secrets:
                return self._generate_openai_review(analysis)
            else:
                return self._generate_fallback_review(analysis)
        except Exception as e:
            logger.error(f"Failed to generate enhanced review: {e}")
            return self._generate_fallback_review(analysis)
    
    def _generate_openai_review(self, analysis: TerraformPlanAnalysis) -> str:
        """Generate review using OpenAI API"""
        try:
            import openai
            
            client = openai.OpenAI(api_key=self.secrets['openai_api_key'])
            
            prompt = self._build_enhanced_plan_prompt(analysis)
            
            response = client.chat.completions.create(
                model="gpt-3.5-turbo",
                max_tokens=2000,
                temperature=0.3,
                messages=[{
                    "role": "system",
                    "content": "You are a senior DevOps engineer and AWS solutions architect specializing in Terraform infrastructure review. Provide comprehensive, actionable analysis."
                }, {
                    "role": "user", 
                    "content": prompt
                }]
            )
            
            return response.choices[0].message.content
            
        except Exception as e:
            logger.error(f"OpenAI API call failed: {e}")
            return self._generate_fallback_review(analysis)
    
    def _build_enhanced_plan_prompt(self, analysis: TerraformPlanAnalysis) -> str:
        """Build comprehensive prompt for AI review"""
        prompt = f"""# Terraform Infrastructure Plan Review

As a senior DevOps engineer and AWS solutions architect, provide a comprehensive analysis of this Terraform plan.

## 📊 Infrastructure Changes Overview
- **Resources to Create**: {analysis.resources_to_create}
- **Resources to Update**: {analysis.resources_to_update}
- **Resources to Delete**: {analysis.resources_to_delete}
- **Modules Involved**: {analysis.module_count}
- **Risk Level**: {analysis.get_severity()}

## 💰 Cost Analysis"""

        if analysis.infracost_analysis and analysis.infracost_analysis.has_breakdown:
            prompt += f"""
- **Monthly Cost**: {analysis.infracost_analysis.total_monthly_cost} {analysis.infracost_analysis.currency} (Infracost)
- **Projects Analyzed**: {len(analysis.infracost_analysis.projects)}"""
            
            if analysis.infracost_analysis.projects:
                prompt += "\n### Project Breakdown:"
                for project in analysis.infracost_analysis.projects:
                    prompt += f"\n  - **{project.name}**: {project.monthly_cost} {project.currency}"
        else:
            prompt += f"""
- **Estimated Monthly Cost**: ~${analysis.estimated_monthly_cost} (heuristic)
- **Note**: Infracost data not available - using estimation"""

        if analysis.security_issues:
            prompt += f"\n\n## 🚨 Security Concerns ({len(analysis.security_issues)})"
            for issue in analysis.security_issues:
                prompt += f"\n- ⚠️ `{issue}`"

        if analysis.create_actions:
            prompt += f"\n\n## 🆕 New Resources ({len(analysis.create_actions)})"
            for resource in analysis.create_actions[:5]:  # Limit to first 5
                prompt += f"\n- `{resource}`"
            if len(analysis.create_actions) > 5:
                prompt += f"\n- ... and {len(analysis.create_actions) - 5} more"

        prompt += """

## Required Analysis
Please provide a comprehensive review covering:

### 1. 🏗️ **Architecture Assessment**
- Infrastructure design patterns and best practices compliance
- Resource relationships and dependencies
- Scalability and maintainability considerations

### 2. 🛡️ **Security & Compliance Review**
- IAM permissions and least privilege principle
- Network security (VPC, Security Groups, NACLs)
- Data encryption and compliance requirements

### 3. 💰 **Cost Optimization Analysis**
- Resource sizing and cost efficiency
- Alternative solutions for cost reduction

### 4. 📝 **Final Recommendation**
- Overall risk level (LOW/MEDIUM/HIGH)
- Approval recommendation (APPROVE/REVIEW/REJECT)
- Critical action items before deployment

Provide actionable insights and specific recommendations."""

        return prompt
    
    def _generate_fallback_review(self, analysis: TerraformPlanAnalysis) -> str:
        """Generate fallback review when AI is unavailable"""
        review = f"""## 📊 Terraform Plan Analysis
*(Fallback analysis - AI API unavailable)*

### Changes Summary
- **Create**: {analysis.resources_to_create} resources
- **Update**: {analysis.resources_to_update} resources  
- **Delete**: {analysis.resources_to_delete} resources
- **Risk Level**: {analysis.get_severity()}

"""

        if analysis.infracost_analysis and analysis.infracost_analysis.has_breakdown:
            review += f"""### 💰 Cost Analysis
Monthly Cost: {analysis.infracost_analysis.total_monthly_cost} {analysis.infracost_analysis.currency}

"""

        if analysis.security_issues:
            review += f"""### 🚨 Security Issues Detected
"""
            for issue in analysis.security_issues:
                review += f"- {issue}\n"
            review += "\n"

        review += """### ⚠️ Recommendation
"""
        if analysis.is_high_risk():
            review += """**HIGH RISK** - Careful review recommended before approval
- Review deletion operations
- Verify security configurations
- Consider cost implications"""
        elif analysis.get_total_changes() > 10:
            review += """**MEDIUM RISK** - Standard review process
- Verify all changes are intentional
- Check for unintended side effects"""
        else:
            review += """**LOW RISK** - Changes appear routine
- Standard deployment procedures apply"""

        return review
    
    def generate_apply_summary(self, result: TerraformApplyResult) -> str:
        """Generate apply completion summary"""
        try:
            if 'openai_api_key' in self.secrets:
                return self._generate_openai_apply_summary(result)
            else:
                return self._generate_fallback_apply_summary(result)
        except Exception as e:
            logger.error(f"Failed to generate apply summary: {e}")
            return self._generate_fallback_apply_summary(result)
    
    def _generate_openai_apply_summary(self, result: TerraformApplyResult) -> str:
        """Generate apply summary using OpenAI API"""
        try:
            import openai
            
            client = openai.OpenAI(api_key=self.secrets['openai_api_key'])
            
            prompt = f"""다음 Terraform Apply 결과를 요약해주세요:

## 배포 정보
- 프로젝트: {result.project_name}
- 환경: {result.environment}
- 상태: {result.get_status_emoji()} {result.get_status_text()}
- 시간: {result.timestamp.strftime('%Y-%m-%d %H:%M:%S')}

## 리소스 변경사항
- 생성: {result.resources_created}개
- 수정: {result.resources_updated}개
- 삭제: {result.resources_destroyed}개

{"## 오류 정보\n" + result.error_message if not result.success and result.error_message else ""}

위 정보를 바탕으로 간결한 배포 요약을 제공해주세요."""
            
            response = client.chat.completions.create(
                model="gpt-3.5-turbo",
                max_tokens=500,
                temperature=0.2,
                messages=[{
                    "role": "system",
                    "content": "당신은 AWS와 Terraform 전문가입니다. Apply 결과를 분석하여 한국어로 간결한 요약을 제공해주세요."
                }, {
                    "role": "user", 
                    "content": prompt
                }]
            )
            
            return response.choices[0].message.content
            
        except Exception as e:
            logger.error(f"OpenAI apply summary failed: {e}")
            return self._generate_fallback_apply_summary(result)
    
    def _generate_fallback_apply_summary(self, result: TerraformApplyResult) -> str:
        """Generate fallback apply summary"""
        if result.success:
            return f"""✅ 배포 완료!
총 {result.get_total_changes()}개 리소스 변경 (생성: {result.resources_created}, 수정: {result.resources_updated}, 삭제: {result.resources_destroyed})"""
        else:
            return f"""❌ 배포 실패
오류: {result.error_message or '알 수 없는 오류'}"""
    
    def generate_plan_failure_analysis(self, failure: TerraformPlanFailure) -> str:
        """Generate plan failure analysis"""
        try:
            if 'openai_api_key' in self.secrets:
                return self._generate_openai_failure_analysis(failure)
            else:
                return self._generate_fallback_failure_analysis(failure)
        except Exception as e:
            logger.error(f"Failed to generate failure analysis: {e}")
            return self._generate_fallback_failure_analysis(failure)
    
    def _generate_openai_failure_analysis(self, failure: TerraformPlanFailure) -> str:
        """Generate failure analysis using OpenAI API"""
        try:
            import openai
            
            client = openai.OpenAI(api_key=self.secrets['openai_api_key'])
            
            prompt = f"""다음 Terraform Plan 실패를 분석해주세요:

## 📋 실패 정보
- 프로젝트: {failure.project_name}
- 환경: {failure.environment}
- 실패 유형: {failure.failure_category}
- 발생 시간: {failure.timestamp.strftime('%Y-%m-%d %H:%M:%S')}

## 🚨 오류 메시지
```
{failure.error_message}
```

위 정보를 바탕으로 다음을 분석해주세요:

1. **🔍 문제 원인 분석**: 실패의 근본 원인
2. **⚡ 즉시 해결 방안**: 가장 빠른 해결 방법
3. **🛠️ 단계별 해결 가이드**: 구체적인 실행 단계
4. **📊 위험도 평가**: LOW/MEDIUM/HIGH 위험 수준

실무진이 바로 적용할 수 있도록 구체적이고 실용적인 가이드를 제공해주세요."""
            
            response = client.chat.completions.create(
                model="gpt-3.5-turbo",
                max_tokens=1500,
                temperature=0.2,
                messages=[{
                    "role": "system",
                    "content": "당신은 AWS와 Terraform 전문가입니다. Plan 실패를 분석하여 한국어로 명확한 원인 분석과 해결 방안을 제공해주세요."
                }, {
                    "role": "user", 
                    "content": prompt
                }]
            )
            
            return response.choices[0].message.content
            
        except Exception as e:
            logger.error(f"OpenAI failure analysis failed: {e}")
            return self._generate_fallback_failure_analysis(failure)
    
    def _generate_fallback_failure_analysis(self, failure: TerraformPlanFailure) -> str:
        """Generate fallback failure analysis"""
        risk_levels = {
            FailureCategory.AUTHENTICATION_ERROR.value: "HIGH",
            FailureCategory.STATE_ERROR.value: "HIGH",
            FailureCategory.RESOURCE_CONFLICT.value: "MEDIUM",
            FailureCategory.CONFIGURATION_ERROR.value: "MEDIUM"
        }
        
        risk_level = risk_levels.get(failure.failure_category, "LOW")
        
        return f"""## 🚨 Terraform Plan 실패 분석
*(Fallback 분석 - AI API 사용 불가)*

### 📋 실패 정보
- **프로젝트**: {failure.project_name}
- **환경**: {failure.environment}
- **실패 유형**: {failure.failure_category}
- **발생 시간**: {failure.timestamp.strftime('%Y-%m-%d %H:%M:%S')}

### 🚨 오류 메시지
```
{failure.error_message}
```

### 📊 위험도 평가: {risk_level}

### 🛠️ 권장 조치
1. 아래 자동 생성된 해결 가이드 참조
2. DevOps 팀과 상황 공유
3. 문제 해결 후 재시도"""
    
    # Notification Methods
    def send_plan_review_notification(self, analysis: TerraformPlanAnalysis, review: str, object_key: str):
        """Send plan review notification to Slack"""
        try:
            slack_webhook = self.secrets.get('slack_webhook_url')
            if not slack_webhook:
                logger.info("Slack webhook not configured")
                return
            
            # Extract project info
            key_parts = object_key.split('/')
            project_name = key_parts[1] if len(key_parts) > 1 else "Unknown"
            
            cost_info = "비용 정보 없음"
            if analysis.infracost_analysis and analysis.infracost_analysis.has_breakdown:
                cost_info = f"{analysis.infracost_analysis.total_monthly_cost} {analysis.infracost_analysis.currency}"
            else:
                cost_info = f"~${analysis.estimated_monthly_cost}"
            
            message = f"""*🏗️ 프로젝트:* `{project_name}`

*📊 변경 사항*
• 생성: {analysis.resources_to_create}개
• 수정: {analysis.resources_to_update}개  
• 삭제: {analysis.resources_to_delete}개
• 월 예상 비용: {cost_info}

*🤖 AI 리뷰*
```
{review[:1500] + ('...' if len(review) > 1500 else '')}
```"""
            
            if analysis.security_issues:
                message = f"""*🚨 보안 알림*
{chr(10).join([f"• {issue}" for issue in analysis.security_issues[:3]])}

""" + message
            
            payload = {
                "text": "🔍 Terraform Plan 리뷰 완료",
                "blocks": [
                    {
                        "type": "section",
                        "text": {
                            "type": "mrkdwn",
                            "text": message
                        }
                    },
                    {
                        "type": "context",
                        "elements": [
                            {
                                "type": "mrkdwn",
                                "text": f"📁 파일: `{object_key}`"
                            }
                        ]
                    }
                ]
            }
            
            response = requests.post(slack_webhook, json=payload, timeout=10)
            if response.status_code == 200:
                logger.info("Plan review notification sent successfully")
            else:
                logger.error(f"Slack notification failed: {response.status_code}")
                
        except Exception as e:
            logger.error(f"Failed to send plan review notification: {e}")
    
    def send_apply_completion_notification(self, result: TerraformApplyResult, summary: str, object_key: str):
        """Send apply completion notification to Slack"""
        try:
            slack_webhook = self.secrets.get('slack_webhook_url')
            if not slack_webhook:
                logger.info("Slack webhook not configured")
                return
            
            emoji = result.get_status_emoji()
            status = result.get_status_text()
            
            message = f"""*🏗️ 프로젝트:* `{result.project_name}`
*🌍 환경:* `{result.environment}`

*📊 변경사항*
• 생성: {result.resources_created}개
• 수정: {result.resources_updated}개
• 삭제: {result.resources_destroyed}개

*🤖 AI 요약*
```
{summary}
```"""
            
            if not result.success and result.error_message:
                message = f"""*🚨 오류 정보*
```
{result.error_message[:500]}
```

""" + message
            
            payload = {
                "text": f"{emoji} Terraform Apply {status}",
                "blocks": [
                    {
                        "type": "header",
                        "text": {
                            "type": "plain_text",
                            "text": f"{emoji} Terraform Apply {status}"
                        }
                    },
                    {
                        "type": "section",
                        "text": {
                            "type": "mrkdwn",
                            "text": message
                        }
                    },
                    {
                        "type": "context",
                        "elements": [
                            {
                                "type": "mrkdwn",
                                "text": f"📁 파일: `{object_key}` | ⏰ {result.timestamp.strftime('%Y-%m-%d %H:%M:%S')}"
                            }
                        ]
                    }
                ]
            }
            
            response = requests.post(slack_webhook, json=payload, timeout=10)
            if response.status_code == 200:
                logger.info("Apply completion notification sent successfully")
            else:
                logger.error(f"Slack notification failed: {response.status_code}")
                
        except Exception as e:
            logger.error(f"Failed to send apply completion notification: {e}")
    
    def send_plan_failure_notification(self, failure: TerraformPlanFailure, analysis: str, base_path: str):
        """Send plan failure notification to Slack"""
        try:
            slack_webhook = self.secrets.get('slack_webhook_url')
            if not slack_webhook:
                logger.info("Slack webhook not configured")
                return
            
            message = f"""*🏗️ 프로젝트:* `{failure.project_name}`
*🌍 환경:* `{failure.environment}`
*🏷️ 실패 유형:* `{failure.failure_category}`

*🚨 오류 메시지*
```
{failure.error_message[:500]}
```

*🤖 AI 분석*
```
{analysis[:1000] + ('...' if len(analysis) > 1000 else '')}
```

*🛠️ 자동 생성 해결 가이드*
```
{failure.troubleshooting_guide[:800] + ('...' if len(failure.troubleshooting_guide) > 800 else '')}
```"""
            
            payload = {
                "text": "❌ Terraform Plan 실패",
                "blocks": [
                    {
                        "type": "header",
                        "text": {
                            "type": "plain_text",
                            "text": "❌ Terraform Plan 실패"
                        }
                    },
                    {
                        "type": "section",
                        "text": {
                            "type": "mrkdwn",
                            "text": message
                        }
                    },
                    {
                        "type": "context",
                        "elements": [
                            {
                                "type": "mrkdwn",
                                "text": f"📁 경로: `{base_path}` | ⏰ {failure.timestamp.strftime('%Y-%m-%d %H:%M:%S')} | 🏷️ {failure.failure_category}"
                            }
                        ]
                    }
                ]
            }
            
            response = requests.post(slack_webhook, json=payload, timeout=10)
            if response.status_code == 200:
                logger.info("Plan failure notification sent successfully")
            else:
                logger.error(f"Slack notification failed: {response.status_code}")
                
        except Exception as e:
            logger.error(f"Failed to send plan failure notification: {e}")


def lambda_handler(event, context):
    """Main Lambda handler with SQS message routing"""
    logger.info("Unified AI Reviewer Lambda triggered")
    logger.info(f"Event: {json.dumps(event, default=str)}")
    
    try:
        reviewer = UnifiedTerraformReviewer()
        
        # Determine message type and route accordingly
        message_type, message_data = reviewer.determine_message_type(event)
        
        logger.info(f"Determined message type: {message_type.value}")
        
        results = []
        
        # Handle SQS batch processing
        if 'Records' in event:
            for record in event['Records']:
                try:
                    msg_type, msg_data = reviewer.determine_message_type({'Records': [record]})
                    
                    if msg_type == MessageType.PLAN_REVIEW:
                        result = reviewer.process_plan_review(record)
                        results.append({"type": "plan_review", "result": result})
                    elif msg_type == MessageType.APPLY_COMPLETION:
                        result = reviewer.process_apply_completion(record)
                        results.append({"type": "apply_completion", "result": result})
                    elif msg_type == MessageType.PLAN_FAILURE:
                        # Plan failure is handled within process_plan_review
                        result = reviewer.process_plan_review(record)
                        results.append({"type": "plan_failure", "result": result})
                    else:
                        logger.warning(f"Unknown message type for record: {record.get('messageId')}")
                        results.append({"type": "unknown", "result": {"error": "Unknown message type"}})
                        
                except Exception as e:
                    logger.error(f"Error processing record {record.get('messageId')}: {e}")
                    results.append({"type": "error", "result": {"error": str(e)}})
        
        else:
            # Handle single message (direct S3 event)
            if message_type == MessageType.PLAN_REVIEW:
                result = reviewer.process_plan_review(message_data)
                results.append({"type": "plan_review", "result": result})
            elif message_type == MessageType.APPLY_COMPLETION:
                result = reviewer.process_apply_completion(message_data)
                results.append({"type": "apply_completion", "result": result})
            else:
                results.append({"type": "unknown", "result": {"error": "Unknown message type"}})
        
        # Summary statistics
        plan_reviews = len([r for r in results if r["type"] == "plan_review"])
        apply_completions = len([r for r in results if r["type"] == "apply_completion"]) 
        plan_failures = len([r for r in results if r["type"] == "plan_failure"])
        errors = len([r for r in results if r["type"] in ["error", "unknown"]])
        
        summary_message = f"Processed: {plan_reviews} plan reviews, {apply_completions} apply completions, {plan_failures} plan failures, {errors} errors"
        logger.info(summary_message)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': summary_message,
                'results': results,
                'total_processed': len(results)
            })
        }
        
    except Exception as e:
        logger.error(f"Lambda execution failed: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }