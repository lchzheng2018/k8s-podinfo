
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
│   ├── setup-cluster.ps1
│   └── setup-cluster.sh
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

The values files provide the configuration, and the templates render the Kubernetes resources. For a normal deployment:

```bash
./scripts/deploy-podinfo.sh
```

For a production-style deployment using `values-prod.yaml`:

```bash
./scripts/deploy-podinfo-prod.sh
```

The deployment scripts also wait for rollout completion and print the main resources after deployment, which makes manual verification easier.

---

## CI/CD Pipeline

GitHub Actions workflows are located under:

```text
.github/workflows/
```

The pipeline performs:
- `helm lint`
- `helm template`
- simulated staging deployment
- manual approval before production deployment
- rollback handling for failed production deployment

### Helm Validation

Every push triggers:

```bash
helm lint charts/podinfo

helm template podinfo charts/podinfo
```

to validate both the chart structure and rendered manifests.

### Staging Deployment

The staging workflow uses a temporary `kind` cluster created during the GitHub Actions run. This allows the workflow to simulate:

```bash
helm upgrade --install
```

without requiring a long-running Kubernetes cluster.

### Production Deployment

Production deployment uses GitHub Environments with required reviewer approval configured in the repository settings.

Rollback handling is implemented with:

```bash
helm rollback podinfo
```

In a real production setup, secure kubeconfig handling and cluster credentials would be required.

---

## Observability Stack

Prometheus and Grafana are deployed using the official community Helm chart:

```bash
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack
```

The observability configuration is stored under:

```text
observability/
```

Included resources:
- ServiceMonitor
- PrometheusRule
- Grafana dashboard
- Prometheus values override

### ServiceMonitor

A `ServiceMonitor` resource is used to allow Prometheus to scrape the podinfo metrics endpoint.

Metrics are scraped every 15 seconds from:

```text
/metrics
```

### Grafana Dashboard

The Grafana dashboard visualizes RED metrics:
- request rate
- error rate
- latency

### Alerting

Prometheus alert rules were added for:
- service unavailability
- high latency
- excessive error budget burn

---

## SLO / SLI / Error Budget

The following SLOs were defined for the service:

- 99.9% availability
- p99 latency below 200ms

Example SLI queries:

Availability:

```promql
up{job="podinfo"}
```

Error rate:

```promql
rate(http_requests_total{status=~"5.."}[5m])
```

Latency:

```promql
histogram_quantile(
  0.99,
  sum(rate(http_request_duration_seconds_bucket[5m])) by (le)
)
```

A 99.9% availability SLO allows a 0.1% error budget.

Burn-rate alerts were added to detect excessive error budget consumption over short time windows.

---

## Deployment Instructions

### Deploy podinfo

```bash
helm upgrade --install podinfo charts/podinfo \
  --namespace podinfo \
  --create-namespace
```

### Install Prometheus and Grafana

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

---

## Design Decisions / Tradeoffs

A few parts of the implementation were intentionally simplified for the assignment.

- The staging deployment uses a temporary `kind` cluster created during the GitHub Actions workflow instead of a persistent shared cluster.
- The production deployment workflow includes approval and rollback logic, but does not connect to a real production Kubernetes cluster.
- Alert thresholds and SLO windows are simplified examples intended to demonstrate monitoring concepts rather than production tuning.
- The Grafana dashboard focuses on RED metrics only and does not include infrastructure-level monitoring.
- The Helm chart keeps a relatively small set of configurable values to keep the example easier to review.

The goal was to keep the implementation reasonably small while still covering deployment, CI/CD, observability, and operational concepts.

---

## Limitations / Future Improvements

Given more time, a few areas could be expanded further:

- Separate Helm values files for additional environments beyond production.
- More realistic deployment validation tests in the CI pipeline.
- Alertmanager integration for notifications instead of local alert rules only.
- Persistent Grafana dashboards and storage configuration.
- Additional application metrics and dashboards beyond the RED model.
- More advanced SLO burn-rate windows and multi-window alerting strategies.