terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.95.0, < 6.0.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.4"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.25.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.0"
    }
  }

  # S3 Backend Configuration
  backend "s3" {}
}

# Configure the AWS provider
provider "aws" {
  region = var.aws_region
  # Profile is optional - only set if provided (not empty)
  # If empty, Terraform will use default credentials (environment variables, IAM role, etc.)
  profile = var.aws_profile != "" ? var.aws_profile : null

  default_tags {
    tags = merge(
      {
        Environment = var.environment
        Project     = var.project_name
        ManagedBy   = "Terraform"
        Owner       = var.owner
      },
      var.additional_tags
    )
  }
}

# TLS provider
provider "tls" {
}

# Kubernetes provider
provider "kubernetes" {
  host                   = module.eks_cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_cluster.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = concat(
      [
        "eks",
        "get-token",
        "--cluster-name",
        module.eks_cluster.cluster_name,
        "--region",
        var.aws_region
      ],
      var.aws_profile != "" ? ["--profile", var.aws_profile] : []
    )
  }
}

# Helm provider
provider "helm" {
  kubernetes {
    host                   = module.eks_cluster.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_cluster.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = concat(
        [
          "eks",
          "get-token",
          "--cluster-name",
          module.eks_cluster.cluster_name,
          "--region",
          var.aws_region
        ],
        var.aws_profile != "" ? ["--profile", var.aws_profile] : []
      )
    }
  }
}

# Kubectl provider
provider "kubectl" {
  host                   = module.eks_cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_cluster.cluster_certificate_authority_data)
  load_config_file       = false
  token                  = data.aws_eks_cluster_auth.cluster.token

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = concat(
      [
        "eks",
        "get-token",
        "--cluster-name",
        module.eks_cluster.cluster_name,
        "--region",
        var.aws_region
      ],
      var.aws_profile != "" ? ["--profile", var.aws_profile] : []
    )
  }
}

