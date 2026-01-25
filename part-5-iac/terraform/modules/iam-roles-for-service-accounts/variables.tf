# Variables for IAM Roles for Service Accounts Module

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for the EKS cluster (from eks_cluster module)"
  type        = string
  default     = ""
}

variable "oidc_provider_url" {
  description = "URL of the OIDC provider for the EKS cluster (from eks_cluster module)"
  type        = string
  default     = ""
}

variable "use_oidc_from_module" {
  description = "Whether OIDC provider info is provided from module outputs (use this instead of checking ARN string for count)"
  type        = bool
  default     = false
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# External Secrets Operator Configuration
variable "enable_external_secrets" {
  description = "Enable External Secrets Operator IAM role"
  type        = bool
  default     = true
}

variable "external_secrets_role_name" {
  description = "Name of the IAM role for External Secrets Operator"
  type        = string
  default     = "external-secrets-operator-role"
}

variable "external_secrets_namespace" {
  description = "Kubernetes namespace for External Secrets Operator"
  type        = string
  default     = "external-secrets-system"
}

variable "external_secrets_service_account" {
  description = "Kubernetes service account name for External Secrets Operator"
  type        = string
  default     = "external-secrets-operator"
}

# Lab Controller Configuration
variable "enable_lab_controller" {
  description = "Enable Lab Controller ECR IAM role"
  type        = bool
  default     = true
}

variable "lab_controller_role_name" {
  description = "Name of the IAM role for Lab Controller ECR access"
  type        = string
  default     = "lab-controller-ecr-role"
}

variable "lab_controller_namespace" {
  description = "Kubernetes namespace for Lab Controller"
  type        = string
  default     = "lab-controller"
}

variable "lab_controller_service_account" {
  description = "Kubernetes service account name for Lab Controller"
  type        = string
  default     = "lab-controller"
}

# External DNS Configuration
variable "enable_external_dns" {
  description = "Enable External DNS IAM role"
  type        = bool
  default     = true
}

variable "external_dns_role_name" {
  description = "Name of the IAM role for External DNS"
  type        = string
  default     = "external-dns-role"
}

variable "external_dns_namespace" {
  description = "Kubernetes namespace for External DNS"
  type        = string
  default     = "external-dns-system"
}

variable "external_dns_service_account" {
  description = "Kubernetes service account name for External DNS"
  type        = string
  default     = "external-dns"
}

variable "route53_hosted_zone_id" {
  description = "Route53 hosted zone ID for External DNS"
  type        = string
  default     = ""
}

# Cert-Manager Configuration
variable "enable_cert_manager" {
  description = "Enable cert-manager IAM role for Route53"
  type        = bool
  default     = false
}

variable "cert_manager_role_name" {
  description = "Name of the IAM role for cert-manager"
  type        = string
  default     = "cert-manager-role"
}

variable "cert_manager_namespace" {
  description = "Kubernetes namespace for cert-manager"
  type        = string
  default     = "cert-manager"
}

variable "cert_manager_service_account" {
  description = "Kubernetes service account name for cert-manager"
  type        = string
  default     = "cert-manager"
}

variable "cert_manager_route53_hosted_zone_id" {
  description = "Route53 hosted zone ID for cert-manager (empty = allow all hosted zones). Cert-manager needs access to all zones to find the correct zone for any domain."
  type        = string
  default     = ""
}
