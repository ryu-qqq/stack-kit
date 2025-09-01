#!/usr/bin/env bash
set -euo pipefail

# Build script for Atlantis AI Reviewer Lambda function with Gradle

echo "🔨 Building Atlantis AI Reviewer Lambda with Gradle..."

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Clean and build with Gradle
echo "🧹 Cleaning previous builds..."
# Try gradlew first, fallback to system gradle
if [[ -x "./gradlew" ]] && ./gradlew --version &>/dev/null; then
    GRADLE_CMD="./gradlew"
else
    echo "⚠️  Gradle wrapper not working, using system gradle..."
    GRADLE_CMD="gradle"
fi

$GRADLE_CMD clean

echo "📦 Compiling and building..."
$GRADLE_CMD build

echo "🧪 Running tests..."
$GRADLE_CMD test

echo "📦 Creating Lambda deployment package..."
$GRADLE_CMD jar

# Check if JAR was created
JAR_PATH="build/libs/atlantis-ai-reviewer-1.0.0.jar"
if [[ -f "$JAR_PATH" ]]; then
    echo "✅ Build successful: $JAR_PATH"
    echo "📏 JAR size: $(du -h "$JAR_PATH" | cut -f1)"
    
    # Copy to Terraform directory for easier deployment
    TERRAFORM_DIR="../../terraform/stacks/atlantis-demo/dev"
    LAMBDA_DIR="$TERRAFORM_DIR/lambda-packages"
    
    if [[ -d "$TERRAFORM_DIR" ]]; then
        echo "📦 Creating Lambda package directory..."
        mkdir -p "$LAMBDA_DIR"
        
        echo "🚚 Copying JAR to Terraform directory..."
        cp "$JAR_PATH" "$LAMBDA_DIR/"
        
        echo "🔄 Updating Terraform configuration..."
        # Update the filename path in main.tf
        RELATIVE_PATH="./lambda-packages/atlantis-ai-reviewer-1.0.0.jar"
        
        echo "💡 Update the filename paths in $TERRAFORM_DIR/main.tf to: $RELATIVE_PATH"
    fi
else
    echo "❌ Build failed: JAR not found"
    exit 1
fi

echo "🎉 Build complete! Ready for deployment."
echo ""
echo "📋 Next steps:"
echo "1. 🏗️  Create Atlantis AI Reviewer infrastructure:"
echo "   cd ../terraform/scripts"
echo "   ./new-stack.sh atlantis-ai-reviewer dev us-east-1"
echo ""
echo "2. 📝 Configure AWS Secrets Manager:"
echo "   aws secretsmanager create-secret --name 'atlantis/github-token' --secret-string 'ghp_your_token'"
echo "   aws secretsmanager create-secret --name 'atlantis/aws-access-key' --secret-string 'AKIA...'"
echo "   aws secretsmanager create-secret --name 'atlantis/aws-secret-key' --secret-string '...'"
echo ""
echo "3. 🔧 Set environment variables:"
echo "   export TF_VAR_webhook_secret='your-webhook-secret'"
echo "   export TF_VAR_slack_webhook_url='https://hooks.slack.com/services/...'"
echo "   export TF_VAR_openai_api_key='sk-your-openai-api-key'"
echo ""
echo "4. 🚀 Deploy the infrastructure:"
echo "   cd ../terraform/stacks/atlantis-ai-reviewer-dev-us-east-1"
echo "   terraform init -backend-config=backend.hcl"
echo "   terraform plan"
echo "   terraform apply"