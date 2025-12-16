# variables.tf
# This file defines all input variables used throughout the Terraform configuration
# Variables make the code reusable and allow customization without changing the core code

# ============================================================================
# GENERAL CONFIGURATION VARIABLES
# ============================================================================

variable "aws_region" {
  description = "AWS region where all resources will be created. Choose a region close to your users for lower latency."
  type        = string
  default     = "us-west-2"
  
  # Validation ensures only valid AWS regions are used
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "AWS region must be a valid region format (e.g., us-west-2, eu-west-1)."
  }
}

variable "environment" {
  description = "Environment name (e.g., production, staging, development). Used for resource naming and tagging."
  type        = string
  default     = "production"
  
  # Validation ensures consistent environment naming
  validation {
    condition     = contains(["production", "staging", "development", "qa"], var.environment)
    error_message = "Environment must be one of: production, staging, development, qa."
  }
}

variable "project_name" {
  description = "Project name used for resource naming and identification. Should be lowercase with hyphens."
  type        = string
  default     = "eks-auto-cluster"
  
  # Validation ensures naming conventions
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "owner" {
  description = "Owner of the infrastructure (team name or email). Used for tagging and contact purposes."
  type        = string
  default     = "platform-team"
}

variable "cost_center" {
  description = "Cost center for billing and cost allocation. Used for financial tracking."
  type        = string
  default     = "engineering"
}

# ============================================================================
# NETWORKING VARIABLES
# ============================================================================

variable "vpc_cidr" {
  description = "CIDR block for the VPC. This defines the IP address range for your entire VPC. /16 gives you 65,536 IP addresses."
  type        = string
  default     = "10.0.0.0/16"
  
  # Validation ensures valid CIDR format
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "availability_zones" {
  description = "List of availability zones to use. Multi-AZ deployment provides high availability and fault tolerance."
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b", "us-west-2c"]
  
  # Validation ensures at least 2 AZs for HA
  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least 2 availability zones must be specified for high availability."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets. Private subnets host EKS nodes and don't have direct internet access."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  
  # Validation ensures matching number of subnets and AZs
  validation {
    condition     = length(var.private_subnet_cidrs) >= 2
    error_message = "At least 2 private subnets must be specified."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets. Public subnets host NAT Gateways and Load Balancers with internet access."
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  
  # Validation ensures matching number of subnets and AZs
  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "At least 2 public subnets must be specified."
  }
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnet internet access. Required for nodes to pull images and access AWS services."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway (cost-saving) instead of one per AZ. Single NAT reduces costs but removes AZ-level redundancy."
  type        = bool
  default     = false  # false = one NAT per AZ for high availability
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC. Required for EKS."
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in the VPC. Required for EKS."
  type        = bool
  default     = true
}

# ============================================================================
# EKS CLUSTER VARIABLES
# ============================================================================

variable "cluster_name" {
  description = "Name of the EKS cluster. Must be unique within your AWS account and region."
  type        = string
  default     = "production-eks-auto"
  
  # Validation ensures valid cluster name
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.cluster_name)) && length(var.cluster_name) <= 100
    error_message = "Cluster name must start with a letter, contain only alphanumeric characters and hyphens, and be 100 characters or less."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster. Using 1.34 as specified."
  type        = string
  default     = "1.34"
  
  # Validation ensures valid version format
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+$", var.kubernetes_version))
    error_message = "Kubernetes version must be in format X.Y (e.g., 1.34)."
  }
}

variable "cluster_endpoint_public_access" {
  description = "Enable public access to the cluster API endpoint. Set to false for private-only clusters."
  type        = bool
  default     = true
}

variable "cluster_endpoint_private_access" {
  description = "Enable private access to the cluster API endpoint. Should always be true for production."
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks that can access the public API endpoint. Restrict this in production to known IPs."
  type        = list(string)
  default     = ["0.0.0.0/0"]  # WARNING: Change this to your office/VPN IP ranges in production!
}

