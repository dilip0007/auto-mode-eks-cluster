# outputs.tf
# This file defines outputs that will be displayed after Terraform apply completes
# Outputs provide important information needed to interact with your resources

# ============================================================================
# VPC OUTPUTS
# ============================================================================

output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = aws_nat_gateway.main[*].id
}

# ============================================================================
# EKS CLUSTER OUTPUTS
# ============================================================================

output "cluster_id" {
  description = "The name/id of the EKS cluster"
  value       = aws_eks_cluster.main.id
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  description = "Endpoint for your Kubernetes API server"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_version" {
  description = "The Kubernetes server version for the cluster"
  value       = aws_eks_cluster.main.version
}

output "cluster_platform_version" {
  description = "The platform version for the cluster"
  value       = aws_eks_cluster.main.platform_version
}

output "cluster_status" {
  description = "Status of the EKS cluster. One of `CREATING`, `ACTIVE`, `DELETING`, `FAILED`"
  value       = aws_eks_cluster.main.status
}

# ============================================================================
# OIDC PROVIDER OUTPUTS
# ============================================================================

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for IAM Roles for Service Accounts (IRSA)"
  value       = var.enable_irsa ? aws_iam_openid_connect_provider.cluster[0].arn : null
}

# ============================================================================
# IAM ROLE OUTPUTS
# ============================================================================

output "cluster_iam_role_arn" {
  description = "IAM role ARN of the EKS cluster"
  value       = aws_iam_role.cluster.arn
}

output "node_iam_role_arn" {
  description = "IAM role ARN of the EKS nodes"
  value       = aws_iam_role.node.arn
}

output "node_instance_profile_arn" {
  description = "ARN of the IAM instance profile for nodes"
  value       = aws_iam_instance_profile.node.arn
}

# ============================================================================
# SECURITY GROUP OUTPUTS
# ============================================================================

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_security_group.cluster.id
}

output "node_security_group_id" {
  description = "Security group ID attached to the EKS nodes"
  value       = aws_security_group.node.id
}

output "pod_security_group_id" {
  description = "Security group ID for EKS pods"
  value       = aws_security_group.pod.id
}

# ============================================================================
# CLOUDWATCH OUTPUTS
# ============================================================================

output "cluster_cloudwatch_log_group_name" {
  description = "Name of the CloudWatch Log Group for cluster logs"
  value       = aws_cloudwatch_log_group.cluster.name
}

output "cluster_cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch Log Group for cluster logs"
  value       = aws_cloudwatch_log_group.cluster.arn
}

# ============================================================================
# KMS OUTPUTS
# ============================================================================

output "kms_key_id" {
  description = "The globally unique identifier for the KMS key"
  value       = var.enable_cluster_encryption ? aws_kms_key.eks[0].id : null
}

output "kms_key_arn" {
  description = "The Amazon Resource Name (ARN) of the KMS key"
  value       = var.enable_cluster_encryption ? aws_kms_key.eks[0].arn : null
}

# ============================================================================
# ADDON OUTPUTS
# ============================================================================

output "addon_vpc_cni_version" {
  description = "Version of the VPC CNI addon"
  value       = aws_eks_addon.vpc_cni.addon_version
}

output "addon_coredns_version" {
  description = "Version of the CoreDNS addon"
  value       = aws_eks_addon.coredns.addon_version
}

output "addon_kube_proxy_version" {
  description = "Version of the kube-proxy addon"
  value       = aws_eks_addon.kube_proxy.addon_version
}

output "addon_pod_identity_agent_version" {
  description = "Version of the pod identity agent addon"
  value       = aws_eks_addon.pod_identity_agent.addon_version
}

# ============================================================================
# KUBECTL CONFIGURATION COMMAND
# ============================================================================

output "configure_kubectl" {
  description = "Command to configure kubectl to connect to the cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}

# ============================================================================
# REGION OUTPUT
# ============================================================================

output "aws_region" {
  description = "AWS region where resources are created"
  value       = var.aws_region
}

# ============================================================================
# AUTO MODE CONFIGURATION
# ============================================================================

output "compute_config" {
  description = "Compute configuration for EKS Auto Mode"
  value = {
    enabled    = aws_eks_cluster.main.compute_config[0].enabled
    node_pools = aws_eks_cluster.main.compute_config[0].node_pools
  }
}

# ============================================================================
# HELPFUL NEXT STEPS
# ============================================================================

output "next_steps" {
  description = "Helpful next steps after cluster creation"
  value = <<-EOT
    
    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║                    EKS CLUSTER CREATED SUCCESSFULLY!                          ║
    ╚══════════════════════════════════════════════════════════════════════════════╝
    
    📋 CLUSTER INFORMATION:
    ├─ Cluster Name: ${aws_eks_cluster.main.name}
    ├─ Kubernetes Version: ${aws_eks_cluster.main.version}
    ├─ Region: ${var.aws_region}
    ├─ Endpoint: ${aws_eks_cluster.main.endpoint}
    └─ Auto Mode: ENABLED ✓
    
    🔧 NEXT STEPS:
    
    1️⃣  Configure kubectl to connect to your cluster:
        
        aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}
    
    2️⃣  Verify cluster access:
        
        kubectl get nodes
        kubectl get pods -A
    
    3️⃣  Check Auto Mode status:
        
        kubectl get pods -n kube-system
    
    4️⃣  Deploy a sample application:
        
        kubectl create deployment nginx --image=nginx
        kubectl expose deployment nginx --port=80 --type=LoadBalancer
    
    5️⃣  Monitor cluster logs in CloudWatch:
        
        Log Group: ${aws_cloudwatch_log_group.cluster.name}
    
    📚 USEFUL COMMANDS:
    
    • View cluster details:
      aws eks describe-cluster --name ${aws_eks_cluster.main.name} --region ${var.aws_region}
    
    • View addons:
      aws eks list-addons --cluster-name ${aws_eks_cluster.main.name} --region ${var.aws_region}
    
    • View compute configuration:
      aws eks describe-cluster --name ${aws_eks_cluster.main.name} --region ${var.aws_region} --query 'cluster.computeConfig'
    
    🔐 SECURITY NOTES:
    
    • Cluster encryption: ${var.enable_cluster_encryption ? "ENABLED ✓" : "DISABLED ✗"}
    • IRSA (IAM Roles for Service Accounts): ${var.enable_irsa ? "ENABLED ✓" : "DISABLED ✗"}
    • VPC Flow Logs: ENABLED ✓
    • Control Plane Logs: ENABLED ✓
    
    ⚠️  IMPORTANT:
    
    • Review and restrict cluster_endpoint_public_access_cidrs in production
    • Implement network policies for pod-level security
    • Enable AWS Backup for disaster recovery
    • Set up monitoring and alerting with CloudWatch
    • Review IAM permissions and follow principle of least privilege
    
    📖 DOCUMENTATION:
    
    • EKS Auto Mode: https://docs.aws.amazon.com/eks/latest/userguide/cluster-compute.html
    • EKS Best Practices: https://aws.github.io/aws-eks-best-practices/
    
    EOT
}
