# Monitoring Stack - Quick Start Guide

Get up and running with Prometheus, Grafana, and AlertManager in 5 minutes.

## 1. Deploy Infrastructure

```bash
# Deploy shared infrastructure (EKS + Monitoring Stack)
cd /Users/nikhilkulkarni/Multi-Tenant-Platform/shared-infrastructure
terraform init
terraform apply

# Output shows service endpoints:
# - prometheus_service = "xxx.elb.amazonaws.com"
# - grafana_service = "yyy.elb.amazonaws.com"
```

## 2. Deploy Tenants

```bash
cd /Users/nikhilkulkarni/Multi-Tenant-Platform/tenants/acme-corp
terraform init
terraform apply

cd ../closed-ai
terraform init
terraform apply
```

## 3. Access Services

| Service | URL | Credentials |
|---------|-----|-------------|
| **Prometheus** | `http://<prometheus_service>:9090` | No auth |
| **Grafana** | `http://<grafana_service>:3000` | admin / admin |
| **AlertManager** | Internal only | No auth |

## 4. Generate Traffic

Get tenant service IPs:
```bash
kubectl get svc -n acme-corp
kubectl get svc -n closed-ai
```

Generate requests:
```bash
# ACME Corp
for i in {1..100}; do
  curl http://<acme-corp-service>:5000/hello
done

# Closed AI
for i in {1..100}; do
  curl http://<closed-ai-service>:5000/hello
done
```

## 5. View Dashboards

1. Login to Grafana: `http://<grafana_service>:3000`
2. Go to **Dashboards**
3. Select:
   - **Tenant Metrics Overview** - See all tenants
   - **ACME Corp Tenant Dashboard** - ACME specific
   - **Closed AI Tenant Dashboard** - Closed AI specific
   - **Cluster Overview** - Infrastructure health

## Key Metrics to Monitor

### Per Tenant
- **Request Rate**: `sum by (tenant) (rate(http_requests_total[5m]))`
- **Error Rate**: `sum by (tenant) (rate(http_request_errors_total[5m])) / sum by (tenant) (rate(http_requests_total[5m]))`
- **P95 Latency**: `histogram_quantile(0.95, sum by (tenant, le) (rate(http_request_duration_seconds_bucket[5m])))`
- **Active Requests**: `http_requests_active{tenant=""}`

### Cluster Health
- **Node CPU**: `avg by (node) (rate(node_cpu_seconds_total[5m]))`
- **Node Memory**: `(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))`
- **Pod Count**: `count(kube_pod_info)`
- **Failed Pods**: Count of pods not in Ready state

## Common Tasks

### Check Metrics Scraping
1. Go to Prometheus: `http://<prometheus_service>:9090/targets`
2. Verify all targets show "UP"
3. Green = metrics flowing, Red = problems

### Create Custom Dashboard
1. Click **+** → **Create** → **Dashboard**
2. Click **Add panel**
3. Write PromQL query: `http_requests_total{tenant="acme-corp"}`
4. Click **Save**

### Set Up Alerts
Edit `/shared-infrastructure/alertmanager-config.yml`:
```yaml
receivers:
  - name: 'slack-alerts'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK'
```

Redeploy:
```bash
cd shared-infrastructure
terraform apply
```

### Test Alert Rules
```bash
# Trigger high error rate
for i in {1..50}; do
  curl http://<service>:5000/error >/dev/null 2>&1
done

# Check Prometheus alerts
# Go to: http://<prometheus_service>:9090/alerts
```

## File Structure

```
shared-infrastructure/
├── monitoring.tf                      # Prometheus + AlertManager
├── grafana.tf                         # Grafana deployment
├── prometheus-config.yml              # Scrape configuration
├── alertmanager-config.yml            # Alert routing
├── alert-rules.yml                    # Alert rules
├── grafana-datasource-prometheus.yml  # Data source config
├── grafana-dashboard-provider.yml     # Dashboard provisioning
├── dashboards/
│   ├── tenant-metrics-dashboard.json
│   ├── cluster-overview-dashboard.json
│   ├── acme-corp-dashboard.json
│   └── closed-ai-dashboard.json
├── terraform.tf                       # Provider config
├── main.tf                            # EKS infrastructure
├── variables.tf                       # Variables
└── outputs.tf                         # Output endpoints

index.py                               # Flask app with metrics
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| No data in Grafana | Check Prometheus targets are UP |
| Alerts not firing | Verify alert rules in Prometheus /alerts page |
| Can't access Grafana | Check LoadBalancer status: `kubectl get svc -n monitoring` |
| Metrics missing | Verify pods have `/metrics` endpoint |

## Next: Production Setup

- [ ] Change Grafana admin password
- [ ] Configure Slack/PagerDuty alerts
- [ ] Increase data retention: edit `monitoring.tf` → `--storage.tsdb.retention.time=30d`
- [ ] Enable high availability: increase replicas
- [ ] Set up backups for Grafana dashboards
- [ ] Add security policies

## Useful Links

- Prometheus queries: https://prometheus.io/docs/prometheus/latest/querying/basics/
- Grafana docs: https://grafana.com/docs/grafana/latest/
- PromQL examples: https://prometheus.io/docs/prometheus/latest/querying/examples/

---

**Need help?** See `MONITORING_SETUP.md` for detailed documentation.
