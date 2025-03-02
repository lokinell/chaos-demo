#!/bin/bash
set -e

echo "Cleaning up all chaos experiments..."

# Delete all chaos experiments in the demo namespace
kubectl -n demo delete podchaos,networkchaos,stresschaos --all

echo "All chaos experiments have been cleaned up!" 