# AWS Configuration
variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "eu-west-2"
}

# ECR Configuration
variable "ecr_namespace" {
  description = "ECR namespace/prefix for repositories (pipeline will create repos under this namespace)"
  type        = string
  default     = "titanic-api"
}

variable "ecr_repositories" {
  description = "List of ECR repository names to create"
  type        = list(string)
  default     = []
}

# Project Configuration
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "titanic-api"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "owner" {
  description = "Owner/team responsible for the resources"
  type        = string
  default     = "titanic-api-team"
}

variable "aws_profile" {
  description = "AWS profile to use for authentication"
  type        = string
  default     = ""
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "availability_zones" {
  description = "List of availability zones (leave empty for auto-selection of 3 AZs)"
  type        = list(string)
  default     = []
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (leave empty for auto-calculation)"
  type        = list(string)
  default     = []
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (leave empty for auto-calculation)"
  type        = list(string)
  default     = []
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway instead of one per AZ (saves ~$32/month, but single point of failure)"
  type        = bool
  default     = false
}

# EKS Configuration
variable "kubernetes_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.34"

  validation {
    condition     = can(regex("^\\d+\\.\\d+$", var.kubernetes_version))
    error_message = "kubernetes_version must be in format X.Y (e.g., 1.34)."
  }
}

variable "enable_auto_mode" {
  description = "Enable EKS Auto Mode (includes Karpenter for automatic node provisioning)"
  type        = bool
  default     = true
}

variable "enable_autoscaling_nodepool_tuning" {
  description = "Apply opinionated NodePool settings to widen instance choices and reduce Pending pods"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Whether or not the Amazon EKS public API server endpoint is enabled"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks which can access the Amazon EKS public API server endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Kubeconfig Configuration

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}


# NGINX Ingress Controller Configuration
variable "enable_nginx_ingress" {
  description = "Enable NGINX Ingress Controller deployment"
  type        = bool
  default     = false
}

variable "nginx_ingress_namespace" {
  description = "Namespace for NGINX Ingress Controller"
  type        = string
  default     = "ingress-nginx"
}

variable "nginx_ingress_chart_version" {
  description = "NGINX Ingress Controller Helm chart version"
  type        = string
  default     = "4.11.3" # Latest stable version
}

variable "nginx_ingress_lb_scheme" {
  description = "AWS Load Balancer scheme for NGINX (internet-facing or internal)"
  type        = string
  default     = "internet-facing"
}

variable "nginx_ingress_use_nlb" {
  description = "Use NLB for NGINX Ingress (true = NLB, false = CLB)"
  type        = bool
  default     = true
}

variable "nginx_ingress_service_type" {
  description = "Service type for NGINX controller (LoadBalancer or ClusterIP)"
  type        = string
  default     = "LoadBalancer"
}

variable "nginx_ingress_default_class" {
  description = "Set NGINX as default ingress class"
  type        = bool
  default     = false
}

variable "nginx_ingress_replica_count" {
  description = "Number of NGINX Ingress Controller replicas"
  type        = number
  default     = 2
}

variable "nginx_ingress_cpu_request" {
  description = "CPU request for NGINX Ingress Controller"
  type        = string
  default     = "100m"
}

variable "nginx_ingress_memory_request" {
  description = "Memory request for NGINX Ingress Controller"
  type        = string
  default     = "128Mi"
}

variable "nginx_ingress_cpu_limit" {
  description = "CPU limit for NGINX Ingress Controller"
  type        = string
  default     = "1000m"
}

variable "nginx_ingress_memory_limit" {
  description = "Memory limit for NGINX Ingress Controller"
  type        = string
  default     = "512Mi"
}


# Route53 Hosted Zone Configuration
variable "enable_route53_hosted_zone" {
  description = "Enable Route53 hosted zone creation"
  type        = bool
  default     = false
}

variable "route53_domain_name" {
  description = "Domain name for the Route53 hosted zone"
  type        = string
  default     = "titanic-api.example.com"
}

variable "route53_parent_zone_name" {
  description = "Parent domain name (e.g., example.com for titanic-api.example.com subdomain) - for automatic delegation"
  type        = string
  default     = ""
}

variable "route53_create_parent_delegation" {
  description = "Whether to create NS delegation record in parent zone (requires parent zone to exist)"
  type        = bool
  default     = false
}

variable "route53_zone_comment" {
  description = "Comment for the Route53 hosted zone"
  type        = string
  default     = "Managed by Terraform"
}

variable "route53_force_destroy" {
  description = "Whether to destroy all records in the zone when deleting"
  type        = bool
  default     = false
}

variable "route53_ns_ttl" {
  description = "TTL for NS delegation records in seconds"
  type        = number
  default     = 172800
}

