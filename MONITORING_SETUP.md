# Monitoring Stack Setup Guide

This document describes the complete monitoring stack (Prometheus + Grafana + AlertManager) integrated into your multi-tenant Kubernetes platform.

## Overview

The monitoring stack provides comprehensive observability for your multi-tenant EKS cluster:

- **Prometheus**: Time-series database for metrics collection and storage (15-day retention)
- **Grafana**: Dashboard visualization with pre-built dashboards for tenants and cluster
- **AlertManager**: Alert routing and management with tenant-specific rules
- **Flask App Instrumentation**: Application-level metrics for request tracking

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Kubernetes EKS Cluster                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Monitoring Namespace                        │  │
│  ├──────────────────────────────────────────────────────────┤  │
│  │  ┌──────────────┐  ┌────────────┐  ┌──────────────────┐ │  │
│  │  │ Prometheus   │  │ Grafana    │  │ AlertManager     │ │  │
│  │  │ (LB Service) │  │ (LB Service)  │ (ClusterIP)      │ │  │
│  │  └──────────────┘  └────────────┘  └──────────────────┘ │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────┐      ┌──────────────────────────┐   │
│  │  acme-corp Namespace │      │  closed-ai Namespace     │   │
│  ├──────────────────────┤      ├──────────────────────────┤   │
│  │ tenant-app Pods      │      │ tenant-app Pods          │   │
│  │ (expose /metrics)    │      │ (expose /metrics)        │   │
│  └──────────────────────┘      └──────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
         ↓ Scrape Every 15s
    [Prometheus Scrape Jobs]
         ↓
    [Time Series Database (15-day retention)]
         ↓
    [Alert Rules Evaluation]
         ↓ If Alert Triggered
    [AlertManager Routing]
         ↓
    [Grafana Dashboards]
```

## Deployment Instructions

### Prerequisites

- Terraform >= 1.0
- AWS CLI configured
- kubectl configured to access EKS cluster
- Python 3.9+ (for Flask app updates)

### Step 1: Update Flask Application (Already Done)

The Flask app has been updated to expose Prometheus metrics. Key changes:

**File**: `/Users/nikhilkulkarni/Multi-Tenant-Platform/index.py`

```python
# Added metrics exposure:
- http_requests_total (Counter): Total HTTP requests by method, endpoint, tenant, status
- http_request_duration_seconds (Histogram): Request latency with p95, p99 percentiles
- http_requests_active (Gauge): Number of active requests per tenant
- http_request_errors_total (Counter): Total errors by type
- app_info (Gauge): Application metadata (company, industry, tenant)
- GET /metrics endpoint for Prometheus scraping
```

**Requirements**: Add `prometheus-client` to your Flask dependencies:
```bash
pip install prometheus-client
```

### Step 2: Deploy Shared Infrastructure with Monitoring

```bash
cd /Users/nikhilkulkarni/Multi-Tenant-Platform/shared-infrastructure

# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Deploy infrastructure (EKS + Monitoring Stack)
terraform apply
```

**Note**: Set Grafana admin password via environment variable (optional):
```bash
terraform apply -var="grafana_admin_password=YourSecurePassword123"
```

### Step 3: Deploy Tenant Infrastructure

```bash
cd /Users/nikhilkulkarni/Multi-Tenant-Platform/tenants

# For ACME Corp
cd acme-corp
terraform init
terraform apply

# For Closed AI
cd ../closed-ai
terraform init
terraform apply
```

### Step 4: Verify Deployment

After `terraform apply` completes, you'll get output values:

```
Outputs:
prometheus_service = "a1b2c3d4-123456789.us-east-1.elb.amazonaws.com"
grafana_service = "a1b2c3d4-987654321.us-east-1.elb.amazonaws.com"
alertmanager_service = "alertmanager"
monitoring_namespace = "monitoring"
```

## Accessing the Monitoring Stack

### Prometheus
- **URL**: `http://<prometheus_service>:9090`
- **Purpose**: Metrics database and queries
- **Key Pages**:
  - `/graph`: Interactive metric queries
  - `/targets`: Scrape target status
  - `/alerts`: Active alert rules
  - `/rules`: Alert rules evaluation

### Grafana
- **URL**: `http://<grafana_service>:3000`
- **Default Credentials**: `admin` / `admin` (or password you set)
- **Pre-configured Dashboards**:
  1. **Tenant Metrics Overview** - Cross-tenant request rates, error rates, latency
  2. **Cluster Overview** - Node health, pod count, resource usage
  3. **ACME Corp Dashboard** - Tenant-specific metrics and request breakdown
  4. **Closed AI Dashboard** - Tenant-specific metrics and request breakdown

