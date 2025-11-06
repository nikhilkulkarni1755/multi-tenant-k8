# Multi-Tenant Kubernetes Platform with LLM Integration

A production-ready multi-tenant Kubernetes platform that serves AI/LLM workloads with tenant isolation, custom system prompts, and comprehensive monitoring via Prometheus and Grafana.

## Overview

This platform demonstrates enterprise-grade multi-tenancy on Kubernetes, where each tenant (company) gets:

- **Isolated Kubernetes namespace** with resource quotas and RBAC
- **Custom LLM system prompts** - Each tenant's AI assistant has unique behavior based on their industry
- **Dedicated application pods** with Prometheus metrics
- **LLM proxy service** that routes requests to a shared LLM gateway with tenant-specific context
- **Centralized monitoring** via Prometheus and Grafana dashboards

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     AWS EKS Cluster                         │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Monitoring Namespace (Shared Infrastructure)        │  │
│  │  - LLM Gateway (OpenAI Proxy)                        │  │
│  │  - Prometheus (Metrics Collection)                   │  │
│  │  - Grafana (Visualization & Dashboards)              │  │
│  │  - Alertmanager (Alerts)                             │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌─────────────────────┐      ┌─────────────────────┐      │
│  │  acme-corp NS       │      │  closed-ai NS       │      │
│  │  - Tenant App       │      │  - Tenant App       │      │
│  │  - LLM Proxy        │      │  - LLM Proxy        │      │
│  │  - Resource Quotas  │      │  - Resource Quotas  │      │
│  │  - RBAC Policies    │      │  - RBAC Policies    │      │
│  └─────────────────────┘      └─────────────────────┘      │
│           │                              │                  │
│           └──────────────┬───────────────┘                  │
│                          │                                  │
│                          ▼                                  │
│                   LLM Gateway ───► OpenAI API              │
└─────────────────────────────────────────────────────────────┘
```

### Key Features

- **Tenant Isolation**: Each tenant operates in their own namespace with dedicated resources
- **Custom AI Behavior**: Tenant-specific system prompts customize LLM responses per industry
- **Centralized LLM Management**: Shared LLM gateway manages API keys and provides consistent interface
- **Real-time Monitoring**: Prometheus scrapes metrics from all tenants
- **Pre-built Dashboards**: Grafana dashboards for cluster overview and per-tenant metrics
- **Resource Governance**: CPU/memory quotas prevent resource exhaustion
- **RBAC Security**: Role-based access control for tenant isolation

## Technology Stack

### Infrastructure

- **Kubernetes**: AWS EKS (Elastic Kubernetes Service)
- **Infrastructure as Code**: Terraform
- **Container Runtime**: Docker
- **Cloud Provider**: AWS (VPC, EKS, EC2, ELB)

### Application

- **Language**: Python 3.11
- **Web Framework**: Flask
- **LLM Provider**: OpenAI API (GPT-3.5-turbo)
- **HTTP Client**: Requests library

### Monitoring & Observability

- **Metrics Collection**: Prometheus
- **Visualization**: Grafana
- **Alerting**: Alertmanager
- **Metrics Library**: prometheus_client (Python)

### DevOps

- **CLI Tools**: kubectl, AWS CLI, Terraform CLI
- **Version Control**: Git

## Prerequisites

Before installing, ensure you have the following tools installed:

- **AWS CLI** (v2.x+) - [Install Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- **kubectl** (v1.28+) - [Install Guide](https://kubernetes.io/docs/tasks/tools/)
- **Terraform** (v1.0+) - [Install Guide](https://developer.hashicorp.com/terraform/install)
- **AWS Account** with permissions to create EKS clusters, VPCs, and IAM roles
- **OpenAI API Key** - [Get one here](https://platform.openai.com/account/api-keys)

## Installation & Setup

### Step 1: Clone the Repository

```bash
git clone <repository-url>
cd Multi-Tenant-Platform
```

### Step 2: Configure AWS Credentials

```bash
aws configure
# Enter your AWS Access Key ID, Secret Access Key, and default region (us-east-1)
```

### Step 3: Deploy Shared Infrastructure

Deploy the monitoring stack and LLM gateway:

```bash
cd shared-infrastructure

