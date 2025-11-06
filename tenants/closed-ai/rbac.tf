# RBAC RESOURCES - Isolated to this tenant's namespace

# Service Account for the namespace
resource "kubernetes_service_account" "tenant" {
  metadata {
    name      = "${var.namespace_name}-sa"
    namespace = kubernetes_namespace.tenant.metadata[0].name
    labels = {
      app = "${var.namespace_name}-app"
    }
  }
}

# Role for read-only access
resource "kubernetes_role" "read_only" {
  metadata {
    name      = "${var.namespace_name}-read-only"
    namespace = kubernetes_namespace.tenant.metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "services", "configmaps"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "statefulsets", "daemonsets"]
    verbs      = ["get", "list", "watch"]
  }
}

# Role for admin access
resource "kubernetes_role" "admin" {
  metadata {
    name      = "${var.namespace_name}-admin"
    namespace = kubernetes_namespace.tenant.metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["*"]
    verbs      = ["*"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["*"]
    verbs      = ["*"]
  }

  rule {
    api_groups = ["batch"]
    resources  = ["*"]
    verbs      = ["*"]
  }
}

# RoleBinding for service account to admin role
resource "kubernetes_role_binding" "tenant_admin" {
  metadata {
    name      = "${var.namespace_name}-admin-binding"
    namespace = kubernetes_namespace.tenant.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.admin.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.tenant.metadata[0].name
    namespace = kubernetes_namespace.tenant.metadata[0].name
  }
}

# NetworkPolicy - Deny all ingress by default
resource "kubernetes_network_policy" "deny_all_ingress" {
  metadata {
    name      = "${var.namespace_name}-deny-all-ingress"
    namespace = kubernetes_namespace.tenant.metadata[0].name
  }

  spec {
    pod_selector {
      # Empty selector = applies to all pods in namespace
    }

    policy_types = ["Ingress"]
  }
}

# NetworkPolicy - Allow ingress from same namespace only
resource "kubernetes_network_policy" "allow_same_namespace" {
  metadata {
    name      = "${var.namespace_name}-allow-same-ns"
    namespace = kubernetes_namespace.tenant.metadata[0].name
  }

  spec {
    pod_selector {
      # Empty selector = applies to all pods in namespace
    }

    policy_types = ["Ingress"]

    ingress {
      from {
        pod_selector {
          match_labels = {}
        }
        namespace_selector {
          match_labels = {
            name = kubernetes_namespace.tenant.metadata[0].name
          }
        }
      }
    }
  }
}

# NetworkPolicy - Allow DNS egress
resource "kubernetes_network_policy" "allow_dns_egress" {
  metadata {
    name      = "${var.namespace_name}-allow-dns-egress"
    namespace = kubernetes_namespace.tenant.metadata[0].name
  }

  spec {
    pod_selector {
      # Empty selector = applies to all pods in namespace
    }

    policy_types = ["Egress"]

    egress {
      to {
        namespace_selector {
          match_labels = {
            name = "kube-system"
          }
        }
      }
      ports {
        protocol = "UDP"
        port     = "53"
      }
    }

    egress {
      to {
        pod_selector {
          match_labels = {}
        }
        namespace_selector {
          match_labels = {
            name = kubernetes_namespace.tenant.metadata[0].name
          }
        }
      }
    }
  }
}
