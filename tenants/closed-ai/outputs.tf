output "namespace_name" {
  description = "The name of the created namespace"
  value       = kubernetes_namespace.tenant.metadata[0].name
}

output "service_name" {
  description = "Service name for the tenant application"
  value       = kubernetes_service.tenant_app.metadata[0].name
}

output "deployment_name" {
  description = "Deployment name"
  value       = kubernetes_deployment.tenant_app.metadata[0].name
}
