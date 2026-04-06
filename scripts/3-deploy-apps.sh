#!/bin/bash

# Applications Deployment Script
# This script deploys all three applications using Helm

set -e

echo "🚀 Deploying Applications to AKS..."

# Load configuration
if [ ! -f cluster-config.env ]; then
    echo "❌ Error: cluster-config.env not found. Run 1-setup-aks.sh first."
    exit 1
fi

source cluster-config.env

echo ""
echo "Deploying to cluster: $CLUSTER_NAME"
echo "Using images from ACR: $ACR_NAME"

ACR_LOGIN_SERVER="${ACR_NAME}.azurecr.io"

# Deploy Calculator
echo ""
echo "📊 Deploying Calculator Service"
helm upgrade --install calculator ../helm-charts/calculator-chart \
  --set image.repository=${ACR_LOGIN_SERVER}/calculator \
  --wait --timeout 10m

# Deploy Weather
echo ""
echo "🌤️  Deploying Weather Service"
helm upgrade --install weather ../helm-charts/weather-chart \
  --set image.repository=${ACR_LOGIN_SERVER}/weather \
  --wait --timeout 10m

# Deploy Traffic
echo ""
echo "🚗 Deploying Traffic Service"
helm upgrade --install traffic ../helm-charts/traffic-chart \
  --set image.repository=${ACR_LOGIN_SERVER}/traffic \
  --wait --timeout 10m

echo ""
echo "✅ All Pods are Ready!"

# Get service and ingress information
echo ""
echo "📋 Getting Service and Ingress Information..."
echo ""
kubectl get pods
kubectl get services
kubectl get ingress

echo ""
echo "⏳ Waiting for Ingress external IP to be assigned (this may take 2-3 minutes)..."
echo "Run 'kubectl get ingress' to check, then run './4-test-apps.sh'."
