variable "namespace" {
  description = "Namespace for NGINX Ingress Controller"
  type        = string
  default     = "ingress-nginx"
}

variable "chart_version" {
  description = "NGINX Ingress Controller Helm chart version"
  type        = string
  default     = "4.11.3"
}

variable "lb_scheme" {
  description = "AWS Load Balancer scheme (internet-facing or internal)"
  type        = string
  default     = "internet-facing"
}

variable "use_nlb" {
  description = "Use NLB for NGINX Ingress (true = NLB, false = CLB)"
  type        = bool
  default     = true
}

variable "service_type" {
  description = "Service type for NGINX controller (LoadBalancer or ClusterIP)"
  type        = string
  default     = "LoadBalancer"
  validation {
    condition     = contains(["LoadBalancer", "ClusterIP", "NodePort"], var.service_type)
    error_message = "service_type must be one of: LoadBalancer, ClusterIP, NodePort"
  }
}

variable "default_ingress_class" {
  description = "Set NGINX as default ingress class"
  type        = bool
  default     = false
}

variable "replica_count" {
  description = "Number of NGINX Ingress Controller replicas"
  type        = number
  default     = 2
}

variable "cpu_request" {
  description = "CPU request for NGINX Ingress Controller"
  type        = string
  default     = "100m"
}

variable "memory_request" {
  description = "Memory request for NGINX Ingress Controller"
  type        = string
  default     = "128Mi"
}

variable "cpu_limit" {
  description = "CPU limit for NGINX Ingress Controller"
  type        = string
  default     = "1000m"
}

variable "memory_limit" {
  description = "Memory limit for NGINX Ingress Controller"
  type        = string
  default     = "512Mi"
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for LoadBalancer"
  type        = list(string)
}

