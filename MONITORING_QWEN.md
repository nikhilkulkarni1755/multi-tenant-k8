# Monitoring + Qwen LLM Integration Guide

## Overview

This document describes the integration of:
- **Prometheus + Grafana** monitoring stack
- **Qwen LLM** inference engine with tenant-specific prompts
- **Multi-tenant architecture** where each tenant gets their own LLM interface with custom system prompts

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│           Kubernetes EKS Cluster (shared-infrastructure)    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────── monitoring namespace ──────────────┐│
│  │                                                         ││
│  │  ┌──────────────┐  ┌────────────┐  ┌──────────────┐  ││
│  │  │ Prometheus   │  │ Grafana    │  │ Qwen LLM     │  ││
│  │  │ (metrics)    │  │ (dashboards)  │ (inference)  │  ││
│  │  └──────────────┘  └────────────┘  └──────────────┘  ││
│  │                                                         ││
│  └──────────────────────────────────────────────────────────┘│
│                                                             │
│  ┌──────────────────── acme-corp namespace ──────────────┐│
│  │  ┌────────────────────────────────────────────────┐  ││
│  │  │ Flask App (tenant app with /metrics endpoint) │  ││
│  │  └────────────────────────────────────────────────┘  ││
│  │  ┌────────────────────────────────────────────────┐  ││
│  │  │ LLM Proxy (design-first system prompt)        │  ││
│  │  │ Calls: qwen-llm.monitoring:5001               │  ││
│  │  └────────────────────────────────────────────────┘  ││
│  │  ┌────────────────────────────────────────────────┐  ││
│  │  │ ConfigMap: acme-llm-prompt                     │  ││
│  │  │ (Design-first approach instructions)          │  ││
│  │  └────────────────────────────────────────────────┘  ││
│  └──────────────────────────────────────────────────────────┘│
│                                                             │
│  ┌──────────────────── closed-ai namespace ──────────────┐│
│  │  ┌────────────────────────────────────────────────┐  ││
│  │  │ Flask App (tenant app with /metrics endpoint) │  ││
│  │  └────────────────────────────────────────────────┘  ││
│  │  ┌────────────────────────────────────────────────┐  ││
│  │  │ LLM Proxy (code-first system prompt)          │  ││
│  │  │ Calls: qwen-llm.monitoring:5001               │  ││
│  │  └────────────────────────────────────────────────┘  ││
│  │  ┌────────────────────────────────────────────────┐  ││
│  │  │ ConfigMap: closed-ai-llm-prompt               │  ││
│  │  │ (Code-first approach instructions)            │  ││
│  │  └────────────────────────────────────────────────┘  ││
│  └──────────────────────────────────────────────────────────┘│
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Deployment Steps

### Prerequisites
- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- kubectl configured

### Step 1: Deploy Shared Infrastructure

```bash
cd /path/to/shared-infrastructure

# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Deploy EKS, monitoring stack, and LLM
terraform apply
```

**This creates:**
- EKS cluster with 2 nodes
- VPC with public/private subnets
- Monitoring namespace with:
  - Prometheus (metrics collection)
  - Grafana (dashboards)
  - AlertManager (alerting)
  - Qwen LLM server (inference)

**Output will show:**
```
prometheus_service = "xxx.elb.amazonaws.com:9090"
grafana_service = "yyy.elb.amazonaws.com:3000"
monitoring_namespace = "monitoring"
```

### Step 2: Deploy ACME Corp Tenant

```bash
cd /path/to/tenants/acme-corp

# Initialize Terraform
terraform init

# Deploy tenant with design-first LLM proxy
terraform apply
```

**This creates:**
- acme-corp namespace
- Flask application (tenant app)
- LLM proxy service with design-first system prompt
- RBAC and network policies

### Step 3: Deploy Closed AI Tenant

```bash
cd /path/to/tenants/closed-ai

# Initialize Terraform
terraform init

# Deploy tenant with code-first LLM proxy
terraform apply
```

**This creates:**
- closed-ai namespace
- Flask application (tenant app)
- LLM proxy service with code-first system prompt
- RBAC and network policies

## Accessing Services