# Cert-Manager Configuration
variable "enable_cert_manager" {
  description = "Enable cert-manager installation"
  type        = bool
  default     = false
}

variable "cert_manager_namespace" {
  description = "Namespace for cert-manager"
  type        = string
  default     = "cert-manager"
}

variable "cert_manager_service_account" {
  description = "Kubernetes service account name for cert-manager"
  type        = string
  default     = "cert-manager"
}

variable "cert_manager_version" {
  description = "Version of cert-manager to install"
  type        = string
  default     = "v1.13.3"
}

variable "enable_letsencrypt_prod" {
  description = "Enable Let's Encrypt production ClusterIssuer"
  type        = bool
  default     = true
}

variable "enable_letsencrypt_staging" {
  description = "Enable Let's Encrypt staging ClusterIssuer (for testing)"
  type        = bool
  default     = true
}

variable "letsencrypt_email" {
  description = "Email address for Let's Encrypt account (required for certificate notifications)"
  type        = string
  default     = ""
}

# External Secrets Operator Configuration
variable "enable_external_secrets" {
  description = "Enable External Secrets Operator IAM role"
  type        = bool
  default     = false
}

# Lab Controller Configuration
variable "enable_lab_controller" {
  description = "Enable Lab Controller ECR IAM role"
  type        = bool
  default     = true
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
  description = "Enable External DNS module"
  type        = bool
  default     = false
}

variable "external_dns_namespace" {
  description = "Kubernetes namespace for External DNS"
  type        = string
  default     = "external-dns-system"
}

variable "external_dns_chart_version" {
  description = "Version of the External DNS Helm chart (leave empty for latest)"
  type        = string
  default     = "" # Use latest version - pinning can cause version not found errors
}

variable "external_dns_service_account" {
  description = "Service account name for External DNS"
  type        = string
  default     = "external-dns"
}

variable "external_dns_txt_owner_id" {
  description = "TXT record owner ID for External DNS (unique identifier)"
  type        = string
  default     = ""
}

variable "external_dns_domain_filters" {
  description = "Domain filters for External DNS (only manage DNS for these domains)"
  type        = list(string)
  default     = []
}

variable "external_dns_hosted_zone_id" {
  description = "Route53 hosted zone ID for External DNS (if not using route53_hosted_zone module)"
  type        = string
  default     = ""
}

variable "external_dns_policy" {
  description = "Policy for External DNS (sync, upsert-only, create-only). Use 'upsert-only' to prevent deletion of records and allow manual additions."
  type        = string
  default     = "upsert-only"
}

variable "external_dns_resources" {
  description = "Resource requests and limits for External DNS"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "100m"
      memory = "128Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "512Mi"
    }
  }
}

variable "external_dns_exclude_dns_record_types" {
  description = "List of DNS record types to exclude (e.g., ['AAAA'] to disable IPv6 records)"
  type        = list(string)
  default     = []
}

# ACM Certificate Configuration
variable "enable_acm_certificate" {
  description = "Enable ACM certificate creation"
  type        = bool
  default     = false
}

variable "acm_domain_name" {
  description = "Primary domain name for the ACM certificate (supports wildcard, e.g., *.titanic-api.example.com)"
  type        = string
  default     = ""
}

variable "acm_subject_alternative_names" {
  description = "Additional domain names for the ACM certificate (e.g., apex domain)"
  type        = list(string)
  default     = []
}

variable "acm_route53_zone_id" {
  description = "Route53 hosted zone ID for ACM DNS validation (if not using route53_hosted_zone module)"
  type        = string
  default     = ""
}

variable "acm_enable_validation" {
  description = "Enable ACM certificate validation wait (set to false to skip validation and apply other resources first)"
  type        = bool
  default     = false
}

variable "acm_validation_timeout" {
  description = "Timeout for ACM certificate validation"
  type        = string
  default     = "30m"
}

# RDS PostgreSQL Configuration
variable "enable_rds_postgresql" {
  description = "Enable RDS PostgreSQL deployment"
  type        = bool
  default     = false
}

variable "rds_postgresql_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "17.6"
}

variable "rds_postgresql_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_postgresql_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "rds_postgresql_max_allocated_storage" {
  description = "Maximum allocated storage for autoscaling in GB"
  type        = number
  default     = 100
}

variable "rds_postgresql_storage_type" {
  description = "Storage type (gp3, gp2, io1)"
  type        = string
  default     = "gp3"
}

variable "rds_postgresql_storage_encrypted" {
  description = "Enable storage encryption"
  type        = bool
  default     = true
}

variable "rds_postgresql_database_name" {
  description = "Name of the database to create"
  type        = string
  default     = "titanicapi"
}

