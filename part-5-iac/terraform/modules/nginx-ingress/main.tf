resource "time_sleep" "wait_for_cluster" {
  create_duration = "60s"
}

resource "kubernetes_namespace" "nginx_ingress" {
  metadata {
    name = var.namespace

    labels = {
      name = var.namespace
    }
  }

  depends_on = [time_sleep.wait_for_cluster]
}

resource "helm_release" "nginx_ingress" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = var.chart_version
  namespace  = var.namespace

  values = [
    yamlencode({
      controller = {
        service = {
          type = var.service_type
          annotations = merge(
            {
              "service.beta.kubernetes.io/aws-load-balancer-scheme"                            = var.lb_scheme
              "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
              "service.beta.kubernetes.io/aws-load-balancer-subnets"                           = join(",", var.public_subnet_ids)
            },
            var.use_nlb ? {
              "service.beta.kubernetes.io/aws-load-balancer-type"             = "nlb"
              "service.beta.kubernetes.io/aws-load-balancer-backend-protocol" = "tcp"
            } : {}
          )
        }

        admissionWebhooks = {
          enabled        = true
          failurePolicy  = "Ignore"
          timeoutSeconds = 30
        }

        ingressClassResource = {
          name    = "nginx"
          enabled = true
          default = var.default_ingress_class
        }

        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = false
          }
        }

        resources = {
          requests = {
            cpu    = var.cpu_request
            memory = var.memory_request
          }
          limits = {
            cpu    = var.cpu_limit
            memory = var.memory_limit
          }
        }

        replicaCount = var.replica_count

        podAnnotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "10254"
        }
      }
    })
  ]

  wait          = true
  timeout       = 1200
  wait_for_jobs = true
  max_history   = 3

  depends_on = [kubernetes_namespace.nginx_ingress]
}

data "kubernetes_service" "nginx_ingress_controller" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = var.namespace
  }

  depends_on = [helm_release.nginx_ingress]
}

