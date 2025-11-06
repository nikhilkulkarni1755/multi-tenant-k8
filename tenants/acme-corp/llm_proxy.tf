# LLM Proxy for ACME Corp
# Provides tenant-specific LLM access with design-first system prompt

# ConfigMap with ACME Corp's system prompt
resource "kubernetes_config_map" "acme_llm_prompt" {
  metadata {
    name      = "acme-llm-prompt"
    namespace = kubernetes_namespace.tenant.metadata[0].name
  }

  data = {
    "system_prompt.txt" = <<-EOT
You are a world-class design-first architect and engineer.

Your approach:
1. **Design First**: Always start with comprehensive design and architecture planning
2. **User-Centric**: Focus on user experience, accessibility, and usability
3. **Visual Thinking**: Describe designs with diagrams, wireframes, and visual hierarchy
4. **Best Practices**: Implement SOLID principles, design patterns, and architectural best practices
5. **Scalability**: Design for scale from the start

Format your responses as:
- **Design Phase**: Describe the architecture, components, and user flows
- **Implementation**: Provide code/technical details after design approval
- **Validation**: Include testing strategies and quality metrics

Remember: Great design enables great implementation. Take time with architecture.
EOT
  }

  depends_on = [kubernetes_namespace.tenant]
}

# Proxy deployment that calls the shared LLM with tenant-specific prompt
resource "kubernetes_deployment" "acme_llm_proxy" {
  metadata {
    name      = "acme-llm-proxy"
    namespace = kubernetes_namespace.tenant.metadata[0].name
    labels = {
      app = "acme-llm-proxy"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "acme-llm-proxy"
      }
    }

    template {
      metadata {
        labels = {
          app = "acme-llm-proxy"
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
            name = kubernetes_config_map.acme_llm_prompt.metadata[0].name
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
    kubernetes_config_map.acme_llm_prompt,
    kubernetes_config_map.llm_proxy_code
  ]
}

# Service to expose the proxy within the tenant namespace
resource "kubernetes_service" "acme_llm_proxy" {
  metadata {
    name      = "llm"
    namespace = kubernetes_namespace.tenant.metadata[0].name
    labels = {
      app = "acme-llm-proxy"
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      app = "acme-llm-proxy"
    }

    port {
      name        = "http"
      port        = 5002
      target_port = "http"
      protocol    = "TCP"
    }
  }

  depends_on = [kubernetes_deployment.acme_llm_proxy]
}
