# Appsmith ECS Fargate Deployment Guide

This guide provides a complete CI/CD pipeline for deploying Appsmith to AWS ECS Fargate using GitHub Actions.

## 🏗️ Architecture Overview

```
GitHub Push
    ↓
GitHub Action Workflow Triggered
    ↓
Docker Image Built (Multi-stage build)
    ↓
Pushed to AWS ECR
    ↓
ECS Task Definition Updated
    ↓
Fargate Service Rolled Out
    ↓
ALB Exposes Public URL
```

## 🛠️ Infrastructure Components

- **VPC**: Custom VPC with public and private subnets across 2 AZs
- **ECR**: Elastic Container Registry for Docker images
- **ECS**: Elastic Container Service with Fargate launch type
- **ALB**: Application Load Balancer for traffic distribution
- **CloudWatch**: Logging and monitoring
- **IAM**: Roles and policies for secure access

## 📋 Prerequisites

1. **AWS Account** with appropriate permissions
2. **GitHub Repository** with the Appsmith code
3. **Local Tools**:
   - AWS CLI v2
   - Terraform >= 1.0
   - Docker
   - Git

## 🚀 Quick Start

### Step 1: Clone and Setup

```bash
git clone <your-appsmith-repo>
cd appsmith
```

### Step 2: Configure AWS

```bash
aws configure
# Enter your AWS Access Key ID, Secret Access Key, Region, and Output format
```

### Step 3: Run Deployment Setup

```bash
./deploy-setup.sh
```

This script will:
- Create ECR repository
- Deploy infrastructure using Terraform
- Update task definitions
- Provide GitHub secrets configuration instructions

### Step 4: Configure GitHub Secrets

Add these secrets to your GitHub repository (`Settings > Secrets and variables > Actions`):

- `AWS_ACCESS_KEY_ID`: Your AWS access key
- `AWS_SECRET_ACCESS_KEY`: Your AWS secret key

### Step 5: Deploy

Push your code to trigger the GitHub Actions workflow:

```bash
git add .
git commit -m "Setup ECS deployment"
git push origin main
```

## 📁 File Structure

```
.
├── .github/workflows/deploy-to-ecs.yml    # GitHub Actions workflow
├── .aws/task-definition.json              # ECS task definition
├── terraform/main.tf                      # Infrastructure as code
├── deploy-setup.sh                        # Setup script
├── Dockerfile                             # Application container
└── deploy/                                # Existing deployment configs
```

## 🔧 Configuration

### Environment Variables

The deployment supports these environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `AWS_REGION` | `us-east-1` | AWS region for deployment |
| `ENVIRONMENT` | `staging` | Environment name |
| `APP_NAME` | `appsmith` | Application name |

### Task Definition Configuration

Edit `.aws/task-definition.json` to customize:

- CPU and memory allocation
- Environment variables
- Health checks
- Log configuration

### Terraform Variables

Customize `terraform/main.tf` variables:

```hcl
variable "aws_region" {
  default = "us-east-1"
}

variable "environment" {
  default = "staging"
}

variable "desired_count" {
  default = 1  # Number of running tasks
}
```

## 🔄 GitHub Actions Workflow

The workflow (`.github/workflows/deploy-to-ecs.yml`) includes:

1. **Build Artifacts**: Client, Server, and RTS builds
2. **Docker Build**: Multi-stage Docker build with caching
3. **ECR Push**: Tagged image push to ECR
4. **ECS Deploy**: Rolling deployment to Fargate

### Workflow Triggers

- **Push to main/master/release**: Automatic deployment
- **Manual trigger**: Via GitHub Actions UI with environment selection

### Workflow Steps

```yaml
- Checkout code
- Configure AWS credentials
- Login to ECR
- Build artifacts (if needed)
- Build and push Docker image
- Update ECS task definition
- Deploy to ECS service
- Display deployment info
```

## 🐳 Docker Configuration

The deployment uses the existing `Dockerfile` with these build args:

- `BASE`: Base image (defaults to `appsmithorg/base:release`)
- `APPSMITH_CLOUD_SERVICES_BASE_URL`
- `APPSMITH_SEGMENT_CE_KEY`

## 📊 Monitoring and Logs

### CloudWatch Logs

View application logs:

```bash
aws logs tail /ecs/appsmith --follow --region us-east-1
```

### ECS Service Status

Check service health:

```bash
aws ecs describe-services \
  --cluster appsmith-cluster \
  --services appsmith-service \
  --region us-east-1
```

### Application Health

The deployment includes health checks:
- **Health Check Path**: `/`
- **Health Check Interval**: 30 seconds
- **Health Check Timeout**: 5 seconds

## 🔧 Troubleshooting

### Common Issues

1. **Build Failures**
   - Check GitHub Actions logs
   - Verify AWS credentials
   - Ensure ECR repository exists

2. **Service Won't Start**
   - Check ECS task logs in CloudWatch
   - Verify task definition configuration
   - Check security group rules

3. **Health Check Failures**
   - Verify application starts correctly
   - Check health check endpoint
   - Review container logs

### Useful Commands

```bash
# Check ECS service status
aws ecs describe-services --cluster appsmith-cluster --services appsmith-service

# View running tasks
aws ecs list-tasks --cluster appsmith-cluster --service-name appsmith-service

# Scale service
aws ecs update-service --cluster appsmith-cluster --service appsmith-service --desired-count 2

# View application logs
aws logs describe-log-groups --log-group-name-prefix "/ecs/appsmith"

# Get ALB DNS name
aws elbv2 describe-load-balancers --names appsmith-alb --query 'LoadBalancers[0].DNSName'
```

## 🔄 Updates and Rollbacks

### Deploying Updates

1. Push code changes to trigger workflow
2. Monitor deployment in GitHub Actions
3. Verify health checks pass

### Rolling Back

```bash
# List task definition revisions
aws ecs list-task-definitions --family-prefix appsmith-task

# Rollback to previous revision
aws ecs update-service \
  --cluster appsmith-cluster \
  --service appsmith-service \
  --task-definition appsmith-task:PREVIOUS_REVISION
```

## 💰 Cost Optimization

### Fargate Pricing

- **CPU**: $0.04048 per vCPU per hour
- **Memory**: $0.004445 per GB per hour

### Optimization Tips

1. **Right-size resources**: Adjust CPU/memory based on usage
2. **Use Spot capacity**: Consider Fargate Spot for dev environments
3. **Implement auto-scaling**: Scale based on CPU/memory utilization
4. **Schedule downtime**: Stop non-prod environments during off-hours

## 🔐 Security Best Practices

1. **IAM Roles**: Use least-privilege principle
2. **Secrets Management**: Store sensitive data in AWS Secrets Manager
3. **Network Security**: Use private subnets for ECS tasks
4. **Image Scanning**: Enable ECR vulnerability scanning
5. **HTTPS**: Configure SSL/TLS termination at ALB

## 📚 Additional Resources

- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Appsmith Documentation](https://docs.appsmith.com/)

## 🆘 Support

For issues related to:
- **Infrastructure**: Check Terraform state and AWS console
- **CI/CD**: Review GitHub Actions workflow logs
- **Application**: Consult Appsmith documentation

## 📜 License

This deployment configuration follows the same license as the Appsmith project.