variable "cluster_enabled_log_types" {
  description = "List of control plane logging types to enable. Logs are sent to CloudWatch for monitoring and troubleshooting."
  type        = list(string)
  default = [
    "api",                # Kubernetes API server logs
    "audit",              # Kubernetes audit logs (who did what)
    "authenticator",      # AWS IAM Authenticator logs
    "controllerManager",  # Kubernetes controller manager logs
    "scheduler"           # Kubernetes scheduler logs
  ]
}

variable "cluster_log_retention_days" {
  description = "Number of days to retain cluster logs in CloudWatch. Longer retention increases costs."
  type        = number
  default     = 30
  
  # Validation ensures valid retention period
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.cluster_log_retention_days)
    error_message = "Log retention must be a valid CloudWatch retention period."
  }
}

# ============================================================================
# EKS AUTO MODE VARIABLES
# ============================================================================

variable "compute_config" {
  description = "Compute configuration for EKS Auto Mode. Defines which node types to use and preferences."
  type = object({
    enabled = bool           # Enable Auto Mode
    node_pools = list(string)  # Node pool types: general-purpose, memory-optimized, compute-optimized
    node_role_arn = string   # IAM role ARN for the nodes (will be created automatically)
  })
  default = {
    enabled       = true
    node_pools    = ["general-purpose"]  # Start with general-purpose, add others as needed
    node_role_arn = ""  # Will be populated after IAM role creation
  }
}

# ============================================================================
# SECURITY AND ACCESS VARIABLES
# ============================================================================

variable "enable_cluster_encryption" {
  description = "Enable envelope encryption of Kubernetes secrets using AWS KMS. Highly recommended for production."
  type        = bool
  default     = true
}

variable "enable_irsa" {
  description = "Enable IAM Roles for Service Accounts (IRSA). Allows pods to assume IAM roles securely."
  type        = bool
  default     = true
}

variable "cluster_security_group_additional_rules" {
  description = "Additional security group rules for the cluster security group."
  type        = map(any)
  default     = {}
}

# ============================================================================
# ADD-ONS VARIABLES
# ============================================================================

variable "cluster_addons" {
  description = "Map of cluster addon configurations. Add-ons extend cluster functionality."
  type = map(object({
    version               = string
    resolve_conflicts     = string  # OVERWRITE or PRESERVE
    service_account_role_arn = string
  }))
  default = {
    # VPC CNI - Networking plugin for pod IP addressing
    vpc-cni = {
      version               = "v1.19.0-eksbuild.1"
      resolve_conflicts     = "OVERWRITE"
      service_account_role_arn = ""
    }
    # CoreDNS - DNS server for service discovery
    coredns = {
      version               = "v1.11.3-eksbuild.2"
      resolve_conflicts     = "OVERWRITE"
      service_account_role_arn = ""
    }
    # Kube-proxy - Network proxy for Kubernetes services
    kube-proxy = {
      version               = "v1.34.0-eksbuild.1"
      resolve_conflicts     = "OVERWRITE"
      service_account_role_arn = ""
    }
    # Pod Identity Agent - For IAM roles for service accounts
    eks-pod-identity-agent = {
      version               = "v1.3.4-eksbuild.1"
      resolve_conflicts     = "OVERWRITE"
      service_account_role_arn = ""
    }
  }
}

# ============================================================================
# MONITORING AND OBSERVABILITY VARIABLES
# ============================================================================

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights for monitoring. Provides metrics and logs for containers."
  type        = bool
  default     = true
}

# ============================================================================
# BACKUP AND DISASTER RECOVERY VARIABLES
# ============================================================================

variable "enable_backup" {
  description = "Enable AWS Backup for the EKS cluster. Provides automated backup capabilities."
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days to retain backups."
  type        = number
  default     = 7
}

# ============================================================================
# TAGS VARIABLE
# ============================================================================

variable "additional_tags" {
  description = "Additional tags to apply to all resources. Merge with default tags."
  type        = map(string)
  default     = {}
}
