# Outputs for shared infrastructure - used by tenant modules

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_ca_certificate" {
  description = "EKS cluster CA certificate"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = aws_eks_cluster.main.arn
}

output "cluster_region" {
  description = "AWS region where cluster is deployed"
  value       = "us-east-1"
}

# Monitoring stack outputs
output "prometheus_service" {
  description = "Prometheus LoadBalancer service endpoint"
  value       = kubernetes_service.prometheus.status[0].load_balancer[0].ingress[0].hostname
  depends_on  = [kubernetes_service.prometheus]
}

output "grafana_service" {
  description = "Grafana LoadBalancer service endpoint"
  value       = kubernetes_service.grafana.status[0].load_balancer[0].ingress[0].hostname
  depends_on  = [kubernetes_service.grafana]
}

output "alertmanager_service" {
  description = "AlertManager ClusterIP service endpoint"
  value       = kubernetes_service.alertmanager.metadata[0].name
  depends_on  = [kubernetes_service.alertmanager]
}

output "monitoring_namespace" {
  description = "Kubernetes namespace for monitoring stack"
  value       = kubernetes_namespace.monitoring.metadata[0].name
  depends_on  = [kubernetes_namespace.monitoring]
}
