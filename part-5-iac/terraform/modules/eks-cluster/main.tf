data "aws_caller_identity" "current" {}

resource "aws_kms_key" "eks_cluster" {
  description             = "EKS Cluster Secret Encryption Key"
  deletion_window_in_days = 7

  tags = merge(
    {
      Name = "${var.cluster_name}-eks-cluster-key"
    },
    var.tags
  )
}

resource "aws_kms_alias" "eks_cluster" {
  name          = "alias/${var.cluster_name}-eks-cluster"
  target_key_id = aws_kms_key.eks_cluster.key_id
}

module "eks" {
  source                                   = "terraform-aws-modules/eks/aws"
  version                                  = "~> 20.31"
  cluster_name                             = var.cluster_name
  cluster_version                          = var.kubernetes_version
  cluster_endpoint_public_access           = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
  enable_cluster_creator_admin_permissions = true
  cluster_compute_config = {
    enabled    = var.enable_auto_mode
    node_pools = ["general-purpose"]
  }
  cluster_upgrade_policy = {
    support_type = "STANDARD"
  }

  # EKS Add-ons
  # Manage VPC CNI to enable Prefix Delegation (more pod IPs per node)
  # EBS CSI Driver should be automatically managed by EKS Auto Mode
  cluster_addons = {
    vpc-cni = {
      most_recent       = true
      resolve_conflicts = "OVERWRITE"
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
          # Optionally tune IP targets further
          # MINIMUM_IP_TARGET      = "10"
        }
      })
    }
  }

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids
  tags       = var.tags
}

resource "aws_iam_group" "eks_admins" {
  name = "${var.cluster_name}-eks-admin-group"
}

resource "aws_iam_role" "eks_admins" {
  name = "${var.cluster_name}-eks-admin-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        "AWS" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      },
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:PrincipalType" = "User"
        }
      }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "eks_admins" {
  role       = aws_iam_role.eks_admins.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_policy" "eks_assume_role" {
  name        = "${var.cluster_name}-eks-assume-role-policy"
  description = "Allows users in the group to assume the eks-admins-role"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = aws_iam_role.eks_admins.arn
    }]
  })
  tags = var.tags
}

resource "aws_iam_group_policy_attachment" "eks_assume_role" {
  group      = aws_iam_group.eks_admins.name
  policy_arn = aws_iam_policy.eks_assume_role.arn
}

resource "aws_eks_access_entry" "admins" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.eks_admins.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admins" {
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_iam_role.eks_admins.arn
  access_scope {
    type = "cluster"
  }
}

