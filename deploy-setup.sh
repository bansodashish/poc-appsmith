#!/bin/bash

# Appsmith ECS Deployment Script
# This script sets up the complete infrastructure and deployment pipeline

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION=${AWS_REGION:-"us-east-1"}
ENVIRONMENT=${ENVIRONMENT:-"staging"}
APP_NAME=${APP_NAME:-"appsmith"}
GITHUB_REPO=${GITHUB_REPO:-"$(git config --get remote.origin.url | sed 's/.*[\/:]([^\/]*\/[^\/]*).git/\1/')"}

echo -e "${BLUE}🚀 Starting Appsmith ECS Deployment Setup${NC}"
echo -e "${BLUE}===========================================${NC}"

# Function to print status
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    echo -e "${BLUE}🔍 Checking prerequisites...${NC}"
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install it first."
        exit 1
    fi
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install it first."
        exit 1
    fi
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir &> /dev/null; then
        print_error "Not in a git repository. Please run this from the project root."
        exit 1
    fi
    
    print_status "All prerequisites are met"
}

# Configure AWS credentials
configure_aws() {
    echo -e "${BLUE}🔐 Configuring AWS...${NC}"
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_warning "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    print_status "Connected to AWS Account: $AWS_ACCOUNT_ID"
}

# Create ECR repository if it doesn't exist
create_ecr_repository() {
    echo -e "${BLUE}📦 Setting up ECR repository...${NC}"
    
    if aws ecr describe-repositories --repository-names $APP_NAME --region $AWS_REGION &> /dev/null; then
        print_status "ECR repository '$APP_NAME' already exists"
    else
        aws ecr create-repository \
            --repository-name $APP_NAME \
            --region $AWS_REGION \
            --image-scanning-configuration scanOnPush=true
        print_status "ECR repository '$APP_NAME' created"
    fi
    
    ECR_URI=$(aws ecr describe-repositories --repository-names $APP_NAME --region $AWS_REGION --query 'repositories[0].repositoryUri' --output text)
    print_status "ECR Repository URI: $ECR_URI"
}

# Deploy infrastructure with Terraform
deploy_infrastructure() {
    echo -e "${BLUE}🏗️  Deploying infrastructure with Terraform...${NC}"
    
    cd terraform
    
    # Initialize Terraform
    terraform init
    
    # Plan the deployment
    terraform plan \
        -var="aws_region=$AWS_REGION" \
        -var="environment=$ENVIRONMENT" \
        -var="app_name=$APP_NAME"
    
    # Apply the configuration
    terraform apply \
        -var="aws_region=$AWS_REGION" \
        -var="environment=$ENVIRONMENT" \
        -var="app_name=$APP_NAME" \
        -auto-approve
    
    # Get outputs
    ALB_DNS=$(terraform output -raw alb_dns_name)
    ECS_CLUSTER=$(terraform output -raw ecs_cluster_name)
    ECS_SERVICE=$(terraform output -raw ecs_service_name)
    
    cd ..
    
    print_status "Infrastructure deployed successfully"
    print_status "ALB DNS: $ALB_DNS"
    print_status "ECS Cluster: $ECS_CLUSTER"
    print_status "ECS Service: $ECS_SERVICE"
}

# Update task definition with correct account ID
update_task_definition() {
    echo -e "${BLUE}📝 Updating task definition...${NC}"
    
    # Replace ACCOUNT_ID placeholder in task definition
    sed -i.bak "s/ACCOUNT_ID/$AWS_ACCOUNT_ID/g" .aws/task-definition.json
    
    print_status "Task definition updated with account ID: $AWS_ACCOUNT_ID"
}

# Setup GitHub Secrets
setup_github_secrets() {
    echo -e "${BLUE}🔑 Setting up GitHub Secrets...${NC}"
    
    print_warning "Please add the following secrets to your GitHub repository:"
    echo -e "${YELLOW}Repository Settings > Secrets and variables > Actions > New repository secret${NC}"
    echo ""
    echo "AWS_ACCESS_KEY_ID: Your AWS access key ID"
    echo "AWS_SECRET_ACCESS_KEY: Your AWS secret access key"
    echo ""
    print_warning "Make sure your AWS user has the following permissions:"
    echo "- AmazonEC2ContainerRegistryPowerUser"
    echo "- AmazonECS_FullAccess"
    echo "- AmazonEC2ContainerServiceTaskRole"
    echo "- AmazonECSTaskExecutionRolePolicy"
}

# Build and push initial image
build_and_push_initial_image() {
    echo -e "${BLUE}🐳 Building and pushing initial Docker image...${NC}"
    
    # Login to ECR
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_URI
    
    # Build the image (assuming we have the necessary artifacts)
    if [ -f "Dockerfile" ]; then
        docker build -t $APP_NAME:latest --build-arg BASE=appsmithorg/base:release .
        docker tag $APP_NAME:latest $ECR_URI:latest
        docker push $ECR_URI:latest
        print_status "Initial image pushed to ECR"
    else
        print_warning "Dockerfile not found. Skipping initial image build."
        print_warning "The GitHub Actions workflow will build and push the image on the next commit."
    fi
}

# Main execution
main() {
    check_prerequisites
    configure_aws
    create_ecr_repository
    update_task_definition
    deploy_infrastructure
    setup_github_secrets
    build_and_push_initial_image
    
    echo -e "${GREEN}🎉 Deployment setup completed successfully!${NC}"
    echo -e "${GREEN}===============================================${NC}"
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo "1. Add AWS credentials to GitHub Secrets"
    echo "2. Push your code to trigger the GitHub Actions workflow"
    echo "3. Monitor the deployment in GitHub Actions"
    echo "4. Access your application at: http://$ALB_DNS"
    echo ""
    echo -e "${BLUE}Useful Commands:${NC}"
    echo "- Monitor ECS service: aws ecs describe-services --cluster $ECS_CLUSTER --services $ECS_SERVICE"
    echo "- View logs: aws logs tail /ecs/$APP_NAME --follow"
    echo "- Scale service: aws ecs update-service --cluster $ECS_CLUSTER --service $ECS_SERVICE --desired-count <count>"
}

# Run main function
main "$@"
