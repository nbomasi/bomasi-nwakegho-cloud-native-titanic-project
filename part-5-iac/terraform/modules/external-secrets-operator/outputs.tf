output "namespace" {
  description = "Namespace where External Secrets Operator is deployed"
  value       = var.namespace
}

output "release_name" {
  description = "Name of the Helm release"
  value       = helm_release.external_secrets.name
}

