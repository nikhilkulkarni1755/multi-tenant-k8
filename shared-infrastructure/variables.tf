# Variables for shared infrastructure

variable "grafana_admin_password" {
  description = "Admin password for Grafana"
  type        = string
  sensitive   = true
  default     = ""  # Set via environment variable: TF_VAR_grafana_admin_password

  validation {
    condition     = var.grafana_admin_password == "" || length(var.grafana_admin_password) >= 8
    error_message = "Grafana admin password must be empty or at least 8 characters long."
  }
}

variable "openai_api_key" {
  description = "OpenAI API key for LLM Gateway"
  type        = string
  sensitive   = true
  default     = ""  # Set via environment variable: TF_VAR_openai_api_key

  validation {
    condition     = var.openai_api_key == "" || length(var.openai_api_key) > 10
    error_message = "OpenAI API key must be empty or a valid key (more than 10 characters)."
  }
}
