# provider.tf
# This file configures the AWS provider with default settings

# Configure the AWS Provider
provider "aws" {
  # AWS region where all resources will be created
  region = var.aws_region

  # Default tags applied to ALL resources created by this Terraform configuration
  # Tags are crucial for:
  # - Cost tracking and allocation
  # - Resource organization
  # - Compliance and governance
  # - Automation and filtering
  default_tags {
    tags = {
      Environment = var.environment          # e.g., "production", "staging", "dev"
      Project     = var.project_name         # Project identifier
      ManagedBy   = "Terraform"              # Indicates infrastructure is managed by Terraform
      Owner       = var.owner                # Team or individual responsible
      CostCenter  = var.cost_center          # For billing and cost allocation
      CreatedDate = timestamp()              # When the resource was created
    }
  }
}
