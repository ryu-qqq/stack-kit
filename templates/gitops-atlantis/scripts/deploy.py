#!/usr/bin/env python3
"""
VaultDB-Compatible Deployment Orchestrator
Blue/Green deployment with zero-downtime strategy
"""

import os
import sys
import time
import json
import boto3
import logging
from typing import Dict, List, Optional
from dataclasses import dataclass
from enum import Enum

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class DeploymentStrategy(Enum):
    DIRECT = "direct"
    BLUE_GREEN = "blue_green"

@dataclass
class DeploymentConfig:
    cluster_name: str
    service_name: str
    task_definition: str
    strategy: DeploymentStrategy
    environment: str
    blue_tg_arn: Optional[str] = None
    green_tg_arn: Optional[str] = None
    listener_arn: Optional[str] = None
    health_check_url: str = "/healthz"
    timeout_minutes: int = 10

class VaultDBDeploymentOrchestrator:
    """
    Orchestrates VaultDB-compatible deployments with minimal downtime
    """

    def __init__(self, config: DeploymentConfig):
        self.config = config
        self.ecs = boto3.client('ecs')
        self.elbv2 = boto3.client('elbv2')
        self.current_target = self._get_current_target_group()

    def _get_current_target_group(self) -> str:
        """Determine which target group is currently active"""
        if self.config.strategy == DeploymentStrategy.DIRECT:
            return "main"

        try:
            response = self.elbv2.describe_listeners(
                ListenerArns=[self.config.listener_arn]
            )

            for action in response['Listeners'][0]['DefaultActions']:
                if action['Type'] == 'forward':
                    tg_arn = action['TargetGroupArn']
                    if tg_arn == self.config.blue_tg_arn:
                        return "blue"
                    elif tg_arn == self.config.green_tg_arn:
                        return "green"

        except Exception as e:
            logger.error(f"Failed to determine current target group: {e}")

        return "blue"  # Default fallback

    def _get_inactive_target_group(self) -> str:
        """Get the inactive target group for blue/green deployment"""
        if self.current_target == "blue":
            return "green"
        return "blue"

    def _wait_for_healthy_targets(self, target_group_arn: str, timeout_minutes: int = 5) -> bool:
        """Wait for target group to have healthy targets"""
        logger.info(f"Waiting for healthy targets in {target_group_arn}")

        timeout = time.time() + (timeout_minutes * 60)

        while time.time() < timeout:
            try:
                response = self.elbv2.describe_target_health(
                    TargetGroupArn=target_group_arn
                )

                healthy_targets = [
                    target for target in response['TargetHealthDescriptions']
                    if target['TargetHealth']['State'] == 'healthy'
                ]

                if healthy_targets:
                    logger.info(f"Found {len(healthy_targets)} healthy targets")
                    return True

                logger.info("No healthy targets yet, waiting...")
                time.sleep(30)

            except Exception as e:
                logger.error(f"Error checking target health: {e}")
                time.sleep(30)

        logger.error("Timeout waiting for healthy targets")
        return False

    def _switch_traffic(self, target_group_arn: str) -> bool:
        """Switch traffic to specified target group"""
        try:
            logger.info(f"Switching traffic to {target_group_arn}")

            self.elbv2.modify_listener(
                ListenerArn=self.config.listener_arn,
                DefaultActions=[
                    {
                        'Type': 'forward',
                        'TargetGroupArn': target_group_arn
                    }
                ]
            )

            logger.info("Traffic successfully switched")
            return True

        except Exception as e:
            logger.error(f"Failed to switch traffic: {e}")
            return False

    def _update_service(self, target_group_arn: Optional[str] = None) -> bool:
        """Update ECS service with new task definition"""
        try:
            logger.info(f"Updating service {self.config.service_name}")

            update_params = {
                'cluster': self.config.cluster_name,
                'service': self.config.service_name,
                'taskDefinition': self.config.task_definition
            }

            # For blue/green, specify target group
            if target_group_arn and self.config.strategy == DeploymentStrategy.BLUE_GREEN:
                update_params['loadBalancers'] = [
                    {
                        'targetGroupArn': target_group_arn,
                        'containerName': 'atlantis',
                        'containerPort': 4141
                    }
                ]

            response = self.ecs.update_service(**update_params)

            logger.info("Service update initiated")
            return True

        except Exception as e:
            logger.error(f"Failed to update service: {e}")
            return False

    def _wait_for_deployment(self, timeout_minutes: int = 10) -> bool:
        """Wait for ECS deployment to complete"""
        logger.info("Waiting for deployment to complete")

        timeout = time.time() + (timeout_minutes * 60)

        while time.time() < timeout:
            try:
                response = self.ecs.describe_services(
                    cluster=self.config.cluster_name,
                    services=[self.config.service_name]
                )

                service = response['services'][0]
                deployments = service['deployments']

                # Check if primary deployment is stable
                primary_deployment = next(
                    (d for d in deployments if d['status'] == 'PRIMARY'), None
                )

                if primary_deployment and primary_deployment.get('rolloutState') == 'COMPLETED':
                    logger.info("Deployment completed successfully")
                    return True

                # Check for failed deployments
                failed_deployments = [
                    d for d in deployments if d['status'] == 'FAILED'
                ]

                if failed_deployments:
                    logger.error("Deployment failed")
                    return False

                logger.info("Deployment in progress...")
                time.sleep(30)

            except Exception as e:
                logger.error(f"Error checking deployment status: {e}")
                time.sleep(30)

        logger.error("Deployment timeout")
        return False

    def deploy_direct(self) -> bool:
        """Direct deployment strategy (for dev environment)"""
        logger.info("Starting direct deployment")

        # Update service with new task definition
        if not self._update_service():
            return False

        # Wait for deployment to complete
        if not self._wait_for_deployment(self.config.timeout_minutes):
            return False

        logger.info("Direct deployment completed successfully")
        return True

    def deploy_blue_green(self) -> bool:
        """Blue/Green deployment strategy (for prod environment)"""
        logger.info("Starting Blue/Green deployment")

        inactive_target = self._get_inactive_target_group()
        inactive_tg_arn = (
            self.config.green_tg_arn if inactive_target == "green"
            else self.config.blue_tg_arn
        )

        logger.info(f"Deploying to inactive target group: {inactive_target}")

        # Step 1: Deploy to inactive target group
        if not self._update_service(inactive_tg_arn):
            return False

        # Step 2: Wait for deployment to complete
        if not self._wait_for_deployment(self.config.timeout_minutes):
            logger.error("Deployment to inactive target group failed")
            return False

        # Step 3: Wait for healthy targets
        if not self._wait_for_healthy_targets(inactive_tg_arn):
            logger.error("New deployment failed health checks")
            return False

        # Step 4: Switch traffic
        if not self._switch_traffic(inactive_tg_arn):
            logger.error("Failed to switch traffic")
            return False

        # Step 5: Verify new deployment is receiving traffic
        time.sleep(60)  # Allow some time for traffic to flow

        if not self._wait_for_healthy_targets(inactive_tg_arn, timeout_minutes=2):
            logger.error("New deployment became unhealthy after traffic switch")
            # TODO: Implement rollback
            return False

        logger.info("Blue/Green deployment completed successfully")
        return True

    def deploy(self) -> bool:
        """Main deployment entry point"""
        logger.info(f"Starting {self.config.strategy.value} deployment for {self.config.environment}")

        if self.config.strategy == DeploymentStrategy.DIRECT:
            return self.deploy_direct()
        elif self.config.strategy == DeploymentStrategy.BLUE_GREEN:
            return self.deploy_blue_green()
        else:
            logger.error(f"Unknown deployment strategy: {self.config.strategy}")
            return False

