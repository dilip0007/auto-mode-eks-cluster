# backend.tf
# This file configures where Terraform stores its "state" (the map of what it created).
# Storing it in S3 allows multiple people to work on it and prevents data loss.
# The DynamoDB table prevents two people from running 'apply' at the same time.

terraform {
  backend "s3" {
    # REPLACE THIS with your unique bucket name!
    # Bucket must be created manually before running 'terraform init'
    bucket         = "terraform-state-eks-auto-cluster-dilip-ni" 
    
    # The path to the state file inside the bucket
    key            = "eks-auto-module/terraform.tfstate"
    
    # AWS Region of the bucket
    region         = "us-east-1"
    
    # Encrypt state at rest
    encrypt        = true
    
    # Use native state locking (modern replacement for dynamodb_table)
    use_lockfile   = true
  }
}
