# Part 4: Observability & Monitoring

## Overview

This document describes the observability and monitoring implementation for the Titanic API, providing comprehensive visibility into application performance, errors, and resource utilization.

## Requirements Summary

### 1. Application Instrumentation
- ✅ Structured logging (JSON format)
- ✅ Prometheus metrics endpoint (`/metrics`)
- ✅ Distributed tracing (OpenTelemetry)
- ✅ Custom business metrics (API requests, response times, error rates)

### 2. Monitoring Stack
- ✅ Prometheus configuration for scraping (ServiceMonitor)
- ✅ Grafana dashboard (minimum 3 panels):
  - Request rate and latency
  - Error rate
  - Resource utilization (CPU/Memory)
- ✅ Alert rules for critical scenarios

### 3. Logging Strategy
- ✅ Centralized logging (Loki)
- ✅ Log aggregation from all pods (Promtail)
- ✅ Structured logging format (JSON)
- ✅ Log retention policy

## Architecture

```
┌─────────────────┐
│  Titanic API    │
│  (Flask App)    │
│                 │
│  - /metrics     │──┐
│  - JSON Logs    │  │
│  - OTel Traces  │  │
└─────────────────┘  │
                     │
        ┌────────────┴────────────┐
        │                         │
┌───────▼────────┐      ┌─────────▼────────┐
│  Prometheus    │      │      Loki        │
│  (Metrics)     │      │   (Logs)         │
└───────┬────────┘      └─────────┬────────┘
        │                         │
        │                         │
┌───────▼────────┐      ┌─────────▼────────┐
│    Grafana     │      │    Promtail      │
│  (Dashboards)  │      │ (Log Collector)  │
└────────────────┘      └──────────────────┘
```

## Components

### 1. Application Instrumentation

#### Prometheus Metrics
- **Endpoint**: `/metrics`
- **Metrics Exposed**:
  - `http_requests_total` - Total HTTP requests
  - `http_request_duration_seconds` - Request latency histogram
  - `http_requests_in_progress` - Current requests in progress
  - `database_connections_active` - Active database connections
  - `database_query_duration_seconds` - Database query latency

#### Structured Logging
- **Format**: JSON
- **Fields**:
  - `timestamp` - ISO 8601 format
  - `level` - Log level (INFO, WARNING, ERROR)
  - `logger` - Logger name
  - `message` - Log message
  - `service` - Service name (titanic-api)
  - `environment` - Environment (dev/staging/prod)
  - `request_id` - Request correlation ID (if available)
  - `user_id` - User ID (if authenticated)
  - `path` - Request path
  - `method` - HTTP method
  - `status_code` - HTTP status code
  - `duration_ms` - Request duration in milliseconds

#### OpenTelemetry Tracing
- **Instrumentation**: Flask and SQLAlchemy
- **Exporter**: Prometheus (metrics) + OTLP (traces)
- **Trace Context**: Propagated via HTTP headers

### 2. Monitoring Stack

#### Prometheus Configuration
- **ServiceMonitor**: Automatically discovers and scrapes `/metrics` endpoint
- **Scrape Interval**: 30 seconds
- **Scrape Timeout**: 10 seconds

#### Grafana Dashboard
- **Dashboard ID**: `titanic-api-overview`
- **Panels**:
  1. **Request Rate**: Requests per second (rate)
  2. **Latency**: P50, P95, P99 percentiles
  3. **Error Rate**: 4xx and 5xx errors per second
  4. **Resource Utilization**: CPU and Memory usage

#### Alert Rules
- **High Error Rate**: Error rate > 5% for 5 minutes
- **High Latency**: P95 latency > 1 second for 5 minutes
- **Pod CrashLoopBackOff**: Pod restarting repeatedly
- **High CPU Usage**: CPU usage > 80% for 10 minutes
- **High Memory Usage**: Memory usage > 80% for 10 minutes
- **Database Connection Failure**: Database connection errors

### 3. Logging Stack

#### Loki Configuration
- **Retention**: 30 days (production), 7 days (staging/dev)
- **Storage**: PersistentVolumeClaim
- **Replicas**: 1 (dev/staging), 2 (production)

#### Promtail Configuration
- **DaemonSet**: Runs on all nodes
- **Scrapes**: All pod logs from `/var/log/pods`
- **Labels**: namespace, pod, container, app

## Implementation Files

### Application Code
- `titanic-api/src/observability/` - Observability module
  - `metrics.py` - Prometheus metrics setup
  - `logging.py` - Structured JSON logging
  - `tracing.py` - OpenTelemetry tracing setup
