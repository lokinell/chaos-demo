#!/bin/bash
set -e

# Build the Docker image
echo "Building Docker image..."
docker build -t localhost:30500/demo-web-service:latest .

# Push to Kubernetes registry (via NodePort)
echo "Pushing to Kubernetes registry..."
docker push localhost:30500/demo-web-service:latest

# Apply Kubernetes manifests
echo "Deploying application..."
kubectl apply -f k8s/demo-app.yaml

# Wait for deployment to be ready
echo "Waiting for deployment to be ready..."
kubectl -n demo wait --for=condition=available --timeout=300s deployment/web-service
kubectl -n demo wait --for=condition=available --timeout=300s deployment/redis
kubectl -n demo wait --for=condition=ready --timeout=300s pod -l app=mysql

echo "Application deployed successfully!"
echo "You can access the application using:"
echo "kubectl -n demo port-forward svc/web-service 8080:8080"
echo "Then visit http://localhost:8080 in your browser" 