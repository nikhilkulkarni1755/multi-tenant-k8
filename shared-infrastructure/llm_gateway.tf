# LLM Gateway - Proxy to External LLM Service (OpenAI)
# This provides centralized API key management and tenant isolation

# ConfigMap with LLM Gateway code
resource "kubernetes_config_map" "llm_gateway_code" {
  metadata {
    name      = "llm-gateway-code"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  data = {
    "llm_gateway.py" = file("${path.module}/llm_gateway.py")
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# Secret for OpenAI API Key
# NOTE: You must set this via kubectl after deployment:
# kubectl create secret generic openai-api-key -n monitoring --from-literal=api-key=YOUR_API_KEY
resource "kubernetes_secret" "openai_api_key" {
  metadata {
    name      = "openai-api-key"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  data = {
    api-key = var.openai_api_key != "" ? var.openai_api_key : "REPLACE_ME"
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# LLM Gateway Deployment
resource "kubernetes_deployment" "llm_gateway" {
  # Don't wait for rollout - starts quickly
  wait_for_rollout = false

  metadata {
    name      = "llm-gateway"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      app = "llm-gateway"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "llm-gateway"
      }
    }

    template {
      metadata {
        labels = {
          app = "llm-gateway"
        }
      }

      spec {
        container {
          name  = "llm-gateway"
          image = "python:3.11-slim"

          # Install Flask and requests, then run gateway
          command = ["/bin/bash", "-c"]
          args = [
            "pip install flask requests --quiet && python /app/llm_gateway.py"
          ]

          port {
            name           = "http"
            container_port = 5000
            protocol       = "TCP"
          }

          # Environment variables
          env {
            name = "OPENAI_API_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.openai_api_key.metadata[0].name
                key  = "api-key"
              }
            }
          }

          env {
            name  = "OPENAI_MODEL"
            value = "gpt-3.5-turbo"
          }

          env {
            name  = "OPENAI_ENDPOINT"
            value = "https://api.openai.com/v1/chat/completions"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "256Mi"
            }
          }

          volume_mount {
            name       = "gateway-code"
            mount_path = "/app"
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 5000
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 5000
            }
            initial_delay_seconds = 10
            period_seconds        = 5
          }
        }

        volume {
          name = "gateway-code"
          config_map {
            name = kubernetes_config_map.llm_gateway_code.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_config_map.llm_gateway_code,
    kubernetes_secret.openai_api_key
  ]
}

# Service to expose LLM Gateway (ClusterIP - internal only)
resource "kubernetes_service" "llm_gateway" {
  metadata {
    name      = "llm-gateway"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      app = "llm-gateway"
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      app = "llm-gateway"
    }

    port {
      name        = "http"
      port        = 5000
      target_port = "http"
      protocol    = "TCP"
    }
  }

  depends_on = [kubernetes_deployment.llm_gateway]
}
