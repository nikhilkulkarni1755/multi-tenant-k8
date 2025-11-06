# TENANT-SPECIFIC RESOURCES
# This file creates Kubernetes resources for the acme-corp tenant
# Each tenant has its own directory with its own state file

# Create isolated namespace
resource "kubernetes_namespace" "tenant" {
  metadata {
    name = var.namespace_name
    labels = {
      company  = var.namespace_name
      industry = var.industry
      managed  = "terraform"
      tenant   = var.namespace_name
    }
    annotations = {
      "industry" = var.industry
    }
  }
}

# Resource Quota for namespace
resource "kubernetes_resource_quota" "tenant" {
  metadata {
    name      = "${var.namespace_name}-quota"
    namespace = kubernetes_namespace.tenant.metadata[0].name
  }
  spec {
    hard = {
      "requests.cpu"    = var.cpu_limit
      "requests.memory" = var.memory_limit
      "pods"            = "10"
      "services"        = "5"
    }
  }
}

# ConfigMap with company and industry info
resource "kubernetes_config_map" "tenant_info" {
  metadata {
    name      = "tenant-info"
    namespace = kubernetes_namespace.tenant.metadata[0].name
  }
  data = {
    COMPANY  = var.namespace_name
    INDUSTRY = var.industry
  }
}

# ConfigMap for application code
resource "kubernetes_config_map" "app_code" {
  metadata {
    name      = "app-code"
    namespace = kubernetes_namespace.tenant.metadata[0].name
  }
  data = {
    "index.py" = file("${path.module}/../../index.py")
  }
}

# Deployment with index.py script
resource "kubernetes_deployment" "tenant_app" {
  metadata {
    name      = "${var.namespace_name}-app"
    namespace = kubernetes_namespace.tenant.metadata[0].name
    labels = {
      app = "${var.namespace_name}-app"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "${var.namespace_name}-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "${var.namespace_name}-app"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.tenant.metadata[0].name

        container {
          image = "python:3.11-slim"
          name  = "${var.namespace_name}-container"

          command = ["/bin/bash", "-c"]
          args = [
            "pip install flask prometheus-client > /dev/null 2>&1 && python /app/index.py"
          ]

          env_from {
            config_map_ref {
              name = kubernetes_config_map.tenant_info.metadata[0].name
            }
          }

          resources {
            requests = {
              cpu    = var.cpu_request
              memory = var.memory_request
            }
            limits = {
              cpu    = var.cpu_limit
              memory = var.memory_limit
            }
          }

          volume_mount {
            name       = "app-code"
            mount_path = "/app"
          }

          port {
            container_port = 5000
            name           = "http"
          }
        }

        volume {
          name = "app-code"
          config_map {
            name = kubernetes_config_map.app_code.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service_account.tenant
  ]
}

# Service to expose the app
resource "kubernetes_service" "tenant_app" {
  metadata {
    name      = "${var.namespace_name}-service"
    namespace = kubernetes_namespace.tenant.metadata[0].name
  }
  spec {
    selector = {
      app = "${var.namespace_name}-app"
    }
    type = "ClusterIP"
    port {
      port        = 80
      target_port = 5000
      protocol    = "TCP"
    }
  }
}
