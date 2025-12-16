# iam.tf
# This file creates all IAM (Identity and Access Management) roles and policies
# IAM roles define what AWS services and resources can do on your behalf

# ============================================================================
# EKS CLUSTER IAM ROLE
# ============================================================================

# IAM role for EKS cluster
# This role allows EKS to manage AWS resources on your behalf
resource "aws_iam_role" "cluster" {
  name = "${var.project_name}-${var.environment}-eks-cluster-role"

  # Trust policy (assume role policy) - defines WHO can assume this role
  # This allows the EKS service to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"  # EKS service can assume this role
        }
      }
    ]
  })

  tags = merge(
    var.additional_tags,
    {
      Name = "${var.project_name}-${var.environment}-eks-cluster-role"
    }
  )
}

# Attach AWS managed policy for EKS cluster
# This policy contains all permissions needed for EKS to function
resource "aws_iam_role_policy_attachment" "cluster_policy" {
  # The role to attach the policy to
  role = aws_iam_role.cluster.name

  # AWS managed policy ARN - contains permissions for EKS cluster operations
  # This includes permissions to:
  # - Create/modify EC2 resources (security groups, network interfaces)
  # - Create/modify ELB resources (load balancers)
  # - Manage Auto Scaling Groups
  # - Access CloudWatch for logs and metrics
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Attach VPC Resource Controller policy
# This allows EKS to manage network interfaces in your VPC
resource "aws_iam_role_policy_attachment" "cluster_vpc_resource_controller" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

# ============================================================================
# EKS NODE IAM ROLE (For Auto Mode)
# ============================================================================

# IAM role for EKS worker nodes
# This role allows EC2 instances (nodes) to call AWS services on your behalf
resource "aws_iam_role" "node" {
  name = "${var.project_name}-${var.environment}-eks-node-role"

  # Trust policy - allows EC2 instances to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"  # EC2 instances can assume this role
        }
      }
    ]
  })

  tags = merge(
    var.additional_tags,
    {
      Name = "${var.project_name}-${var.environment}-eks-node-role"
    }
  )
}

# Attach AWS managed policy for EKS worker nodes
# This policy allows nodes to:
# - Connect to EKS cluster
# - Pull container images from ECR
# - Write logs to CloudWatch
resource "aws_iam_role_policy_attachment" "node_policy" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

# Attach CNI policy for networking
# This allows the VPC CNI plugin to modify network interfaces
# Required for pod networking
resource "aws_iam_role_policy_attachment" "node_cni_policy" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# Attach ECR read-only policy
# This allows nodes to pull container images from Amazon ECR
resource "aws_iam_role_policy_attachment" "node_ecr_policy" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Attach SSM policy for Systems Manager access
# This allows you to use AWS Systems Manager Session Manager to access nodes
# without SSH keys - more secure and auditable
resource "aws_iam_role_policy_attachment" "node_ssm_policy" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ============================================================================
# CUSTOM POLICIES FOR ENHANCED FUNCTIONALITY
# ============================================================================

# Custom policy for CloudWatch Container Insights
# This allows nodes to send detailed metrics to CloudWatch
resource "aws_iam_policy" "node_cloudwatch" {
  name        = "${var.project_name}-${var.environment}-eks-node-cloudwatch-policy"
  description = "Policy for EKS nodes to send metrics to CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",      # Send custom metrics
          "ec2:DescribeVolumes",            # Describe EBS volumes
          "ec2:DescribeTags",               # Describe EC2 tags
          "logs:PutLogEvents",              # Write log events
          "logs:DescribeLogStreams",        # Describe log streams
          "logs:DescribeLogGroups",         # Describe log groups
          "logs:CreateLogStream",           # Create log streams
          "logs:CreateLogGroup"             # Create log groups
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(
    var.additional_tags,
    {
      Name = "${var.project_name}-${var.environment}-eks-node-cloudwatch-policy"
    }
  )
}

# Attach CloudWatch policy to node role
resource "aws_iam_role_policy_attachment" "node_cloudwatch" {
  role       = aws_iam_role.node.name
  policy_arn = aws_iam_policy.node_cloudwatch.arn
}

