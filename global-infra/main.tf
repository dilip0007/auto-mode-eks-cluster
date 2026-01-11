
# --------------------------------------------------------------------------------------------------
# GitHub OIDC Identity Provider
# --------------------------------------------------------------------------------------------------
# This creates the trust relationship between AWS and GitHub.
# It only needs to be created ONCE per AWS account.
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  
  # This thumbprint is GitHub's certificate thumbprint.
  # Although AWS now supports automatically trusting GitHub without this in some contexts,
  # it's best practice to include it for Terraform stability.
  thumbprint_list = ["ffffffffffffffffffffffffffffffffffffffff"]
}

# --------------------------------------------------------------------------------------------------
# IAM Role for GitHub Actions
# --------------------------------------------------------------------------------------------------
resource "aws_iam_role" "github_actions_role" {
  name = "github-actions-ecr-push-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            # This locks access to ONLY your repository
            "token.actions.githubusercontent.com:sub": [
              "repo:dilip0007/microservices-demo:*",
              "repo:dilip0007/auto-mode-eks-cluster:*"
            ]
          }
          StringEquals = {
             "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Environment = "learning"
    ManagedBy   = "Terraform"
  }
}

# --------------------------------------------------------------------------------------------------
# Permissions for ECR
# --------------------------------------------------------------------------------------------------
# This policy allows the role to log in, push, and create repositories in ECR.
resource "aws_iam_role_policy" "github_actions_ecr_policy" {
  name = "github-actions-ecr-policy"
  role = aws_iam_role.github_actions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:CreateRepository"
        ]
        Resource = "*"
      }
    ]
  })
}

# --------------------------------------------------------------------------------------------------
# Output
# --------------------------------------------------------------------------------------------------
output "github_actions_role_arn" {
  description = "The ARN of the IAM role for GitHub Actions to assume"
  value       = aws_iam_role.github_actions_role.arn
}
