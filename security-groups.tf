# security-groups.tf
# This file creates security groups for controlling network traffic
# Security groups act as virtual firewalls for your resources

# ============================================================================
# CLUSTER SECURITY GROUP
# ============================================================================

# Security group for EKS cluster control plane
# Controls traffic to/from the Kubernetes API server
resource "aws_security_group" "cluster" {
  name_prefix = "${var.project_name}-${var.environment}-eks-cluster-sg-"
  description = "Security group for EKS cluster control plane"
  vpc_id      = aws_vpc.main.id

  # Lifecycle configuration
  # create_before_destroy ensures new SG is created before old one is destroyed
  # This prevents downtime during updates
  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    var.additional_tags,
    {
      Name = "${var.project_name}-${var.environment}-eks-cluster-sg"
      # This tag is required for EKS to identify the security group
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  )
}

# Egress rule - allow all outbound traffic from cluster
# The cluster needs to communicate with nodes, AWS APIs, and external services
resource "aws_vpc_security_group_egress_rule" "cluster_egress" {
  security_group_id = aws_security_group.cluster.id

  # -1 means all protocols
  ip_protocol = "-1"
  # 0.0.0.0/0 means all destinations
  cidr_ipv4   = "0.0.0.0/0"
  description = "Allow all outbound traffic"
}

# Ingress rule - allow HTTPS traffic from specified CIDR blocks
# This allows external access to the Kubernetes API server
resource "aws_vpc_security_group_ingress_rule" "cluster_ingress_https" {
  count = var.cluster_endpoint_public_access ? 1 : 0

  security_group_id = aws_security_group.cluster.id

  # TCP protocol
  ip_protocol = "tcp"
  # Port 443 for HTTPS
  from_port   = 443
  to_port     = 443
  # Allow access from specified CIDR blocks
  cidr_ipv4   = var.cluster_endpoint_public_access_cidrs[0]
  description = "Allow HTTPS access to cluster API from specified CIDRs"
}

# ============================================================================
# NODE SECURITY GROUP
# ============================================================================

# Security group for EKS worker nodes
# Controls traffic to/from worker nodes
resource "aws_security_group" "node" {
  name_prefix = "${var.project_name}-${var.environment}-eks-node-sg-"
  description = "Security group for EKS worker nodes"
  vpc_id      = aws_vpc.main.id

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    var.additional_tags,
    {
      Name = "${var.project_name}-${var.environment}-eks-node-sg"
      # This tag is required for EKS to identify the security group
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  )
}

# Egress rule - allow all outbound traffic from nodes
# Nodes need to:
# - Pull container images from registries
# - Access AWS APIs
# - Communicate with other nodes and the cluster
# - Access external services
resource "aws_vpc_security_group_egress_rule" "node_egress" {
  security_group_id = aws_security_group.node.id

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
  description = "Allow all outbound traffic"
}

# Ingress rule - allow traffic from cluster to nodes
# The cluster needs to communicate with kubelet and pods on the nodes
resource "aws_vpc_security_group_ingress_rule" "node_ingress_cluster" {
  security_group_id = aws_security_group.node.id

  # Reference the cluster security group
  referenced_security_group_id = aws_security_group.cluster.id

  ip_protocol = "-1"
  description = "Allow all traffic from cluster control plane"
}

# Ingress rule - allow nodes to communicate with each other
# Required for:
# - Pod-to-pod communication
# - Service discovery
# - CNI networking
resource "aws_vpc_security_group_ingress_rule" "node_ingress_self" {
  security_group_id = aws_security_group.node.id

  # Reference itself - allows communication between nodes
  referenced_security_group_id = aws_security_group.node.id

  ip_protocol = "-1"
  description = "Allow nodes to communicate with each other"
}

# Ingress rule - allow kubelet API access from cluster
# The cluster needs to communicate with kubelet for node management
resource "aws_vpc_security_group_ingress_rule" "node_ingress_kubelet" {
  security_group_id = aws_security_group.node.id

  referenced_security_group_id = aws_security_group.cluster.id

  ip_protocol = "tcp"
  from_port   = 10250  # Kubelet API port
  to_port     = 10250
  description = "Allow kubelet API access from cluster"
}

# Ingress rule - allow CoreDNS access from cluster
# CoreDNS runs on nodes and provides DNS services for the cluster
resource "aws_vpc_security_group_ingress_rule" "node_ingress_coredns_tcp" {
  security_group_id = aws_security_group.node.id

  referenced_security_group_id = aws_security_group.cluster.id

  ip_protocol = "tcp"
  from_port   = 53  # DNS TCP port
  to_port     = 53
  description = "Allow CoreDNS TCP access from cluster"
}

resource "aws_vpc_security_group_ingress_rule" "node_ingress_coredns_udp" {
  security_group_id = aws_security_group.node.id

  referenced_security_group_id = aws_security_group.cluster.id

  ip_protocol = "udp"
  from_port   = 53  # DNS UDP port
  to_port     = 53
  description = "Allow CoreDNS UDP access from cluster"
}

# ============================================================================
# ALLOW CLUSTER TO COMMUNICATE BACK TO NODES
# ============================================================================

# Egress rule - allow cluster to communicate with nodes on kubelet port
# This allows the cluster to manage nodes and pods
resource "aws_vpc_security_group_egress_rule" "cluster_to_node_kubelet" {
  security_group_id = aws_security_group.cluster.id

  referenced_security_group_id = aws_security_group.node.id

  ip_protocol = "tcp"
  from_port   = 10250
  to_port     = 10250
  description = "Allow cluster to communicate with kubelet"
}

# Egress rule - allow cluster to communicate with nodes on all ports
# Required for the cluster to manage workloads and execute commands
resource "aws_vpc_security_group_egress_rule" "cluster_to_node_all" {
  security_group_id = aws_security_group.cluster.id

  referenced_security_group_id = aws_security_group.node.id

  ip_protocol = "-1"
  description = "Allow cluster to communicate with nodes"
}

# ============================================================================
# ADDITIONAL SECURITY GROUP (Optional)
# ============================================================================

# Additional security group for pod-level security
# You can use this to control traffic to specific pods using NetworkPolicies
resource "aws_security_group" "pod" {
  name_prefix = "${var.project_name}-${var.environment}-eks-pod-sg-"
  description = "Security group for EKS pods"
  vpc_id      = aws_vpc.main.id

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    var.additional_tags,
    {
      Name = "${var.project_name}-${var.environment}-eks-pod-sg"
    }
  )
}

# Allow all egress from pods
resource "aws_vpc_security_group_egress_rule" "pod_egress" {
  security_group_id = aws_security_group.pod.id

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
  description = "Allow all outbound traffic from pods"
}

# Allow pods to communicate with each other
resource "aws_vpc_security_group_ingress_rule" "pod_ingress_self" {
  security_group_id = aws_security_group.pod.id

  referenced_security_group_id = aws_security_group.pod.id

  ip_protocol = "-1"
  description = "Allow pods to communicate with each other"
}

# Allow traffic from nodes to pods
resource "aws_vpc_security_group_ingress_rule" "pod_ingress_from_nodes" {
  security_group_id = aws_security_group.pod.id

  referenced_security_group_id = aws_security_group.node.id

  ip_protocol = "-1"
  description = "Allow traffic from nodes to pods"
}
