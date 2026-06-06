#!/usr/bin/env bash

# Stop immediately if a command fails
set -euo pipefail

# Start minikube cluster
status="$(minikube status --format='{{.Host}}' 2>/dev/null || true)"
if [[ "$status" != "Running" ]]; then
  minikube start --driver=docker --cpus=4 --memory=8192
fi

# An alternative approach
# kubectl create namespace podinfo || true
# kubectl create namespace monitoring || true

# Create namespaces for podinfo and monitoring
kubectl create namespace podinfo --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Wait for system pods to become ready
kubectl wait --namespace kube-system --for=condition=Ready pods --all --timeout=60s

# Verify cluster status 
kubectl get nodes
kubectl get namespaces
kubectl get pods -A