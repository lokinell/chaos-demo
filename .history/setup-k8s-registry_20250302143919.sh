#!/bin/bash
set -e

echo "Deploying Docker Registry in Kubernetes..."
kubectl apply -f k8s/registry.yaml

echo "Waiting for registry to be ready..."
kubectl -n registry wait --for=condition=available --timeout=120s deployment/registry

echo "Registry is now running in Kubernetes!"
echo "Internal access: registry.registry.svc.cluster.local:5000"
echo "External access: localhost:30500 (via NodePort)"

# Test the registry
echo "Testing registry connection..."
kubectl -n registry run registry-test --rm -i --tty --restart=Never --image=busybox -- wget -q -O- http://registry:5000/v2/ || {
  echo "Failed to connect to registry. Please check the registry deployment."
  exit 1
}

echo "Registry is accessible from within the cluster!"
echo ""
echo "To push images to the registry:"
echo "1. Tag your image: docker tag your-image localhost:30500/your-image:tag"
echo "2. Push to registry: docker push localhost:30500/your-image:tag"
echo ""
echo "In Kubernetes manifests, use: registry.registry.svc.cluster.local:5000/your-image:tag" 