# Wild Rydes Infrastructure as Code - CloudFormation

This repository contains AWS CloudFormation templates for deploying the complete Wild Rydes infrastructure with ECS Fargate and CI/CD pipeline.

## Architecture Overview

The infrastructure includes:

### Networking
- **VPC** with CIDR 10.0.0.0/16
- **2 Public Subnets** (10.0.1.0/24, 10.0.2.0/24) across two Availability Zones for the ALB
- **2 Private Subnets** (10.0.11.0/24, 10.0.12.0/24) across two Availability Zones for ECS tasks
- **Internet Gateway** for public internet access
- **2 NAT Gateways** (one per AZ) for private subnet internet access
- **Route Tables** configured for public and private subnets

### Application Load Balancer
- Internet-facing Application Load Balancer in public subnets
- Target Group for ECS service
- HTTP listener on port 80
- Health checks configured for container monitoring

### ECS Infrastructure
- **ECS Fargate Cluster** with Container Insights enabled
- **ECS Service** running in private subnets
- **Task Definition** with 256 CPU units and 512 MB memory
- **Auto Scaling** based on CPU utilization (70% target)
- Scales between 2-10 tasks based on load

### Container Registry
- **ECR Repository** with image scanning on push
- Lifecycle policy to keep last 10 images

### CI/CD Pipeline
- **CodePipeline** with three stages:
  1. **Source**: GitHub integration
  2. **Build**: CodeBuild project to build and push Docker images
  3. **Deploy**: Automated ECS service update
- **CodeBuild Project** with Docker support
- **S3 Bucket** for pipeline artifacts

### Monitoring & Notifications
- **SNS Topic** for pipeline notifications
- **CloudWatch Alarms**:
  - Pipeline execution failures
  - Build failures
  - Build successes
  - Deployment successes
  - High CPU utilization on ECS service
  - High memory utilization on ECS service
  - Unhealthy ALB targets

### Security
- **IAM Roles**:
  - ECS Task Execution Role
  - ECS Task Role
  - CodeBuild Service Role
  - CodePipeline Service Role
- **Security Groups**:
  - ALB Security Group (HTTP/HTTPS from internet)
  - ECS Security Group (traffic only from ALB)
- **S3 Bucket** encryption and public access blocking

## Prerequisites

Before deploying this stack, ensure you have:

1. **AWS Account** with appropriate permissions
2. **AWS CLI** installed and configured
3. **GitHub Repository** with your application code and Dockerfile
4. **GitHub Personal Access Token** with `repo` and `admin:repo_hook` permissions
5. **Email address** for receiving notifications

## Parameters

The CloudFormation template accepts the following parameters:

| Parameter | Description | Default |
|-----------|-------------|---------|
| EnvironmentName | Environment name prefix for resources | WildRydes |
| GitHubRepo | GitHub repository (format: username/repo-name) | wildrydes/application |
| GitHubBranch | GitHub branch to track | main |
| GitHubToken | GitHub personal access token | (required) |
| ContainerPort | Port the container listens on | 80 |
| DesiredCount | Desired number of ECS tasks | 2 |
| MinContainers | Minimum number of containers for auto-scaling | 2 |
| MaxContainers | Maximum number of containers for auto-scaling | 10 |
| AutoScalingTargetCPU | Target CPU utilization for auto-scaling | 70 |
| NotificationEmail | Email for pipeline notifications | admin@wildrydes.com |

## Deployment Instructions

### Option 1: Deploy via AWS CLI

1. **Clone this repository**:
   ```bash
   git clone <repository-url>
   cd imp_finalexam
   ```

2. **Update the parameters file** (`parameters-example.json`) with your values:
   - Replace `your-username/wild-rydes-app` with your GitHub repository
   - Replace `your-github-personal-access-token` with your actual token
   - Replace `your-email@example.com` with your email address

3. **Validate the template**:
   ```bash
   aws cloudformation validate-template --template-body file://wild-rydes-infrastructure.yaml
   ```

4. **Deploy the stack**:
   ```bash
   aws cloudformation create-stack \
     --stack-name wild-rydes-infrastructure \
     --template-body file://wild-rydes-infrastructure.yaml \
     --parameters file://parameters-example.json \
     --capabilities CAPABILITY_NAMED_IAM \
     --region us-east-1
   ```

5. **Monitor the deployment**:
   ```bash
   aws cloudformation describe-stacks \
     --stack-name wild-rydes-infrastructure \
     --query 'Stacks[0].StackStatus' \
     --region us-east-1
   ```

   Or watch events in real-time:
   ```bash
   aws cloudformation describe-stack-events \
     --stack-name wild-rydes-infrastructure \
     --region us-east-1
   ```

### Option 2: Deploy via AWS Console

1. Navigate to **CloudFormation** in the AWS Console
2. Click **Create Stack** → **With new resources**
3. Upload the `wild-rydes-infrastructure.yaml` template
4. Fill in the parameters:
   - Stack name: `wild-rydes-infrastructure`
   - Provide all required parameters
5. On the **Configure stack options** page, add tags if desired
6. On the **Review** page, check **"I acknowledge that AWS CloudFormation might create IAM resources with custom names"**
7. Click **Create stack**

## Post-Deployment Steps

### 1. Confirm SNS Subscription
After deployment, you'll receive an email to confirm the SNS subscription. Click the confirmation link to receive pipeline notifications.

### 2. Push Initial Image to ECR
Before the pipeline can deploy, you need an initial image in ECR:

