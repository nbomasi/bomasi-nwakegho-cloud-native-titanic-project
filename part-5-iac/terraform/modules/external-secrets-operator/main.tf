terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.25.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12.0"
    }
  }
}

resource "kubernetes_namespace" "external_secrets" {
  metadata {
    name = var.namespace
    labels = {
      name = var.namespace
    }
  }
}

resource "kubernetes_service_account" "external_secrets" {
  metadata {
    name      = "external-secrets-operator"
    namespace = var.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = var.irsa_role_arn
    }
  }

  depends_on = [kubernetes_namespace.external_secrets]
}

resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = var.chart_version
  namespace  = var.namespace

  values = [
    yamlencode({
      installCRDs = true
      serviceAccount = {
        create = false
        name   = kubernetes_service_account.external_secrets.metadata[0].name
      }
      replicaCount = 2
      resources = {
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
      }
    })
  ]

  wait          = true
  timeout       = 600
  wait_for_jobs = false
  max_history   = 3

  depends_on = [
    kubernetes_namespace.external_secrets,
    kubernetes_service_account.external_secrets
  ]
}

