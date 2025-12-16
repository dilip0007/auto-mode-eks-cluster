# terraform.tfvars
# This file contains the actual values for your variables
# Customize these values according to your requirements

# ============================================================================
# GENERAL CONFIGURATION
# ============================================================================

# AWS region where resources will be created
aws_region = "us-west-2"

# Environment name (production, staging, development, qa)
environment = "production"

# Project name - used for resource naming
project_name = "eks-auto-cluster"

# Owner information
owner = "platform-team"

# Cost center for billing
cost_center = "engineering"

# ============================================================================
# NETWORKING CONFIGURATION
# ============================================================================

# VPC CIDR block - provides 65,536 IP addresses
vpc_cidr = "10.0.0.0/16"

# Availability zones - use at least 2 for high availability
availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]

# Private subnet CIDRs - for EKS nodes and pods
# Each /24 subnet provides 251 usable IP addresses
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]

# Public subnet CIDRs - for NAT gateways and load balancers
public_subnet_cidrs = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

# Enable NAT Gateway - required for private subnet internet access
enable_nat_gateway = true

# Use single NAT Gateway (false = one per AZ for high availability)
# Set to true to save costs in non-production environments
single_nat_gateway = false

# ============================================================================
# EKS CLUSTER CONFIGURATION
# ============================================================================

# Cluster name
cluster_name = "production-eks-auto"

# Kubernetes version
kubernetes_version = "1.34"

# Cluster endpoint access
cluster_endpoint_public_access  = true
cluster_endpoint_private_access = true

# IMPORTANT: Restrict this to your office/VPN IP ranges in production!
# Example: ["1.2.3.4/32", "5.6.7.8/32"]
cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

# Control plane logging
cluster_enabled_log_types = [
  "api",
  "audit",
  "authenticator",
  "controllerManager",
  "scheduler"
]

# Log retention in CloudWatch (days)
cluster_log_retention_days = 30

# ============================================================================
# SECURITY CONFIGURATION
# ============================================================================

# Enable envelope encryption for Kubernetes secrets
enable_cluster_encryption = true

# Enable IAM Roles for Service Accounts (IRSA)
enable_irsa = true

# ============================================================================
# ADD-ONS CONFIGURATION
# ============================================================================

cluster_addons = {
  vpc-cni = {
    version               = "v1.19.0-eksbuild.1"
    resolve_conflicts     = "OVERWRITE"
    service_account_role_arn = ""
  }
  coredns = {
    version               = "v1.11.3-eksbuild.2"
    resolve_conflicts     = "OVERWRITE"
    service_account_role_arn = ""
  }
  kube-proxy = {
    version               = "v1.34.0-eksbuild.1"
    resolve_conflicts     = "OVERWRITE"
    service_account_role_arn = ""
  }
  eks-pod-identity-agent = {
    version               = "v1.3.4-eksbuild.1"
    resolve_conflicts     = "OVERWRITE"
    service_account_role_arn = ""
  }
}

# ============================================================================
# MONITORING CONFIGURATION
# ============================================================================

# Enable CloudWatch Container Insights
enable_container_insights = true

# ============================================================================
# BACKUP CONFIGURATION
# ============================================================================

# Enable AWS Backup
enable_backup = true

# Backup retention period (days)
backup_retention_days = 7

# ============================================================================
# ADDITIONAL TAGS
# ============================================================================

additional_tags = {
  Terraform   = "true"
  Application = "kubernetes-cluster"
  Compliance  = "required"
}
