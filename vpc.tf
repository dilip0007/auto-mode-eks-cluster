# vpc.tf
# This file creates the Virtual Private Cloud (VPC) and all networking components
# A VPC is an isolated network environment in AWS where your EKS cluster will run

# ============================================================================
# DATA SOURCES
# ============================================================================

# Get list of available availability zones in the current region
# This ensures we use valid AZs and can dynamically adapt to different regions
data "aws_availability_zones" "available" {
  state = "available"  # Only get AZs that are currently available
  
  # Exclude local zones and wavelength zones (use only standard AZs)
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# ============================================================================
# VPC
# ============================================================================

# Create the main VPC
# This is the container for all your network resources
resource "aws_vpc" "main" {
  # CIDR block defines the IP address range for the VPC
  cidr_block = var.vpc_cidr

  # Enable DNS hostnames - required for EKS
  # This allows instances to get public DNS hostnames
  enable_dns_hostnames = var.enable_dns_hostnames

  # Enable DNS support - required for EKS
  # This enables DNS resolution within the VPC
  enable_dns_support = var.enable_dns_support

  # Tags for the VPC
  tags = merge(
    var.additional_tags,
    {
      Name = "${var.project_name}-${var.environment}-vpc"
      # This tag is required for Kubernetes to discover the VPC
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    }
  )
}

# ============================================================================
# INTERNET GATEWAY
# ============================================================================

# Create Internet Gateway for public subnet internet access
# This allows resources in public subnets to communicate with the internet
resource "aws_internet_gateway" "main" {
  # Attach the IGW to our VPC
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.additional_tags,
    {
      Name = "${var.project_name}-${var.environment}-igw"
    }
  )

  # Ensure VPC is created before IGW
  depends_on = [aws_vpc.main]
}

# ============================================================================
# ELASTIC IPs FOR NAT GATEWAYS
# ============================================================================

# Create Elastic IPs for NAT Gateways
# One EIP per NAT Gateway (one per AZ for HA, or one total for cost savings)
# Elastic IPs are static public IP addresses
resource "aws_eip" "nat" {
  # Create one EIP per AZ if not using single NAT, otherwise just one
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0

  # EIP must be in VPC domain
  domain = "vpc"

  tags = merge(
    var.additional_tags,
    {
      Name = "${var.project_name}-${var.environment}-eip-nat-${count.index + 1}"
    }
  )

  # EIP depends on IGW being created first
  depends_on = [aws_internet_gateway.main]
}

# ============================================================================
# PUBLIC SUBNETS
# ============================================================================

# Create public subnets
# Public subnets have routes to the Internet Gateway
# These will host NAT Gateways and public-facing load balancers
resource "aws_subnet" "public" {
  # Create one public subnet per availability zone
  count = length(var.availability_zones)

  # Reference the VPC we created
  vpc_id = aws_vpc.main.id

  # Assign CIDR block from our list
  cidr_block = var.public_subnet_cidrs[count.index]

  # Place subnet in specific AZ
  availability_zone = var.availability_zones[count.index]

  # Auto-assign public IPs to instances launched in this subnet
  # Required for NAT Gateways and public load balancers
  map_public_ip_on_launch = true

  tags = merge(
    var.additional_tags,
    {
      Name = "${var.project_name}-${var.environment}-public-${var.availability_zones[count.index]}"
      # These tags tell Kubernetes this subnet can be used for public load balancers
      "kubernetes.io/role/elb"                        = "1"
      "kubernetes.io/cluster/${var.cluster_name}"     = "shared"
      # Subnet type identifier
      Type = "public"
    }
  )
}

# ============================================================================
# PRIVATE SUBNETS
# ============================================================================

# Create private subnets
# Private subnets don't have direct internet access
# These will host EKS worker nodes and pods
resource "aws_subnet" "private" {
  # Create one private subnet per availability zone
  count = length(var.availability_zones)

  # Reference the VPC we created
  vpc_id = aws_vpc.main.id

  # Assign CIDR block from our list
  cidr_block = var.private_subnet_cidrs[count.index]

  # Place subnet in specific AZ
  availability_zone = var.availability_zones[count.index]

  # Do NOT auto-assign public IPs in private subnets
  map_public_ip_on_launch = false

  tags = merge(
    var.additional_tags,
    {
      Name = "${var.project_name}-${var.environment}-private-${var.availability_zones[count.index]}"
      # These tags tell Kubernetes this subnet can be used for internal load balancers
      "kubernetes.io/role/internal-elb"               = "1"
      "kubernetes.io/cluster/${var.cluster_name}"     = "shared"
      # Subnet type identifier
      Type = "private"
    }
  )
}

# ============================================================================
# NAT GATEWAYS
# ============================================================================

