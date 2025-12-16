# eks-cluster.tf
# This file creates the EKS cluster with Auto Mode enabled
# EKS Auto Mode automatically manages compute capacity for your workloads

# ============================================================================
# CLOUDWATCH LOG GROUP FOR CLUSTER LOGS
# ============================================================================

# CloudWatch Log Group for EKS cluster control plane logs
# This stores logs from the Kubernetes control plane components
resource "aws_cloudwatch_log_group" "cluster" {
  # Log group name must follow this pattern for EKS
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cluster_log_retention_days

  # Enable encryption of logs at rest using KMS
  kms_key_id = var.enable_cluster_encryption ? aws_kms_key.eks[0].arn : null

  tags = merge(
    var.additional_tags,
    {
      Name = "${var.project_name}-${var.environment}-eks-cluster-logs"
    }
  )
}

# ============================================================================
# EKS CLUSTER
# ============================================================================

# Create the EKS cluster
resource "aws_eks_cluster" "main" {
  # Cluster name - must be unique in your AWS account and region
  name = var.cluster_name

  # Kubernetes version
  version = var.kubernetes_version

  # IAM role that provides permissions for the Kubernetes control plane
  role_arn = aws_iam_role.cluster.arn

  # Enable control plane logging
  # Logs help with troubleshooting and security auditing
  enabled_cluster_log_types = var.cluster_enabled_log_types

  # VPC configuration for the cluster
  vpc_config {
    # Subnets where the cluster control plane will be placed
    # Using private subnets for better security
    # EKS automatically creates ENIs (Elastic Network Interfaces) in these subnets
    subnet_ids = concat(
      aws_subnet.private[*].id,
      aws_subnet.public[*].id
    )

    # Security group IDs for the cluster control plane
    security_group_ids = [aws_security_group.cluster.id]

    # Enable public access to the cluster API endpoint
    # Set to false for private-only clusters
    endpoint_public_access = var.cluster_endpoint_public_access

    # Enable private access to the cluster API endpoint
    # This allows nodes and pods to access the API server through VPC
    # Should always be true for production
    endpoint_private_access = var.cluster_endpoint_private_access

    # CIDR blocks that can access the public API endpoint
    # In production, restrict this to your office/VPN IP ranges
    public_access_cidrs = var.cluster_endpoint_public_access ? var.cluster_endpoint_public_access_cidrs : null
  }

  # Encryption configuration for secrets
  # Encrypts Kubernetes secrets at rest using AWS KMS
  dynamic "encryption_config" {
    for_each = var.enable_cluster_encryption ? [1] : []
    content {
      provider {
        key_arn = aws_kms_key.eks[0].arn
      }
      resources = ["secrets"]  # Encrypt Kubernetes secrets
    }
  }

  # Cluster access configuration
  # This configures authentication and authorization for the cluster
  access_config {
    # Authentication mode determines how users authenticate to the cluster
    # API_AND_CONFIG_MAP: Uses both EKS API and aws-auth ConfigMap (default)
    # API: Uses only EKS API (recommended for new clusters)
    authentication_mode = "API_AND_CONFIG_MAP"

    # Bootstrap cluster creator admin permissions
    # This grants the IAM principal that creates the cluster admin access
    bootstrap_cluster_creator_admin_permissions = true
  }

  # Compute configuration for Auto Mode
  # This enables EKS Auto Mode which automatically manages compute capacity
  compute_config {
    enabled = true  # Enable Auto Mode

    # Node pools define the types of compute instances to use
    # general-purpose: Balanced compute, memory, and networking (e.g., t3, t4g, m5, m6i)
    # memory-optimized: For memory-intensive workloads (e.g., r5, r6i)
    # compute-optimized: For compute-intensive workloads (e.g., c5, c6i)
    node_pools = ["general-purpose"]

    # IAM role for the nodes
    # This role provides permissions for nodes to join the cluster and access AWS services
    node_role_arn = aws_iam_role.node.arn
  }

  # Storage configuration
  # Defines default storage class for the cluster
  storage_config {
    block_storage {
      enabled = true  # Enable block storage (EBS volumes)
    }
  }

  # Kubernetes network configuration
  kubernetes_network_config {
    # Service IP CIDR - IP range for Kubernetes services
    # This must not overlap with your VPC CIDR
    service_ipv4_cidr = "172.20.0.0/16"

    # IP family - IPv4 or IPv6
    ip_family = "ipv4"
  }

  tags = merge(
    var.additional_tags,
    {
      Name = var.cluster_name
    }
  )

  # Dependencies - ensure these resources are created before the cluster
  depends_on = [
    # IAM role policies must be attached before creating the cluster
    aws_iam_role_policy_attachment.cluster_policy,
    aws_iam_role_policy_attachment.cluster_vpc_resource_controller,
    # CloudWatch log group must exist before enabling cluster logging
    aws_cloudwatch_log_group.cluster,
    # VPC and networking must be ready
    aws_vpc.main,
    aws_subnet.private,
    aws_subnet.public,
    # Security groups must be created
    aws_security_group.cluster,
    aws_security_group.node
  ]
}