variable "rds_postgresql_master_username" {
  description = "Master username for RDS"
  type        = string
  default     = "postgres"
}

variable "rds_password" {
  description = "Master password (leave empty to auto-generate and store in Secrets Manager). MUST be set via TF_VAR_rds_password environment variable - DO NOT put in .tfvars files."
  type        = string
  default     = ""
  sensitive   = true
}

variable "jwt_secret_key" {
  description = "JWT secret key for application authentication. MUST be set via TF_VAR_jwt_secret_key environment variable - DO NOT put in .tfvars files. This will be stored in AWS Secrets Manager."
  type        = string
  default     = ""
  sensitive   = true
}

variable "rds_postgresql_backup_retention_period" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}

variable "rds_postgresql_backup_window" {
  description = "Preferred backup window"
  type        = string
  default     = "03:00-04:00"
}

variable "rds_postgresql_maintenance_window" {
  description = "Preferred maintenance window"
  type        = string
  default     = "mon:04:00-mon:05:00"
}

variable "rds_postgresql_multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

variable "rds_postgresql_deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

variable "rds_postgresql_skip_final_snapshot" {
  description = "Skip final snapshot on deletion"
  type        = bool
  default     = false
}

variable "rds_postgresql_allowed_security_group_ids" {
  description = "List of security group IDs allowed to access RDS"
  type        = list(string)
  default     = []
}

variable "rds_postgresql_allow_eks_access" {
  description = "Allow EKS cluster security group to access RDS"
  type        = bool
  default     = true
}

variable "rds_postgresql_allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access RDS"
  type        = list(string)
  default     = []
}

variable "rds_postgresql_port" {
  description = "Database port"
  type        = number
  default     = 5432
}

variable "rds_postgresql_enabled_cloudwatch_logs_exports" {
  description = "List of log types to export to CloudWatch"
  type        = list(string)
  default     = ["postgresql", "upgrade"]
}

variable "rds_postgresql_performance_insights_enabled" {
  description = "Enable Performance Insights"
  type        = bool
  default     = false
}

# External Secrets Operator Configuration
variable "enable_external_secrets_operator" {
  description = "Enable External Secrets Operator deployment"
  type        = bool
  default     = false
}

variable "external_secrets_namespace" {
  description = "Namespace for External Secrets Operator"
  type        = string
  default     = "external-secrets-system"
}

variable "external_secrets_service_account" {
  description = "Kubernetes service account name for External Secrets Operator"
  type        = string
  default     = "external-secrets-operator"
}

variable "external_secrets_chart_version" {
  description = "External Secrets Operator Helm chart version"
  type        = string
  default     = "0.10.3"
}



# Kube Prometheus Stack Configuration
variable "enable_kube_prometheus_stack" {
  description = "Enable kube-prometheus-stack deployment"
  type        = bool
  default     = false
}

variable "kube_prometheus_stack_namespace" {
  description = "Namespace for kube-prometheus-stack"
  type        = string
  default     = "monitoring"
}

variable "kube_prometheus_stack_chart_version" {
  description = "kube-prometheus-stack Helm chart version"
  type        = string
  default     = "56.8.0"
}

variable "kube_prometheus_stack_retention" {
  description = "Prometheus retention period"
  type        = string
  default     = "30d"
}

variable "kube_prometheus_stack_storage_size" {
  description = "Prometheus persistent volume size"
  type        = string
  default     = "50Gi"
}

variable "kube_prometheus_stack_storage_class" {
  description = "Storage class for Prometheus persistent volume. Defaults to 'auto-ebs-sc' (created by Terraform). Leave empty to use the auto-created storage class."
  type        = string
  default     = "" # Empty string uses kubernetes_storage_class.auto_mode_ebs
}

variable "kube_prometheus_stack_grafana_password_secret_name" {
  description = "Name of the Kubernetes secret containing Grafana admin password (managed by External Secrets)"
  type        = string
  default     = "grafana-admin-password"
}

variable "kube_prometheus_stack_grafana_password_secret_key" {
  description = "Key in the secret containing the Grafana admin password"
  type        = string
  default     = "password"
}

variable "kube_prometheus_stack_enable_grafana_ingress" {
  description = "Enable ingress for Grafana"
  type        = bool
  default     = false
}

variable "kube_prometheus_stack_grafana_domain" {
  description = "Domain for Grafana (for ingress)"
  type        = string
  default     = "grafana.example.com"
}

variable "kube_prometheus_stack_grafana_ingress_class" {
  description = "Ingress class for Grafana (alb or nginx)"
  type        = string
  default     = "nginx"
}

variable "kube_prometheus_stack_grafana_tls_secret_name" {
  description = "TLS secret name for Grafana ingress (empty to disable TLS)"
  type        = string
  default     = ""
}
