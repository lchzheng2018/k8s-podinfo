
# Podinfo Kubernetes Deployment and Observability Demo

## Overview

This repository contains a Kubernetes deployment setup for `podinfo` using both raw Kubernetes manifests and a reusable Helm chart.

It also includes:
- local Kubernetes cluster setup scripts
- GitHub Actions CI/CD workflows
- Prometheus and Grafana observability setup with RED metrics dashboard, alert rules, and basic SLO/error budget monitoring

The goal of the project was not only to deploy the application, but also to demonstrate operational concepts such as:
- configuration management
- deployment validation
- monitoring and alerting
- deployment automation
- SLO/error budget monitoring

---

## Repository Structure

```text
.
├── .github/workflows/
│   ├── helm-ci.yaml
│   ├── deploy-staging.yaml
│   └── deploy-prod.yaml
│
├── charts/podinfo/
│   ├── templates/
│   │   ├── _helpers.tpl
│   │   ├── configmap.yaml
│   │   ├── deployment.yaml
│   │   ├── hpa.yaml
│   │   └── service.yaml
│   ├── Chart.yaml
│   ├── values.yaml
│   └── values-prod.yaml
│
├── manifests/
│   ├── podinfo-basic.yaml
│   └── podinfo-with-config.yaml
│
├── observability/
│   ├── grafana-dashboard.json
│   ├── prometheus-values.yaml
│   ├── prometheusrule.yaml
│   └── servicemonitor.yaml
│
├── scripts/
│   ├── setup-cluster.sh
│   ├── setup-cluster.ps1
│   ├── deploy-podinfo.sh
│   └── deploy-podinfo-prod.sh
│
└── README.md
```

## Architecture Overview

The local Kubernetes cluster can be created using either:

```bash
./scripts/setup-cluster.sh
```

or:

```powershell
.\scripts\setup-cluster.ps1
```

The project deploys `podinfo` into Kubernetes using both raw manifests and a reusable Helm chart.

The raw manifests under `manifests/` can be used for manual deployment testing or as a simpler deployment example before using the Helm chart.

The Helm chart includes:
- Deployment
- Service
- ConfigMap
- HorizontalPodAutoscaler

GitHub Actions workflows are used for:
- Helm validation
- rendered manifest validation
- staging deployment simulation
- production deployment approval flow
- rollback handling

The application exposes:
- `/healthz` for health probes
- `/metrics` for Prometheus metrics scraping

Prometheus and Grafana are deployed separately through the community `kube-prometheus-stack` chart.

The observability stack includes:
- ServiceMonitor
- PrometheusRule alerts
- Grafana RED metrics dashboard
- basic SLO/error budget monitoring

---

## Kubernetes Manifests

The `manifests/` directory contains raw Kubernetes manifests for deploying podinfo without Helm.

Files:
- `podinfo-basic.yaml`
- `podinfo-with-config.yaml`

Resources included:
- Namespace
- Deployment
- Service
- ConfigMap
- HorizontalPodAutoscaler

The deployment uses:
- readiness and liveness probes
- CPU/memory requests and limits
- ConfigMap-driven UI configuration
- autoscaling based on CPU utilization

---

## Helm Chart Design

The Helm chart is under `charts/podinfo/`. It packages the podinfo deployment into a reusable form so it can be installed, upgraded, and tested consistently with Helm.

The main files are:

- `Chart.yaml`  
  Defines the chart name, chart version, application version, and basic chart metadata.

- `values.yaml`  
  Contains the default configuration used by the templates. This includes the image, replica count, service port, resource requests/limits, HPA settings, and UI color configuration.

- `values-prod.yaml`  
  Provides production-style overrides. The production deployment script and production workflow use this file to show how the same chart can be deployed with different environment settings.

- `templates/_helpers.tpl`  
  Contains reusable helpers for names and labels. This keeps the labels consistent across the Deployment, Service, ConfigMap, and HPA templates.

- `templates/deployment.yaml`  
  Defines the podinfo Deployment. It uses values from `values.yaml` for the image, replica count, resource requests/limits, health probes, and ConfigMap-based environment variable.

- `templates/service.yaml`  
  Defines the ClusterIP Service for podinfo. The service exposes port `80` and forwards traffic to the podinfo container on port `9898`. The service port is named `http` so the Prometheus `ServiceMonitor` can reference it.

- `templates/configmap.yaml`  
  Defines application configuration used by podinfo. In this project it is used for the UI color setting.

- `templates/hpa.yaml`  
  Defines the HorizontalPodAutoscaler. It uses the min/max replica count and CPU utilization target from the values file.