### Prometheus
```
http://<prometheus_service>:9090
```
- **Metrics**: View metrics from both tenants
- **Targets**: See scrape targets (should show acme-corp-app and closed-ai-app)
- **Alerts**: View active alerts

### Grafana
```
http://<grafana_service>:3000
- Username: admin
- Password: [Set via terraform variable: grafana_admin_password]
```

Pre-configured dashboards:
- **Tenant Metrics Overview**: Cross-tenant request rates, latency, errors
- **ACME Corp Dashboard**: ACME-specific metrics
- **Closed AI Dashboard**: Closed AI-specific metrics
- **Cluster Overview**: Infrastructure health

## Testing the Integration

### 1. Generate Metrics (from your machine)

```bash
# Port-forward tenant services
kubectl port-forward -n acme-corp svc/acme-corp-service 8080:80 &
kubectl port-forward -n closed-ai svc/closed-ai-service 8081:80 &

# Make requests to generate metrics
for i in {1..10}; do
  curl http://localhost:8080/hello
  curl http://localhost:8081/hello
  sleep 1
done

# Check Grafana - metrics should appear in dashboards
```

### 2. Test LLM Endpoints

```bash
# Port-forward LLM services
kubectl port-forward -n acme-corp svc/llm 5002:5002 &
kubectl port-forward -n closed-ai svc/llm 5003:5002 &

# Ask ACME Corp (Design-First Approach)
curl -X POST http://localhost:5002/ask \
  -H "Content-Type: application/json" \
  -d '{
    "question": "How should we build a real-time collaboration platform?",
    "max_tokens": 512
  }'

# Ask Closed AI (Code-First Approach)
curl -X POST http://localhost:5003/ask \
  -H "Content-Type: application/json" \
  -d '{
    "question": "How should we build a real-time collaboration platform?",
    "max_tokens": 512
  }'

# Get tenant info
curl http://localhost:5002/info
curl http://localhost:5003/info
```

## Key Differences: Same Question, Different Answers

When you ask both tenants the same question, they get different responses because of their system prompts:

### ACME Corp Response (Design-First)
- Starts with architecture and design
- User experience considerations
- Visual hierarchy and wireframes
- Implementation comes after design approval

### Closed AI Response (Code-First)
- Jumps straight to working code
- Implementation details immediately
- Includes test cases
- Focus on shipping fast

## File Structure

### New LLM Files

```
shared-infrastructure/
├── llm.tf                          # LLM deployment config
└── llm_server.py                   # Qwen inference server

tenants/acme-corp/
├── llm_proxy.tf                    # ACME Corp LLM proxy
└── llm_proxy_code.tf               # Proxy application code

tenants/closed-ai/
├── llm_proxy.tf                    # Closed AI LLM proxy
└── llm_proxy_code.tf               # Proxy application code
```

### Existing Files (Unchanged)
- `monitoring.tf`, `grafana.tf` - Prometheus and Grafana
- `main.tf` - EKS infrastructure
- `tenants/*/main.tf` - Tenant applications

## LLM Model Details

### Model: Qwen 1.5-0.5B
- **Size**: ~500MB (smallest version)
- **Parameters**: 0.5B
- **Format**: HuggingFace transformers
- **First Run**: Will download model (~15 minutes)
- **Subsequent Runs**: Uses cached model (fast)

### LLM Server Endpoints

**Health Check**
```bash
GET /health
```

**Inference**
```bash
POST /infer
Content-Type: application/json

{
  "prompt": "Your question here",
  "system_prompt": "Custom system instructions",
  "max_tokens": 256
}
```

**Model Info**
```bash
GET /models
```

## Tenant LLM Proxy Endpoints

### Health Check
```bash
GET /health
```

### Ask Question
```bash
POST /ask
Content-Type: application/json

{
  "question": "Your question here",
  "max_tokens": 512
}
```

### Get Tenant Info
```bash
GET /info
```

Response includes:
- Tenant name and company
- System prompt being used
- LLM service URL
- Available endpoints

## Performance Considerations

### Model Download
- First inference request triggers model download (~15 minutes)
- Model is cached for subsequent requests
- Total download size: ~500MB (model) + 1GB+ (dependencies)

### Inference Speed
- First token: ~30-60 seconds
- Subsequent tokens: ~1-2 seconds each
- Total response for 256 tokens: ~2-5 minutes

