# main.tf
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = var.cluster_name
  cluster_version = "1.34"

  # Free Tier: No CloudWatch Logs
  cluster_enabled_log_types = []

  # Access
  cluster_endpoint_public_access = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"] 

  # EKS Auto Mode Configuration
  cluster_compute_config = {
    enabled    = true
    node_pools = ["general-purpose", "system"]
  }

  # Enable API authentication mode
  authentication_mode = "API"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  access_entries = {
    dilip = {
      principal_arn = "arn:aws:iam::173235558072:user/dilip"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
    admin_cli = {
      principal_arn = "arn:aws:iam::173235558072:user/admin-cli"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  # Access Entry for the cluster creator
  enable_cluster_creator_admin_permissions = true

  tags = {
    Environment = "learning"
    Terraform   = "true"
  }
}
```
