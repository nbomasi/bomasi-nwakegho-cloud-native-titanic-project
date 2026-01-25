variable "namespace" {
  description = "Kubernetes namespace for External Secrets Operator"
  type        = string
  default     = "external-secrets-system"
}

variable "chart_version" {
  description = "External Secrets Operator Helm chart version"
  type        = string
  default     = "0.10.3"
}

variable "irsa_role_arn" {
  description = "IAM role ARN for service account (IRSA)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