### Resource Requirements
```yaml
LLM Pod:
  requests:
    cpu: 500m
    memory: 2Gi
  limits:
    cpu: 2000m
    memory: 4Gi

Proxy Pod (per tenant):
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

## Customizing Tenant Prompts

### Modify ACME Corp Prompt

Edit `tenants/acme-corp/llm_proxy.tf`:

```hcl
resource "kubernetes_config_map" "acme_llm_prompt" {
  data = {
    "system_prompt.txt" = <<-EOT
Your custom system prompt here...
EOT
  }
}
```

Then redeploy:
```bash
terraform apply
```

### Modify Closed AI Prompt

Edit `tenants/closed-ai/llm_proxy.tf` similarly.

## Troubleshooting

### LLM Pod Not Starting

**Check logs:**
```bash
kubectl logs -n monitoring deployment/qwen-llm -f
```

**Common issues:**
- Model download in progress (takes 10-20 minutes)
- Insufficient memory (needs 2GB+ requested)
- Network issues downloading from HuggingFace

### LLM Inference Timing Out

**Check if model is loaded:**
```bash
kubectl port-forward -n monitoring svc/qwen-llm 5001:5001
curl http://localhost:5001/health
```

**If model not loaded yet:**
- First request triggers download
- Wait 15-30 minutes
- Then retry

### LLM Proxy Can't Reach LLM Service

**Verify service exists:**
```bash
kubectl get svc -n monitoring | grep qwen
```

**Check network connectivity:**
```bash
kubectl exec -n acme-corp deployment/acme-llm-proxy -- \
  curl http://qwen-llm.monitoring:5001/health
```

### Prometheus Not Scraping Metrics

**Verify targets:**
```bash
# Port-forward Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Check targets at http://localhost:9090/targets
# Should see acme-corp-app and closed-ai-app as UP
```

**If targets DOWN:**
- Check network policies
- Verify pods are running: `kubectl get pods -n acme-corp`
- Check pod logs for errors

## Demo Flow

### Quick Demo (5 minutes)

```bash
# 1. Show cluster
kubectl get ns

# 2. Show monitoring
kubectl get pods -n monitoring

# 3. Open Grafana
# http://<grafana_service>:3000

# 4. Show metrics flowing
# Click on tenant dashboards

# 5. Show LLM working
curl http://localhost:5002/ask -d '{"question": "Quick answer"}'
curl http://localhost:5003/ask -d '{"question": "Quick answer"}'

# 6. Show different responses
# ACME: Starts with design
# Closed AI: Starts with code
```

### Full Demo (15+ minutes)

1. **Monitoring Stack** (5 min)
   - Show Prometheus targets
   - Show Grafana dashboards
   - Generate traffic and watch metrics update

2. **LLM Integration** (10+ min)
   - Ask ACME Corp (wait for response ~2-5 min)
   - Ask Closed AI with same question
   - Compare responses (different approaches)
   - Show tenant info endpoint

## Production Considerations

### For Production Use

1. **Model Optimization**
   - Use quantized models for faster inference
   - Cache model in Docker image (pre-download)
   - Use GPU instances for 10x speedup

2. **High Availability**
   - Deploy multiple LLM replicas
   - Use load balancer
   - Add rate limiting

3. **Security**
   - Add authentication to LLM endpoints
   - Use network policies to restrict access
   - Validate and sanitize prompts

4. **Monitoring**
   - Track inference latency
   - Monitor model health
   - Alert on errors

5. **Cost Optimization**
   - Use spot instances
   - Auto-scale based on load
   - Or use cloud-based LLM APIs (OpenRouter, Together AI, etc.)

## Next Steps

1. Deploy infrastructure on Windows machine using same terraform commands
2. Generate traffic to see Prometheus metrics
3. Ask LLM questions from both tenants
4. Record demo showing different responses
5. Consider customizing system prompts for your use case

## Support & References

- **Qwen Models**: https://huggingface.co/Qwen
- **HuggingFace Transformers**: https://huggingface.co/docs/transformers
- **Prometheus**: https://prometheus.io/docs
- **Grafana**: https://grafana.com/docs
- **Kubernetes**: https://kubernetes.io/docs