For a normal deployment, the chart uses the default configuration from `values.yaml`. The deployment can be done with:

```bash
./scripts/deploy-podinfo.sh
```

For a production-style deployment, the chart uses overrides from `values-prod.yaml`. The deployment can be done with:

```bash
./scripts/deploy-podinfo-prod.sh
```

The deployment scripts also wait for rollout completion and print the main Kubernetes resources after deployment for easier verification.

---

## CI/CD Pipeline

GitHub Actions workflows are located under:

```text
.github/workflows/
```

The pipeline performs:
- Helm lint validation
- rendered manifest validation
- simulated staging deployment
- manual approval before production deployment
- rollback handling for failed production deployment

### Helm Validation (CI)

Workflow file:

```text
.github/workflows/helm-ci.yaml
```

Every push triggers:

```bash
helm lint charts/podinfo

helm template podinfo charts/podinfo
```

to validate both the chart structure and rendered manifests.

The validation workflow status can be checked in the GitHub repository Actions tab.

### Staging Deployment

Workflow file:

```text
.github/workflows/deploy-staging.yaml
```

The staging workflow uses a temporary `kind` cluster created during the GitHub Actions run. This allows the workflow to simulate:

```bash
helm upgrade --install podinfo charts/podinfo \
  --namespace podinfo-staging \
  --create-namespace \
  --dry-run=client \
  --debug
```

without requiring a long-running Kubernetes cluster.

The staging deployment status can also be checked in the GitHub repository Actions tab.

### Production Deployment

Workflow file:

```text
.github/workflows/deploy-prod.yaml
```

Production deployment uses GitHub Environments with required reviewer approval configured in the repository settings.

Before the workflow can be used, the `production` GitHub Environment must be created manually in the repository settings with required reviewer approval enabled.

Rollback handling is implemented with:

```bash
helm upgrade --install podinfo charts/podinfo \
  --namespace podinfo-prod \
  --create-namespace \
  -f charts/podinfo/values-prod.yaml \
  --rollback-on-failure \
  --wait \
  --timeout 5m
```

The production deployment workflow status can be checked in the GitHub repository Actions tab.

In a real production setup, secure kubeconfig handling and cluster credentials would be required.

---

## Observability Stack

The observability resources are stored under:

```text
observability/
```

Prometheus and Grafana are installed through the community `kube-prometheus-stack` Helm chart.

### Prometheus and Grafana Install

Related file:

```text
observability/prometheus-values.yaml
```

Install command:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  -f observability/prometheus-values.yaml
```

The values file allows Prometheus to discover custom `ServiceMonitor` and `PrometheusRule` resources.

### ServiceMonitor

Related file:

```text
observability/servicemonitor.yaml
```

The `ServiceMonitor` tells Prometheus how to scrape podinfo metrics.

It selects the podinfo Service in the `podinfo` namespace using the Service labels:

```yaml
app.kubernetes.io/name: podinfo
app.kubernetes.io/instance: podinfo
```

It then scrapes the Service port named:

```text
http
```

at:

```text
/metrics
```

This means the podinfo Service must expose a named port:

```yaml
ports:
  - name: http
    port: 80
    targetPort: 9898
