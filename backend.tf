# backend.tf
# This file configures where Terraform stores its "state" (the map of what it created).
# Storing it in S3 allows multiple people to work on it and prevents data loss.
# The DynamoDB table prevents two people from running 'apply' at the same time.

terraform {
  backend "s3" {
    # REPLACE THIS with your unique bucket name!
    # Bucket must be created manually before running 'terraform init'
    bucket         = "terraform-state-eks-auto-cluster-dilip" 
    
    # The path to the state file inside the bucket
    key            = "eks-auto-mode/terraform.tfstate"
    
    # AWS Region of the bucket
    region         = "us-west-2"
    
    # Encrypt state at rest
    encrypt        = true
    
    # DynamoDB table for locking (must be created manually)
    # Partition key must be "LockID"
    dynamodb_table = "terraform-locks"
  }
}
