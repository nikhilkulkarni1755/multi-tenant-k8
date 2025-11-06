# Grafana deployment for dashboard visualization

# Create ConfigMap for Grafana data source (Prometheus)
resource "kubernetes_config_map" "grafana_datasources" {
  metadata {
    name      = "grafana-datasources"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  data = {
    "prometheus.yaml" = file("${path.module}/grafana-datasource-prometheus.yml")
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# Create ConfigMap for Grafana dashboards provider
resource "kubernetes_config_map" "grafana_dashboard_provider" {
  metadata {
    name      = "grafana-dashboard-provider"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  data = {
    "dashboards.yaml" = file("${path.module}/grafana-dashboard-provider.yml")
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# Create ConfigMap for Grafana dashboards
resource "kubernetes_config_map" "grafana_dashboards" {
  metadata {
    name      = "grafana-dashboards"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  data = {
    "tenant-metrics-dashboard.json"     = file("${path.module}/dashboards/tenant-metrics-dashboard.json")
    "cluster-overview-dashboard.json"   = file("${path.module}/dashboards/cluster-overview-dashboard.json")
    "acme-corp-dashboard.json"          = file("${path.module}/dashboards/acme-corp-dashboard.json")
    "closed-ai-dashboard.json"          = file("${path.module}/dashboards/closed-ai-dashboard.json")
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# Grafana Deployment
resource "kubernetes_deployment" "grafana" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      app = "grafana"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "grafana"
      }
    }

    template {
      metadata {
        labels = {
          app = "grafana"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.grafana.metadata[0].name

        container {
          name  = "grafana"
          image = "grafana/grafana:10.2.0"

          env {
            name  = "GF_SECURITY_ADMIN_USER"
            value = "admin"
          }

          env {
            name = "GF_SECURITY_ADMIN_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.grafana_admin.metadata[0].name
                key  = "admin-password"
              }
            }
          }

          env {
            name  = "GF_USERS_ALLOW_SIGN_UP"
            value = "false"
          }

          env {
            name  = "GF_SERVER_ROOT_URL"
            value = "http://grafana.monitoring:3000"
          }

          env {
            name  = "GF_INSTALL_PLUGINS"
            value = "grafana-piechart-panel"
          }

          port {
            name           = "http"
            container_port = 3000
            protocol       = "TCP"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
          }

          volume_mount {
            name       = "grafana-storage"
            mount_path = "/var/lib/grafana"
          }

          volume_mount {
            name       = "grafana-datasources"
            mount_path = "/etc/grafana/provisioning/datasources"
          }

          volume_mount {
            name       = "grafana-dashboard-provider"
            mount_path = "/etc/grafana/provisioning/dashboards"
          }

          volume_mount {
            name       = "grafana-dashboards"
            mount_path = "/var/lib/grafana/dashboards"
          }

          liveness_probe {
            http_get {
              path   = "/api/health"
              port   = 3000
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path   = "/api/health"
              port   = 3000
            }
            initial_delay_seconds = 10
            period_seconds        = 5
          }
        }

        volume {
          name = "grafana-storage"
          empty_dir {}
        }

        volume {
          name = "grafana-datasources"
          config_map {
            name = kubernetes_config_map.grafana_datasources.metadata[0].name
          }
        }

        volume {
          name = "grafana-dashboard-provider"
          config_map {
            name = kubernetes_config_map.grafana_dashboard_provider.metadata[0].name
          }
        }

        volume {
          name = "grafana-dashboards"
          config_map {
            name = kubernetes_config_map.grafana_dashboards.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.monitoring,
    kubernetes_secret.grafana_admin
  ]
}

# Grafana Service
resource "kubernetes_service" "grafana" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      app = "grafana"
    }
  }

  spec {
    type = "LoadBalancer"

    selector = {
      app = "grafana"
    }

    port {
      name        = "http"
      port        = 3000
      target_port = "http"
      protocol    = "TCP"
    }
  }

  depends_on = [kubernetes_deployment.grafana]
}

# ServiceAccount for Grafana
resource "kubernetes_service_account" "grafana" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# Secret for Grafana admin password
resource "kubernetes_secret" "grafana_admin" {
  metadata {
    name      = "grafana-admin"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  type = "Opaque"

  data = {
    "admin-password" = base64encode(var.grafana_admin_password)
  }

  depends_on = [kubernetes_namespace.monitoring]
}
