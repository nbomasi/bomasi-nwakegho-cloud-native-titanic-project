output "namespace" {
  description = "NGINX Ingress Controller namespace"
  value       = var.namespace
}

output "loadbalancer_hostname" {
  description = "NGINX Ingress Controller LoadBalancer hostname"
  value       = try(data.kubernetes_service.nginx_ingress_controller.status[0].load_balancer[0].ingress[0].hostname, "pending")
}

output "loadbalancer_ip" {
  description = "NGINX Ingress Controller LoadBalancer IP (if available)"
  value       = try(data.kubernetes_service.nginx_ingress_controller.status[0].load_balancer[0].ingress[0].ip, null)
}

output "helm_release_id" {
  description = "Helm release ID for dependency tracking"
  value       = helm_release.nginx_ingress.id
}

