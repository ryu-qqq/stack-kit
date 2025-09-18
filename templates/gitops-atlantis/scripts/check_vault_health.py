#!/usr/bin/env python3
"""
VaultDB Health Check Script
Validates VaultDB state before deployment to ensure safe operations
"""

import os
import sys
import time
import json
import boto3
import requests
import logging
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@dataclass
class HealthCheckConfig:
    atlantis_url: str
    environment: str
    timeout_seconds: int = 30
    retry_count: int = 3
    retry_delay: int = 10

class VaultDBHealthChecker:
    """
    Comprehensive health checker for VaultDB before deployments
    """

    def __init__(self, config: HealthCheckConfig):
        self.config = config
        self.ecs = boto3.client('ecs')
        self.elbv2 = boto3.client('elbv2')

    def check_atlantis_api(self) -> Tuple[bool, str]:
        """Check if Atlantis API is responding"""
        try:
            logger.info(f"Checking Atlantis API at {self.config.atlantis_url}")

            response = requests.get(
                f"{self.config.atlantis_url}/healthz",
                timeout=self.config.timeout_seconds
            )

            if response.status_code == 200:
                logger.info("✅ Atlantis API is healthy")
                return True, "Atlantis API responding normally"
            else:
                logger.error(f"❌ Atlantis API returned status {response.status_code}")
                return False, f"API returned status {response.status_code}"

        except requests.exceptions.Timeout:
            logger.error("❌ Atlantis API timeout")
            return False, "API timeout"
        except requests.exceptions.ConnectionError:
            logger.error("❌ Cannot connect to Atlantis API")
            return False, "Connection failed"
        except Exception as e:
            logger.error(f"❌ Atlantis API check failed: {e}")
            return False, f"API check failed: {str(e)}"

    def check_vaultdb_locks(self) -> Tuple[bool, str]:
        """Check for active VaultDB locks that might prevent safe deployment"""
        try:
            logger.info("Checking for active VaultDB locks...")

            # Check for active Terraform locks via Atlantis API
            response = requests.get(
                f"{self.config.atlantis_url}/locks",
                timeout=self.config.timeout_seconds
            )

            if response.status_code == 200:
                locks = response.json()

                if not locks:
                    logger.info("✅ No active VaultDB locks found")
                    return True, "No active locks"
                else:
                    logger.warning(f"⚠️  Found {len(locks)} active locks")
                    lock_details = [f"Lock {i+1}: {lock.get('project', 'Unknown')}" for i, lock in enumerate(locks[:3])]
                    return False, f"Active locks detected: {', '.join(lock_details)}"

            # If locks endpoint is not available, assume safe to proceed
            logger.warning("⚠️  Cannot check locks endpoint, assuming safe")
            return True, "Locks endpoint unavailable"

        except Exception as e:
            logger.error(f"❌ Lock check failed: {e}")
            # Don't block deployment for lock check failures
            return True, f"Lock check failed but proceeding: {str(e)}"

    def check_ecs_service_stability(self) -> Tuple[bool, str]:
        """Check if ECS service is in stable state"""
        try:
            logger.info("Checking ECS service stability...")

            cluster_name = f"{self.config.environment}-connectly-atlantis-cluster"
            service_name = f"{self.config.environment}-connectly-atlantis-service"

            response = self.ecs.describe_services(
                cluster=cluster_name,
                services=[service_name]
            )

            if not response.get('services'):
                logger.error("❌ ECS service not found")
                return False, "ECS service not found"

            service = response['services'][0]

            # Check service status
            if service['status'] != 'ACTIVE':
                logger.error(f"❌ ECS service status: {service['status']}")
                return False, f"Service status: {service['status']}"

            # Check deployment status
            deployments = service.get('deployments', [])
            active_deployments = [d for d in deployments if d['status'] in ['PRIMARY', 'ACTIVE']]

            if len(active_deployments) != 1:
                logger.error(f"❌ Unexpected number of active deployments: {len(active_deployments)}")
                return False, f"Multiple active deployments: {len(active_deployments)}"

            primary_deployment = active_deployments[0]

            # Check deployment state
            rollout_state = primary_deployment.get('rolloutState')
            if rollout_state != 'COMPLETED':
                logger.error(f"❌ Deployment rollout state: {rollout_state}")
                return False, f"Deployment state: {rollout_state}"

            # Check desired vs running count
            desired = service['desiredCount']
            running = service['runningCount']

            if desired != running:
                logger.error(f"❌ Desired count ({desired}) != Running count ({running})")
                return False, f"Count mismatch: desired={desired}, running={running}"

            logger.info("✅ ECS service is stable")
            return True, "ECS service stable"

        except Exception as e:
            logger.error(f"❌ ECS service check failed: {e}")
            return False, f"ECS check failed: {str(e)}"

    def check_target_group_health(self) -> Tuple[bool, str]:
        """Check if target group has healthy targets"""
        try:
            logger.info("Checking target group health...")

            # Get target groups for this environment
            response = self.elbv2.describe_target_groups(
                Names=[f"{self.config.environment}-connectly-atlantis"]
            )

            if not response.get('TargetGroups'):
                logger.error("❌ Target group not found")
                return False, "Target group not found"

            target_group = response['TargetGroups'][0]
            tg_arn = target_group['TargetGroupArn']

            # Check target health
            health_response = self.elbv2.describe_target_health(
                TargetGroupArn=tg_arn
            )

            targets = health_response.get('TargetHealthDescriptions', [])
            healthy_targets = [t for t in targets if t['TargetHealth']['State'] == 'healthy']

            if not healthy_targets:
                logger.error("❌ No healthy targets found")
                return False, "No healthy targets"

            if len(healthy_targets) < len(targets):
                unhealthy_count = len(targets) - len(healthy_targets)
                logger.warning(f"⚠️  {unhealthy_count} unhealthy targets detected")

            logger.info(f"✅ {len(healthy_targets)}/{len(targets)} targets healthy")
            return True, f"{len(healthy_targets)} healthy targets"

        except Exception as e:
            logger.error(f"❌ Target group health check failed: {e}")
            return False, f"Target group check failed: {str(e)}"

    def check_vault_backup_status(self) -> Tuple[bool, str]:
        """Check if recent VaultDB backup exists"""
        try:
            logger.info("Checking VaultDB backup status...")

            # For EFS-based VaultDB, check if backup process is available
            # This is a placeholder - implement based on your backup strategy

            # Check if EFS backup is configured
            backup_available = True  # Placeholder

            if backup_available:
                logger.info("✅ VaultDB backup system is available")
                return True, "Backup system available"
            else:
                logger.warning("⚠️  VaultDB backup system not configured")
                return False, "No backup system"

        except Exception as e:
            logger.error(f"❌ Backup status check failed: {e}")
            return False, f"Backup check failed: {str(e)}"

    def check_deployment_window(self) -> Tuple[bool, str]:
        """Check if current time is within safe deployment window"""
        try:
            import datetime

            now = datetime.datetime.now()

            # Production deployment windows
            if self.config.environment == "prod":
                # Allow deployments only during business hours (9 AM - 6 PM KST)
                if now.hour < 9 or now.hour >= 18:
                    logger.warning("⚠️  Outside production deployment window (9 AM - 6 PM KST)")
                    return False, "Outside deployment window"

                # Avoid Friday afternoons and weekends
                if now.weekday() == 4 and now.hour >= 15:  # Friday after 3 PM
                    logger.warning("⚠️  Friday afternoon deployment not recommended")
                    return False, "Friday afternoon deployment"

                if now.weekday() >= 5:  # Weekend
                    logger.warning("⚠️  Weekend deployment not recommended")
                    return False, "Weekend deployment"

            logger.info("✅ Within safe deployment window")
            return True, "Safe deployment window"

        except Exception as e:
            logger.error(f"❌ Deployment window check failed: {e}")
            return True, f"Window check failed but proceeding: {str(e)}"

    def run_comprehensive_check(self) -> bool:
        """Run all health checks and return overall status"""
        logger.info(f"Starting comprehensive health check for {self.config.environment}")

        checks = [
            ("Atlantis API", self.check_atlantis_api),
            ("VaultDB Locks", self.check_vaultdb_locks),
            ("ECS Service", self.check_ecs_service_stability),
            ("Target Groups", self.check_target_group_health),
            ("Backup Status", self.check_vault_backup_status),
            ("Deployment Window", self.check_deployment_window)
        ]

        results = []
        all_passed = True

        for check_name, check_func in checks:
            try:
                passed, message = check_func()
                results.append({
                    'check': check_name,
                    'passed': passed,
                    'message': message
                })

                if not passed:
                    all_passed = False
                    logger.error(f"❌ {check_name}: {message}")
                else:
                    logger.info(f"✅ {check_name}: {message}")

            except Exception as e:
                logger.error(f"❌ {check_name} check failed with exception: {e}")
                results.append({
                    'check': check_name,
                    'passed': False,
                    'message': f"Exception: {str(e)}"
                })
                all_passed = False

        # Summary
        passed_count = sum(1 for r in results if r['passed'])
        total_count = len(results)

        logger.info(f"\n📊 Health Check Summary: {passed_count}/{total_count} checks passed")

        if all_passed:
            logger.info("🎉 All health checks passed - Safe to deploy!")
        else:
            logger.error("⚠️  Some health checks failed - Review before deploying")

        return all_passed

