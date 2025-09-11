#!/usr/bin/env python3
"""
StackKit Enterprise Template Selector

Selects optimal templates based on infrastructure requirements
"""

import argparse
import json
import os
import yaml
from typing import Dict, List, Any, Optional
from dataclasses import dataclass, asdict

@dataclass
class TemplateMetadata:
    """Template metadata structure"""
    name: str
    type: str  # base, specialized, compliance, addon
    categories: List[str]
    tech_stack: List[str]
    dependencies: List[str]
    conflicts: List[str]
    priority: int  # Higher number = higher priority
    maturity: str  # experimental, beta, stable
    version: str
    description: str
    author: str
    last_updated: str

class TemplateSelector:
    """Intelligent template selection based on requirements"""
    
    def __init__(self, templates_dir: str):
        self.templates_dir = templates_dir
        self.templates_registry = self._load_templates_registry()
    
    def _load_templates_registry(self) -> Dict[str, TemplateMetadata]:
        """Load all available templates from registry"""
        registry = {}
        registry_dir = os.path.join(self.templates_dir, "registry")
        
        if not os.path.exists(registry_dir):
            # Return default templates if registry doesn't exist
            return self._get_default_templates()
        
        for template_file in os.listdir(registry_dir):
            if template_file.endswith(('.yml', '.yaml')):
                template_path = os.path.join(registry_dir, template_file)
                try:
                    with open(template_path, 'r') as f:
                        template_data = yaml.safe_load(f)
                    
                    template_name = os.path.splitext(template_file)[0]
                    registry[template_name] = TemplateMetadata(
                        name=template_name,
                        type=template_data.get('type', 'base'),
                        categories=template_data.get('categories', []),
                        tech_stack=template_data.get('tech_stack', []),
                        dependencies=template_data.get('dependencies', []),
                        conflicts=template_data.get('conflicts', []),
                        priority=template_data.get('priority', 50),
                        maturity=template_data.get('maturity', 'stable'),
                        version=template_data.get('version', '1.0.0'),
                        description=template_data.get('description', ''),
                        author=template_data.get('author', 'StackKit'),
                        last_updated=template_data.get('last_updated', '')
                    )
                except Exception as e:
                    print(f"Warning: Could not load template {template_file}: {e}")
                    continue
        
        return registry if registry else self._get_default_templates()
    
    def _get_default_templates(self) -> Dict[str, TemplateMetadata]:
        """Return default template set when registry is not available"""
        return {
            "base-infrastructure": TemplateMetadata(
                name="base-infrastructure",
                type="base",
                categories=["networking", "security", "monitoring"],
                tech_stack=[],
                dependencies=[],
                conflicts=[],
                priority=100,
                maturity="stable",
                version="1.0.0",
                description="Base infrastructure with VPC, security groups, and basic monitoring",
                author="StackKit",
                last_updated="2024-09-10"
            ),
            
            "nodejs-ecs": TemplateMetadata(
                name="nodejs-ecs",
                type="specialized",
                categories=["compute", "containerization"],
                tech_stack=["nodejs"],
                dependencies=["base-infrastructure"],
                conflicts=[],
                priority=80,
                maturity="stable",
                version="1.2.0",
                description="Node.js application on ECS Fargate",
                author="StackKit",
                last_updated="2024-09-10"
            ),
            
            "python-ecs": TemplateMetadata(
                name="python-ecs",
                type="specialized",
                categories=["compute", "containerization"],
                tech_stack=["python"],
                dependencies=["base-infrastructure"],
                conflicts=[],
                priority=80,
                maturity="stable",
                version="1.1.0",
                description="Python application on ECS Fargate",
                author="StackKit", 
                last_updated="2024-09-10"
            ),
            
            "react-spa": TemplateMetadata(
                name="react-spa",
                type="specialized",
                categories=["frontend", "cdn"],
                tech_stack=["react"],
                dependencies=[],
                conflicts=[],
                priority=75,
                maturity="stable",
                version="1.0.0",
                description="React SPA with S3 and CloudFront",
                author="StackKit",
                last_updated="2024-09-10"
            ),
            
            "postgres-rds": TemplateMetadata(
                name="postgres-rds",
                type="specialized", 
                categories=["database", "storage"],
                tech_stack=["postgres"],
                dependencies=["base-infrastructure"],
                conflicts=[],
                priority=85,
                maturity="stable",
                version="1.0.0",
                description="PostgreSQL on RDS with backup and monitoring",
                author="StackKit",
                last_updated="2024-09-10"
            ),
            
            "redis-cache": TemplateMetadata(
                name="redis-cache",
                type="addon",
                categories=["cache", "performance"],
                tech_stack=["redis"],
                dependencies=["base-infrastructure"],
                conflicts=[],
                priority=60,
                maturity="stable", 
                version="1.0.0",
                description="Redis cluster for caching and sessions",
                author="StackKit",
                last_updated="2024-09-10"
            ),
            
            "compliance-sox": TemplateMetadata(
                name="compliance-sox",
                type="compliance",
                categories=["governance", "audit"],
                tech_stack=[],
                dependencies=["base-infrastructure"],
                conflicts=[],
                priority=90,
                maturity="stable",
                version="1.0.0",
                description="SOX compliance with CloudTrail and Config",
                author="StackKit",
                last_updated="2024-09-10"
            ),
            
            "compliance-gdpr": TemplateMetadata(
                name="compliance-gdpr",
                type="compliance",
                categories=["privacy", "encryption"],
                tech_stack=[],
                dependencies=["base-infrastructure"],
                conflicts=[],
                priority=90,
                maturity="stable",
                version="1.0.0",
                description="GDPR compliance with encryption and data lifecycle",
                author="StackKit",
                last_updated="2024-09-10"
            ),
            
            "monitoring-advanced": TemplateMetadata(
                name="monitoring-advanced",
                type="addon",
                categories=["monitoring", "observability"],
                tech_stack=[],
                dependencies=["base-infrastructure"],
                conflicts=[],
                priority=70,
                maturity="stable",
                version="1.0.0",
                description="Advanced monitoring with custom metrics and alerting",
                author="StackKit",
                last_updated="2024-09-10"
            )
        }
    
    def select_templates(self, requirements: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Select optimal templates based on requirements"""
        
        # Extract requirement details
        requirements_by_category = requirements.get('requirements_by_category', {})
        tech_stack = requirements.get('tech_stack', [])
        compliance = requirements.get('compliance', [])
        complexity_score = requirements.get('complexity_score', 0.0)
        
        # Template selection strategy
        selected_templates = []
        template_scores = {}
        
        # Score all templates
        for template_name, template in self.templates_registry.items():
            score = self._calculate_template_score(
                template, requirements_by_category, tech_stack, compliance, complexity_score
            )
            template_scores[template_name] = score
        
        # Select templates based on scores and constraints
        selected_templates = self._select_optimal_templates(template_scores)
        
        # Resolve dependencies and conflicts
        resolved_templates = self._resolve_dependencies_and_conflicts(selected_templates)
        
        # Convert to output format
        template_selections = []
        for template_name in resolved_templates:
            template = self.templates_registry[template_name]
            template_selections.append({
                **asdict(template),
                "selection_score": template_scores[template_name],
                "selection_reason": self._get_selection_reason(
                    template, requirements_by_category, tech_stack, compliance
                )
            })
        
        # Sort by priority and score
        template_selections.sort(key=lambda x: (-x['priority'], -x['selection_score']))
        
        return template_selections
    
    def _calculate_template_score(self, 
                                template: TemplateMetadata,
                                requirements_by_category: Dict[str, List],
                                tech_stack: List[str],
                                compliance: List[str],
                                complexity_score: float) -> float:
        """Calculate relevance score for a template"""
        score = 0.0
        
        # Tech stack match (high weight)
        if template.tech_stack:
            tech_matches = len(set(template.tech_stack) & set(tech_stack))
            tech_total = len(set(template.tech_stack) | set(tech_stack))
            if tech_total > 0:
                score += (tech_matches / tech_total) * 40
        
        # Category relevance (medium weight)
        template_categories = set(template.categories)
        requirement_categories = set(requirements_by_category.keys())
        if template_categories and requirement_categories:
            category_matches = len(template_categories & requirement_categories)
            score += (category_matches / len(template_categories)) * 30
        
        # Compliance match (high weight for compliance templates)
        if template.type == "compliance":
            compliance_match = any(comp in template.name.lower() for comp in compliance)
            if compliance_match:
                score += 35
            elif compliance:  # Penalty if compliance needed but template doesn't match
                score -= 10
        
        # Base template bonus (always needed)
        if template.type == "base":
            score += 25
        
        # Priority and maturity adjustments
        priority_bonus = (template.priority / 100) * 10
        score += priority_bonus
        
        maturity_bonus = {"stable": 5, "beta": 2, "experimental": -3}.get(template.maturity, 0)
        score += maturity_bonus
        
        # Complexity adjustment
        if complexity_score > 0.7 and template.type in ["addon", "specialized"]:
            score += 10
        elif complexity_score < 0.3 and template.type == "addon":
            score -= 5
        
        return max(0.0, score)
    
    def _select_optimal_templates(self, template_scores: Dict[str, float]) -> List[str]:
        """Select optimal template set based on scores"""
        # Sort templates by score
        sorted_templates = sorted(template_scores.items(), key=lambda x: -x[1])
        
        selected = []
        
        # Always include highest scoring base template
        for template_name, score in sorted_templates:
            template = self.templates_registry[template_name]
            if template.type == "base" and score > 0:
                selected.append(template_name)
                break
        
        # Add specialized templates with good scores
        for template_name, score in sorted_templates:
            template = self.templates_registry[template_name]
            if (template.type in ["specialized", "compliance"] and 
                score > 30 and 
                template_name not in selected):
                selected.append(template_name)
        
        # Add addon templates selectively
        for template_name, score in sorted_templates:
            template = self.templates_registry[template_name]
            if (template.type == "addon" and 
                score > 40 and 
                template_name not in selected and
                len(selected) < 8):  # Limit total templates
                selected.append(template_name)
        
        return selected
    
    def _resolve_dependencies_and_conflicts(self, selected_templates: List[str]) -> List[str]:
        """Resolve template dependencies and conflicts"""
        resolved = list(selected_templates)
        
        # Add missing dependencies
        added_deps = True
        while added_deps:
            added_deps = False
            for template_name in list(resolved):
                template = self.templates_registry[template_name]
                for dep in template.dependencies:
                    if dep not in resolved and dep in self.templates_registry:
                        resolved.append(dep)
                        added_deps = True
        
        # Remove conflicts (keep higher priority template)
        to_remove = set()
        for template_name in resolved:
            if template_name in to_remove:
                continue
            
            template = self.templates_registry[template_name]
            for conflict in template.conflicts:
                if conflict in resolved and conflict not in to_remove:
                    conflict_template = self.templates_registry[conflict]
                    # Keep higher priority template
                    if template.priority >= conflict_template.priority:
                        to_remove.add(conflict)
                    else:
                        to_remove.add(template_name)
                        break
        
        resolved = [t for t in resolved if t not in to_remove]
        
        return resolved
    
    def _get_selection_reason(self, 
                            template: TemplateMetadata,
                            requirements_by_category: Dict[str, List],
                            tech_stack: List[str],
                            compliance: List[str]) -> str:
        """Generate human-readable reason for template selection"""
        reasons = []
        
        # Tech stack match
        tech_matches = set(template.tech_stack) & set(tech_stack)
        if tech_matches:
            reasons.append(f"matches tech stack: {', '.join(tech_matches)}")
        
        # Category match
        category_matches = set(template.categories) & set(requirements_by_category.keys())
        if category_matches:
            reasons.append(f"provides {', '.join(category_matches)} capabilities")
        
        # Compliance match
        if template.type == "compliance":
            compliance_matches = [comp for comp in compliance if comp in template.name.lower()]
            if compliance_matches:
                reasons.append(f"required for {', '.join(compliance_matches)} compliance")
        
        # Base template
        if template.type == "base":
            reasons.append("provides foundational infrastructure")
        
        # High priority
        if template.priority >= 80:
            reasons.append("high priority template for this use case")
        
        if not reasons:
            reasons.append("general compatibility with requirements")
        
        return "; ".join(reasons)

def main():
    parser = argparse.ArgumentParser(description="StackKit Enterprise Template Selector")
    parser.add_argument("--requirements", required=True,
                       help="Requirements JSON (from requirement_detector)")
    parser.add_argument("--templates-dir", required=True,
                       help="Templates directory path")
    parser.add_argument("--output-format", choices=["json", "yaml"], default="json",
                       help="Output format")
    parser.add_argument("--max-templates", type=int, default=8,
                       help="Maximum number of templates to select")
    
    args = parser.parse_args()
    
    # Parse requirements
    try:
        if args.requirements.startswith('{'):
            requirements = json.loads(args.requirements)
        else:
            # Assume it's a file path
            with open(args.requirements, 'r') as f:
                requirements = json.load(f)
    except Exception as e:
        print(f"Error parsing requirements: {e}")
        return 1
    
    selector = TemplateSelector(args.templates_dir)
    selected_templates = selector.select_templates(requirements)
    
    # Limit number of templates
    if len(selected_templates) > args.max_templates:
        selected_templates = selected_templates[:args.max_templates]
    
    if args.output_format == "json":
        print(json.dumps(selected_templates, indent=2))
    else:
        import yaml
        print(yaml.dump(selected_templates, default_flow_style=False))

if __name__ == "__main__":
    exit(main() or 0)