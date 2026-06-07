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