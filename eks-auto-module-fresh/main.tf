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



  # Access Entry for the cluster creator
  enable_cluster_creator_admin_permissions = true

  tags = {
    Environment = "learning"
    Terraform   = "true"
  }
}