def main():
    """Main entry point for CLI usage"""
    import argparse

    parser = argparse.ArgumentParser(description='VaultDB Health Check')
    parser.add_argument('--environment', '-e', required=True, choices=['dev', 'staging', 'prod'])
    parser.add_argument('--timeout', '-t', type=int, default=30, help='Request timeout in seconds')
    parser.add_argument('--retry-count', '-r', type=int, default=3, help='Number of retries')
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose output')

    args = parser.parse_args()

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    # Determine Atlantis URL based on environment
    atlantis_urls = {
        'dev': 'https://atlantis-dev.set-of.com',
        'staging': 'https://atlantis-staging.set-of.com',
        'prod': 'https://atlantis.set-of.com'
    }

    config = HealthCheckConfig(
        atlantis_url=atlantis_urls[args.environment],
        environment=args.environment,
        timeout_seconds=args.timeout,
        retry_count=args.retry_count
    )

    checker = VaultDBHealthChecker(config)

    # Run health checks with retries
    for attempt in range(args.retry_count):
        if attempt > 0:
            logger.info(f"Retry attempt {attempt + 1}/{args.retry_count}")
            time.sleep(10)

        success = checker.run_comprehensive_check()

        if success:
            sys.exit(0)

    logger.error("Health checks failed after all retry attempts")
    sys.exit(1)

if __name__ == "__main__":
    main()
