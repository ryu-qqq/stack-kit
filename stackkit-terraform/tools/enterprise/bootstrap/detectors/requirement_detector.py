#!/usr/bin/env python3
"""
StackKit Enterprise Requirement Detector

Analyzes team inputs and patterns to determine infrastructure requirements
"""

import argparse
import json
import re
from typing import Dict, List, Set, Any
from dataclasses import dataclass, asdict

@dataclass
class InfrastructureRequirement:
    """Infrastructure requirement specification"""
    category: str
    component: str
    priority: str  # critical, high, medium, low
    rationale: str
    dependencies: List[str]
    configurations: Dict[str, Any]

class RequirementDetector:
    """Intelligent requirement detection based on tech stack and team patterns"""
    
    def __init__(self):
        self.tech_stack_mappings = self._load_tech_stack_mappings()
        self.team_patterns = self._load_team_patterns()
        self.compliance_requirements = self._load_compliance_requirements()
    
    def _load_tech_stack_mappings(self) -> Dict[str, List[InfrastructureRequirement]]:
        """Load technology to infrastructure mappings"""
        return {
            # Backend Technologies
            "nodejs": [
                InfrastructureRequirement(
                    category="compute",
                    component="ecs_fargate",
                    priority="critical",
                    rationale="Containerized Node.js apps run efficiently on ECS Fargate",
                    dependencies=["vpc", "alb"],
                    configurations={
                        "task_cpu": "1024",
                        "task_memory": "2048",
                        "container_port": 3000
                    }
                ),
                InfrastructureRequirement(
                    category="storage",
                    component="s3",
                    priority="high",
                    rationale="Asset storage and static file serving",
                    dependencies=["iam"],
                    configurations={
                        "versioning_enabled": True,
                        "lifecycle_rules": ["delete_old_versions_90d"]
                    }
                )
            ],
            
            "python": [
                InfrastructureRequirement(
                    category="compute",
                    component="ecs_fargate",
                    priority="critical",
                    rationale="Python applications with dependency management",
                    dependencies=["vpc", "alb"],
                    configurations={
                        "task_cpu": "1024",
                        "task_memory": "2048",
                        "container_port": 8000
                    }
                ),
                InfrastructureRequirement(
                    category="monitoring",
                    component="cloudwatch_insights",
                    priority="high",
                    rationale="Python apps benefit from detailed log analysis",
                    dependencies=["cloudwatch"],
                    configurations={
                        "log_retention_days": 30,
                        "query_definitions": ["error_analysis", "performance_metrics"]
                    }
                )
            ],
            
            # Frontend Technologies
            "react": [
                InfrastructureRequirement(
                    category="storage",
                    component="s3_cloudfront",
                    priority="critical",
                    rationale="Static site hosting with global CDN",
                    dependencies=["cloudfront", "route53"],
                    configurations={
                        "spa_routing": True,
                        "cache_behaviors": ["static_assets", "api_proxy"]
                    }
                ),
                InfrastructureRequirement(
                    category="cicd",
                    component="codepipeline_frontend",
                    priority="high",
                    rationale="Automated build and deployment pipeline",
                    dependencies=["codebuild", "s3"],
                    configurations={
                        "build_commands": ["npm install", "npm run build"],
                        "artifacts_location": "dist/"
                    }
                )
            ],
            
            "vue": [
                InfrastructureRequirement(
                    category="storage", 
                    component="s3_cloudfront",
                    priority="critical",
                    rationale="Static site hosting optimized for Vue.js",
                    dependencies=["cloudfront", "route53"],
                    configurations={
                        "spa_routing": True,
                        "cache_behaviors": ["static_assets", "api_proxy"],
                        "vue_router_mode": "history"
                    }
                )
            ],
            
            # Databases
            "postgres": [
                InfrastructureRequirement(
                    category="database",
                    component="rds_postgres",
                    priority="critical",
                    rationale="Managed PostgreSQL with high availability",
                    dependencies=["vpc", "security_groups"],
                    configurations={
                        "engine_version": "14.9",
                        "instance_class": "db.r5.large",
                        "multi_az": True,
                        "backup_retention_period": 7
                    }
                ),
                InfrastructureRequirement(
                    category="security",
                    component="secrets_manager",
                    priority="critical",
                    rationale="Secure database credential management",
                    dependencies=["kms"],
                    configurations={
                        "auto_rotation": True,
                        "rotation_days": 90
                    }
                )
            ],
            
            "mysql": [
                InfrastructureRequirement(
                    category="database",
                    component="rds_mysql",
                    priority="critical", 
                    rationale="Managed MySQL with automated backups",
                    dependencies=["vpc", "security_groups"],
                    configurations={
                        "engine_version": "8.0.35",
                        "instance_class": "db.r5.large",
                        "backup_retention_period": 7
                    }
                )
            ],
            
            "redis": [
                InfrastructureRequirement(
                    category="cache",
                    component="elasticache_redis",
                    priority="high",
                    rationale="High-performance in-memory data store",
                    dependencies=["vpc", "security_groups"],
                    configurations={
                        "node_type": "cache.r6g.large",
                        "num_cache_clusters": 2,
                        "automatic_failover": True
                    }
                )
            ],
            
            # Message Queues & Streaming
            "kafka": [
                InfrastructureRequirement(
                    category="messaging",
                    component="msk_kafka",
                    priority="critical",
                    rationale="Managed Kafka for high-throughput streaming",
                    dependencies=["vpc", "security_groups"],
                    configurations={
                        "kafka_version": "2.8.1",
                        "instance_type": "kafka.m5.large",
                        "ebs_volume_size": 1000
                    }
                )
            ],
            
            "elasticsearch": [
                InfrastructureRequirement(
                    category="search",
                    component="opensearch",
                    priority="high",
                    rationale="Managed search and analytics engine",
                    dependencies=["vpc", "security_groups"],
                    configurations={
                        "engine_version": "OpenSearch_2.3",
                        "instance_type": "r6g.large.search",
                        "instance_count": 3
                    }
                )
            ],
            
            # Orchestration
            "kubernetes": [
                InfrastructureRequirement(
                    category="orchestration", 
                    component="eks_cluster",
                    priority="critical",
                    rationale="Managed Kubernetes for container orchestration",
                    dependencies=["vpc", "iam"],
                    configurations={
                        "version": "1.27",
                        "node_groups": ["general-purpose"],
                        "addons": ["vpc-cni", "ebs-csi"]
                    }
                )
            ],
            
            "terraform": [
                InfrastructureRequirement(
                    category="infrastructure",
                    component="terraform_state",
                    priority="critical",
                    rationale="Remote state management for infrastructure",
                    dependencies=["s3", "dynamodb"],
                    configurations={
                        "state_bucket_versioning": True,
                        "state_locking": True,
                        "backend_encryption": True
                    }
                )
            ]
        }
    
    def _load_team_patterns(self) -> Dict[str, Dict[str, Any]]:
        """Load team naming patterns and associated requirements"""
        return {
            "backend": {
                "implied_tech": ["api_gateway", "load_balancer"],
                "monitoring_level": "comprehensive",
                "security_focus": "api_security"
            },
            "frontend": {
                "implied_tech": ["cdn", "static_hosting"],
                "monitoring_level": "basic",
                "security_focus": "content_security"
            },
            "data": {
                "implied_tech": ["data_pipeline", "analytics"],
                "monitoring_level": "comprehensive", 
                "security_focus": "data_privacy"
            },
            "platform": {
                "implied_tech": ["service_mesh", "observability"],
                "monitoring_level": "advanced",
                "security_focus": "zero_trust"
            },
            "mobile": {
                "implied_tech": ["api_gateway", "push_notifications"],
                "monitoring_level": "basic",
                "security_focus": "mobile_security"
            }
        }
    
    def _load_compliance_requirements(self) -> Dict[str, List[InfrastructureRequirement]]:
        """Load compliance framework requirements"""
        return {
            "sox": [
                InfrastructureRequirement(
                    category="governance",
                    component="config_compliance",
                    priority="critical",
                    rationale="SOX compliance requires configuration tracking",
                    dependencies=["config", "cloudtrail"],
                    configurations={
                        "compliance_rules": ["sox_data_retention", "sox_access_control"]
                    }
                ),
                InfrastructureRequirement(
                    category="audit",
                    component="cloudtrail_advanced",
                    priority="critical",
                    rationale="SOX requires comprehensive audit trails",
                    dependencies=["s3", "kms"],
                    configurations={
                        "log_file_validation": True,
                        "include_global_services": True,
                        "is_multi_region_trail": True
                    }
                )
            ],
            
            "gdpr": [
                InfrastructureRequirement(
                    category="privacy",
                    component="data_encryption",
                    priority="critical",
                    rationale="GDPR requires encryption at rest and in transit",
                    dependencies=["kms"],
                    configurations={
                        "enforce_ssl": True,
                        "kms_key_rotation": True
                    }
                ),
                InfrastructureRequirement(
                    category="governance",
                    component="data_lifecycle",
                    priority="critical",
                    rationale="GDPR right to erasure and data minimization",
                    dependencies=["s3", "rds"],
                    configurations={
                        "data_retention_policies": True,
                        "automated_deletion": True
                    }
                )
            ],
            
            "pci": [
                InfrastructureRequirement(
                    category="security",
                    component="waf_security",
                    priority="critical",
                    rationale="PCI DSS requires web application firewall",
                    dependencies=["waf", "alb"],
                    configurations={
                        "managed_rules": ["AWSManagedRulesCommonRuleSet"],
                        "custom_rules": ["pci_compliance_rules"]
                    }
                )
            ],
            
            "hipaa": [
                InfrastructureRequirement(
                    category="security",
                    component="encryption_everywhere",
                    priority="critical",
                    rationale="HIPAA requires comprehensive encryption",
                    dependencies=["kms"],
                    configurations={
                        "enforce_encryption_at_rest": True,
                        "enforce_encryption_in_transit": True,
                        "dedicated_hsm": True
                    }
                )
            ]
        }
    
    def detect_team_patterns(self, team_name: str) -> List[InfrastructureRequirement]:
        """Detect requirements based on team naming patterns"""
        requirements = []
        team_lower = team_name.lower()
        
        for pattern, config in self.team_patterns.items():
            if pattern in team_lower:
                # Add monitoring requirement based on team pattern
                requirements.append(
                    InfrastructureRequirement(
                        category="monitoring",
                        component="monitoring_" + config["monitoring_level"],
                        priority="high",
                        rationale=f"Team pattern '{pattern}' suggests {config['monitoring_level']} monitoring",
                        dependencies=["cloudwatch"],
                        configurations={
                            "monitoring_level": config["monitoring_level"],
                            "security_focus": config["security_focus"]
                        }
                    )
                )
        
        return requirements
    
    def detect_tech_stack_requirements(self, tech_stack: List[str]) -> List[InfrastructureRequirement]:
        """Detect infrastructure requirements from technology stack"""
        requirements = []
        
        for tech in tech_stack:
            tech_lower = tech.strip().lower()
            if tech_lower in self.tech_stack_mappings:
                requirements.extend(self.tech_stack_mappings[tech_lower])
        
        return requirements
    
    def detect_compliance_requirements(self, compliance_frameworks: List[str]) -> List[InfrastructureRequirement]:
        """Detect requirements from compliance frameworks"""
        requirements = []
        
        for framework in compliance_frameworks:
            framework_lower = framework.strip().lower()
            if framework_lower in self.compliance_requirements:
                requirements.extend(self.compliance_requirements[framework_lower])
        
        return requirements
    
    def detect_cross_cutting_requirements(self, 
                                       tech_stack: List[str], 
                                       team: str,
                                       compliance: List[str]) -> List[InfrastructureRequirement]:
        """Detect cross-cutting concerns and implicit requirements"""
        requirements = []
        
        # Always include basic networking
        requirements.append(
            InfrastructureRequirement(
                category="networking",
                component="vpc",
                priority="critical",
                rationale="All applications require isolated networking",
                dependencies=[],
                configurations={
                    "enable_dns_hostnames": True,
                    "enable_dns_support": True,
                    "availability_zones": 2
                }
            )
        )
        
        # Load balancer for multi-service architectures
        if len([t for t in tech_stack if t in ["nodejs", "python", "java", "go"]]) > 0:
            requirements.append(
                InfrastructureRequirement(
                    category="networking",
                    component="application_load_balancer",
                    priority="high",
                    rationale="Application services require load balancing",
                    dependencies=["vpc"],
                    configurations={
                        "enable_http2": True,
                        "enable_cross_zone_load_balancing": True
                    }
                )
            )
        
        # Enhanced monitoring for production workloads
        if "prod" in team.lower() or len(tech_stack) > 3:
            requirements.append(
                InfrastructureRequirement(
                    category="monitoring",
                    component="advanced_monitoring",
                    priority="high",
                    rationale="Complex applications require advanced monitoring",
                    dependencies=["cloudwatch"],
                    configurations={
                        "custom_metrics": True,
                        "detailed_monitoring": True,
                        "alerting": True
                    }
                )
            )
        
        return requirements
    
    def analyze_requirements(self, 
                           tech_stack: str, 
                           team: str, 
                           compliance: str = "") -> Dict[str, Any]:
        """Main requirement analysis function"""
        
        # Parse inputs
        tech_stack_list = [t.strip() for t in tech_stack.split(",") if t.strip()]
        compliance_list = [c.strip() for c in compliance.split(",") if c.strip()] if compliance else []
        
        # Detect requirements from different sources
        tech_requirements = self.detect_tech_stack_requirements(tech_stack_list)
        team_requirements = self.detect_team_patterns(team)
        compliance_requirements = self.detect_compliance_requirements(compliance_list)
        cross_cutting_requirements = self.detect_cross_cutting_requirements(
            tech_stack_list, team, compliance_list
        )
        
        # Combine and deduplicate requirements
        all_requirements = (
            tech_requirements + 
            team_requirements + 
            compliance_requirements + 
            cross_cutting_requirements
        )
        
        # Deduplicate by (category, component)
        seen = set()
        unique_requirements = []
        for req in all_requirements:
            key = (req.category, req.component)
            if key not in seen:
                seen.add(key)
                unique_requirements.append(req)
        
        # Group by category and priority
        grouped = {}
        for req in unique_requirements:
            if req.category not in grouped:
                grouped[req.category] = []
            grouped[req.category].append(asdict(req))
        
        # Calculate complexity score
        complexity_score = self._calculate_complexity(unique_requirements)
        
        return {
            "team": team,
            "tech_stack": tech_stack_list,
            "compliance": compliance_list,
            "requirements_by_category": grouped,
            "total_requirements": len(unique_requirements),
            "complexity_score": complexity_score,
            "priority_breakdown": self._get_priority_breakdown(unique_requirements),
            "estimated_monthly_cost": self._estimate_cost(unique_requirements),
            "deployment_time_estimate": self._estimate_deployment_time(unique_requirements)
        }
    
    def _calculate_complexity(self, requirements: List[InfrastructureRequirement]) -> float:
        """Calculate project complexity score (0.0-1.0)"""
        if not requirements:
            return 0.0
        
        priority_weights = {"critical": 1.0, "high": 0.7, "medium": 0.4, "low": 0.2}
        category_weights = {
            "compute": 0.8, "database": 0.9, "messaging": 0.8,
            "orchestration": 1.0, "networking": 0.5, "security": 0.7,
            "monitoring": 0.3, "storage": 0.4, "governance": 0.6
        }
        
        total_weight = 0.0
        for req in requirements:
            priority_weight = priority_weights.get(req.priority, 0.5)
            category_weight = category_weights.get(req.category, 0.5)
            dependency_weight = min(len(req.dependencies) * 0.1, 0.5)
            
            total_weight += priority_weight * category_weight + dependency_weight
        
        # Normalize to 0.0-1.0 scale
        normalized_score = min(total_weight / len(requirements), 1.0)
        return round(normalized_score, 2)
    
    def _get_priority_breakdown(self, requirements: List[InfrastructureRequirement]) -> Dict[str, int]:
        """Get count of requirements by priority"""
        breakdown = {"critical": 0, "high": 0, "medium": 0, "low": 0}
        for req in requirements:
            breakdown[req.priority] += 1
        return breakdown
    
    def _estimate_cost(self, requirements: List[InfrastructureRequirement]) -> str:
        """Rough monthly cost estimate"""
        # Simplified cost estimation based on component types
        cost_map = {
            "ecs_fargate": 50, "rds_postgres": 200, "rds_mysql": 150,
            "elasticache_redis": 100, "eks_cluster": 150, "msk_kafka": 300,
            "opensearch": 200, "s3": 20, "cloudfront": 30, "alb": 25
        }
        
        total_cost = 0
        for req in requirements:
            component_cost = cost_map.get(req.component, 25)  # Default $25/month
            total_cost += component_cost
        
        if total_cost < 100:
            return f"${total_cost}-150/month"
        elif total_cost < 500:
            return f"${total_cost}-{int(total_cost * 1.3)}/month"
        else:
            return f"${total_cost}-{int(total_cost * 1.5)}/month"
    
    def _estimate_deployment_time(self, requirements: List[InfrastructureRequirement]) -> str:
        """Estimate deployment time based on complexity"""
        critical_count = len([r for r in requirements if r.priority == "critical"])
        total_count = len(requirements)
        
        if total_count <= 5:
            return "30-60 minutes"
        elif total_count <= 10:
            return "1-2 hours"
        elif critical_count > 5:
            return "2-4 hours"
        else:
            return "1-3 hours"

def main():
    parser = argparse.ArgumentParser(description="StackKit Enterprise Requirement Detector")
    parser.add_argument("--tech-stack", required=True, 
                       help="Technology stack (comma-separated)")
    parser.add_argument("--team", required=True,
                       help="Team name")
    parser.add_argument("--compliance", default="",
                       help="Compliance frameworks (comma-separated)")
    parser.add_argument("--output-format", choices=["json", "yaml"], default="json",
                       help="Output format")
    
    args = parser.parse_args()
    
    detector = RequirementDetector()
    result = detector.analyze_requirements(args.tech_stack, args.team, args.compliance)
    
    if args.output_format == "json":
        print(json.dumps(result, indent=2))
    else:
        # YAML output would require PyYAML
        import yaml
        print(yaml.dump(result, default_flow_style=False))

if __name__ == "__main__":
    main()