def lambda_handler(event, context):
    """AWS Lambda entry point"""
    try:
        # Extract configuration from environment variables
        config = DeploymentConfig(
            cluster_name=os.environ['CLUSTER_NAME'],
            service_name=os.environ['SERVICE_NAME'],
            task_definition=event.get('task_definition', os.environ.get('TASK_DEFINITION')),
            strategy=DeploymentStrategy(os.environ.get('DEPLOYMENT_STRATEGY', 'direct')),
            environment=os.environ['ENVIRONMENT'],
            blue_tg_arn=os.environ.get('BLUE_TG_ARN'),
            green_tg_arn=os.environ.get('GREEN_TG_ARN'),
            listener_arn=os.environ.get('LISTENER_ARN'),
            health_check_url=os.environ.get('HEALTH_CHECK_URL', '/healthz'),
            timeout_minutes=int(os.environ.get('TIMEOUT_MINUTES', '10'))
        )

        orchestrator = VaultDBDeploymentOrchestrator(config)
        success = orchestrator.deploy()

        return {
            'statusCode': 200 if success else 500,
            'body': json.dumps({
                'success': success,
                'environment': config.environment,
                'strategy': config.strategy.value
            })
        }

    except Exception as e:
        logger.error(f"Deployment failed: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'success': False,
                'error': str(e)
            })
        }

if __name__ == "__main__":
    # CLI usage for testing
    import argparse

    parser = argparse.ArgumentParser(description='VaultDB Deployment Orchestrator')
    parser.add_argument('--cluster', required=True, help='ECS cluster name')
    parser.add_argument('--service', required=True, help='ECS service name')
    parser.add_argument('--task-definition', required=True, help='Task definition ARN')
    parser.add_argument('--strategy', choices=['direct', 'blue_green'], default='direct')
    parser.add_argument('--environment', required=True, help='Environment name')
    parser.add_argument('--blue-tg', help='Blue target group ARN')
    parser.add_argument('--green-tg', help='Green target group ARN')
    parser.add_argument('--listener', help='ALB listener ARN')

    args = parser.parse_args()

    config = DeploymentConfig(
        cluster_name=args.cluster,
        service_name=args.service,
        task_definition=args.task_definition,
        strategy=DeploymentStrategy(args.strategy),
        environment=args.environment,
        blue_tg_arn=args.blue_tg,
        green_tg_arn=args.green_tg,
        listener_arn=args.listener
    )

    orchestrator = VaultDBDeploymentOrchestrator(config)
    success = orchestrator.deploy()

    sys.exit(0 if success else 1)
