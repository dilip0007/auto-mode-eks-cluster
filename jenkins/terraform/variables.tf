
variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "Name of the EKS cluster to deploy into"
  type        = string
  default     = "eks-auto-module-demo"
}
