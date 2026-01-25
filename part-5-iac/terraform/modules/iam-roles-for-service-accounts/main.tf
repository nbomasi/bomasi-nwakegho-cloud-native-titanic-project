# IAM Roles for Service Accounts (IRSA) Module

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.30.0"
    }
  }
}

# Data source to get EKS cluster OIDC issuer (only if not provided as variables)
data "aws_eks_cluster" "cluster" {
  count = var.use_oidc_from_module ? 0 : 1
  name  = var.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

# Data source to get OIDC provider (only if not provided as variables)
data "aws_iam_openid_connect_provider" "cluster" {
  count = var.use_oidc_from_module ? 0 : 1
  url   = data.aws_eks_cluster.cluster[0].identity[0].oidc[0].issuer
}

# Local values for OIDC provider info
locals {
  oidc_provider_arn = var.use_oidc_from_module ? var.oidc_provider_arn : data.aws_iam_openid_connect_provider.cluster[0].arn
  oidc_provider_url = var.use_oidc_from_module ? var.oidc_provider_url : data.aws_iam_openid_connect_provider.cluster[0].url
}

# External Secrets Operator IAM Role
resource "aws_iam_role" "external_secrets_operator" {
  count = var.enable_external_secrets ? 1 : 0

  name = var.external_secrets_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = local.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(local.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:${var.external_secrets_namespace}:${var.external_secrets_service_account}"
            "${replace(local.oidc_provider_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name    = var.external_secrets_role_name
    Purpose = "External Secrets Operator"
    Service = "external-secrets"
  })
}

# External Secrets Operator IAM Policy
resource "aws_iam_policy" "external_secrets_operator" {
  count = var.enable_external_secrets ? 1 : 0

  name        = "${var.external_secrets_role_name}-policy"
  description = "Policy for External Secrets Operator to access AWS Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets",
          "secretsmanager:ListSecretVersionIds"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:ListSecrets"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name    = "${var.external_secrets_role_name}-policy"
    Purpose = "External Secrets Operator Policy"
  })
}

# Attach policy to External Secrets role
resource "aws_iam_role_policy_attachment" "external_secrets_operator" {
  count = var.enable_external_secrets ? 1 : 0

  role       = aws_iam_role.external_secrets_operator[0].name
  policy_arn = aws_iam_policy.external_secrets_operator[0].arn
}

# Lab Controller ECR IAM Role
resource "aws_iam_role" "lab_controller" {
  count = var.enable_lab_controller ? 1 : 0

  name = var.lab_controller_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = local.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(local.oidc_provider_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "${replace(local.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:*-lab:*"
          }
        }
      },
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = local.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(local.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:${var.lab_controller_namespace}:${var.lab_controller_service_account}"
            "${replace(local.oidc_provider_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name    = var.lab_controller_role_name
    Purpose = "Lab Controller ECR Access"
    Service = "lab-controller"
  })
}

# Lab Controller ECR IAM Policy - Access to all repositories
resource "aws_iam_policy" "lab_controller" {
  count = var.enable_lab_controller ? 1 : 0

  name        = "${var.lab_controller_role_name}-policy"
  description = "ECR permissions for Lab Controller - access to all repositories"

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
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name    = "${var.lab_controller_role_name}-policy"
    Purpose = "Lab Controller ECR Policy"
  })
}

# Attach basic policy to Lab Controller role
resource "aws_iam_role_policy_attachment" "lab_controller" {
  count = var.enable_lab_controller ? 1 : 0

  role       = aws_iam_role.lab_controller[0].name
  policy_arn = aws_iam_policy.lab_controller[0].arn
}

# External DNS IAM Role
resource "aws_iam_role" "external_dns" {
  count = var.enable_external_dns ? 1 : 0

  name = var.external_dns_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = local.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(local.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:${var.external_dns_namespace}:${var.external_dns_service_account}"
            "${replace(local.oidc_provider_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name    = var.external_dns_role_name
    Purpose = "External DNS"
    Service = "external-dns"
  })
}

# External DNS IAM Policy
resource "aws_iam_policy" "external_dns" {
  count = var.enable_external_dns ? 1 : 0

  name        = "${var.external_dns_role_name}-policy"
  description = "Policy for External DNS to manage Route53 records"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets"
        ]
        # Allow writing to any hosted zone (not restricted to specific zone)
        Resource = var.route53_hosted_zone_id != "" ? [
          "arn:aws:route53:::hostedzone/${var.route53_hosted_zone_id}"
          ] : [
          "arn:aws:route53:::hostedzone/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:GetChange",
          "route53:ListTagsForResource"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name    = "${var.external_dns_role_name}-policy"
    Purpose = "External DNS Policy"
  })
}

# Attach policy to External DNS role
resource "aws_iam_role_policy_attachment" "external_dns" {
  count = var.enable_external_dns ? 1 : 0

  role       = aws_iam_role.external_dns[0].name
  policy_arn = aws_iam_policy.external_dns[0].arn
}

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# Cert-Manager IAM Role
resource "aws_iam_role" "cert_manager" {
  count = var.enable_cert_manager ? 1 : 0

  name = var.cert_manager_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = local.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            # Fully qualified OIDC condition keys (not placeholders)
            # Format: oidc.eks.REGION.amazonaws.com/id/OIDC_ID:sub
            "${replace(local.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:${var.cert_manager_namespace}:${var.cert_manager_service_account}"
            "${replace(local.oidc_provider_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  # Force update if assume_role_policy changes (e.g., when OIDC provider URL is fixed)
  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name    = var.cert_manager_role_name
    Purpose = "cert-manager Route53 DNS-01 Challenge"
    Service = "cert-manager"
  })
}

# Cert-Manager IAM Policy for Route53
# Cert-manager needs access to ALL hosted zones to:
# 1. Find the correct hosted zone for any domain
# 2. Create TXT records for DNS-01 challenges in any hosted zone
resource "aws_iam_policy" "cert_manager" {
  count = var.enable_cert_manager ? 1 : 0

  name        = "${var.cert_manager_role_name}-policy"
  description = "Policy for cert-manager to manage Route53 records for DNS-01 challenge (all hosted zones)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "route53:GetChange"
        Resource = "arn:aws:route53:::change/*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets"
        ]
        # Allow access to ALL hosted zones (cert-manager needs to work with any domain)
        Resource = var.cert_manager_route53_hosted_zone_id != "" ? [
          "arn:aws:route53:::hostedzone/${var.cert_manager_route53_hosted_zone_id}"
          ] : [
          "arn:aws:route53:::hostedzone/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListHostedZonesByName"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name    = "${var.cert_manager_role_name}-policy"
    Purpose = "cert-manager Route53 Policy"
  })
}

# Attach policy to cert-manager role
resource "aws_iam_role_policy_attachment" "cert_manager" {
  count = var.enable_cert_manager ? 1 : 0

  role       = aws_iam_role.cert_manager[0].name
  policy_arn = aws_iam_policy.cert_manager[0].arn
}
