#!/bin/bash

# AKS Cluster Setup Script
# This script creates an Azure Kubernetes Service cluster with 2 nodes

set -e

echo "🚀 Starting AKS Cluster Setup..."

# Configuration Variables
RESOURCE_GROUP="myAKSResourceGroup"
CLUSTER_NAME="myAKSCluster"
LOCATION="eastus"
NODE_COUNT=2
NODE_VM_SIZE="Standard_DS2_v2"
ACR_NAME="myaksregistry$(date +%s)"

# Step 1: Create Resource Group
echo ""
echo "📦 Creating Resource Group: $RESOURCE_GROUP"
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION

# Step 2: Create AKS Cluster
echo ""
echo "☸️  Creating AKS Cluster: $CLUSTER_NAME (this may take 5-10 minutes)"
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --node-count $NODE_COUNT \
  --node-vm-size $NODE_VM_SIZE \
  --enable-managed-identity \
  --generate-ssh-keys \
  --network-plugin azure

# Step 3: Get Credentials
echo ""
echo "🔑 Getting AKS Credentials"
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --overwrite-existing

# Step 4: Verify Cluster
echo ""
echo "✅ Verifying Cluster Nodes"
kubectl get nodes

# Step 5: Create Azure Container Registry
echo ""
echo "🐳 Creating Azure Container Registry: $ACR_NAME"
az acr create \
  --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME \
  --sku Basic

# Step 6: Attach ACR to AKS
echo ""
echo "🔗 Attaching ACR to AKS Cluster"
az aks update \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --attach-acr $ACR_NAME

# Save configuration to file
echo ""
echo "💾 Saving configuration..."
cat > cluster-config.env << EOF
RESOURCE_GROUP=$RESOURCE_GROUP
CLUSTER_NAME=$CLUSTER_NAME
LOCATION=$LOCATION
ACR_NAME=$ACR_NAME
EOF

echo ""
echo "✨ AKS Cluster Setup Complete!"
echo ""
echo "Cluster Information:"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Cluster Name: $CLUSTER_NAME"
echo "  Location: $LOCATION"
echo "  ACR Name: $ACR_NAME"
echo ""
echo "Configuration saved to: cluster-config.env"
echo ""
echo "Next steps:"
echo "  1. Run: ./2-build-images.sh"
echo "  2. Update Helm chart values with ACR name: $ACR_NAME"
echo "  3. Run: ./3-deploy-apps.sh"
