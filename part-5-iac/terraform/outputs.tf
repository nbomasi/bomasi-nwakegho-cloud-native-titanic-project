# General Outputs
output "aws_region" {
  description = "AWS region where resources are deployed"
  value       = var.aws_region
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "project_name" {
  description = "Project name"
  value       = var.project_name
}

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.networking.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.networking.public_subnets
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.networking.private_subnets
}

# Route53 Hosted Zone Outputs
output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = var.enable_route53_hosted_zone ? module.route53_hosted_zone[0].zone_id : null
}

output "route53_zone_arn" {
  description = "Route53 hosted zone ARN"
  value       = var.enable_route53_hosted_zone ? module.route53_hosted_zone[0].zone_arn : null
}

output "route53_name_servers" {
  description = "Name servers for the hosted zone (configure these in your domain registrar)"
  value       = var.enable_route53_hosted_zone ? module.route53_hosted_zone[0].name_servers : null
}


output "route53_domain_name" {
  description = "Domain name for the hosted zone"
  value       = var.enable_route53_hosted_zone ? module.route53_hosted_zone[0].domain_name : null
}

# EKS Outputs
output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks_cluster.cluster_id
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks_cluster.cluster_arn
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks_cluster.cluster_endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks_cluster.cluster_name
}

output "cluster_version" {
  description = "EKS cluster version"
  value       = module.eks_cluster.cluster_version
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks_cluster.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks_cluster.cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider"
  value       = module.eks_cluster.oidc_provider_arn
}

output "cluster_access_command" {
  description = "Command to update kubeconfig for cluster access"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks_cluster.cluster_name}"
}

# IAM Outputs
output "eks_admin_group_name" {
  description = "Name of the IAM group for EKS cluster administrators"
  value       = module.eks_cluster.admin_group_name
}

output "eks_admin_role_name" {
  description = "Name of the IAM role for EKS cluster administrators"
  value       = module.eks_cluster.admin_role_name
}

# NGINX Ingress Outputs
output "nginx_ingress_namespace" {
  description = "NGINX Ingress Controller namespace"
  value       = var.enable_nginx_ingress ? module.nginx_ingress[0].namespace : null
}

output "nginx_ingress_loadbalancer_hostname" {
  description = "NGINX Ingress Controller LoadBalancer hostname"
  value       = var.enable_nginx_ingress ? module.nginx_ingress[0].loadbalancer_hostname : null
}

output "nginx_ingress_access_instructions" {
  description = "Instructions to access services via NGINX Ingress"
  value       = var.enable_nginx_ingress ? "NGINX Ingress deployed! LoadBalancer: ${module.nginx_ingress[0].loadbalancer_hostname}. Point your domains to this hostname." : null
}


# IAM Roles for Service Accounts Outputs
output "external_secrets_role_arn" {
  description = "ARN of the External Secrets Operator IAM role"
  value       = var.enable_external_secrets ? module.iam_roles_for_service_accounts.external_secrets_role_arn : null
}

output "external_secrets_role_name" {
  description = "Name of the External Secrets Operator IAM role"
  value       = var.enable_external_secrets ? module.iam_roles_for_service_accounts.external_secrets_role_name : null
}

# Lab Controller Outputs
output "lab_controller_role_arn" {
  description = "ARN of the Lab Controller ECR IAM role"
  value       = var.enable_lab_controller ? module.iam_roles_for_service_accounts.lab_controller_role_arn : null
}

output "lab_controller_role_name" {
  description = "Name of the Lab Controller ECR IAM role"
  value       = var.enable_lab_controller ? module.iam_roles_for_service_accounts.lab_controller_role_name : null
}

# ECR Outputs
output "ecr_pipeline_policy_arn" {
  description = "ARN of the ECR pipeline policy"
  value       = module.ecr.ecr_pipeline_policy_arn
}

output "ecr_pull_policy_arn" {
  description = "ARN of the ECR pull policy (for pod IRSA roles)"
  value       = module.ecr.ecr_pull_policy_arn
}

output "ecr_registry_url" {
  description = "ECR Registry URL"
  value       = module.ecr.ecr_registry_url
}

