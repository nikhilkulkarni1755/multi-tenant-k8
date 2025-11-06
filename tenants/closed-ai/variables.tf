variable "namespace_name" {
  description = "Company name / namespace identifier"
  type        = string
  default     = "closed-ai"
}

variable "industry" {
  description = "Industry classification"
  type        = string
  default     = "ai"
}

variable "cpu_limit" {
  description = "CPU limit per namespace"
  type        = string
  default     = "500m"
}

variable "memory_limit" {
  description = "Memory limit per namespace"
  type        = string
  default     = "512Mi"
}

variable "cpu_request" {
  description = "CPU request per pod"
  type        = string
  default     = "100m"
}

variable "memory_request" {
  description = "Memory request per pod"
  type        = string
  default     = "128Mi"
}
