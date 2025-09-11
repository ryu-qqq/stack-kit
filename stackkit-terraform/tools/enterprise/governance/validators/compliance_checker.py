#!/usr/bin/env python3
"""
StackKit Enterprise Compliance Checker

Validates project compliance against organizational policies and regulatory frameworks
"""

import argparse
import json
import os
import re
import yaml
from pathlib import Path
from typing import Dict, List, Any, Optional, Tuple
from dataclasses import dataclass, asdict
from enum import Enum

class Severity(Enum):
    """Severity levels for compliance violations"""
    CRITICAL = "critical"
    HIGH = "high" 
    MEDIUM = "medium"
    LOW = "low"
    INFO = "info"

@dataclass
class ComplianceViolation:
    """Compliance violation details"""
    rule_id: str
    severity: Severity
    message: str
    file_path: str
    line_number: Optional[int]
    column_number: Optional[int]
    suggestion: str
    framework: str  # sox, gdpr, pci, etc.
    
class ComplianceChecker:
    """Main compliance checking engine"""
    
    def __init__(self, project_dir: str):
        self.project_dir = Path(project_dir)
        self.violations = []
        self.rules = self._load_compliance_rules()
    
    def _load_compliance_rules(self) -> Dict[str, Any]:
        """Load compliance rules from configuration"""
        
        return {
            "security": {
                "no_hardcoded_secrets": {
                    "severity": Severity.CRITICAL,
                    "patterns": [
                        r"password\s*=\s*[\"'][^\"']+[\"']",
                        r"secret\s*=\s*[\"'][^\"']+[\"']",
                        r"api[_-]?key\s*=\s*[\"'][^\"']+[\"']",
                        r"aws[_-]?access[_-]?key\s*=\s*[\"'][^\"']+[\"']",
                        r"aws[_-]?secret\s*=\s*[\"'][^\"']+[\"']"
                    ],
                    "frameworks": ["sox", "gdpr", "pci", "hipaa"],
                    "suggestion": "Use AWS Secrets Manager or environment variables"
                },
                
                "public_s3_buckets": {
                    "severity": Severity.HIGH,
                    "patterns": [
                        r'acl\s*=\s*["\']public-read["\']',
                        r'acl\s*=\s*["\']public-read-write["\']'
                    ],
                    "frameworks": ["sox", "gdpr", "pci"],
                    "suggestion": "Use private S3 buckets with explicit access policies"
                },
                
                "unencrypted_resources": {
                    "severity": Severity.HIGH,
                    "patterns": [
                        r'encrypted\s*=\s*false',
                        r'kms_key_id\s*=\s*["\']["\']',  # Empty KMS key
                        r'storage_encrypted\s*=\s*false'
                    ],
                    "frameworks": ["sox", "gdpr", "pci", "hipaa"],
                    "suggestion": "Enable encryption at rest with KMS keys"
                },
                
                "open_security_groups": {
                    "severity": Severity.HIGH,  
                    "patterns": [
                        r'cidr_blocks\s*=\s*\[\s*["\']0\.0\.0\.0/0["\']',
                        r'from_port\s*=\s*0.*to_port\s*=\s*65535',
                        r'protocol\s*=\s*["\']["\'].*cidr_blocks.*0\.0\.0\.0/0'
                    ],
                    "frameworks": ["sox", "pci"],
                    "suggestion": "Restrict security group rules to specific IP ranges and ports",
                    "exemptions": ["ALLOW_PUBLIC_EXEMPT"]  # Allow with explicit comment
                }
            },
            
            "sox_compliance": {
                "missing_audit_trail": {
                    "severity": Severity.CRITICAL,
                    "required_resources": [
                        "aws_cloudtrail",
                        "aws_config_configuration_recorder"
                    ],
                    "frameworks": ["sox"],
                    "suggestion": "Enable CloudTrail and AWS Config for audit compliance"
                },
                
                "insufficient_backup_retention": {
                    "severity": Severity.HIGH,
                    "patterns": [
                        r'backup_retention_period\s*=\s*[0-6]',  # Less than 7 days
                        r'retention_in_days\s*=\s*[0-6]'
                    ],
                    "frameworks": ["sox"],
                    "suggestion": "Set backup retention to at least 7 days for SOX compliance"
                },
                
                "missing_data_classification": {
                    "severity": Severity.MEDIUM,
                    "required_tags": ["DataClassification", "Owner", "Environment"],
                    "frameworks": ["sox"],
                    "suggestion": "Add required tags for data classification and ownership"
                }
            },
            
            "gdpr_compliance": {
                "data_residency_violation": {
                    "severity": Severity.CRITICAL,
                    "allowed_regions": [
                        "eu-central-1", "eu-west-1", "eu-west-2", "eu-west-3", 
                        "eu-north-1", "eu-south-1"
                    ],
                    "frameworks": ["gdpr"],
                    "suggestion": "Use EU regions for GDPR compliance"
                },
                
                "missing_encryption": {
                    "severity": Severity.CRITICAL,
                    "required_encryption": True,
                    "frameworks": ["gdpr"],
                    "suggestion": "Enable encryption for all data storage and transmission"
                },
                
                "no_data_retention_policy": {
                    "severity": Severity.HIGH,
                    "required_lifecycle_rules": True,
                    "frameworks": ["gdpr"],
                    "suggestion": "Implement data lifecycle and retention policies"
                }
            },
            
            "pci_compliance": {
                "missing_waf": {
                    "severity": Severity.CRITICAL,
                    "required_resources": ["aws_wafv2_web_acl"],
                    "frameworks": ["pci"],
                    "suggestion": "Deploy WAF for PCI DSS compliance"
                },
                
                "weak_ssl_policy": {
                    "severity": Severity.HIGH,
                    "patterns": [
                        r'ssl_support_method\s*=\s*["\']sni-only["\']',
                        r'security_policy.*TLS-1-0',
                        r'security_policy.*TLS-1-1'
                    ],
                    "frameworks": ["pci"],
                    "suggestion": "Use TLS 1.2 or higher for PCI compliance"
                }
            },
            
            "general_security": {
                "missing_monitoring": {
                    "severity": Severity.MEDIUM,
                    "required_resources": [
                        "aws_cloudwatch_metric_alarm",
                        "aws_sns_topic"
                    ],
                    "frameworks": ["general"],
                    "suggestion": "Implement monitoring and alerting"
                },
                
                "no_multi_az": {
                    "severity": Severity.MEDIUM,
                    "patterns": [r'multi_az\s*=\s*false'],
                    "frameworks": ["general"],
                    "suggestion": "Enable Multi-AZ for production workloads",
                    "environments": ["prod"]  # Only apply to production
                }
            }
        }
    
    def check_compliance(self, config: Dict[str, Any]) -> Dict[str, Any]:
        """Perform comprehensive compliance check"""
        
        self.violations = []
        
        # Extract compliance frameworks from config
        compliance_frameworks = config.get('compliance', [])
        if isinstance(compliance_frameworks, str):
            compliance_frameworks = [compliance_frameworks]
        
        # Check different aspects
        self._check_terraform_files(compliance_frameworks)
        self._check_configuration_compliance(config, compliance_frameworks)
        self._check_security_requirements(compliance_frameworks)
        self._check_framework_specific_requirements(compliance_frameworks)
        
        # Generate report
        return self._generate_compliance_report()
    
    def _check_terraform_files(self, frameworks: List[str]) -> None:
        """Check Terraform files for compliance violations"""
        
        terraform_files = list(self.project_dir.rglob("*.tf"))
        
        for tf_file in terraform_files:
            self._check_file_compliance(tf_file, frameworks)
    
    def _check_file_compliance(self, file_path: Path, frameworks: List[str]) -> None:
        """Check individual file for compliance violations"""
        
        try:
            with open(file_path, 'r') as f:
                content = f.read()
                lines = content.splitlines()
        except Exception as e:
            self._add_violation(
                "file_read_error",
                Severity.MEDIUM,
                f"Could not read file: {e}",
                str(file_path),
                None,
                "Ensure file is readable and properly formatted",
                "general"
            )
            return
        
        # Check security patterns
        for category, rules in self.rules.items():
            for rule_id, rule_config in rules.items():
                
                # Skip if rule doesn't apply to current frameworks
                rule_frameworks = rule_config.get('frameworks', [])
                if rule_frameworks and not any(fw in frameworks for fw in rule_frameworks):
                    continue
                
                # Check patterns
                patterns = rule_config.get('patterns', [])
                for pattern in patterns:
                    for line_num, line in enumerate(lines, 1):
                        if self._check_pattern_with_exemptions(line, pattern, rule_config):
                            self._add_violation(
                                rule_id,
                                rule_config['severity'],
                                f"Potential compliance violation: {rule_id}",
                                str(file_path),
                                line_num,
                                rule_config['suggestion'],
                                rule_frameworks[0] if rule_frameworks else 'general'
                            )
    
    def _check_pattern_with_exemptions(self, line: str, pattern: str, rule_config: Dict) -> bool:
        """Check pattern while considering exemptions"""
        
        if not re.search(pattern, line, re.IGNORECASE):
            return False
        
        # Check for exemptions
        exemptions = rule_config.get('exemptions', [])
        for exemption in exemptions:
            if exemption in line:
                return False  # Exempted
        
        return True
    
    def _check_configuration_compliance(self, config: Dict[str, Any], frameworks: List[str]) -> None:
        """Check configuration for compliance requirements"""
        
        # Check AWS region compliance for GDPR
        if 'gdpr' in frameworks:
            aws_region = config.get('aws_region', '')
            allowed_regions = self.rules['gdpr_compliance']['data_residency_violation']['allowed_regions']
            
            if aws_region and aws_region not in allowed_regions:
                self._add_violation(
                    "data_residency_violation",
                    Severity.CRITICAL,
                    f"AWS region {aws_region} not compliant with GDPR data residency",
                    "configuration",
                    None,
                    "Use EU regions for GDPR compliance",
                    "gdpr"
                )
        
        # Check backup retention for SOX
        if 'sox' in frameworks:
            backup_retention = config.get('backup_retention_period', 0)
            if backup_retention < 7:
                self._add_violation(
                    "insufficient_backup_retention",
                    Severity.HIGH,
                    f"Backup retention {backup_retention} days insufficient for SOX",
                    "configuration",
                    None,
                    "Set backup retention to at least 7 days",
                    "sox"
                )
        
        # Check environment-specific rules
        environment = config.get('environment', 'dev')
        if environment == 'prod':
            self._check_production_requirements(config, frameworks)
    
    def _check_production_requirements(self, config: Dict[str, Any], frameworks: List[str]) -> None:
        """Check production-specific compliance requirements"""
        
        # Multi-AZ requirement for production
        multi_az = config.get('multi_az', False)
        if not multi_az:
            self._add_violation(
                "no_multi_az",
                Severity.MEDIUM,
                "Multi-AZ not enabled for production environment",
                "configuration", 
                None,
                "Enable Multi-AZ for production workloads",
                "general"
            )
        
        # Enhanced monitoring requirement
        detailed_monitoring = config.get('detailed_monitoring', False)
        if not detailed_monitoring:
            self._add_violation(
                "insufficient_monitoring",
                Severity.MEDIUM,
                "Detailed monitoring not enabled for production",
                "configuration",
                None,
                "Enable detailed monitoring for production",
                "general"
            )
    
    def _check_security_requirements(self, frameworks: List[str]) -> None:
        """Check general security requirements"""
        
        # Check for required security resources
        terraform_files = list(self.project_dir.rglob("*.tf"))
        all_content = ""
        
        for tf_file in terraform_files:
            try:
                with open(tf_file, 'r') as f:
                    all_content += f.read() + "\\n"
            except:
                continue
        
        # Check for security resources
        security_resources = [
            ("aws_cloudtrail", "CloudTrail for audit logging"),
            ("aws_kms_key", "KMS key for encryption"),
            ("aws_security_group", "Security groups for access control")
        ]
        
        for resource_type, description in security_resources:
            if resource_type not in all_content:
                self._add_violation(
                    f"missing_{resource_type}",
                    Severity.MEDIUM,
                    f"Missing {description}",
                    "terraform",
                    None,
                    f"Add {resource_type} resource for security",
                    "general"
                )
    
    def _check_framework_specific_requirements(self, frameworks: List[str]) -> None:
        """Check framework-specific requirements"""
        
        for framework in frameworks:
            if framework == 'pci':
                self._check_pci_requirements()
            elif framework == 'sox':
                self._check_sox_requirements()
            elif framework == 'gdpr':
                self._check_gdpr_requirements()
            elif framework == 'hipaa':
                self._check_hipaa_requirements()
    
    def _check_pci_requirements(self) -> None:
        """Check PCI DSS specific requirements"""
        
        # Check for WAF
        terraform_files = list(self.project_dir.rglob("*.tf"))
        has_waf = False
        
        for tf_file in terraform_files:
            try:
                with open(tf_file, 'r') as f:
                    content = f.read()
                    if 'aws_wafv2_web_acl' in content:
                        has_waf = True
                        break
            except:
                continue
        
        if not has_waf:
            self._add_violation(
                "missing_waf",
                Severity.CRITICAL,
                "WAF not configured for PCI compliance",
                "terraform",
                None,
                "Deploy AWS WAF for web application protection",
                "pci"
            )
    
    def _check_sox_requirements(self) -> None:
        """Check SOX specific requirements"""
        
        # Check for Config recorder
        terraform_files = list(self.project_dir.rglob("*.tf"))
        has_config = False
        
        for tf_file in terraform_files:
            try:
                with open(tf_file, 'r') as f:
                    content = f.read()
                    if 'aws_config_configuration_recorder' in content:
                        has_config = True
                        break
            except:
                continue
        
        if not has_config:
            self._add_violation(
                "missing_config_recorder",
                Severity.CRITICAL,
                "AWS Config not enabled for SOX compliance",
                "terraform",
                None,
                "Enable AWS Config for configuration tracking",
                "sox"
            )
    
    def _check_gdpr_requirements(self) -> None:
        """Check GDPR specific requirements"""
        
        # Check for lifecycle policies
        terraform_files = list(self.project_dir.rglob("*.tf"))
        has_lifecycle = False
        
        for tf_file in terraform_files:
            try:
                with open(tf_file, 'r') as f:
                    content = f.read()
                    if 'lifecycle_rule' in content or 'lifecycle_configuration' in content:
                        has_lifecycle = True
                        break
            except:
                continue
        
        if not has_lifecycle:
            self._add_violation(
                "no_data_retention_policy",
                Severity.HIGH,
                "No data lifecycle policies for GDPR compliance",
                "terraform",
                None,
                "Implement S3 lifecycle rules for data retention",
                "gdpr"
            )
    
    def _check_hipaa_requirements(self) -> None:
        """Check HIPAA specific requirements"""
        
        # Check for encryption
        terraform_files = list(self.project_dir.rglob("*.tf"))
        encryption_found = False
        
        for tf_file in terraform_files:
            try:
                with open(tf_file, 'r') as f:
                    content = f.read()
                    if 'encrypted = true' in content or 'kms_key_id' in content:
                        encryption_found = True
                        break
            except:
                continue
        
        if not encryption_found:
            self._add_violation(
                "missing_hipaa_encryption",
                Severity.CRITICAL,
                "Insufficient encryption for HIPAA compliance",
                "terraform",
                None,
                "Enable encryption at rest and in transit",
                "hipaa"
            )
    
    def _add_violation(self, 
                      rule_id: str, 
                      severity: Severity, 
                      message: str, 
                      file_path: str, 
                      line_number: Optional[int],
                      suggestion: str, 
                      framework: str) -> None:
        """Add a compliance violation to the list"""
        
        violation = ComplianceViolation(
            rule_id=rule_id,
            severity=severity,
            message=message,
            file_path=file_path,
            line_number=line_number,
            column_number=None,
            suggestion=suggestion,
            framework=framework
        )
        
        self.violations.append(violation)
    
    def _generate_compliance_report(self) -> Dict[str, Any]:
        """Generate comprehensive compliance report"""
        
        # Group violations by severity
        violations_by_severity = {}
        violations_by_framework = {}
        
        for violation in self.violations:
            severity = violation.severity.value
            framework = violation.framework
            
            if severity not in violations_by_severity:
                violations_by_severity[severity] = []
            violations_by_severity[severity].append(asdict(violation))
            
            if framework not in violations_by_framework:
                violations_by_framework[framework] = []
            violations_by_framework[framework].append(asdict(violation))
        
        # Calculate compliance score
        total_violations = len(self.violations)
        critical_violations = len(violations_by_severity.get('critical', []))
        high_violations = len(violations_by_severity.get('high', []))
        
        # Compliance score calculation (0-100)
        if total_violations == 0:
            compliance_score = 100
        else:
            # Weight violations by severity
            weighted_score = (
                critical_violations * 10 +
                high_violations * 5 +
                len(violations_by_severity.get('medium', [])) * 2 +
                len(violations_by_severity.get('low', [])) * 1
            )
            compliance_score = max(0, 100 - weighted_score)
        
        # Determine overall status
        if critical_violations > 0:
            status = "NON_COMPLIANT"
        elif high_violations > 3:
            status = "PARTIAL_COMPLIANCE"
        elif total_violations > 10:
            status = "NEEDS_ATTENTION"
        else:
            status = "COMPLIANT"
        
        return {
            "compliance_status": status,
            "compliance_score": compliance_score,
            "total_violations": total_violations,
            "violations_by_severity": violations_by_severity,
            "violations_by_framework": violations_by_framework,
            "summary": {
                "critical": len(violations_by_severity.get('critical', [])),
                "high": len(violations_by_severity.get('high', [])),
                "medium": len(violations_by_severity.get('medium', [])),
                "low": len(violations_by_severity.get('low', [])),
                "info": len(violations_by_severity.get('info', []))
            },
            "recommendations": self._generate_recommendations(),
            "next_steps": self._generate_next_steps(status),
            "scan_metadata": {
                "timestamp": "2024-09-10T00:00:00Z",
                "project_dir": str(self.project_dir),
                "files_scanned": len(list(self.project_dir.rglob("*.tf"))),
                "rules_applied": sum(len(rules) for rules in self.rules.values())
            }
        }
    
    def _generate_recommendations(self) -> List[str]:
        """Generate actionable recommendations"""
        
        recommendations = []
        
        # Group violations by type for better recommendations
        rule_counts = {}
        for violation in self.violations:
            rule_counts[violation.rule_id] = rule_counts.get(violation.rule_id, 0) + 1
        
        # Top issues first
        sorted_rules = sorted(rule_counts.items(), key=lambda x: x[1], reverse=True)
        
        for rule_id, count in sorted_rules[:5]:  # Top 5 issues
            if rule_id == "no_hardcoded_secrets":
                recommendations.append("🔐 Move all secrets to AWS Secrets Manager or environment variables")
            elif rule_id == "open_security_groups":
                recommendations.append("🛡️ Restrict security group rules to specific IP ranges")
            elif rule_id == "unencrypted_resources":
                recommendations.append("🔒 Enable encryption at rest for all storage resources")
            elif rule_id == "missing_waf":
                recommendations.append("🔥 Deploy AWS WAF for web application protection")
            elif rule_id == "insufficient_backup_retention":
                recommendations.append("💾 Increase backup retention to meet compliance requirements")
        
        if not recommendations:
            recommendations.append("✅ No major compliance issues found")
        
        return recommendations
    
    def _generate_next_steps(self, status: str) -> List[str]:
        """Generate next steps based on compliance status"""
        
        if status == "NON_COMPLIANT":
            return [
                "🚨 Address all critical violations immediately",
                "📋 Create remediation plan with timelines",
                "👥 Involve security and compliance teams",
                "🔄 Re-scan after fixes are applied"
            ]
        elif status == "PARTIAL_COMPLIANCE":
            return [
                "⚡ Focus on high-severity violations first",
                "📅 Create timeline for medium-severity fixes",
                "📊 Monitor progress weekly",
                "🔍 Consider additional security controls"
            ]
        elif status == "NEEDS_ATTENTION":
            return [
                "🔧 Address medium and low severity issues",
                "📈 Implement monitoring for compliance drift",
                "📚 Review and update security policies",
                "🎯 Aim for 95%+ compliance score"
            ]
        else:
            return [
                "✅ Maintain current compliance posture",
                "🔄 Run regular compliance scans",
                "📋 Keep documentation up to date",
                "🎓 Provide team training on compliance"
            ]

