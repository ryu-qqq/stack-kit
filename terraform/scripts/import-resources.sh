#!/bin/bash

# Import existing AWS resources into Terraform state
# Usage: ./import-resources.sh <stack-dir> <resource-type> <terraform-address> <aws-resource-id>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="${1:-}"
RESOURCE_TYPE="${2:-}"
TF_ADDRESS="${3:-}"
AWS_ID="${4:-}"

show_usage() {
    cat << EOF
📦 Terraform Resource Import Helper

Usage: $0 <stack-dir> <resource-type> <terraform-address> <aws-resource-id>

Arguments:
    stack-dir        Path to terraform stack directory
    resource-type    Type of AWS resource to import
    terraform-address Terraform resource address (e.g., module.vpc.aws_vpc.main)
    aws-resource-id  AWS resource identifier

Supported resource types:
    vpc              VPC ID (vpc-xxxxx)
    subnet           Subnet ID (subnet-xxxxx)
    igw              Internet Gateway ID (igw-xxxxx)  
    nat              NAT Gateway ID (nat-xxxxx)
    sg               Security Group ID (sg-xxxxx)
    s3               S3 Bucket name
    rds              RDS instance identifier
    lambda           Lambda function name
    ecs-cluster      ECS cluster name
    alb              Load balancer ARN

Examples:
    # Import existing VPC
    $0 ../stacks/my-app-dev-us-east-1 vpc module.vpc.aws_vpc.main vpc-0123456789abcdef0
    
    # Import existing subnet
    $0 ../stacks/my-app-dev-us-east-1 subnet module.vpc.aws_subnet.private[0] subnet-0123456789abcdef0
    
    # Import existing S3 bucket
    $0 ../stacks/my-app-dev-us-east-1 s3 module.atlantis_outputs_bucket.aws_s3_bucket.main my-existing-bucket
    
    # Import existing ECS cluster
    $0 ../stacks/my-app-dev-us-east-1 ecs-cluster module.atlantis_cluster.aws_ecs_cluster.main my-existing-cluster

EOF
}

if [[ $# -lt 4 ]]; then
    show_usage
    exit 1
fi

if [[ ! -d "$STACK_DIR" ]]; then
    echo "❌ Stack directory not found: $STACK_DIR"
    exit 1
fi

echo "📦 Importing AWS resource into Terraform state..."
echo "   Stack: $STACK_DIR"
echo "   Resource Type: $RESOURCE_TYPE"
echo "   Terraform Address: $TF_ADDRESS"
echo "   AWS ID: $AWS_ID"
echo ""

cd "$STACK_DIR"

# Validate terraform configuration
if [[ ! -f "main.tf" ]]; then
    echo "❌ main.tf not found in $STACK_DIR"
    exit 1
fi

# Check if terraform is initialized
if [[ ! -d ".terraform" ]]; then
    echo "⚠️  Terraform not initialized. Running terraform init..."
    terraform init -backend-config=backend.hcl
fi

# Verify AWS resource exists
echo "🔍 Verifying AWS resource exists..."
case $RESOURCE_TYPE in
    vpc)
        aws ec2 describe-vpcs --vpc-ids "$AWS_ID" --query 'Vpcs[0].VpcId' --output text > /dev/null
        ;;
    subnet)
        aws ec2 describe-subnets --subnet-ids "$AWS_ID" --query 'Subnets[0].SubnetId' --output text > /dev/null
        ;;
    igw)
        aws ec2 describe-internet-gateways --internet-gateway-ids "$AWS_ID" --query 'InternetGateways[0].InternetGatewayId' --output text > /dev/null
        ;;
    nat)
        aws ec2 describe-nat-gateways --nat-gateway-ids "$AWS_ID" --query 'NatGateways[0].NatGatewayId' --output text > /dev/null
        ;;
    sg)
        aws ec2 describe-security-groups --group-ids "$AWS_ID" --query 'SecurityGroups[0].GroupId' --output text > /dev/null
        ;;
    s3)
        aws s3api head-bucket --bucket "$AWS_ID" > /dev/null
        ;;
    rds)
        aws rds describe-db-instances --db-instance-identifier "$AWS_ID" --query 'DBInstances[0].DBInstanceIdentifier' --output text > /dev/null
        ;;
    lambda)
        aws lambda get-function --function-name "$AWS_ID" --query 'Configuration.FunctionName' --output text > /dev/null
        ;;
    ecs-cluster)
        aws ecs describe-clusters --clusters "$AWS_ID" --query 'clusters[0].clusterName' --output text > /dev/null
        ;;
    alb)
        aws elbv2 describe-load-balancers --load-balancer-arns "$AWS_ID" --query 'LoadBalancers[0].LoadBalancerArn' --output text > /dev/null
        ;;
    *)
        echo "❌ Unsupported resource type: $RESOURCE_TYPE"
        exit 1
        ;;
esac

echo "✅ AWS resource verified: $AWS_ID"

# Import the resource
echo "📥 Importing resource into Terraform state..."
if terraform import "$TF_ADDRESS" "$AWS_ID"; then
    echo "✅ Resource imported successfully!"
    echo ""
    echo "📋 Next steps:"
    echo "1. Run 'terraform plan' to see if configuration matches"
    echo "2. Update your terraform configuration if needed"
    echo "3. Run 'terraform apply' to sync any differences"
    echo ""
    echo "💡 Pro tip: Use 'terraform show' to see the imported resource attributes"
else
    echo "❌ Import failed. Check the terraform address and AWS resource ID."
    exit 1
fi