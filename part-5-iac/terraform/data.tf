data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_eks_cluster_auth" "cluster" {
  name     = module.eks_cluster.cluster_name
  provider = aws
}

locals {
  aws_account_id = data.aws_caller_identity.current.account_id
}