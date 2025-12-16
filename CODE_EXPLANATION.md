# DETAILED CODE EXPLANATION
# This document explains each component of the Terraform configuration in detail

## TABLE OF CONTENTS
1. [Terraform Basics](#terraform-basics)
2. [File-by-File Explanation](#file-by-file-explanation)
3. [Resource Dependencies](#resource-dependencies)
4. [Best Practices Implemented](#best-practices-implemented)
5. [Customization Guide](#customization-guide)

---

## TERRAFORM BASICS

### What is Terraform?
Terraform is an Infrastructure as Code (IaC) tool that lets you define cloud infrastructure using configuration files instead of manual setup through the AWS Console.

### Key Concepts

**Providers**: Plugins that interact with cloud platforms (AWS, Azure, etc.)
**Resources**: Individual infrastructure components (VPC, EC2, EKS)
**Variables**: Input parameters that make code reusable
**Outputs**: Values to display after deployment
**State**: Terraform's record of managed infrastructure

---

## FILE-BY-FILE EXPLANATION

### 1. versions.tf - Version Requirements

```hcl
terraform {
  required_version = ">= 1.0"
```
**Explanation**: This ensures everyone uses Terraform 1.0 or newer, preventing version compatibility issues.

```hcl
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
```
**Explanation**: 
- `source`: Where to download the provider from (HashiCorp's registry)
- `version = "~> 5.0"`: Use any 5.x version (5.0, 5.1, 5.2, etc.) but not 6.0
- The `~>` operator means "approximately greater than"

**Backend Block (Commented)**:
```hcl
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
```
**Explanation**: 
- Terraform stores infrastructure state in a file
- By default, it's stored locally (terraform.tfstate)
- For teams/production, store in S3 with DynamoDB locking
- This prevents conflicts when multiple people work together

---

### 2. provider.tf - AWS Provider Configuration

```hcl
provider "aws" {
  region = var.aws_region
```
**Explanation**: Configures AWS provider to use the region from variables (us-west-2).

```hcl
  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
```
**Explanation**: 
- These tags are automatically added to EVERY resource
- Helps with:
  - Cost tracking (see costs by Environment or Project)
  - Resource organization
  - Compliance requirements
  - Automation scripts

**Why this is important**: Without tags, you can't easily track which resources belong to which project or environment, making cost management difficult.

---

### 3. variables.tf - Variable Definitions

#### Structure of a Variable

```hcl
variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-west-2"
  
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "AWS region must be a valid format."
  }
}
```

**Breaking it down**:

1. **description**: Human-readable explanation
2. **type**: Data type (string, number, bool, list, map, object)
3. **default**: Value used if none provided
4. **validation**: Checks if the value is valid before running

**Example validation explained**:
- `can(regex(...))`: Tests if value matches pattern
- `^[a-z]{2}-[a-z]+-[0-9]{1}$`: Pattern for AWS regions
  - `^`: Start of string
  - `[a-z]{2}`: Two lowercase letters (us, eu, ap)
  - `-`: Hyphen
  - `[a-z]+`: One or more lowercase letters (west, east, south)
  - `-`: Hyphen
  - `[0-9]{1}`: Single digit (1, 2, 3)
  - `$`: End of string

#### Variable Types

**Simple Types**:
```hcl
type = string   # "hello"
type = number   # 42
type = bool     # true or false
```

**Complex Types**:
```hcl
type = list(string)              # ["a", "b", "c"]
type = map(string)               # {key1 = "value1", key2 = "value2"}
type = object({                  # Structured data
  name = string
  age  = number
})
```

---

### 4. vpc.tf - Network Infrastructure

#### VPC (Virtual Private Cloud)

```hcl
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr  # "10.0.0.0/16"
```

**What is CIDR?**
- CIDR = Classless Inter-Domain Routing
- `10.0.0.0/16` means:
  - First 16 bits are fixed (10.0)
  - Last 16 bits can vary (0.0 to 255.255)
  - Total: 65,536 IP addresses (2^16)

**Why 10.0.0.0/16?**
- `10.x.x.x` is a private IP range (not routable on internet)
- /16 gives plenty of IPs for large deployments
- Can create many subnets within this range

```hcl
  enable_dns_hostnames = true
  enable_dns_support   = true
```
**Explanation**:
- `enable_dns_hostnames`: Instances get DNS names like ip-10-0-1-5.ec2.internal
- `enable_dns_support`: Enables Amazon DNS server at 10.0.0.2
- **Required for EKS** - pods need DNS resolution

#### Subnets

**Public Subnet**:
```hcl
resource "aws_subnet" "public" {
  count = length(var.availability_zones)
  cidr_block = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true
```

**Explanation**:
- `count`: Creates multiple subnets (one per AZ)
- `count.index`: 0, 1, 2 (for accessing list items)
- `map_public_ip_on_launch = true`: Auto-assign public IPs
- Used for: Load Balancers, NAT Gateways

**Private Subnet**:
```hcl
resource "aws_subnet" "private" {
  map_public_ip_on_launch = false
```

**Explanation**:
- No public IPs assigned
- Internet access only through NAT Gateway
- Used for: EKS nodes, databases, internal services
- **More secure** - not directly accessible from internet

#### NAT Gateway

```hcl
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
```

**What does NAT Gateway do?**
1. Sits in public subnet
2. Private subnet instances route internet traffic through it
3. Provides one-way internet access:
   - ✅ Instances can initiate outbound connections
   - ❌ Internet can't initiate inbound connections
4. Uses Elastic IP (static public IP)

**Why is this needed?**
- EKS nodes need to:
  - Pull container images (Docker Hub, ECR)
  - Access AWS APIs
  - Download packages
- But we don't want them directly exposed to internet

**High Availability Configuration**:
```hcl
count = var.single_nat_gateway ? 1 : length(var.availability_zones)
```

**Explanation**:
- Ternary operator: `condition ? if_true : if_false`
- If `single_nat_gateway = true`: Create 1 NAT
- If `single_nat_gateway = false`: Create one per AZ

**Cost vs Availability**:
- Single NAT: $32/month, but if it fails, all private subnets lose internet
- Multi NAT: $96/month (3 AZs), but failure only affects one AZ

#### Route Tables

```hcl
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}
```

**What are route tables?**
- Like a GPS for network traffic
- Defines where traffic should go based on destination

**Public route table logic**:
- Traffic to 10.0.0.0/16 (VPC): Stay in VPC (implicit)
- Traffic to 0.0.0.0/0 (everything else): Go to Internet Gateway

**Private route table logic**:
- Traffic to 10.0.0.0/16: Stay in VPC
- Traffic to 0.0.0.0/0: Go to NAT Gateway

#### VPC Flow Logs

```hcl
resource "aws_flow_log" "main" {
  traffic_type = "ALL"
  vpc_id       = aws_vpc.main.id
```

**What are Flow Logs?**
- Capture information about IP traffic
- Logs include:
  - Source/destination IPs
  - Ports
  - Protocol
  - Accepted/rejected packets

**Use cases**:
- Security analysis (detect attacks)
- Troubleshooting connectivity
- Compliance auditing

---

### 5. iam.tf - Identity and Access Management

#### IAM Roles

**What is an IAM Role?**
- A set of permissions that can be assumed by AWS services
- Like giving someone a temporary badge with specific access

**EKS Cluster Role**:
```hcl
resource "aws_iam_role" "cluster" {
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Principal = {
        Service = "eks.amazonaws.com"
      }
```

**Explanation**:
- `assume_role_policy`: WHO can use this role (trust policy)
- `eks.amazonaws.com`: EKS service can assume this role
- `sts:AssumeRole`: The action that allows assuming the role

**Attached Policies**:
```hcl
policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
```

**What's in this policy?**
- Permissions to create/modify:
  - EC2 instances and network interfaces
  - Elastic Load Balancers
  - Auto Scaling Groups
- Essentially: Everything EKS needs to manage infrastructure

#### Node Role

```hcl
resource "aws_iam_role" "node" {
  assume_role_policy = jsonencode({
    Principal = {
      Service = "ec2.amazonaws.com"
    }
```

**Why different from cluster role?**
- Cluster role: For EKS control plane
- Node role: For EC2 instances (worker nodes)
- Different services, different permissions needed

**Key policies attached**:
1. **AmazonEKSWorkerNodePolicy**: Join cluster
2. **AmazonEKS_CNI_Policy**: Manage networking
3. **AmazonEC2ContainerRegistryReadOnly**: Pull images
4. **AmazonSSMManagedInstanceCore**: SSH alternative

#### KMS Key for Encryption

```hcl
resource "aws_kms_key" "eks" {
  enable_key_rotation = true
```

**What is KMS?**
- Key Management Service
- Creates and manages encryption keys

**How it works with EKS**:
1. Kubernetes stores secrets in etcd database
2. KMS key encrypts these secrets
3. Without KMS key, can't decrypt secrets
4. `enable_key_rotation = true`: AWS rotates key annually

**Envelope Encryption**:
- KMS doesn't encrypt data directly (too slow)
- Instead:
  1. Generate data key from KMS
  2. Encrypt data with data key
  3. Encrypt data key with KMS key
  4. Store encrypted data + encrypted data key

---

### 6. security-groups.tf - Network Security

#### Security Groups

**What is a Security Group?**
- Virtual firewall for AWS resources
- Controls inbound and outbound traffic
- Stateful: If you allow inbound, return traffic is auto-allowed

#### Cluster Security Group

```hcl
resource "aws_vpc_security_group_ingress_rule" "cluster_ingress_https" {
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
  cidr_ipv4   = var.cluster_endpoint_public_access_cidrs[0]
```

**Explanation**:
- **Port 443**: HTTPS (Kubernetes API server)
- **cidr_ipv4**: IP ranges that can access
- **Why restrict**: Prevent unauthorized API access

**Production Best Practice**:
```hcl
cluster_endpoint_public_access_cidrs = ["YOUR_OFFICE_IP/32"]
```
- Replace `0.0.0.0/0` with your office/VPN IP
- `/32` means exact single IP

#### Node Security Group

**Key rules**:

1. **Allow cluster to node**:
```hcl
referenced_security_group_id = aws_security_group.cluster.id
```
- Cluster needs to communicate with kubelet on nodes
- For: Logs, metrics, exec commands

2. **Allow node to node**:
```hcl
referenced_security_group_id = aws_security_group.node.id
```
- Pods need to talk to each other
- For: Service mesh, networking

3. **CoreDNS ports**:
```hcl
from_port = 53
to_port   = 53
```
- Port 53: DNS queries
- Both TCP and UDP needed

**Why separate security groups?**
- Principle of least privilege
- Easier to manage and audit
- Can apply different rules to cluster vs nodes

---

### 7. eks-cluster.tf - EKS Cluster Creation

#### Cluster Configuration

```hcl
resource "aws_eks_cluster" "main" {
  name    = var.cluster_name
  version = var.kubernetes_version
```

**Kubernetes Version**:
- `1.34`: Latest stable release
- EKS supports last 3 versions
- Plan upgrades regularly (quarterly)

#### VPC Configuration

```hcl
  vpc_config {
    subnet_ids = concat(
      aws_subnet.private[*].id,
      aws_subnet.public[*].id
    )
```

**Why both subnet types?**
- Private: For nodes (security)
- Public: For load balancers
- EKS control plane uses both

**Endpoint Access**:
```hcl
    endpoint_public_access  = true
    endpoint_private_access = true
```

**Access modes**:
1. **Public only**: Access from internet only
2. **Private only**: Access from VPC only
3. **Both (recommended)**: Flexible access

#### Encryption Configuration

```hcl
  encryption_config {
    provider {
      key_arn = aws_kms_key.eks[0].arn
    }
    resources = ["secrets"]
  }
```

**What gets encrypted?**
- Only Kubernetes secrets
- Not: ConfigMaps, pods, volumes (use separate encryption)

#### Compute Configuration (Auto Mode)

```hcl
  compute_config {
    enabled = true
    node_pools = ["general-purpose"]
    node_role_arn = aws_iam_role.node.arn
  }
```

**Node Pool Types**:

1. **general-purpose**: 
   - Instances: t3, t4g, m5, m6i
   - Use: Most workloads
   - Balanced CPU/memory

2. **memory-optimized**:
   - Instances: r5, r6i
   - Use: Databases, caching
   - High memory

3. **compute-optimized**:
   - Instances: c5, c6i
   - Use: CPU-intensive apps
   - High CPU

**How Auto Mode works**:
1. You deploy pod with resource requests
2. EKS analyzes: CPU, memory, GPU needs
3. Selects optimal instance type
4. Provisions node automatically
5. Scales down when not needed

#### Cluster Addons

**VPC CNI**:
```hcl
resource "aws_eks_addon" "vpc_cni" {
  addon_name = "vpc-cni"
```

**What it does**:
- Assigns IP addresses to pods
- Each pod gets VPC IP address
- Enables pod-to-pod communication

**CoreDNS**:
```hcl
resource "aws_eks_addon" "coredns" {
  addon_name = "coredns"
```

**What it does**:
- DNS server for Kubernetes
- Resolves service names to IPs
- Example: `my-service.default.svc.cluster.local`

**Kube-proxy**:
```hcl
resource "aws_eks_addon" "kube_proxy" {
  addon_name = "kube-proxy"
```

**What it does**:
- Maintains network rules
- Enables Services to work
- Routes traffic to correct pods

**Pod Identity Agent**:
```hcl
resource "aws_eks_addon" "pod_identity_agent" {
  addon_name = "eks-pod-identity-agent"
```

**What it does**:
- Allows pods to assume IAM roles
- No need for access keys
- More secure credential management

#### OIDC Provider

```hcl
resource "aws_iam_openid_connect_provider" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
```

**What is OIDC?**
- OpenID Connect (authentication protocol)
- Links Kubernetes service accounts to IAM roles

**How it works**:
1. Pod has Kubernetes service account
2. Service account annotated with IAM role
3. Pod assumes IAM role automatically
4. No static credentials needed

**Example use case**:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/my-app-role
```

---

### 8. outputs.tf - Output Values

#### Purpose of Outputs

```hcl
output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}
```

**Why outputs?**
1. Display important information after deployment
2. Use as inputs for other Terraform modules
3. Reference in automation scripts

**Sensitive outputs**:
```hcl
output "cluster_certificate" {
  value     = aws_eks_cluster.main.certificate_authority[0].data
  sensitive = true  # Not displayed in console
}
```

---

## RESOURCE DEPENDENCIES

### Explicit Dependencies

```hcl
depends_on = [
  aws_iam_role_policy_attachment.cluster_policy,
  aws_cloudwatch_log_group.cluster
]
```

**Why needed?**
- Terraform doesn't always detect dependencies
- Ensures resources created in correct order
- Prevents race conditions

### Implicit Dependencies

```hcl
vpc_id = aws_vpc.main.id
```

**Automatic**:
- Terraform sees reference to `aws_vpc.main`
- Knows VPC must be created first
- Builds dependency graph automatically

### Creation Order

1. VPC and networking
2. IAM roles
3. Security groups
4. KMS keys
5. EKS cluster
6. Addons

---

## BEST PRACTICES IMPLEMENTED

### 1. Tagging Strategy
- Every resource tagged
- Enables cost tracking
- Facilitates automation

### 2. Security
- Private subnets for nodes
- Encryption enabled
- Least privilege IAM
- Security group restrictions

### 3. High Availability
- Multi-AZ deployment
- Multiple NAT gateways (optional)
- Multiple subnets

### 4. Monitoring
- CloudWatch logs enabled
- VPC Flow Logs
- Control plane logging

### 5. Cost Optimization
- Auto Mode (pay for usage)
- Optional single NAT
- Log retention limits

---

## CUSTOMIZATION GUIDE

### Changing Region

1. Update `terraform.tfvars`:
```hcl
aws_region = "eu-west-1"
availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
```

2. Apply changes:
```bash
terraform apply
```

### Adding Node Pool Types

```hcl
compute_config {
  node_pools = ["general-purpose", "memory-optimized"]
}
```

### Restricting API Access

```hcl
cluster_endpoint_public_access_cidrs = [
  "YOUR_OFFICE_IP/32",
  "YOUR_VPN_IP/32"
]
```

### Enabling Additional Logging

```hcl
cluster_enabled_log_types = [
  "api",
  "audit",
  "authenticator",
  "controllerManager",
  "scheduler"
]
```

---

## CONCLUSION

This Terraform configuration implements AWS best practices for:
- Security
- High availability
- Cost optimization
- Scalability
- Maintainability

Key features:
✅ Production-ready
✅ Fully documented
✅ Customizable
✅ Security-focused
✅ Cost-optimized options