```

Without the named port, Prometheus can find the `ServiceMonitor`, but it will not find any scrape targets.

To verify Prometheus target discovery:

```bash
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
```

Then open:

```text
http://localhost:9090/targets
```

The podinfo target should appear as up under the `podinfo` job.

### Grafana Dashboard

Related file:

```text
observability/grafana-dashboard.json
```

The dashboard contains three RED metric panels:
- request rate
- error rate
- p99 latency

To access Grafana:

```bash
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
```

Then open:

```text
http://localhost:3000
```

The default user is:

```text
admin
```

The password can be retrieved with:

```bash
kubectl --namespace monitoring get secrets monitoring-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d ; echo
```

Import the dashboard from:

```text
observability/grafana-dashboard.json
```

The dashboard is intentionally small and focused on the RED metrics required for this assignment. In a production setup, I would extend it with additional panels such as pod restarts, CPU/memory usage, HPA behavior, and deployment health.

### Prometheus Alerts

Related file:

```text
observability/prometheusrule.yaml
```

The alert file defines alerts for availability, latency, and error-budget burn.

#### PodinfoUnavailable

Purpose:

```text
Alert if Prometheus cannot scrape podinfo for more than 2 minutes.
```

This catches cases where the service is down, the pods are unavailable, or the metrics endpoint cannot be reached.

#### PodinfoHighLatency

Purpose:

```text
Alert if p99 latency is above 200ms for more than 5 minutes.
```

The 200ms threshold matches the latency SLO used in this assignment. The 5-minute duration avoids alerting on very short spikes.

#### PodinfoHighErrorBudgetBurn

Purpose:

```text
Alert if 5xx errors are consuming the availability error budget too quickly.
```

For a 99.9% availability SLO, the allowed error budget is 0.1%. The burn-rate alert uses a higher short-window threshold to catch fast budget consumption without alerting on every small error.

---

## SLO / SLI / Error Budget

For this assignment, I defined two basic SLOs for podinfo:

- Availability SLO: 99.9%
- Latency SLO: p99 latency < 200ms

### Availability SLI

The request-based availability SLI is calculated as the ratio of successful requests over total requests:

```promql
1 - (
  sum(rate(http_requests_total{job="podinfo",status=~"5.."}[5m]))
  /
  sum(rate(http_requests_total{job="podinfo"}[5m]))
)
```

I also use the Prometheus `up` metric as a simpler service availability signal:

```promql
up{job="podinfo"}
```

### Latency SLI

The latency SLI uses p99 request latency:

```promql
histogram_quantile(
  0.99,
  sum(rate(http_request_duration_seconds_bucket{job="podinfo"}[5m])) by (le)
)
```

The alert threshold is 200ms, which matches the latency SLO.

### Error Budget

For a 99.9% availability SLO, the allowed failure budget is:

```text
100% - 99.9% = 0.1%
```

So over a 30-day window, the service can be unavailable or return errors for roughly:

```text
30 days * 24 hours/day * 60 minutes/hour * 0.001 = 43.2 minutes
```

This is the monthly error budget for the availability SLO.

### Burn-rate Alert

The burn-rate alert is defined in:

```text
observability/prometheusrule.yaml
```

It checks whether 5xx errors are consuming the availability error budget too quickly:

```promql
(
  sum(rate(http_requests_total{job="podinfo",status=~"5.."}[5m]))
  /
  sum(rate(http_requests_total{job="podinfo"}[5m]))
) > 0.0144
```

The base error budget is `0.001` for a 99.9% SLO. The alert threshold `0.0144` means the service is burning budget at about `14.4x` the allowed rate over the short window.

This is a simplified burn-rate alert for the assignment. In a real production setup, I would normally use multi-window burn-rate alerts, for example a fast page-level alert and a slower ticket-level alert.

---

## Deployment Instructions

The previous sections already describe the individual deployment and observability steps. This section collects the main commands together as a complete deployment flow.

### Create Local Cluster

```bash
./scripts/setup-cluster.sh
```

or:

```powershell
.\scripts\setup-cluster.ps1
```

### Deploy podinfo

For a normal deployment:

```bash
./scripts/deploy-podinfo.sh
```

For a production-style deployment:

```bash
./scripts/deploy-podinfo-prod.sh
```

### Install Observability Stack

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  -f observability/prometheus-values.yaml
```

### Apply Monitoring Resources

```bash
kubectl apply -f observability/servicemonitor.yaml

kubectl apply -f observability/prometheusrule.yaml
```

### Verify Monitoring Stack

Prometheus targets can be checked with:

```bash
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
```

Then open:

```text
http://localhost:9090/targets
```

Grafana can be accessed with:

```bash
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
```

Then open:

```text
http://localhost:3000
```

Import the dashboard from:

```text
observability/grafana-dashboard.json
```

---

## Design Decisions / Tradeoffs

A few parts of the implementation were intentionally simplified for the assignment.

- The staging deployment uses a temporary `kind` cluster created during the GitHub Actions workflow instead of a persistent shared cluster.
- The production deployment workflow includes approval and rollback logic, but does not connect to a real production Kubernetes cluster.
- Alert thresholds and SLO windows are simplified examples intended to demonstrate the monitoring concepts rather than production tuning.
- The Grafana dashboard focuses mainly on the required RED metrics and does not include infrastructure-level monitoring.
- The Helm chart keeps a relatively small set of configurable values to keep the example easier to review.

The goal was to keep the implementation reasonably small while still covering deployment, CI/CD, observability, and operational concepts.

---

## Limitations / Future Improvements

Given more time, a few areas could be expanded further:

- Separate Helm values files for additional environments beyond production.
- More realistic deployment validation tests in the CI pipeline.
- Alertmanager integration for notifications instead of local alert rules only.
- Additional Grafana dashboards for infrastructure and Kubernetes-level monitoring.
- Additional application metrics and dashboards beyond the RED model.
- More advanced SLO burn-rate windows and multi-window alerting strategies.