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

# Update Helm values files with ACR name
echo ""
echo "📝 Updating Helm values files with ACR name"
sed -i "s/YOUR_ACR_NAME/${ACR_NAME}/g" ../helm-charts/calculator-chart/values.yaml
sed -i "s/YOUR_ACR_NAME/${ACR_NAME}/g" ../helm-charts/weather-chart/values.yaml
sed -i "s/YOUR_ACR_NAME/${ACR_NAME}/g" ../helm-charts/traffic-chart/values.yaml

# Deploy Calculator
echo ""
echo "📊 Deploying Calculator Service"
helm install calculator ../helm-charts/calculator-chart

# Deploy Weather
echo ""
echo "🌤️  Deploying Weather Service"
helm install weather ../helm-charts/weather-chart

# Deploy Traffic
echo ""
echo "🚗 Deploying Traffic Service"
helm install traffic ../helm-charts/traffic-chart

# Wait for deployments
echo ""
echo "⏳ Waiting for pods to be ready..."
sleep 10

kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=calculator-chart --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=weather-chart --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=traffic-chart --timeout=300s

echo ""
echo "✅ All Pods are Ready!"

# Get service information
echo ""
echo "📋 Getting Service Information..."
echo ""
kubectl get services

echo ""
echo "⏳ Waiting for external IPs to be assigned (this may take 2-3 minutes)..."
echo "Run './4-test-apps.sh' after external IPs are assigned."