# Custom policy for EBS CSI Driver (if you plan to use EBS volumes)
resource "aws_iam_policy" "ebs_csi_driver" {
  name        = "${var.project_name}-${var.environment}-ebs-csi-driver-policy"
  description = "Policy for EBS CSI Driver to manage EBS volumes"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSnapshot",
          "ec2:AttachVolume",
          "ec2:DetachVolume",
          "ec2:ModifyVolume",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInstances",
          "ec2:DescribeSnapshots",
          "ec2:DescribeTags",
          "ec2:DescribeVolumes",
          "ec2:DescribeVolumesModifications"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags"
        ]
        Resource = [
          "arn:aws:ec2:*:*:volume/*",
          "arn:aws:ec2:*:*:snapshot/*"
        ]
        Condition = {
          StringEquals = {
            "ec2:CreateAction" = [
              "CreateVolume",
              "CreateSnapshot"
            ]
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DeleteTags"
        ]
        Resource = [
          "arn:aws:ec2:*:*:volume/*",
          "arn:aws:ec2:*:*:snapshot/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateVolume"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:RequestTag/ebs.csi.aws.com/cluster" = "true"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateVolume"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:RequestTag/CSIVolumeName" = "*"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DeleteVolume"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "ec2:ResourceTag/ebs.csi.aws.com/cluster" = "true"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DeleteVolume"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "ec2:ResourceTag/CSIVolumeName" = "*"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DeleteVolume"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "ec2:ResourceTag/kubernetes.io/created-for/pvc/name" = "*"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DeleteSnapshot"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "ec2:ResourceTag/CSIVolumeSnapshotName" = "*"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DeleteSnapshot"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "ec2:ResourceTag/ebs.csi.aws.com/cluster" = "true"
          }
        }
      }
    ]
  })

  tags = merge(
    var.additional_tags,
    {
      Name = "${var.project_name}-${var.environment}-ebs-csi-driver-policy"
    }
  )
}

# Attach EBS CSI policy to node role
resource "aws_iam_role_policy_attachment" "node_ebs_csi" {
  role       = aws_iam_role.node.name
  policy_arn = aws_iam_policy.ebs_csi_driver.arn
}

# ============================================================================
# INSTANCE PROFILE FOR EC2 NODES
# ============================================================================

# Instance profile for EC2 instances
# This wraps the IAM role so EC2 instances can use it
resource "aws_iam_instance_profile" "node" {
  name = "${var.project_name}-${var.environment}-eks-node-instance-profile"
  role = aws_iam_role.node.name

  tags = merge(
    var.additional_tags,
    {
      Name = "${var.project_name}-${var.environment}-eks-node-instance-profile"
    }
  )
}

# ============================================================================
# KMS KEY FOR CLUSTER ENCRYPTION
# ============================================================================

# KMS key for encrypting Kubernetes secrets
# This provides envelope encryption for secrets stored in etcd
resource "aws_kms_key" "eks" {
  count = var.enable_cluster_encryption ? 1 : 0

  description             = "EKS Secret Encryption Key for ${var.cluster_name}"
  deletion_window_in_days = 30  # Wait 30 days before deleting key if destroy is requested
  enable_key_rotation     = true  # Automatically rotate key annually

  tags = merge(
    var.additional_tags,
    {
      Name = "${var.project_name}-${var.environment}-eks-encryption-key"
    }
  )
}

# KMS key alias for easier reference
resource "aws_kms_alias" "eks" {
  count = var.enable_cluster_encryption ? 1 : 0

  name          = "alias/${var.project_name}-${var.environment}-eks"
  target_key_id = aws_kms_key.eks[0].key_id
}

# KMS key policy - allows EKS to use the key
resource "aws_kms_key_policy" "eks" {
  count = var.enable_cluster_encryption ? 1 : 0

  key_id = aws_kms_key.eks[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow EKS to use the key"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:CreateGrant",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================================================
# DATA SOURCES
# ============================================================================

# Get current AWS account ID and caller identity
data "aws_caller_identity" "current" {}
