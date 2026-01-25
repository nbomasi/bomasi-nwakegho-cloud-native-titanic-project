output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_version" {
  description = "EKS cluster version"
  value       = module.eks.cluster_version
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_platform_version" {
  description = "Platform version for the EKS cluster"
  value       = module.eks.cluster_platform_version
}

output "cluster_primary_security_group_id" {
  description = "Cluster security group that was created by Amazon EKS for the cluster"
  value       = module.eks.cluster_primary_security_group_id
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "Security group ID attached to the EKS nodes"
  value       = module.eks.node_security_group_id
}

output "oidc_provider" {
  description = "The OpenID Connect identity provider information"
  value       = module.eks.oidc_provider
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider"
  value       = module.eks.oidc_provider_arn
}

output "kms_key_id" {
  description = "KMS key ID for EKS encryption"
  value       = aws_kms_key.eks_cluster.key_id
}

output "kms_key_arn" {
  description = "KMS key ARN for EKS encryption"
  value       = aws_kms_key.eks_cluster.arn
}

output "admin_group_name" {
  description = "Name of the IAM group for EKS cluster administrators"
  value       = aws_iam_group.eks_admins.name
}

output "admin_group_arn" {
  description = "ARN of the IAM group for EKS cluster administrators"
  value       = aws_iam_group.eks_admins.arn
}

output "admin_role_name" {
  description = "Name of the IAM role for EKS cluster administrators"
  value       = aws_iam_role.eks_admins.name
}

output "admin_role_arn" {
  description = "ARN of the IAM role for EKS cluster administrators"
  value       = aws_iam_role.eks_admins.arn
}