# Create NAT Gateways for private subnet internet access
# NAT Gateway allows private subnet resources to access internet (one-way)
# Resources in private subnets can initiate outbound connections but can't receive inbound
resource "aws_nat_gateway" "main" {
  # Create one NAT per AZ for HA, or single NAT for cost savings
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0

  # Assign Elastic IP to NAT Gateway
  allocation_id = aws_eip.nat[count.index].id

  # Place NAT Gateway in public subnet (NAT needs internet access)
  subnet_id = aws_subnet.public[count.index].id

  tags = merge(
    var.additional_tags,
    {
      Name = "${var.project_name}-${var.environment}-nat-${var.availability_zones[count.index]}"
    }
  )

  # NAT Gateway must be created after IGW
  depends_on = [aws_internet_gateway.main]
}

# ============================================================================
# ROUTE TABLES
# ============================================================================

# PUBLIC ROUTE TABLE
# Route table for public subnets - routes internet traffic to IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.additional_tags,
    {
      Name = "${var.project_name}-${var.environment}-public-rt"
      Type = "public"
    }
  )
}

# Route for public subnets to reach internet via IGW
resource "aws_route" "public_internet" {
  # Which route table to add this route to
  route_table_id = aws_route_table.public.id

  # Destination CIDR (0.0.0.0/0 means all internet traffic)
  destination_cidr_block = "0.0.0.0/0"

  # Route traffic to Internet Gateway
  gateway_id = aws_internet_gateway.main.id
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  count = length(var.availability_zones)

  # Which subnet to associate
  subnet_id = aws_subnet.public[count.index].id

  # Which route table to associate with
  route_table_id = aws_route_table.public.id
}

# PRIVATE ROUTE TABLES
# Route tables for private subnets - routes internet traffic to NAT Gateway
# We create one route table per AZ for better isolation and AZ-specific NAT routing
resource "aws_route_table" "private" {
  count = length(var.availability_zones)

  vpc_id = aws_vpc.main.id

  tags = merge(
    var.additional_tags,
    {
      Name = "${var.project_name}-${var.environment}-private-rt-${var.availability_zones[count.index]}"
      Type = "private"
    }
  )
}

# Route for private subnets to reach internet via NAT Gateway
resource "aws_route" "private_nat" {
  count = var.enable_nat_gateway ? length(var.availability_zones) : 0

  # Which route table to add this route to
  route_table_id = aws_route_table.private[count.index].id

  # Destination CIDR (0.0.0.0/0 means all internet traffic)
  destination_cidr_block = "0.0.0.0/0"

  # Route traffic to NAT Gateway
  # If single NAT: all private subnets use the same NAT [0]
  # If multi NAT: each private subnet uses its own AZ's NAT
  nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.main[0].id : aws_nat_gateway.main[count.index].id
}

# Associate private subnets with their respective route tables
resource "aws_route_table_association" "private" {
  count = length(var.availability_zones)

  # Which subnet to associate
  subnet_id = aws_subnet.private[count.index].id

  # Which route table to associate with
  route_table_id = aws_route_table.private[count.index].id
}

# ============================================================================
# VPC FLOW LOGS (Optional but recommended for production)
# ============================================================================

# CloudWatch Log Group for VPC Flow Logs
# This stores network traffic logs for security and troubleshooting
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/${var.project_name}-${var.environment}"
  retention_in_days = 30  # Retain logs for 30 days

  tags = merge(
    var.additional_tags,
    {
      Name = "${var.project_name}-${var.environment}-vpc-flow-logs"
    }
  )
}

# IAM role for VPC Flow Logs to write to CloudWatch
resource "aws_iam_role" "vpc_flow_logs" {
  name = "${var.project_name}-${var.environment}-vpc-flow-logs-role"

  # Trust policy - allows VPC Flow Logs service to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.additional_tags,
    {
      Name = "${var.project_name}-${var.environment}-vpc-flow-logs-role"
    }
  )
}

# IAM policy for VPC Flow Logs to write to CloudWatch
resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "${var.project_name}-${var.environment}-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs.id

  # Policy document granting permissions to write logs
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# VPC Flow Logs - captures IP traffic going to and from network interfaces in VPC
resource "aws_flow_log" "main" {
  # IAM role ARN for Flow Logs to use
  iam_role_arn = aws_iam_role.vpc_flow_logs.arn

  # CloudWatch Log Group to send logs to
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn

  # Capture all traffic (ACCEPT, REJECT, or ALL)
  traffic_type = "ALL"

  # Attach to our VPC
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.additional_tags,
    {
      Name = "${var.project_name}-${var.environment}-vpc-flow-logs"
    }
  )
}
