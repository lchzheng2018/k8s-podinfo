# Stop immediately if a command fails
$ErrorActionPreference = "Stop"

# Start minikube cluster
$status = minikube status --format="{{.Host}}" 2>$null
if ($status -ne "Running") {
    minikube start --driver=docker --cpus=4 --memory=8192
}

# Alternative approach
# kubectl create namespace podinfo || true
# kubectl create namespace monitoring || true

# Create namespaces for podinfo and monitoring
kubectl create namespace podinfo --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Wait for system pods to become ready
kubectl wait --namespace kube-system --for=condition=Ready pods --all --timeout=60s

# Verify cluster statusb
kubectl get nodes
kubectl get namespaces
kubectl get pods -A