# Set your secrets via environment variables
export TF_VAR_openai_api_key="sk-your-openai-api-key-here"
export TF_VAR_grafana_admin_password="your-secure-password"

# Initialize and apply Terraform
terraform init
terraform apply
```

**Note the outputs** - you'll need the cluster endpoint and service URLs.

### Step 4: Update Kubeconfig

Configure kubectl to connect to your EKS cluster:

```bash
aws eks update-kubeconfig --region us-east-1 --name multi-tenant-cluster
```

Verify connectivity:

```bash
kubectl get nodes
kubectl get namespaces
```

### Step 5: Deploy Tenants

Deploy each tenant's resources:

```bash
# Deploy acme-corp tenant
cd ../tenants/acme-corp
terraform init
terraform apply

# Deploy closed-ai tenant
cd ../closed-ai
terraform init
terraform apply
```

### Step 6: Restart LLM Gateway (Important!)

After setting the OpenAI API key, restart the LLM gateway to pick up the new secret:

```bash
kubectl rollout restart deployment/llm-gateway -n monitoring
kubectl rollout status deployment/llm-gateway -n monitoring
```

### Step 7: Verify Deployment

```bash
# Check all pods are running
kubectl get pods -A

# Check services
kubectl get services -n monitoring
kubectl get services -n acme-corp
kubectl get services -n closed-ai
```

## Testing the Platform

### Test Tenant LLM Proxy

Port-forward to a tenant's LLM proxy and send a request:

```bash
# Terminal 1 - Port forward to acme-corp
kubectl port-forward -n acme-corp service/llm 5002:5002
```

```powershell
# Terminal 2 - Send a request (PowerShell)
Invoke-RestMethod -Uri http://localhost:5002/ask -Method Post -ContentType "application/json" -Body '{"question":"What should we build?", "max_tokens":200}'
```

```bash
# Terminal 2 - Send a request (Bash/Linux)
curl -X POST http://localhost:5002/ask \
  -H "Content-Type: application/json" \
  -d '{"question":"What should we build?", "max_tokens":200}'
```

### Test Both Tenants Simultaneously

```bash
# Terminal 1 - acme-corp on port 5002
kubectl port-forward -n acme-corp service/llm 5002:5002

# Terminal 2 - closed-ai on port 5003
kubectl port-forward -n closed-ai service/llm 5003:5002
```

Then send requests to both:

- acme-corp: `http://localhost:5002/ask`
- closed-ai: `http://localhost:5003/ask`

Each tenant will get different responses based on their custom system prompts!

### Access Monitoring Dashboards

Get the external URLs from Terraform outputs:

```bash
cd shared-infrastructure
terraform output
```

**Grafana Dashboard:**

- URL: `http://<grafana-load-balancer>:3000`
- Username: `admin`
- Password: `<your-TF_VAR_grafana_admin_password>`

**Prometheus:**

- URL: `http://<prometheus-load-balancer>:9090`

### Available Dashboards

Once in Grafana, navigate to Dashboards to see:

- **Cluster Overview** - Overall cluster health and resource usage
- **Tenant Metrics** - Aggregated metrics across all tenants
- **acme-corp Dashboard** - Tenant-specific metrics
- **closed-ai Dashboard** - Tenant-specific metrics

## Project Structure

