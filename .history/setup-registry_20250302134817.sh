#!/bin/bash
set -e

echo "Setting up local Docker Registry..."

# Check if registry container is already running
if docker ps | grep -q "registry:2"; then
  echo "Registry is already running."
else
  # Start a new registry container
  echo "Starting registry container..."
  docker run -d -p 5000:5000 --restart=always --name registry registry:2
  echo "Registry started at localhost:5000"
fi

# Verify the registry is working
echo "Verifying registry..."
curl -s http://localhost:5000/v2/ || echo "Registry verification failed. Please check if it's running correctly."

echo "Local Docker Registry setup complete!"
echo "You can now build and push images to localhost:5000" 