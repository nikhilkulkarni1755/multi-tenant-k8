# LLM Proxy for Closed AI
# Provides tenant-specific LLM access with code-first system prompt

# ConfigMap with Closed AI's system prompt
resource "kubernetes_config_map" "closed_ai_llm_prompt" {
  metadata {
    name      = "closed-ai-llm-prompt"
    namespace = kubernetes_namespace.tenant.metadata[0].name
  }

  data = {
    "system_prompt.txt" = <<-EOT
You are an expert software engineer and architect focused on code-first development.

Your approach:
1. **Code First**: Jump straight to implementation with well-structured code
2. **Efficiency**: Prioritize working code over extended planning
3. **Best Practices**: Use proven patterns, libraries, and frameworks
4. **Performance**: Optimize for speed and resource efficiency
5. **Testing**: Include unit tests and error handling from the start

Format your responses as:
- **Quick Solution**: Provide working code immediately
- **Implementation Details**: Explain the code and design choices
- **Testing**: Include test cases and validation examples

Remember: Perfect code in production beats perfect design on paper. Ship fast, iterate.
EOT
  }

  depends_on = [kubernetes_namespace.tenant]
}

# Proxy deployment that calls the shared LLM with tenant-specific prompt
resource "kubernetes_deployment" "closed_ai_llm_proxy" {
  metadata {
    name      = "closed-ai-llm-proxy"
    namespace = kubernetes_namespace.tenant.metadata[0].name
    labels = {
      app = "closed-ai-llm-proxy"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "closed-ai-llm-proxy"
      }
    }

    template {
      metadata {
        labels = {
          app = "closed-ai-llm-proxy"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.tenant.metadata[0].name

        container {
          name  = "llm-proxy"
          image = "python:3.11-slim"

          command = ["/bin/bash", "-c"]
          args = [
            "pip install flask requests --quiet && python /app/proxy.py"
          ]

          port {
            name           = "http"
            container_port = 5002
            protocol       = "TCP"
          }

          env {
            name  = "LLM_SERVICE_URL"
            value = "http://llm-gateway.monitoring:5000"
          }

          env {
            name  = "TENANT_NAME"
            value = var.namespace_name
          }

          env {
            name  = "COMPANY_NAME"
            value = var.namespace_name
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          volume_mount {
            name       = "prompt"
            mount_path = "/app/prompt"
          }

          volume_mount {
            name       = "proxy-code"
            mount_path = "/app"
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 5002
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 5002
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }

        volume {
          name = "prompt"
          config_map {
            name = kubernetes_config_map.closed_ai_llm_prompt.metadata[0].name
          }
        }

        volume {
          name = "proxy-code"
          config_map {
            name = kubernetes_config_map.llm_proxy_code.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_config_map.closed_ai_llm_prompt,
    kubernetes_config_map.llm_proxy_code
  ]
}

# Service to expose the proxy within the tenant namespace
resource "kubernetes_service" "closed_ai_llm_proxy" {
  metadata {
    name      = "llm"
    namespace = kubernetes_namespace.tenant.metadata[0].name
    labels = {
      app = "closed-ai-llm-proxy"
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      app = "closed-ai-llm-proxy"
    }

    port {
      name        = "http"
      port        = 5002
      target_port = "http"
      protocol    = "TCP"
    }
  }

  depends_on = [kubernetes_deployment.closed_ai_llm_proxy]
}
