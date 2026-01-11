terraform {
  backend "s3" {
    bucket         = "terraform-state-eks-auto-cluster-dilip-ni"
    key            = "global-infra/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile   = true
  }
}

provider "aws" {
  region = "us-east-1"
}
