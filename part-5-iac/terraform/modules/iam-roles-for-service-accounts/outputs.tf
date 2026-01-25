# Outputs for IAM Roles for Service Accounts Module

output "external_secrets_role_arn" {
  description = "ARN of the External Secrets Operator IAM role"
  value       = var.enable_external_secrets ? aws_iam_role.external_secrets_operator[0].arn : null
}

output "external_secrets_role_name" {
  description = "Name of the External Secrets Operator IAM role"
  value       = var.enable_external_secrets ? aws_iam_role.external_secrets_operator[0].name : null
}

output "external_secrets_policy_arn" {
  description = "ARN of the External Secrets Operator IAM policy"
  value       = var.enable_external_secrets ? aws_iam_policy.external_secrets_operator[0].arn : null
}

output "lab_controller_role_arn" {
  description = "ARN of the Lab Controller ECR IAM role"
  value       = var.enable_lab_controller ? aws_iam_role.lab_controller[0].arn : null
}

output "lab_controller_role_name" {
  description = "Name of the Lab Controller ECR IAM role"
  value       = var.enable_lab_controller ? aws_iam_role.lab_controller[0].name : null
}

output "lab_controller_policy_arn" {
  description = "ARN of the Lab Controller ECR IAM policy"
  value       = var.enable_lab_controller ? aws_iam_policy.lab_controller[0].arn : null
}

output "external_dns_role_arn" {
  description = "ARN of the External DNS IAM role"
  value       = var.enable_external_dns ? aws_iam_role.external_dns[0].arn : null
}

output "external_dns_role_name" {
  description = "Name of the External DNS IAM role"
  value       = var.enable_external_dns ? aws_iam_role.external_dns[0].name : null
}

output "external_dns_policy_arn" {
  description = "ARN of the External DNS IAM policy"
  value       = var.enable_external_dns ? aws_iam_policy.external_dns[0].arn : null
}

output "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider"
  value       = local.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "URL of the EKS OIDC provider"
  value       = local.oidc_provider_url
}

# Cert-Manager Outputs
output "cert_manager_role_arn" {
  description = "ARN of the cert-manager IAM role"
  value       = var.enable_cert_manager ? aws_iam_role.cert_manager[0].arn : null
}

output "cert_manager_role_name" {
  description = "Name of the cert-manager IAM role"
  value       = var.enable_cert_manager ? aws_iam_role.cert_manager[0].name : null
}

output "cert_manager_policy_arn" {
  description = "ARN of the cert-manager IAM policy"
  value       = var.enable_cert_manager ? aws_iam_policy.cert_manager[0].arn : null
}
