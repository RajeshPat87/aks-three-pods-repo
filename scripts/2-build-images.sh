#!/bin/bash

# Docker Images Build and Push Script
# This script builds and pushes all three application images to ACR

set -e

echo "🐳 Building and Pushing Docker Images..."

# Load configuration
if [ ! -f cluster-config.env ]; then
    echo "❌ Error: cluster-config.env not found. Run 1-setup-aks.sh first."
    exit 1
fi

source cluster-config.env

echo ""
echo "Using ACR: $ACR_NAME"

# Login to ACR
echo ""
echo "🔐 Logging into Azure Container Registry"
az acr login --name $ACR_NAME

# Build and Push Calculator
echo ""
echo "🔨 Building Calculator Image"
cd ../calculator
docker build -t ${ACR_NAME}.azurecr.io/calculator:v1 .

echo "📤 Pushing Calculator Image"
docker push ${ACR_NAME}.azurecr.io/calculator:v1

# Build and Push Weather
echo ""
echo "🔨 Building Weather Image"
cd ../weather
docker build -t ${ACR_NAME}.azurecr.io/weather:v1 .

echo "📤 Pushing Weather Image"
docker push ${ACR_NAME}.azurecr.io/weather:v1

# Build and Push Traffic
echo ""
echo "🔨 Building Traffic Image"
cd ../traffic
docker build -t ${ACR_NAME}.azurecr.io/traffic:v1 .

echo "📤 Pushing Traffic Image"
docker push ${ACR_NAME}.azurecr.io/traffic:v1

cd ../scripts

echo ""
echo "✨ All Images Built and Pushed Successfully!"
echo ""
echo "Images in ACR:"
echo "  - ${ACR_NAME}.azurecr.io/calculator:v1"
echo "  - ${ACR_NAME}.azurecr.io/weather:v1"
echo "  - ${ACR_NAME}.azurecr.io/traffic:v1"
echo ""
echo "Next step: Run ./3-deploy-apps.sh"
