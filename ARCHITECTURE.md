# Wild Rydes CloudFormation Architecture Diagram

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              USERS / INTERNET                            │
└──────────────────────────────────┬──────────────────────────────────────┘
                                   │
                                   │ HTTP/HTTPS
                                   │
                ┌──────────────────▼──────────────────┐
                │   Application Load Balancer (ALB)   │
                │         (Public Subnets)             │
                │    AZ1: 10.0.1.0/24                 │
                │    AZ2: 10.0.2.0/24                 │
                └──────────────────┬──────────────────┘
                                   │
                        ┌──────────┴──────────┐
                        │                     │
              ┌─────────▼────────┐  ┌────────▼─────────┐
              │  ECS Task (AZ1)   │  │  ECS Task (AZ2)  │
              │  Private Subnet   │  │  Private Subnet  │
              │  10.0.11.0/24     │  │  10.0.12.0/24    │
              │                   │  │                  │
              │  ┌─────────────┐ │  │ ┌─────────────┐  │
              │  │ Container   │ │  │ │ Container   │  │
              │  │ (Fargate)   │ │  │ │ (Fargate)   │  │
              │  └─────────────┘ │  │ └─────────────┘  │
              └─────────┬────────┘  └────────┬─────────┘
                        │                    │
                        │                    │
              ┌─────────▼────────┐  ┌────────▼─────────┐
              │  NAT Gateway 1    │  │  NAT Gateway 2   │
              │  (Public Subnet)  │  │  (Public Subnet) │
              └─────────┬────────┘  └────────┬─────────┘
                        │                    │
                        └──────────┬─────────┘
                                   │
                        ┌──────────▼──────────┐
                        │  Internet Gateway    │
                        └─────────────────────┘
```

## CI/CD Pipeline Flow

```
┌──────────────┐
│   GitHub     │
│  Repository  │
└──────┬───────┘
       │
       │ Webhook on Push
       │
┌──────▼────────────────────────────────────────────────────────────┐
│                         CodePipeline                               │
│                                                                    │
│  ┌────────────┐      ┌────────────┐      ┌────────────┐         │
│  │   Source   │─────▶│   Build    │─────▶│   Deploy   │         │
│  │  (GitHub)  │      │(CodeBuild) │      │   (ECS)    │         │
│  └────────────┘      └─────┬──────┘      └────────────┘         │
│                            │                                      │
│                            │                                      │
│                      ┌─────▼──────┐                              │
│                      │   Docker   │                              │
│                      │   Build    │                              │
│                      └─────┬──────┘                              │
│                            │                                      │
│                      ┌─────▼──────┐                              │
│                      │    ECR     │                              │
│                      │   Push     │                              │
│                      └────────────┘                              │
└───────────────────────────────────────────────────────────────────┘
       │                    │                    │
       │                    │                    │
       ▼                    ▼                    ▼
┌──────────────┐   ┌──────────────┐    ┌──────────────┐
│ CloudWatch   │   │ CloudWatch   │    │ CloudWatch   │
│   Alarm:     │   │   Alarm:     │    │   Alarm:     │
│  Pipeline    │   │    Build     │    │  Deployment  │
│   Failure    │   │   Success    │    │   Success    │
└──────┬───────┘   └──────┬───────┘    └──────┬───────┘
       │                  │                    │
       └──────────────────┼────────────────────┘
                          │
                   ┌──────▼──────┐
                   │  SNS Topic  │
                   │   (Email)   │
                   └─────────────┘
