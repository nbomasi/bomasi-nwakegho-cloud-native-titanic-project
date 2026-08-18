module "iam_roles_for_service_accounts" {
  source = "./modules/iam-roles-for-service-accounts"

  cluster_name      = module.eks_cluster.cluster_name
  aws_region        = var.aws_region
  oidc_provider_arn = module.eks_cluster.oidc_provider_arn
  # oidc_provider output from EKS module is a string (URL), not an object
  # Use it directly as the URL
  oidc_provider_url    = try(module.eks_cluster.oidc_provider.url, module.eks_cluster.oidc_provider)
  use_oidc_from_module = true

  # External Secrets Operator
  enable_external_secrets          = var.enable_external_secrets
  external_secrets_role_name       = "${var.project_name}-${var.environment}-external-secrets-operator-role"
  external_secrets_namespace       = var.external_secrets_namespace
  external_secrets_service_account = var.external_secrets_service_account

  # External DNS
  enable_external_dns          = var.enable_external_dns
  external_dns_role_name       = "${var.project_name}-${var.environment}-external-dns-role"
  external_dns_namespace       = var.external_dns_namespace
  external_dns_service_account = var.external_dns_service_account
  route53_hosted_zone_id       = var.external_dns_hosted_zone_id != "" ? var.external_dns_hosted_zone_id : ""

  # Cert-Manager (IRSA role for cert-manager Helm installation)
  enable_cert_manager                 = var.enable_cert_manager
  cert_manager_role_name              = "${var.project_name}-${var.environment}-cert-manager-role"
  cert_manager_namespace              = var.cert_manager_namespace
  cert_manager_service_account        = var.cert_manager_service_account
  cert_manager_route53_hosted_zone_id = ""

  # Lab Controller ECR Access
  enable_lab_controller          = var.enable_lab_controller
  lab_controller_role_name       = "${var.project_name}-${var.environment}-lab-controller-ecr-role"
  lab_controller_namespace       = var.lab_controller_namespace
  lab_controller_service_account = var.lab_controller_service_account

  tags = local.common_tags

  depends_on = [module.eks_cluster, time_sleep.wait_for_cluster]
}

module "ecr" {
  source = "./modules/ecr"

  environment       = var.environment
  ecr_namespace     = var.ecr_namespace
  repositories      = var.ecr_repositories
  irsa_role_arn     = var.enable_lab_controller ? module.iam_roles_for_service_accounts.lab_controller_role_arn : ""
  pipeline_role_arn = ""

  tags = local.common_tags

  depends_on = [module.iam_roles_for_service_accounts]
}

# Attach ECR pull policy to lab controller role (pods can pull images)
resource "aws_iam_role_policy_attachment" "lab_controller_ecr_pull" {
  count = var.enable_lab_controller ? 1 : 0

  role       = module.iam_roles_for_service_accounts.lab_controller_role_name
  policy_arn = module.ecr.ecr_pull_policy_arn

  depends_on = [module.ecr, module.iam_roles_for_service_accounts]
}

module "networking" {
  source = "./modules/networking"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  availability_zones   = local.availability_zones
  public_subnet_cidrs  = local.public_subnet_cidrs
  private_subnet_cidrs = local.private_subnet_cidrs
  single_nat_gateway   = var.single_nat_gateway
  cluster_name         = local.name_prefix
  tags                 = local.common_tags
}

module "route53_hosted_zone" {
  source = "./modules/route53-hosted-zone"
  count  = var.enable_route53_hosted_zone ? 1 : 0

  domain_name              = var.route53_domain_name
  zone_comment             = var.route53_zone_comment
  force_destroy            = var.route53_force_destroy
  environment              = var.environment
  parent_zone_name         = var.route53_parent_zone_name
  create_parent_delegation = var.route53_create_parent_delegation
  ns_ttl                   = var.route53_ns_ttl
  tags                     = local.common_tags
}

module "eks_cluster" {
  source = "./modules/eks-cluster"

  cluster_name                         = local.name_prefix
  kubernetes_version                   = var.kubernetes_version
  enable_auto_mode                     = var.enable_auto_mode
  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  vpc_id                               = module.networking.vpc_id
  subnet_ids                           = module.networking.private_subnets
  tags                                 = local.common_tags

  depends_on = [module.networking]
}

# Wait for cluster to be ready before creating Kubernetes resources
# EKS clusters typically take 10-15 minutes to fully initialize
# This wait ensures the API server is accessible before Helm deployments
resource "time_sleep" "wait_for_cluster" {
  depends_on      = [module.eks_cluster]
  create_duration = "300s" # 5 minutes - allows cluster API to be fully ready
}

