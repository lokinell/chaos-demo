#!/bin/bash
set -e

# Build the Python web service Docker image
echo "Building Python web service Docker image..."
docker build -t localhost:30500/demo-web-service:latest .

# Build the Java service Docker image
echo "Building Java service Docker image..."
cd java-service
docker build -t localhost:30500/demo-java-service:latest .
cd ..

# Push to Kubernetes registry (via NodePort)
echo "Pushing images to Kubernetes registry..."
docker push localhost:30500/demo-web-service:latest
docker push localhost:30500/demo-java-service:latest

# Apply Kubernetes manifests
echo "Deploying application..."
kubectl apply -f k8s/demo-app.yaml
kubectl apply -f k8s/java-service.yaml

# Wait for deployment to be ready
echo "Waiting for deployment to be ready..."
kubectl -n demo wait --for=condition=available --timeout=300s deployment/web-service
kubectl -n demo wait --for=condition=available --timeout=300s deployment/redis
kubectl -n demo wait --for=condition=available --timeout=300s deployment/java-service
kubectl -n demo wait --for=condition=ready --timeout=300s pod -l app=mysql

echo "Application deployed successfully!"
echo "You can access the web service using:"
echo "kubectl -n demo port-forward svc/web-service 8080:8080"
echo "Then visit http://localhost:8080 in your browser"
echo ""
echo "You can access the Java service using:"
echo "kubectl -n demo port-forward svc/java-service 8081:8081"
echo "Then visit http://localhost:8081/api/info in your browser" 