### AlertManager
- **URL**: `http://<alertmanager_service>:9093` (internal access)
- **Purpose**: Alert routing and management
- **Configuration**: `/shared-infrastructure/alertmanager-config.yml`

## Metrics Available

### Application Metrics (Tenant Level)

All metrics are prefixed with the tenant name via labels.

**Counters**:
```
http_requests_total{method, endpoint, tenant, status}
http_request_errors_total{method, endpoint, tenant, error_type}
```

**Histograms**:
```
http_request_duration_seconds{method, endpoint, tenant}
- Buckets: 0.01s, 0.025s, 0.05s, 0.1s, 0.25s, 0.5s, 1s, 2.5s, 5s
- Use: p95, p99 latency analysis
```

**Gauges**:
```
http_requests_active{tenant}
app_info{company, industry, tenant}
```

### Kubernetes Metrics

Prometheus also scrapes:
- **kubelet** metrics (node, pod, container resource usage)
- **API server** metrics (request rates, latencies)
- **Controller manager** metrics

## Alert Rules

**Location**: `/shared-infrastructure/alert-rules.yml`

### Configured Alerts

1. **HighErrorRate** (Warning)
   - Triggers: Error rate > 5% for 5 minutes
   - Labels: `severity: warning`, `tenant: <name>`

2. **HighLatency** (Warning)
   - Triggers: P95 latency > 1 second for 5 minutes
   - Labels: `severity: warning`, `tenant: <name>`

3. **ServiceDown** (Critical)
   - Triggers: Service unavailable for > 2 minutes
   - Labels: `severity: critical`, `tenant: <name>`

4. **TooManyActiveRequests** (Warning)
   - Triggers: > 100 active requests for 5 minutes
   - Labels: `severity: warning`, `tenant: <name>`

5. **HighMemoryUsage** (Warning)
   - Triggers: Memory usage > 80% for 5 minutes
   - Labels: `severity: warning`

6. **HighCPUUsage** (Warning)
   - Triggers: CPU usage > 80% for 5 minutes
   - Labels: `severity: warning`

### Configuring Alert Receivers

Edit `/shared-infrastructure/alertmanager-config.yml` to add integrations:

**Example: Slack Integration**
```yaml
receivers:
  - name: 'critical-alerts'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
        channel: '#alerts'
        title: 'Critical Alert'
        text: '{{ .GroupLabels.alertname }} - {{ .CommonAnnotations.description }}'
```

**Example: Email Integration**
```yaml
receivers:
  - name: 'acme-corp-alerts'
    email_configs:
      - to: 'acme-ops@example.com'
        from: 'alerts@monitoring.example.com'
        smarthost: 'smtp.example.com:587'
```

After updating, restart Prometheus:
```bash
kubectl rollout restart deployment/alertmanager -n monitoring
```

## Testing the Monitoring Stack

### 1. Generate Traffic to Tenant Apps

```bash
# Get one of the tenant service LoadBalancer IPs
kubectl get svc -n acme-corp
kubectl get svc -n closed-ai

# Generate requests
while true; do
  curl http://<service-ip>:5000/hello
  sleep 1
done
```

### 2. Check Metrics in Prometheus

1. Navigate to `http://<prometheus_service>:9090/graph`
2. Query examples:
   ```
   # Request rate per tenant
   sum by (tenant) (rate(http_requests_total[5m]))

   # Error rate per tenant
   sum by (tenant) (rate(http_request_errors_total[5m])) / sum by (tenant) (rate(http_requests_total[5m]))

   # P95 latency
   histogram_quantile(0.95, sum by (tenant, le) (rate(http_request_duration_seconds_bucket[5m])))
   ```

### 3. View Dashboards in Grafana

1. Login to `http://<grafana_service>:3000`
2. Navigate to **Dashboards** → **Tenant Dashboards**
3. Select "Tenant Metrics Overview" to see cross-tenant metrics
4. Select tenant-specific dashboards for detailed analysis

### 4. Trigger Alerts

To test alerting:

```bash
# Simulate high error rate (access non-existent endpoint)
for i in {1..100}; do
  curl http://<service-ip>:5000/error >/dev/null 2>&1
done
```

Check Prometheus at `/alerts` to see triggered alerts.

## Files Created

### Terraform Configuration
- `/shared-infrastructure/monitoring.tf` - Prometheus and AlertManager deployment
- `/shared-infrastructure/grafana.tf` - Grafana deployment and configuration
- `/shared-infrastructure/prometheus-config.yml` - Prometheus scrape configuration
- `/shared-infrastructure/alertmanager-config.yml` - AlertManager routing configuration
- `/shared-infrastructure/alert-rules.yml` - Alert evaluation rules
- `/shared-infrastructure/grafana-datasource-prometheus.yml` - Grafana data source config
- `/shared-infrastructure/grafana-dashboard-provider.yml` - Dashboard provisioning config
- `/shared-infrastructure/variables.tf` - Input variables (Grafana password)

