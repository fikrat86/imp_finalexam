# Deployment Checklist for Wild Rydes Infrastructure

## Pre-Deployment

- [ ] AWS Account configured with appropriate permissions
- [ ] AWS CLI installed and configured
- [ ] GitHub repository created with application code
- [ ] GitHub Personal Access Token generated with required permissions:
  - `repo` scope
  - `admin:repo_hook` scope
- [ ] Email address ready for notifications
- [ ] Dockerfile exists in GitHub repository
- [ ] Application code ready to deploy

## Configuration

- [ ] Review `wild-rydes-infrastructure.yaml` template
- [ ] Update `parameters-example.json` with your values:
  - [ ] GitHubRepo (format: username/repository-name)
  - [ ] GitHubToken (your personal access token)
  - [ ] NotificationEmail (your email address)
  - [ ] Adjust other parameters as needed (CPU, memory, scaling, etc.)

## Deployment Steps

- [ ] Validate CloudFormation template:
  ```bash
  aws cloudformation validate-template --template-body file://wild-rydes-infrastructure.yaml
  ```

- [ ] Deploy the stack:
  ```bash
  aws cloudformation create-stack \
    --stack-name wild-rydes-infrastructure \
    --template-body file://wild-rydes-infrastructure.yaml \
    --parameters file://parameters-example.json \
    --capabilities CAPABILITY_NAMED_IAM \
    --region us-east-1
  ```

- [ ] Monitor deployment progress:
  ```bash
  aws cloudformation describe-stack-events --stack-name wild-rydes-infrastructure
  ```

- [ ] Wait for stack creation to complete (approximately 15-20 minutes)

## Post-Deployment

- [ ] Confirm SNS subscription email
- [ ] Retrieve ECR repository URI from stack outputs
- [ ] Build initial Docker image locally
- [ ] Push initial image to ECR:
  ```bash
  aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <ECR_URI>
  docker build -t wild-rydes-app .
  docker tag wild-rydes-app:latest <ECR_URI>:latest
  docker push <ECR_URI>:latest
  ```

- [ ] Force new ECS deployment to start tasks:
  ```bash
  aws ecs update-service --cluster WildRydes-Cluster --service WildRydes-Service --force-new-deployment
  ```

- [ ] Retrieve Load Balancer URL from stack outputs
- [ ] Test application by accessing ALB URL in browser
- [ ] Verify ECS tasks are running
- [ ] Test CI/CD pipeline by pushing a change to GitHub

## Verification

- [ ] Application accessible via Load Balancer URL
- [ ] ECS service shows desired number of running tasks
- [ ] CloudWatch Logs showing application logs
- [ ] CodePipeline successfully triggered by GitHub push
- [ ] Email notifications received for pipeline events
- [ ] Auto-scaling configured correctly
- [ ] Health checks passing on target group

## Resources Created

The CloudFormation stack creates the following resources:

### Networking (13 resources)
- [ ] VPC
- [ ] Internet Gateway
- [ ] 2 Public Subnets
- [ ] 2 Private Subnets
- [ ] 2 NAT Gateways
- [ ] 2 Elastic IPs
- [ ] 3 Route Tables
- [ ] 4 Route Table Associations

### Security (2 resources)
- [ ] ALB Security Group
- [ ] ECS Security Group

### Load Balancing (3 resources)
- [ ] Application Load Balancer
- [ ] Target Group
- [ ] ALB Listener

### ECS (6 resources)
- [ ] ECS Cluster
- [ ] Task Definition
- [ ] ECS Service
- [ ] CloudWatch Log Group
- [ ] Auto Scaling Target
- [ ] Auto Scaling Policy

### Container Registry (1 resource)
- [ ] ECR Repository

### CI/CD (6 resources)
- [ ] CodePipeline
- [ ] CodeBuild Project
- [ ] S3 Artifact Bucket
- [ ] CodePipeline Service Role
- [ ] CodeBuild Service Role
- [ ] GitHub Webhook (created automatically)

### IAM (4 resources)
- [ ] ECS Task Execution Role
- [ ] ECS Task Role
- [ ] CodeBuild Service Role
- [ ] CodePipeline Service Role

### Monitoring (8 resources)
- [ ] SNS Topic
- [ ] SNS Subscription
- [ ] Pipeline Failure Alarm
- [ ] Build Failure Alarm
- [ ] Build Success Alarm
- [ ] Deployment Success Alarm
- [ ] ECS CPU Alarm
- [ ] ECS Memory Alarm
- [ ] ALB Unhealthy Target Alarm

**Total: ~43 AWS Resources**

## Troubleshooting

### Stack Creation Fails
- [ ] Check CloudFormation events for specific error
- [ ] Verify IAM permissions
- [ ] Check service quotas/limits
- [ ] Ensure unique stack name

### No Initial Image in ECR
- [ ] Build and push initial image manually
- [ ] Update ECS service to force new deployment

### Pipeline Not Triggering
- [ ] Verify GitHub token permissions
- [ ] Check webhook in GitHub repository settings
- [ ] Verify repository and branch names in parameters

### ECS Tasks Not Starting
- [ ] Check ECS service events
- [ ] Verify task definition is valid
- [ ] Check CloudWatch logs for errors
- [ ] Verify security group rules
- [ ] Ensure NAT Gateway allows outbound traffic

### Application Not Accessible
- [ ] Verify ALB is active
- [ ] Check target group health checks
- [ ] Verify security group allows inbound traffic on port 80
- [ ] Check if tasks are registered with target group

## Cleanup Procedure

When finished testing:

- [ ] Empty S3 artifact bucket
- [ ] Delete ECR images
- [ ] Delete CloudFormation stack:
  ```bash
  aws cloudformation delete-stack --stack-name wild-rydes-infrastructure
  ```
- [ ] Wait for complete deletion
- [ ] Verify all resources removed
- [ ] Check for any remaining resources (EIPs, etc.)

## Cost Management

Estimated costs while stack is running:
- ECS Fargate: ~$30-50/month (2 tasks)
- ALB: ~$20-25/month
- NAT Gateways: ~$65-70/month (2 gateways)
- Other services: ~$10-15/month

**Total estimated: $125-160/month**

To minimize costs:
- [ ] Delete stack when not in use
- [ ] Consider single NAT Gateway for dev/test
- [ ] Reduce desired task count
- [ ] Use smaller task sizes

## Notes

- Stack creation takes approximately 15-20 minutes
- NAT Gateways are the most expensive component
- First deployment requires manual image push to ECR
- Subsequent deployments are fully automated via pipeline
- SNS email confirmation required for notifications
