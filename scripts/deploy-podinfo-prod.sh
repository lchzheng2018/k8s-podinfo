#!/usr/bin/env bash
set -euo pipefail

echo "Deploying podinfo with production values..."

helm upgrade --install podinfo charts/podinfo \
  --namespace podinfo-prod \
  --create-namespace \
  -f charts/podinfo/values-prod.yaml \
  --rollback-on-failure \
  --wait \
  --timeout 5m

echo
echo "Waiting for deployment rollout to complete..."

kubectl rollout status deployment/podinfo -n podinfo-prod

echo
echo "Current production podinfo resources:"

kubectl get pods -n podinfo-prod
kubectl get svc -n podinfo-prod
kubectl get hpa -n podinfo-prod

echo
echo "Production deployment completed successfully."