```
Multi-Tenant-Platform/
├── shared-infrastructure/          # Shared services (monitoring, LLM gateway)
│   ├── main.tf                    # EKS cluster and VPC
│   ├── monitoring.tf              # Prometheus, Alertmanager
│   ├── grafana.tf                 # Grafana deployment and dashboards
│   ├── llm_gateway.tf             # LLM Gateway deployment
│   ├── llm_gateway.py             # Python code for LLM proxy
│   ├── variables.tf               # Input variables
│   ├── outputs.tf                 # Output values (URLs, endpoints)
│   ├── dashboards/                # Grafana dashboard JSON files
│   │   ├── cluster-overview-dashboard.json
│   │   ├── tenant-metrics-dashboard.json
│   │   ├── acme-corp-dashboard.json
│   │   └── closed-ai-dashboard.json
│   ├── prometheus-config.yml      # Prometheus scrape configs
│   └── alert-rules.yml            # Alertmanager rules
│
├── tenants/                       # Tenant-specific deployments
│   ├── acme-corp/                 # Example tenant 1
│   │   ├── main.tf               # Namespace, app deployment, quotas
│   │   ├── llm_proxy.tf          # LLM proxy deployment
│   │   ├── llm_proxy_code.tf     # LLM proxy Python code
│   │   ├── rbac.tf               # RBAC policies
│   │   ├── variables.tf          # Tenant-specific variables
│   │   └── terraform.tf          # Provider configuration
│   │
│   └── closed-ai/                 # Example tenant 2
│       ├── main.tf
│       ├── llm_proxy.tf
│       ├── llm_proxy_code.tf
│       ├── rbac.tf
│       ├── variables.tf
│       └── terraform.tf
│
├── index.py                       # Tenant application code (Flask + Prometheus)
├── .gitignore                     # Git ignore rules
└── README.md                      # This file
```

## Configuration

### Tenant Configuration

Each tenant can be customized in their `variables.tf`:

```hcl
variable "namespace_name" {
  default = "acme-corp"
}

variable "industry" {
  default = "Technology"
}

variable "cpu_limit" {
  default = "500m"
}

variable "memory_limit" {
  default = "512Mi"
}
```

### Custom System Prompts

Edit the system prompt in `tenants/<tenant-name>/llm_proxy.tf` to customize AI behavior:

```hcl
data = {
  "system_prompt.txt" = <<-EOT
    You are an AI assistant for ACME Corp, a technology company.
    Focus on innovation, scalability, and design-first approaches.
  EOT
}
```

### Adding New Tenants

1. Copy an existing tenant directory:

   ```bash
   cp -r tenants/acme-corp tenants/new-tenant
   ```

2. Update `variables.tf` with new tenant details

3. Customize the system prompt in `llm_proxy.tf`

4. Deploy:
   ```bash
   cd tenants/new-tenant
   terraform init
   terraform apply
   ```

## Security Considerations

- **Secrets Management**: Never commit API keys or passwords to Git
- **Use `.gitignore`**: Terraform state files and `.tfvars` files are excluded
- **RBAC Policies**: Each tenant has isolated permissions via Kubernetes RBAC
- **Resource Quotas**: Prevent resource exhaustion and noisy neighbor issues
- **Network Policies**: Consider adding network policies for additional isolation
- **API Key Rotation**: Regularly rotate your OpenAI API key

## Monitoring & Metrics

### Prometheus Metrics

The platform exposes metrics for:

- HTTP request counts and latency
- Active requests per tenant
- Error rates and types
- Resource usage (CPU, memory)
- LLM inference metrics

### Custom Metrics Examples

```python
# Request counter
REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP requests',
                       ['method', 'endpoint', 'tenant', 'status'])

# Request latency histogram
REQUEST_DURATION = Histogram('http_request_duration_seconds',
                            'HTTP request latency',
                            ['method', 'endpoint', 'tenant'])
```

## Cleanup

To tear down the infrastructure:

```bash
# Destroy tenants first
cd tenants/closed-ai
terraform destroy

cd ../acme-corp
terraform destroy

# Then destroy shared infrastructure
cd ../../shared-infrastructure
terraform destroy
```

**Warning**: This will delete all resources including the EKS cluster!

## License

This project is provided as-is for educational and demonstration purposes.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## Support

For questions or issues, please open a GitHub issue.

---

**Built using Kubernetes, Terraform, and OpenAI**