- `titanic-api/src/app.py` - Updated with observability integration

### Kubernetes Manifests
- `part-4-observability/manifests/servicemonitor.yaml` - Prometheus scraping config
- `part-4-observability/manifests/prometheusrule.yaml` - Alert rules
- `part-4-observability/manifests/loki-stack.yaml` - Loki and Promtail installation
- `part-4-observability/manifests/grafana-dashboard.yaml` - Grafana dashboard config

### Helm Chart
- `part-2-kubernetes/helm/titanic-api/templates/servicemonitor.yaml`
- `part-2-kubernetes/helm/titanic-api/templates/prometheusrule.yaml`
- `part-2-kubernetes/helm/titanic-api/values.yaml` - Observability configuration

## Setup Instructions

### Prerequisites
- Prometheus Operator installed (via Part 5 Terraform)
- Grafana accessible (via Part 5 Terraform)
- kubectl configured to access cluster

### Deployment Steps

1. **Deploy Loki Stack**:
   ```bash
   kubectl apply -f part-4-observability/manifests/loki-stack.yaml
   ```

2. **Deploy Application with Observability**:
   ```bash
   # Via Helm
   helm upgrade --install titanic-api \
     ./part-2-kubernetes/helm/titanic-api \
     --set observability.enabled=true
   
   # Via Kustomize
   kubectl apply -k part-2-kubernetes/kustomize/overlays/prod
   ```

3. **Verify ServiceMonitor**:
   ```bash
   kubectl get servicemonitor -n titanic-api-prod
   ```

4. **Import Grafana Dashboard**:
   - Access Grafana: `kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80`
   - Login: admin/admin (change password on first login)
   - Import dashboard JSON from `part-4-observability/grafana/titanic-api-dashboard.json`

5. **Verify Metrics**:
   ```bash
   # Port-forward to Prometheus
   kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
   # Query: http_requests_total
   ```

6. **Verify Logs**:
   ```bash
   # Port-forward to Loki
   kubectl port-forward -n monitoring svc/loki 3100:3100
   # Query logs via Grafana Explore or Loki API
   ```

## Accessing Dashboards

### Grafana
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Access: http://localhost:3000
# Default credentials: admin/admin (CHANGE IMMEDIATELY)
```

### Prometheus
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Access: http://localhost:9090
```

### Alertmanager
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
# Access: http://localhost:9093
```

## Metrics Reference

### HTTP Metrics
- `titanic_api_http_requests_total{method, endpoint, status}` - Total requests
- `titanic_api_http_request_duration_seconds{method, endpoint}` - Request latency
- `titanic_api_http_requests_in_progress` - Current requests

### Database Metrics
- `titanic_api_database_connections_active` - Active connections
- `titanic_api_database_query_duration_seconds{query_type}` - Query latency

### System Metrics (from Kubernetes)
- `container_cpu_usage_seconds_total` - CPU usage
- `container_memory_usage_bytes` - Memory usage
- `kube_pod_status_phase` - Pod phase

## Alert Examples

### High Error Rate
```yaml
- alert: HighErrorRate
  expr: rate(titanic_api_http_requests_total{status=~"5.."}[5m]) > 0.05
  for: 5m
  annotations:
    summary: "High error rate detected"
```

### High Latency
```yaml
- alert: HighLatency
  expr: histogram_quantile(0.95, titanic_api_http_request_duration_seconds) > 1
  for: 5m
  annotations:
    summary: "P95 latency exceeds 1 second"
```

## Troubleshooting

### Metrics Not Appearing
1. Check ServiceMonitor: `kubectl get servicemonitor -n titanic-api-prod`
2. Check Prometheus targets: Access Prometheus UI → Status → Targets
3. Verify `/metrics` endpoint: `curl http://<pod-ip>:5000/metrics`

### Logs Not Appearing in Loki
1. Check Promtail pods: `kubectl get pods -n monitoring -l app=promtail`
2. Check Promtail logs: `kubectl logs -n monitoring -l app=promtail`
3. Verify log format: Check application logs are JSON formatted

### Dashboard Not Loading
1. Verify data source: Check Grafana data sources (Prometheus, Loki)
2. Check time range: Ensure time range includes data
3. Verify queries: Check panel queries match available metrics

## Next Steps

- [ ] Implement APM integration (DataDog/New Relic) - Bonus
- [ ] Define SLI/SLO metrics - Bonus
- [ ] Set up automated incident response - Bonus
- [ ] Configure alert notifications (Slack/Email)
- [ ] Add custom business metrics (e.g., passenger data operations)

## References

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator)