```bash
# Get ECR repository URI from stack outputs
ECR_URI=$(aws cloudformation describe-stacks \
  --stack-name wild-rydes-infrastructure \
  --query 'Stacks[0].Outputs[?OutputKey==`ECRRepositoryURI`].OutputValue' \
  --output text)

# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_URI

# Build and push initial image (from your application directory)
docker build -t wild-rydes-app .
docker tag wild-rydes-app:latest $ECR_URI:latest
docker push $ECR_URI:latest
```

### 3. Trigger Initial Deployment
Once the image is in ECR, update the ECS service to start the tasks:

```bash
aws ecs update-service \
  --cluster WildRydes-Cluster \
  --service WildRydes-Service \
  --force-new-deployment \
  --region us-east-1
```

### 4. Access Your Application
Get the Load Balancer URL from stack outputs:

```bash
aws cloudformation describe-stacks \
  --stack-name wild-rydes-infrastructure \
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerURL`].OutputValue' \
  --output text
```

Access your application at the displayed URL.

## CI/CD Pipeline Flow

1. **Developer pushes code** to the GitHub repository
2. **CodePipeline detects** the change and starts execution
3. **Source stage** pulls the latest code from GitHub
4. **Build stage**:
   - CodeBuild pulls the source code
   - Builds Docker image using the Dockerfile
   - Pushes image to ECR with commit hash tag
   - Creates `imagedefinitions.json` file
5. **Deploy stage**:
   - Updates ECS service with new task definition
   - ECS performs rolling update of containers
6. **CloudWatch Alarms** notify via SNS on success or failure

## Application Requirements

Your GitHub repository must include:

### Dockerfile
Example Dockerfile for a simple web application:

```dockerfile
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

### Sample Application Code
Example `index.html`:

```html
<!DOCTYPE html>
<html>
<head>
    <title>Wild Rydes</title>
</head>
<body>
    <h1>Welcome to Wild Rydes!</h1>
    <p>Your unicorn ride-sharing service.</p>
</body>
</html>
```

## Monitoring and Troubleshooting

### View Logs
ECS task logs are available in CloudWatch Logs:
```bash
aws logs tail /ecs/WildRydes --follow --region us-east-1
```

### Check Pipeline Status
```bash
aws codepipeline get-pipeline-state --name WildRydes-Pipeline --region us-east-1
```

### View ECS Service Status
```bash
aws ecs describe-services \
  --cluster WildRydes-Cluster \
  --services WildRydes-Service \
  --region us-east-1
```

### Check Auto Scaling Activity
```bash
aws application-autoscaling describe-scaling-activities \
  --service-namespace ecs \
  --region us-east-1
```

## Cleanup

To delete all resources:

```bash
# Empty the S3 bucket first
BUCKET_NAME=$(aws cloudformation describe-stack-resources \
  --stack-name wild-rydes-infrastructure \
  --query 'StackResources[?ResourceType==`AWS::S3::Bucket`].PhysicalResourceId' \
  --output text)

aws s3 rm s3://$BUCKET_NAME --recursive

# Delete ECR images
aws ecr batch-delete-image \
  --repository-name wildrydes-app \
  --image-ids imageTag=latest \
  --region us-east-1

# Delete the CloudFormation stack
aws cloudformation delete-stack \
  --stack-name wild-rydes-infrastructure \
  --region us-east-1

# Wait for deletion to complete
aws cloudformation wait stack-delete-complete \
  --stack-name wild-rydes-infrastructure \
  --region us-east-1
```

## Cost Considerations

This infrastructure will incur AWS charges:

- **ECS Fargate**: Based on vCPU and memory allocated
- **Application Load Balancer**: Hourly charge + LCU usage
- **NAT Gateways**: Hourly charge + data processing (2 NAT Gateways)
- **ECR**: Storage for container images
- **S3**: Storage for pipeline artifacts
- **CloudWatch**: Logs storage and custom metrics
- **Data Transfer**: Outbound data transfer costs

Estimated monthly cost: $100-$200 depending on traffic and usage.

## Stack Outputs

After successful deployment, the stack provides these outputs:

- **VPCId**: VPC identifier
- **LoadBalancerURL**: Application URL
- **ECRRepositoryURI**: Docker image repository URI
- **ECSClusterName**: ECS cluster name
- **ECSServiceName**: ECS service name
- **CodePipelineName**: Pipeline name
- **SNSTopicArn**: SNS topic for notifications

## Security Best Practices

This template implements:

✅ Private subnets for application containers  
✅ Security groups with least privilege access  
✅ IAM roles with minimal permissions  
✅ Encrypted S3 bucket for artifacts  
✅ VPC with proper network segmentation  
✅ Container insights enabled for monitoring  
✅ Image scanning enabled on ECR  

## Customization

To customize the infrastructure:

1. **Change container resources**: Modify `Cpu` and `Memory` in `ECSTaskDefinition`
2. **Add environment variables**: Update `ContainerDefinitions` in `ECSTaskDefinition`
3. **Change scaling thresholds**: Modify `AutoScalingTargetCPU` parameter or scaling policy
4. **Add HTTPS**: Add ACM certificate and HTTPS listener to ALB
5. **Multi-region**: Create stacks in multiple regions with Route 53 for global distribution

## Support

For issues or questions:
- Review CloudFormation stack events for deployment errors
- Check CloudWatch Logs for application errors
- Review CodeBuild logs for build failures
- Ensure GitHub token has correct permissions

## License

This template is provided as-is for educational purposes.
