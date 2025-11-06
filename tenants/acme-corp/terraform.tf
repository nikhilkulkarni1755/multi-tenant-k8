terraform {
  required_version = ">= 1.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# Kubernetes provider uses local kubeconfig
# Works with Minikube, Docker Desktop, Kind, or EKS
provider "kubernetes" {
  config_path = "~/.kube/config"
}
