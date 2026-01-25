# ECR Module for V1 Migration - Root Registry with Pipeline Access
# This module creates:
# 1. ECR repositories
# 2. IAM policies that allow:
#    - Pipeline (GitLab Runner) to create repositories and push images to any repository
#    - Pods (via IRSA) to pull images from specified repositories

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Local values for repository ARNs
locals {
  # Build repository names with namespace if provided
  repository_names = var.ecr_namespace != "" ? [
    for repo in var.repositories : "${var.ecr_namespace}/${repo}"
  ] : var.repositories

  # Build repository ARNs for IAM policies
  repository_arns = [
    for repo_name in local.repository_names : "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/${repo_name}"
  ]
}

# IAM Policy for Pipeline (GitLab Runner) to create repositories and push images
resource "aws_iam_policy" "ecr_pipeline_policy_v1" {
  name        = "${var.environment}-v1-ecr-pipeline-policy"
  description = "Policy for CI/CD pipeline to create ECR repositories and push images (v1 migration)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:CreateRepository",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:DescribeImages",
          "ecr:ListImages",
          "ecr:TagResource",
          "ecr:UntagResource"
        ]
        Resource = var.ecr_namespace != "" ? "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/${var.ecr_namespace}/*" : "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name    = "${var.environment}-v1-ecr-pipeline-policy"
    Purpose = "ECR Pipeline Access v1"
  })
}

# IAM Policy for Pods (IRSA) to pull images
resource "aws_iam_policy" "ecr_pull_policy_v1" {
  name        = "${var.environment}-v1-ecr-pull-policy"
  description = "Policy for pods to pull images from ECR (used with IRSA) - v1 migration"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Effect = "Allow"
          Action = [
            "ecr:GetAuthorizationToken"
          ]
          Resource = "*"
        }
      ],
      # Add statement for specific repositories if provided
      length(local.repository_arns) > 0 ? [
        {
          Effect = "Allow"
          Action = [
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage",
            "ecr:DescribeImages"
          ]
          Resource = local.repository_arns
        }
      ] : [],
      # Always include wildcard access for backward compatibility
      [
        {
          Effect = "Allow"
          Action = [
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage",
            "ecr:DescribeImages"
          ]
          Resource = var.ecr_namespace != "" ? "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/${var.ecr_namespace}/*" : "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/*"
        }
      ]
    )
  })

  tags = merge(var.tags, {
    Name    = "${var.environment}-v1-ecr-pull-policy"
    Purpose = "ECR Pod Pull Access v1"
  })
}

# ECR Repositories
resource "aws_ecr_repository" "repositories" {
  for_each = toset(local.repository_names)

  name                 = each.value
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  tags = merge(var.tags, {
    Name    = each.value
    Purpose = "ECR Repository v1"
  })
}

# ECR Lifecycle Policies - Keep last 10 images
resource "aws_ecr_lifecycle_policy" "repositories" {
  for_each = toset(local.repository_names)

  repository = aws_ecr_repository.repositories[each.value].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Output policy ARNs for attachment to roles
output "ecr_pipeline_policy_arn" {
  description = "ARN of the ECR pipeline policy"
  value       = aws_iam_policy.ecr_pipeline_policy_v1.arn
}

output "ecr_pull_policy_arn" {
  description = "ARN of the ECR pull policy"
  value       = aws_iam_policy.ecr_pull_policy_v1.arn
}

output "ecr_registry_id" {
  description = "ECR Registry ID (AWS Account ID)"
  value       = data.aws_caller_identity.current.account_id
}

output "ecr_registry_url" {
  description = "ECR Registry URL"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com"
}

output "ecr_namespace" {
  description = "ECR namespace/prefix for repositories"
  value       = var.ecr_namespace
}

output "repository_urls" {
  description = "Map of repository names to their URLs"
  value = {
    for repo_name in local.repository_names : repo_name => "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/${repo_name}"
  }
}

output "repository_arns" {
  description = "Map of repository names to their ARNs"
  value = {
    for repo_name in local.repository_names : repo_name => "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/${repo_name}"
  }
}