def main():
    parser = argparse.ArgumentParser(description="StackKit Enterprise Compliance Checker")
    parser.add_argument("--project-dir", required=True, help="Project directory to scan")
    parser.add_argument("--config", required=True, help="Project configuration JSON")
    parser.add_argument("--output-format", choices=["json", "yaml", "text"], default="json",
                       help="Output format")
    parser.add_argument("--frameworks", help="Comma-separated compliance frameworks to check")
    parser.add_argument("--severity-filter", choices=["critical", "high", "medium", "low", "info"],
                       help="Only show violations of specified severity or higher")
    
    args = parser.parse_args()
    
    # Parse configuration
    try:
        if args.config.startswith('{'):
            config = json.loads(args.config)
        else:
            with open(args.config, 'r') as f:
                config = json.load(f)
    except Exception as e:
        print(f"Error parsing configuration: {e}")
        return 1
    
    # Override frameworks if specified
    if args.frameworks:
        config['compliance'] = args.frameworks.split(',')
    
    # Run compliance check
    checker = ComplianceChecker(args.project_dir)
    report = checker.check_compliance(config)
    
    # Filter by severity if requested
    if args.severity_filter:
        severity_order = ["critical", "high", "medium", "low", "info"]
        min_index = severity_order.index(args.severity_filter)
        
        for severity_level in report['violations_by_severity']:
            if severity_order.index(severity_level) > min_index:
                del report['violations_by_severity'][severity_level]
    
    # Output results
    if args.output_format == "json":
        print(json.dumps(report, indent=2))
    elif args.output_format == "yaml":
        import yaml
        print(yaml.dump(report, default_flow_style=False))
    else:
        # Text format
        print(f"🛡️  Compliance Report")
        print(f"Status: {report['compliance_status']}")
        print(f"Score: {report['compliance_score']}/100")
        print(f"Total Violations: {report['total_violations']}")
        print()
        
        if report['total_violations'] > 0:
            print("📊 Violations by Severity:")
            for severity, count in report['summary'].items():
                if count > 0:
                    print(f"  {severity.upper()}: {count}")
            print()
            
            print("🎯 Top Recommendations:")
            for rec in report['recommendations']:
                print(f"  {rec}")
            print()
        
        print("📋 Next Steps:")
        for step in report['next_steps']:
            print(f"  {step}")
    
    # Exit code based on compliance status
    if report['compliance_status'] == "NON_COMPLIANT":
        return 2
    elif report['compliance_status'] in ["PARTIAL_COMPLIANCE", "NEEDS_ATTENTION"]:
        return 1
    else:
        return 0

if __name__ == "__main__":
    exit(main())