# ============================================================================
# EKS CLUSTER ADDONS
# ============================================================================

# VPC CNI addon - Networking plugin for pod IP addressing
# This addon manages pod networking and IP address assignment
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"

  # Addon version - should match your Kubernetes version
  addon_version = var.cluster_addons["vpc-cni"].version

  # How to handle conflicts during addon updates
  # OVERWRITE: Replace existing configuration with addon defaults
  # PRESERVE: Keep existing configuration
  resolve_conflicts_on_create = var.cluster_addons["vpc-cni"].resolve_conflicts
  resolve_conflicts_on_update = var.cluster_addons["vpc-cni"].resolve_conflicts

  # Preserve addon on cluster deletion (optional)
  preserve = false

  tags = merge(
    var.additional_tags,
    {
      Name = "${var.cluster_name}-vpc-cni-addon"
    }
  )

  depends_on = [aws_eks_cluster.main]
}

# CoreDNS addon - DNS server for service discovery
# Provides DNS resolution for Kubernetes services and pods
resource "aws_eks_addon" "coredns" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "coredns"
  addon_version = var.cluster_addons["coredns"].version

  resolve_conflicts_on_create = var.cluster_addons["coredns"].resolve_conflicts
  resolve_conflicts_on_update = var.cluster_addons["coredns"].resolve_conflicts

  preserve = false

  tags = merge(
    var.additional_tags,
    {
      Name = "${var.cluster_name}-coredns-addon"
    }
  )

  # CoreDNS depends on VPC CNI being ready
  depends_on = [
    aws_eks_cluster.main,
    aws_eks_addon.vpc_cni
  ]
}

# Kube-proxy addon - Network proxy for Kubernetes services
# Maintains network rules and enables service communication
resource "aws_eks_addon" "kube_proxy" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "kube-proxy"
  addon_version = var.cluster_addons["kube-proxy"].version

  resolve_conflicts_on_create = var.cluster_addons["kube-proxy"].resolve_conflicts
  resolve_conflicts_on_update = var.cluster_addons["kube-proxy"].resolve_conflicts

  preserve = false

  tags = merge(
    var.additional_tags,
    {
      Name = "${var.cluster_name}-kube-proxy-addon"
    }
  )

  depends_on = [
    aws_eks_cluster.main,
    aws_eks_addon.vpc_cni
  ]
}

# Pod Identity Agent addon - For IAM roles for service accounts (IRSA)
# Allows pods to assume IAM roles for AWS service access
resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "eks-pod-identity-agent"
  addon_version = var.cluster_addons["eks-pod-identity-agent"].version

  resolve_conflicts_on_create = var.cluster_addons["eks-pod-identity-agent"].resolve_conflicts
  resolve_conflicts_on_update = var.cluster_addons["eks-pod-identity-agent"].resolve_conflicts

  preserve = false

  tags = merge(
    var.additional_tags,
    {
      Name = "${var.cluster_name}-pod-identity-agent-addon"
    }
  )

  depends_on = [
    aws_eks_cluster.main,
    aws_eks_addon.vpc_cni
  ]
}

# ============================================================================
# OIDC PROVIDER FOR IRSA
# ============================================================================

# Get OIDC provider URL from the cluster
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# Create OIDC provider for IRSA
# This allows Kubernetes service accounts to assume IAM roles
resource "aws_iam_openid_connect_provider" "cluster" {
  count = var.enable_irsa ? 1 : 0

  # OIDC provider URL from the cluster
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer

  # Client ID list - eks.amazonaws.com is required
  client_id_list = ["sts.amazonaws.com"]

  # Thumbprint of the OIDC provider certificate
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]

  tags = merge(
    var.additional_tags,
    {
      Name = "${var.cluster_name}-oidc-provider"
    }
  )
}

# ============================================================================
# CLUSTER AUTOSCALING (For Auto Mode)
# ============================================================================

# Auto Mode automatically scales compute capacity
# No additional configuration needed - it's fully managed by AWS
# The cluster will automatically:
# - Provision nodes when pods are pending
# - Scale down nodes when they're underutilized
# - Choose optimal instance types based on pod requirements
# - Handle node lifecycle and upgrades

# ============================================================================
# ACCESS ENTRIES
# ============================================================================

# Optional: Create access entries for additional IAM principals
# This grants specific IAM users or roles access to the cluster

# Example: Grant admin access to a specific IAM role (uncomment to use)
# resource "aws_eks_access_entry" "admin" {
#   cluster_name      = aws_eks_cluster.main.name
#   principal_arn     = "arn:aws:iam::123456789012:role/AdminRole"
#   kubernetes_groups = ["system:masters"]
#   type              = "STANDARD"
# }