```

## VPC Network Layout

```
┌─────────────────────────────────────────────────────────────────────┐
│                          VPC (10.0.0.0/16)                          │
│                                                                     │
│  ┌───────────────────────────┐  ┌───────────────────────────┐     │
│  │   Availability Zone 1     │  │   Availability Zone 2     │     │
│  │                           │  │                           │     │
│  │  ┌─────────────────────┐ │  │  ┌─────────────────────┐ │     │
│  │  │  Public Subnet      │ │  │  │  Public Subnet      │ │     │
│  │  │  10.0.1.0/24        │ │  │  │  10.0.2.0/24        │ │     │
│  │  │                     │ │  │  │                     │ │     │
│  │  │  ┌──────────────┐  │ │  │  │  ┌──────────────┐  │ │     │
│  │  │  │     ALB      │  │ │  │  │  │     ALB      │  │ │     │
│  │  │  └──────────────┘  │ │  │  │  └──────────────┘  │ │     │
│  │  │                     │ │  │  │                     │ │     │
│  │  │  ┌──────────────┐  │ │  │  │  ┌──────────────┐  │ │     │
│  │  │  │ NAT Gateway  │  │ │  │  │  │ NAT Gateway  │  │ │     │
│  │  │  └──────────────┘  │ │  │  │  └──────────────┘  │ │     │
│  │  └─────────────────────┘ │  │  └─────────────────────┘ │     │
│  │                           │  │                           │     │
│  │  ┌─────────────────────┐ │  │  ┌─────────────────────┐ │     │
│  │  │  Private Subnet     │ │  │  │  Private Subnet     │ │     │
│  │  │  10.0.11.0/24       │ │  │  │  10.0.12.0/24       │ │     │
│  │  │                     │ │  │  │                     │ │     │
│  │  │  ┌──────────────┐  │ │  │  │  ┌──────────────┐  │ │     │
│  │  │  │  ECS Tasks   │  │ │  │  │  │  ECS Tasks   │  │ │     │
│  │  │  │  (Fargate)   │  │ │  │  │  │  (Fargate)   │  │ │     │
│  │  │  └──────────────┘  │ │  │  │  └──────────────┘  │ │     │
│  │  └─────────────────────┘ │  │  └─────────────────────┘ │     │
│  └───────────────────────────┘  └───────────────────────────┘     │
│                                                                     │
│  Internet Gateway                                                  │
│  └────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

## Resource Relationships

```
ECS Cluster
    │
    ├─── ECS Service
    │       │
    │       ├─── Task Definition
    │       │       │
    │       │       └─── Container Definition
    │       │               │
    │       │               ├─── ECR Image
    │       │               └─── CloudWatch Logs
    │       │
    │       ├─── Auto Scaling
    │       │       │
    │       │       └─── Target Tracking Policy (CPU)
    │       │
    │       ├─── Load Balancer
    │       │       │
    │       │       ├─── Target Group
    │       │       └─── Listener (Port 80)
    │       │
    │       └─── Network Configuration
    │               │
    │               ├─── Private Subnets
    │               └─── Security Group
    │
    └─── IAM Roles
            │
            ├─── Task Execution Role
            └─── Task Role
```

## Component Details

### VPC Components
- **VPC CIDR**: 10.0.0.0/16
- **Public Subnets**: 2 (for ALB and NAT Gateways)
  - AZ1: 10.0.1.0/24
  - AZ2: 10.0.2.0/24
- **Private Subnets**: 2 (for ECS tasks)
  - AZ1: 10.0.11.0/24
  - AZ2: 10.0.12.0/24
- **Internet Gateway**: 1
- **NAT Gateways**: 2 (high availability)

### Security Groups
1. **ALB Security Group**
   - Inbound: 80 (HTTP), 443 (HTTPS) from 0.0.0.0/0
   - Outbound: All traffic

2. **ECS Security Group**
   - Inbound: Container port from ALB Security Group only
   - Outbound: All traffic

### ECS Configuration
- **Launch Type**: Fargate (serverless)
- **CPU**: 256 units (0.25 vCPU)
- **Memory**: 512 MB
- **Desired Count**: 2 tasks
- **Auto Scaling**: 2-10 tasks based on CPU (70% target)

### Load Balancer
- **Type**: Application Load Balancer
- **Scheme**: Internet-facing
- **Subnets**: Public subnets in 2 AZs
- **Health Check**: HTTP on / path

### CI/CD Components
- **Source**: GitHub with webhook
- **Build**: CodeBuild with Docker support
- **Deploy**: ECS rolling update
- **Artifacts**: S3 bucket
- **Notifications**: SNS topic with email subscription

### Monitoring
- **CloudWatch Logs**: ECS container logs
- **CloudWatch Alarms**:
  - Pipeline failures
  - Build failures/successes
  - Deployment successes
  - High CPU/Memory on ECS
  - Unhealthy targets on ALB