resource "kubernetes_storage_class" "auto_mode_ebs" {
  metadata {
    name = "auto-ebs-sc"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner = "ebs.csi.eks.amazonaws.com"

  volume_binding_mode = "WaitForFirstConsumer"

  parameters = {
    encrypted = "true"
  }

  depends_on = [module.eks_cluster, time_sleep.wait_for_cluster]
}

## Continuous NodePool Reconciler for EKS Auto Mode
## EKS Auto Mode manages the NodePool and reverts manual patches. This reconciler continuously
## applies our desired configuration to prevent reverting to restrictive defaults.
## Root Cause: EKS Auto Mode has `app.kubernetes.io/managed-by: eks` label, causing it to
## reconcile the NodePool back to default settings, which are too restrictive (instance-generation > 4).
module "karpenter_nodepool_reconciler" {
  source = "./modules/karpenter-nodepool-reconciler"
  count  = var.enable_auto_mode && var.enable_autoscaling_nodepool_tuning ? 1 : 0

  enable_nodepool_reconciler = var.enable_autoscaling_nodepool_tuning
  nodepool_name              = "general-purpose"
  reconcile_interval         = "60"

  depends_on = [module.eks_cluster, time_sleep.wait_for_cluster]
}

module "nginx_ingress" {
  source = "./modules/nginx-ingress"
  count  = var.enable_nginx_ingress ? 1 : 0

  namespace             = var.nginx_ingress_namespace
  chart_version         = var.nginx_ingress_chart_version
  lb_scheme             = var.nginx_ingress_lb_scheme
  use_nlb               = var.nginx_ingress_use_nlb
  service_type          = var.nginx_ingress_service_type
  default_ingress_class = var.nginx_ingress_default_class
  replica_count         = var.nginx_ingress_replica_count
  cpu_request           = var.nginx_ingress_cpu_request
  memory_request        = var.nginx_ingress_memory_request
  cpu_limit             = var.nginx_ingress_cpu_limit
  memory_limit          = var.nginx_ingress_memory_limit
  public_subnet_ids     = module.networking.public_subnets

  depends_on = [module.eks_cluster, time_sleep.wait_for_cluster]
}

# External DNS is now deployed manually via deploy-helm-charts.sh script
# IAM role is still managed by Terraform (iam_roles_for_service_accounts module)

module "external_secrets_operator" {
  source = "./modules/external-secrets-operator"
  count  = var.enable_external_secrets_operator ? 1 : 0

  namespace     = var.external_secrets_namespace
  chart_version = var.external_secrets_chart_version
  irsa_role_arn = module.iam_roles_for_service_accounts.external_secrets_role_arn

  depends_on = [module.eks_cluster, module.iam_roles_for_service_accounts, time_sleep.wait_for_cluster]
}


module "rds_postgresql" {
  source = "./modules/rds-postgresql"
  count  = var.enable_rds_postgresql ? 1 : 0

  name_prefix           = local.name_prefix
  environment           = var.environment
  engine_version        = var.rds_postgresql_engine_version
  instance_class        = var.rds_postgresql_instance_class
  allocated_storage     = var.rds_postgresql_allocated_storage
  max_allocated_storage = var.rds_postgresql_max_allocated_storage
  storage_type          = var.rds_postgresql_storage_type
  storage_encrypted     = var.rds_postgresql_storage_encrypted

  database_name   = var.rds_postgresql_database_name
  master_username = var.rds_postgresql_master_username
  master_password = var.rds_password

  backup_retention_period = var.rds_postgresql_backup_retention_period
  backup_window           = var.rds_postgresql_backup_window
  maintenance_window      = var.rds_postgresql_maintenance_window

  multi_az            = var.rds_postgresql_multi_az
  deletion_protection = var.rds_postgresql_deletion_protection
  skip_final_snapshot = var.rds_postgresql_skip_final_snapshot

  vpc_id     = module.networking.vpc_id
  subnet_ids = module.networking.private_subnets

  allowed_security_group_ids = concat(
    var.rds_postgresql_allowed_security_group_ids,
    var.enable_rds_postgresql && var.rds_postgresql_allow_eks_access ? [module.eks_cluster.cluster_security_group_id] : []
  )
  allowed_cidr_blocks = var.rds_postgresql_allowed_cidr_blocks

  port = var.rds_postgresql_port

  enabled_cloudwatch_logs_exports = var.rds_postgresql_enabled_cloudwatch_logs_exports
  performance_insights_enabled    = var.rds_postgresql_performance_insights_enabled

  tags = local.common_tags

  depends_on = [
    module.networking,
    module.eks_cluster
  ]
}

resource "aws_secretsmanager_secret" "app_jwt_secret" {
  count = var.jwt_secret_key != "" ? 1 : 0

  name        = "${local.name_prefix}-app-jwt-secret"
  description = "JWT secret key for Titanic API application"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-app-jwt-secret"
  })
}

resource "aws_secretsmanager_secret_version" "app_jwt_secret" {
  count = var.jwt_secret_key != "" ? 1 : 0

  secret_id = aws_secretsmanager_secret.app_jwt_secret[0].id
  secret_string = jsonencode({
    jwt_secret_key = var.jwt_secret_key
  })
}

# Kube Prometheus Stack is now deployed manually via deploy-helm-charts.sh script
# Storage class is still managed by Terraform (kubernetes_storage_class.auto_mode_ebs)

# Cert-Manager is now deployed manually via deploy-helm-charts.sh script
# IAM role is still managed by Terraform (iam_roles_for_service_accounts module)

