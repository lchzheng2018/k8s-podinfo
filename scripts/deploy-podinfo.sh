#!/usr/bin/env bash
set -euo pipefail

echo "Deploying podinfo..."

helm upgrade --install podinfo charts/podinfo \
  --namespace podinfo \
  --create-namespace


echo
echo "Waiting for deployment rollout to complete..."
kubectl rollout status deployment/podinfo -n podinfo

kubectl get pods -n podinfo
kubectl get svc -n podinfo
kubectl get hpa -n podinfo