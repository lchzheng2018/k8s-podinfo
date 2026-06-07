
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

---
## Written Responses

### Prompt 1: Incident Response

**Question:**  
*It’s 2am and your alert fires — podinfo has been unreachable for 3 minutes. Walk through your investigation and remediation steps, from the moment you receive the alert to the moment the service is restored. Include how you would write up the postmortem: what sections would it contain, what questions would it seek to answer, and what follow-up actions would you drive from it?*

If I received an alert that podinfo had been unreachable for more than 3 minutes, the first thing I would do is confirm whether this is a real outage or a false alert. I would check Prometheus and Grafana to see whether the podinfo target is down, whether traffic dropped to zero, and whether latency or error rate spiked before the outage. I would also check the Kubernetes resources directly to see whether the pods are healthy and whether there were recent deployment or scheduling events.

At that point I would try to quickly narrow the issue down to one of a few common categories:

- failed deployment
- crashing pods
- probe failures
- configuration changes
- networking/service issues

If there was a recent rollout, I would immediately inspect rollout history and pod logs. If the latest deployment caused the issue, I would rollback first to restore service before spending more time on deeper root-cause analysis.

After recovery, I would verify that the pods are healthy again, traffic and metrics returned to normal, and the alerts cleared correctly. I would also continue monitoring for a while to make sure the service remained stable.

For the postmortem, I would document the incident timeline, root cause, customer impact, detection method, remediation steps, and follow-up actions. The main questions I would try to answer are:

- what failed
- why the failure was not prevented earlier
- whether monitoring and alerts worked correctly
- whether the rollout or recovery process could be improved

The follow-up actions would depend on the root cause, but likely include:

- improving monitoring and alert coverage
- improving deployment validation before rollout
- reducing recovery time through faster rollback or automated recovery mechanisms
- improving operational visibility to detect similar failures earlier

### Prompt 2: Capacity Planning

**Question:**  
*podinfo is currently handling 5,000 requests per minute with an average pod CPU utilization of 60%. Your product team projects 4x traffic growth over the next quarter. Describe how you would model and plan for this growth: what signals would you instrument, how would you forecast resource needs, what headroom would you maintain, and at what thresholds would you trigger a scaling review? You do not need to implement this — a written plan with your reasoning is sufficient.*

The first thing I would do is establish a baseline for the current workload and verify whether CPU is actually the primary bottleneck. Besides CPU utilization, I would also monitor request rate, latency, error rate, memory usage, pod restart frequency, HPA behavior, and node-level resource pressure. I would especially pay attention to whether latency or error rate starts increasing before CPU becomes saturated.

Since the projected traffic growth is 4x, I would initially assume the service may eventually need close to 4x the current compute capacity unless optimization work reduces the per-request cost. If the current workload is running at 60% average CPU utilization, a simple linear estimate would push utilization far beyond safe operating levels under 4x traffic growth, so additional replicas and cluster capacity would clearly be required.

I would normally avoid running production services near maximum utilization for extended periods. For a service like this, I would probably target keeping average CPU utilization closer to 50-60% during normal operation to preserve headroom for traffic spikes, deployment rollouts, node failures, and uneven traffic distribution.

I would also review historical traffic patterns to understand:
- peak versus average traffic
- daily or weekly traffic cycles
- burst behavior
- deployment-time traffic impact

Based on those patterns, I would adjust the HPA thresholds and estimate the number of replicas required for both normal peak traffic and unexpected spikes.

I would trigger a scaling review if I started seeing trends such as:
- sustained CPU utilization above 70-80%
- increasing request latency
- HPA frequently scaling near maximum replicas
- node-level resource pressure
- rising error rates during peak traffic

I would also periodically load test the service to validate the assumptions and make sure the scaling behavior still matched the real traffic patterns as usage continued to grow.

### Prompt 3: Architecture Trade-offs

**Question:**  
*You need to extend this deployment to run in two regions (e.g. us-west and us-east) with active-active traffic. Describe the key infrastructure decisions you would need to make: how would you handle data consistency, route traffic between regions, manage deployments across both, and detect a regional failure? What would you do differently compared to a single-region setup, and what trade-offs would you accept?*

#### How would you handle data consistency?

For an active-active two-region setup, I would first separate the stateless application layer from any stateful dependency. The podinfo application itself is mostly stateless, so running replicas in both `us-west` and `us-east` is straightforward. The harder part is deciding how shared state, configuration, monitoring data, and downstream dependencies should behave across regions.

For stateful dependencies, I would first decide whether the system can tolerate eventual consistency or requires stronger consistency. If eventual consistency is acceptable, I would prefer regional writes with asynchronous replication because it keeps latency lower and allows each region to operate more independently. If strong consistency is required, the design becomes more expensive and fragile because cross-region writes add latency and can reduce availability during network partitions.

I would also compare data and service behavior across regions. For example, I would check whether key service metrics such as request rate, error rate, latency, and success rate are consistent between `us-west` and `us-east`. For higher confidence, we could run controlled traffic splitting or A/B-style comparison between regions before fully shifting traffic.

#### How would you route traffic between regions?

I would use global load balancing or DNS-based routing to send users to the closest healthy region. The routing policy should support health checks and failover. If one region becomes unhealthy, traffic can be shifted to the other region.

Before shifting traffic back, I would make sure the recovered region is healthy again and that both regions have enough capacity to safely handle the traffic.

#### How would you manage deployments across both regions?

I would not roll out to both regions blindly at the same time. I would deploy to one region first, verify health metrics, error rate, latency, and service behavior, and then continue to the second region.

The same Helm chart can still be used, but I would keep region-specific values files for differences such as replica count, resource sizing, ingress configuration, and regional endpoints.

#### How would you detect a regional failure?

Failure detection needs to happen at multiple levels:
- pod health
- service metrics
- regional ingress/load balancer health
- end-to-end synthetic checks from outside the cluster

A region should not be considered healthy just because Kubernetes pods are running. I would want alerts on:
- regional traffic drop
- elevated 5xx rate
- high latency
- failed synthetic probes
- inability to scrape metrics from one region

#### What would you do differently compared to a single-region setup, and what trade-offs would you accept?

Compared with a single-region setup, the main trade-offs are:

- better availability, but more operational complexity
- faster regional failover, but higher infrastructure cost
- lower latency with regional serving, but harder data consistency
- safer deployments with staged regional rollout, but slower release speed
- better failure isolation, but more monitoring and alerting work
- eventual consistency where possible, but more careful product behavior design