### Dashboard Files
- `/shared-infrastructure/dashboards/tenant-metrics-dashboard.json` - Multi-tenant overview
- `/shared-infrastructure/dashboards/cluster-overview-dashboard.json` - Infrastructure health
- `/shared-infrastructure/dashboards/acme-corp-dashboard.json` - ACME Corp specific
- `/shared-infrastructure/dashboards/closed-ai-dashboard.json` - Closed AI specific

### Application
- `/index.py` - Updated Flask app with Prometheus instrumentation

## Customization Guide

### Adding More Metrics to Flask App

Edit `index.py` and add custom metrics:

```python
from prometheus_client import Counter, Histogram

# Define custom metric
custom_counter = Counter(
    'custom_metric_name',
    'Description of metric',
    ['label1', 'label2']
)

# Use in code
@app.route('/your-endpoint', methods=['POST'])
def your_endpoint():
    # ... your logic ...
    custom_counter.labels(label1='value1', label2='value2').inc()
    return response
```

### Adding New Dashboards

1. Create dashboard in Grafana UI
2. Export as JSON (Dashboard Settings → JSON Model)
3. Save to `/shared-infrastructure/dashboards/your-dashboard.json`
4. Add to ConfigMap in `grafana.tf`:
```terraform
data = {
  "your-dashboard.json" = file("${path.module}/dashboards/your-dashboard.json")
}
```

### Changing Data Retention

Edit `/shared-infrastructure/monitoring.tf`, in the Prometheus deployment args:

```terraform
args = [
  "--config.file=/etc/prometheus/prometheus.yml",
  "--storage.tsdb.path=/prometheus",
  "--storage.tsdb.retention.time=30d",  # Change this (default: 15d)
]
```

### Scaling Prometheus

The current setup uses:
- `1` Prometheus replica
- `10Gi` storage (EBS volume)

To increase:

1. Edit `/shared-infrastructure/monitoring.tf`:
```terraform
spec {
  replicas = 2  # Increase replicas
}

# Add persistent volume claim with larger size
storage = "100Gi"
```

## Troubleshooting

### Prometheus Targets Showing "Down"

```bash
# Check pod logs
kubectl logs -n monitoring deployment/prometheus

# Verify service account permissions
kubectl get clusterrole prometheus
kubectl get clusterrolebinding prometheus
```

### Grafana Not Showing Data

```bash
# Verify Prometheus is reachable from Grafana
kubectl exec -n monitoring deployment/grafana -- \
  curl http://prometheus:9090/-/healthy

# Check Grafana logs
kubectl logs -n monitoring deployment/grafana
```

### Alerts Not Firing

```bash
# Check AlertManager logs
kubectl logs -n monitoring deployment/alertmanager

# Verify alert rules are loaded
kubectl exec -n monitoring deployment/prometheus -- \
  curl localhost:9090/api/v1/rules
```

### Pod Memory/CPU Issues

```bash
# Check resource usage
kubectl top pod -n monitoring

# Scale down if needed
kubectl scale deployment prometheus -n monitoring --replicas=0
kubectl scale deployment prometheus -n monitoring --replicas=1
```

## Production Recommendations

1. **Security**:
   - Change Grafana admin password immediately
   - Add authentication/authorization to Prometheus
   - Use network policies to restrict access

2. **High Availability**:
   - Deploy multiple Prometheus replicas
   - Use persistent volumes on highly available storage
   - Deploy AlertManager in HA mode (>= 2 replicas)

3. **Storage**:
   - Increase retention period based on compliance needs
   - Use AWS S3 for long-term metric archival
   - Monitor disk usage regularly

4. **Backups**:
   - Backup Grafana dashboards regularly
   - Backup AlertManager configuration
   - Use snapshot feature for Prometheus data

5. **Alerting**:
   - Configure multiple alert receivers (Slack, PagerDuty, etc.)
   - Set up escalation policies
   - Test alert routing regularly

## Next Steps

1. ✅ Deploy shared infrastructure with `terraform apply`
2. ✅ Deploy tenant infrastructure
3. ✅ Access Grafana and verify dashboards
4. ✅ Test alert rules by generating traffic
5. ✅ Configure alert integrations (Slack, email, etc.)
6. ✅ Set up backup strategy
7. ✅ Monitor metrics and optimize alert rules

## Support & Documentation

- **Prometheus**: https://prometheus.io/docs/
- **Grafana**: https://grafana.com/docs/
- **AlertManager**: https://prometheus.io/docs/alerting/latest/alertmanager/
- **Kubernetes**: https://kubernetes.io/docs/
