# versions.tf
# This file defines the required Terraform version and provider versions
# This ensures consistency across different environments and team members

# Terraform block specifies the minimum Terraform version required
terraform {
  # Require Terraform version 1.0 or higher
  # The ~> operator means "approximately greater than" - allows rightmost version component to increment
  required_version = ">= 1.0"

  # Required providers block specifies which providers this configuration needs
  required_providers {
    # AWS provider for managing AWS resources
    aws = {
      source  = "hashicorp/aws"  # Official AWS provider from HashiCorp
      version = "~> 5.0"          # Use AWS provider version 5.x (will use latest 5.x version)
    }

    # TLS provider for generating SSH keys and certificates
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }

    # Random provider for generating random values (used for unique naming)
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # Backend configuration for storing Terraform state
  # IMPORTANT: Uncomment and configure this for production use
  # This stores your state file in S3 with DynamoDB for state locking
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"    # S3 bucket name for state storage
  #   key            = "eks-auto-mode/terraform.tfstate" # Path within the bucket
  #   region         = "us-west-2"                       # AWS region for the bucket
  #   encrypt        = true                              # Encrypt state file at rest
  #   dynamodb_table = "terraform-state-lock"           # DynamoDB table for state locking
  # }
}