output "ecr_registry_id" {
  description = "ECR Registry ID (AWS Account ID)"
  value       = module.ecr.ecr_registry_id
}

output "ecr_namespace" {
  description = "ECR namespace/prefix for repositories"
  value       = module.ecr.ecr_namespace
}

output "ecr_repository_base_url" {
  description = "Base URL for ECR repositories"
  value       = "${module.ecr.ecr_registry_url}/${module.ecr.ecr_namespace}"
}

output "external_dns_role_arn" {
  description = "ARN of the External DNS IAM role"
  value       = var.enable_external_dns ? module.iam_roles_for_service_accounts.external_dns_role_arn : null
}

output "external_dns_role_name" {
  description = "Name of the External DNS IAM role"
  value       = var.enable_external_dns ? module.iam_roles_for_service_accounts.external_dns_role_name : null
}

# External DNS namespace output removed - managed manually via Helm script
# Kube Prometheus Stack outputs removed - managed manually via Helm script

# External Secrets Operator Outputs
output "external_secrets_operator_namespace" {
  description = "Namespace where External Secrets Operator is deployed"
  value       = var.enable_external_secrets_operator ? module.external_secrets_operator[0].namespace : null
}

# RDS PostgreSQL Outputs
output "rds_postgresql_instance_id" {
  description = "RDS PostgreSQL instance ID"
  value       = var.enable_rds_postgresql ? module.rds_postgresql[0].db_instance_id : null
}

output "rds_postgresql_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = var.enable_rds_postgresql ? module.rds_postgresql[0].db_instance_endpoint : null
}

output "rds_postgresql_address" {
  description = "RDS PostgreSQL address"
  value       = var.enable_rds_postgresql ? module.rds_postgresql[0].db_instance_address : null
}

output "rds_postgresql_port" {
  description = "RDS PostgreSQL port"
  value       = var.enable_rds_postgresql ? module.rds_postgresql[0].db_instance_port : null
}

output "rds_postgresql_database_name" {
  description = "RDS PostgreSQL database name"
  value       = var.enable_rds_postgresql ? module.rds_postgresql[0].db_instance_name : null
}

output "rds_postgresql_secrets_manager_secret_arn" {
  description = "ARN of the Secrets Manager secret containing RDS credentials"
  value       = var.enable_rds_postgresql ? module.rds_postgresql[0].secrets_manager_secret_arn : null
}

output "rds_postgresql_secrets_manager_secret_name" {
  description = "Name of the Secrets Manager secret containing RDS credentials"
  value       = var.enable_rds_postgresql ? module.rds_postgresql[0].secrets_manager_secret_name : null
}

output "rds_postgresql_security_group_id" {
  description = "Security group ID for RDS PostgreSQL"
  value       = var.enable_rds_postgresql ? module.rds_postgresql[0].security_group_id : null
}

output "app_jwt_secret_arn" {
  description = "ARN of the Secrets Manager secret containing JWT secret key"
  value       = var.jwt_secret_key != "" ? aws_secretsmanager_secret.app_jwt_secret[0].arn : null
  sensitive   = true
}

output "app_jwt_secret_name" {
  description = "Name of the Secrets Manager secret containing JWT secret key"
  value       = var.jwt_secret_key != "" ? aws_secretsmanager_secret.app_jwt_secret[0].name : null
  sensitive   = true
}

# Cert-Manager Outputs
output "cert_manager_role_arn" {
  description = "ARN of the IAM role for cert-manager"
  value       = var.enable_cert_manager ? module.iam_roles_for_service_accounts.cert_manager_role_arn : null
}

output "cert_manager_role_name" {
  description = "Name of the IAM role for cert-manager"
  value       = var.enable_cert_manager ? module.iam_roles_for_service_accounts.cert_manager_role_name : null
}

output "cert_manager_service_account_name" {
  description = "Service account name for cert-manager"
  value       = var.enable_cert_manager ? var.cert_manager_service_account : null
}

# Cert-Manager namespace output removed - managed manually via Helm script

# Storage Class Outputs
output "auto_ebs_storage_class_name" {
  description = "Name of the auto-created EBS storage class"
  value       = kubernetes_storage_class.auto_mode_ebs.metadata[0].name
}
