# EKS Auto Mode Terraform Infrastructure

This repository contains production-ready Terraform code to deploy an Amazon EKS cluster with Auto Mode enabled on AWS.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Post-Deployment](#post-deployment)
- [Cost Optimization](#cost-optimization)
- [Security Best Practices](#security-best-practices)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)

## 🎯 Overview

This Terraform configuration creates a complete, production-ready EKS infrastructure with:

- **EKS Cluster** with Kubernetes version 1.34
- **Auto Mode Enabled** - Fully managed compute capacity
- **High Availability** - Multi-AZ deployment
- **Security** - Encryption, VPC isolation, security groups
- **Monitoring** - CloudWatch logs, Container Insights
- **Networking** - Custom VPC, public/private subnets, NAT gateways

### What is EKS Auto Mode?

EKS Auto Mode is a fully managed compute option that:
- Automatically provisions and manages worker nodes
- Selects optimal instance types based on pod requirements
- Handles node scaling, upgrades, and lifecycle
- Reduces operational overhead significantly

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          AWS REGION                              │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                         VPC                               │   │
│  │  ┌─────────────────┐  ┌─────────────────┐               │   │
│  │  │  Public Subnet  │  │  Public Subnet  │  (Multi-AZ)   │   │
│  │  │   NAT Gateway   │  │   NAT Gateway   │               │   │
│  │  └────────┬────────┘  └────────┬────────┘               │   │
│  │           │                     │                         │   │
│  │  ┌────────▼────────┐  ┌────────▼────────┐               │   │
│  │  │ Private Subnet  │  │ Private Subnet  │               │   │
│  │  │  EKS Nodes      │  │  EKS Nodes      │               │   │
│  │  │  (Auto Mode)    │  │  (Auto Mode)    │               │   │
│  │  └─────────────────┘  └─────────────────┘               │   │
│  │                                                           │   │
│  │  ┌───────────────────────────────────────────────────┐   │   │
│  │  │          EKS Control Plane (Managed)              │   │   │
│  │  │  - API Server  - Scheduler  - Controller Manager │   │   │
│  │  └───────────────────────────────────────────────────┘   │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  CloudWatch Logs │ KMS Encryption │ IAM Roles            │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## ✅ Prerequisites

### Required Tools

1. **AWS CLI** (v2.x or later)
   ```bash
   aws --version
   ```

2. **Terraform** (v1.0 or later)
   ```bash
   terraform --version
   ```

3. **kubectl** (matching your Kubernetes version)
   ```bash
   kubectl version --client
   ```

### AWS Account Setup

1. **AWS Account**: Fresh AWS account (as mentioned)
2. **IAM Permissions**: Administrator access or permissions to create:
   - VPC and networking resources
   - EKS clusters
   - IAM roles and policies
   - KMS keys
   - CloudWatch logs
   - EC2 instances

3. **AWS Credentials**: Configure AWS CLI
   ```bash
   aws configure
   ```

## 🚀 Quick Start

### Step 1: Clone the Repository

```bash
git clone <repository-url>
cd eks-auto-mode-terraform
```

### Step 2: Review and Customize Variables

Edit `terraform.tfvars` to customize your deployment:

```bash
# Open in your preferred editor
nano terraform.tfvars
```

**Important customizations:**

- `aws_region`: Choose your preferred region
- `cluster_endpoint_public_access_cidrs`: **IMPORTANT** - Restrict to your IP ranges
- `single_nat_gateway`: Set to `true` for cost savings in non-production
- `availability_zones`: Adjust based on your region

### Step 3: Initialize Terraform

```bash
terraform init
```

This command:
- Downloads required providers (AWS, TLS, Random)
- Initializes the backend
- Prepares the working directory

### Step 4: Review the Plan

```bash
terraform plan
```

This shows what resources will be created. Review carefully!

### Step 5: Apply the Configuration

```bash
terraform apply
```

Type `yes` when prompted. Deployment takes approximately **15-20 minutes**.

## ⚙️ Configuration

### File Structure

```
eks-auto-mode-terraform/
├── versions.tf              # Terraform and provider versions
├── provider.tf              # AWS provider configuration
├── variables.tf             # Variable definitions
├── terraform.tfvars         # Variable values (customize this!)
├── vpc.tf                   # VPC, subnets, NAT gateways
├── iam.tf                   # IAM roles and policies
├── security-groups.tf       # Security groups
├── eks-cluster.tf           # EKS cluster and addons
├── outputs.tf               # Output values
└── README.md                # This file
```

### Key Variables

| Variable | Description | Default | Production Value |
|----------|-------------|---------|------------------|
| `aws_region` | AWS region | `us-west-2` | Your choice |
| `cluster_name` | EKS cluster name | `production-eks-auto` | Customize |
| `kubernetes_version` | Kubernetes version | `1.34` | Keep updated |
| `single_nat_gateway` | Use single NAT | `false` | `false` (HA) |
| `cluster_endpoint_public_access_cidrs` | API access CIDRs | `["0.0.0.0/0"]` | **Restrict this!** |
| `enable_cluster_encryption` | Encrypt secrets | `true` | `true` |

### Environment-Specific Configurations

#### Development
```hcl
environment        = "development"
single_nat_gateway = true  # Cost saving
cluster_log_retention_days = 7
```

#### Production
```hcl
environment        = "production"
single_nat_gateway = false  # High availability
cluster_log_retention_days = 30
```

## 📦 Deployment

### Step-by-Step Deployment

1. **Initialize Terraform**
   ```bash
   terraform init
   ```

2. **Validate Configuration**
   ```bash
   terraform validate
   ```

3. **Plan Deployment**
   ```bash
   terraform plan -out=tfplan
   ```

4. **Apply Configuration**
   ```bash
   terraform apply tfplan
   ```

5. **Save Outputs**
   ```bash
   terraform output > outputs.txt
   ```

### Expected Resources Created

The deployment creates approximately **60+ resources**:

- 1 VPC
- 6 Subnets (3 public, 3 private)
- 3 NAT Gateways (or 1 if single_nat_gateway=true)
- 1 Internet Gateway
- Multiple Route Tables
- 1 EKS Cluster
- 4 EKS Addons
- Multiple IAM Roles and Policies
- Security Groups
- CloudWatch Log Groups
- KMS Key
- OIDC Provider

## 🔧 Post-Deployment

### Configure kubectl

```bash
aws eks update-kubeconfig --region us-west-2 --name production-eks-auto
```

### Verify Cluster Access

```bash
# Check cluster info
kubectl cluster-info

# List nodes (Auto Mode manages these)
kubectl get nodes

# Check system pods
kubectl get pods -A

# Verify addons
kubectl get pods -n kube-system
```

### Deploy Sample Application

```bash
# Create a deployment
kubectl create deployment nginx --image=nginx

# Expose as LoadBalancer
kubectl expose deployment nginx --port=80 --type=LoadBalancer

# Get LoadBalancer URL
kubectl get svc nginx
```

### Monitor Auto Mode

Auto Mode automatically:
- Provisions nodes when pods are pending
- Scales down underutilized nodes
- Selects optimal instance types

```bash
# Watch Auto Mode in action
kubectl get nodes -w

# Create a pod and watch node provisioning
kubectl run test-pod --image=nginx
kubectl get pods -w
```

## 💰 Cost Optimization

### Cost Components

1. **EKS Control Plane**: $0.10/hour (~$73/month)
2. **EC2 Instances (Auto Mode)**: Pay for actual compute used
3. **NAT Gateways**: ~$0.045/hour per NAT (~$32/month each)
4. **EBS Volumes**: ~$0.10/GB-month
5. **Data Transfer**: Varies based on usage

### Cost Saving Tips

#### For Non-Production

```hcl
# Use single NAT Gateway
single_nat_gateway = true  # Saves ~$64/month

# Reduce log retention
cluster_log_retention_days = 7

# Use smaller instance types (Auto Mode handles this)
```

#### For All Environments

- Use Auto Mode's automatic scaling (it's efficient!)
- Set up AWS Budgets and alerts
- Use Spot instances for fault-tolerant workloads
- Clean up unused Load Balancers and EBS volumes
- Enable Cost Explorer and analyze spending

### Monthly Cost Estimate (Production)

| Component | Cost |
|-----------|------|
| EKS Control Plane | $73 |
| NAT Gateways (3) | $96 |
| EC2 Instances (Auto Mode) | $200-500 (varies) |
| EBS Volumes | $50-100 |
| Data Transfer | $50-100 |
| **Total** | **$469-869/month** |

*Note: Actual costs vary based on workload and usage*

## 🔒 Security Best Practices

### Implemented Security Features

✅ **Network Isolation**
- Private subnets for nodes
- Public subnets for load balancers only
- Security groups with least privilege

✅ **Encryption**
- Secrets encrypted with KMS
- Encrypted EBS volumes
- HTTPS/TLS for all communications

✅ **Access Control**
- IAM roles with least privilege
- IRSA (IAM Roles for Service Accounts)
- Restricted API endpoint access

✅ **Logging & Monitoring**
- Control plane logs to CloudWatch
- VPC Flow Logs enabled
- Container Insights available

### Additional Hardening Steps

1. **Restrict API Access**
   ```hcl
   # In terraform.tfvars
   cluster_endpoint_public_access_cidrs = ["YOUR_OFFICE_IP/32"]
   ```

2. **Enable Pod Security Standards**
   ```bash
   # Apply pod security policies
   kubectl label namespace default pod-security.kubernetes.io/enforce=restricted
   ```

3. **Implement Network Policies**
   ```bash
   # Install Calico or use AWS VPC CNI network policies
   kubectl apply -f network-policies/
   ```

4. **Enable AWS GuardDuty**
   ```bash
   aws guardduty create-detector --enable
   ```

5. **Set up AWS Security Hub**
   ```bash
   aws securityhub enable-security-hub
   ```

## 🐛 Troubleshooting

### Common Issues

#### 1. Insufficient Permissions

**Error**: "User is not authorized to perform..."

**Solution**:
```bash
# Check your AWS identity
aws sts get-caller-identity

# Ensure you have admin permissions or required policies
```

#### 2. Quota Limits

**Error**: "You have reached your quota for..."

**Solution**:
```bash
# Check service quotas
aws service-quotas list-service-quotas --service-code eks

# Request quota increase
aws service-quotas request-service-quota-increase \
  --service-code eks \
  --quota-code L-1194D53C \
  --desired-value 50
```

#### 3. kubectl Connection Issues

**Error**: "Unable to connect to the server..."

**Solution**:
```bash
# Reconfigure kubectl
aws eks update-kubeconfig --region us-west-2 --name production-eks-auto

# Verify AWS credentials
aws sts get-caller-identity

# Check cluster status
aws eks describe-cluster --name production-eks-auto --region us-west-2
```

#### 4. Nodes Not Appearing

**Issue**: No nodes showing in `kubectl get nodes`

**Solution**:
```bash
# Check Auto Mode status
aws eks describe-cluster --name production-eks-auto \
  --query 'cluster.computeConfig' --region us-west-2

# Look for pending pods (Auto Mode provisions nodes for them)
kubectl get pods -A

# Check CloudWatch logs
aws logs tail /aws/eks/production-eks-auto/cluster --follow
```

### Getting Help

- **AWS Support**: If you have AWS support plan
- **AWS Forums**: https://forums.aws.amazon.com/
- **EKS Documentation**: https://docs.aws.amazon.com/eks/
- **GitHub Issues**: Create an issue in this repository

## 🧹 Cleanup

### Destroy Resources

**WARNING**: This will delete everything!

```bash
# Delete all Kubernetes resources first
kubectl delete all --all --all-namespaces

# Wait for LoadBalancers and EBS volumes to be deleted
# (Check AWS Console: EC2 > Load Balancers & Volumes)

# Destroy Terraform resources
terraform destroy
```

### Destroy Step-by-Step

1. **Delete Kubernetes Resources**
   ```bash
   kubectl delete all --all -n default
   kubectl delete pvc --all -n default
   ```

2. **Delete LoadBalancers Manually** (if needed)
   ```bash
   # List LoadBalancers
   aws elb describe-load-balancers --region us-west-2
   
   # Delete each LoadBalancer
   aws elb delete-load-balancer --load-balancer-name <name>
   ```

3. **Run Terraform Destroy**
   ```bash
   terraform destroy
   ```

4. **Verify Cleanup**
   ```bash
   # Check VPC
   aws ec2 describe-vpcs --region us-west-2
   
   # Check EKS clusters
   aws eks list-clusters --region us-west-2
   ```

## 📚 Additional Resources

### Documentation

- [EKS Auto Mode Documentation](https://docs.aws.amazon.com/eks/latest/userguide/cluster-compute.html)
- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)

### Useful Commands

```bash
# Get cluster information
aws eks describe-cluster --name production-eks-auto --region us-west-2

# List addons
aws eks list-addons --cluster-name production-eks-auto --region us-west-2

# Update kubeconfig
aws eks update-kubeconfig --region us-west-2 --name production-eks-auto

# View logs
aws logs tail /aws/eks/production-eks-auto/cluster --follow

# Get node information
kubectl get nodes -o wide

# Describe node
kubectl describe node <node-name>
```

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📄 License

This project is licensed under the MIT License.

## ⚠️ Disclaimer

This code is provided as-is for educational and production use. Always review and test thoroughly before deploying to production. AWS costs are your responsibility.

---

**Created by**: Platform Team  
**Last Updated**: December 2024  
**Version**: 1.0.0
