#!/bin/bash

# Cleanup Script
# This script removes all deployed resources

set -e

echo "🧹 Starting Cleanup Process..."
echo ""

# Load configuration
if [ ! -f cluster-config.env ]; then
    echo "❌ Error: cluster-config.env not found."
    echo "Nothing to clean up or configuration is missing."
    exit 1
fi

source cluster-config.env

echo "This will delete:"
echo "  - All Helm releases (calculator, weather, traffic)"
echo "  - AKS Cluster: $CLUSTER_NAME"
echo "  - Azure Container Registry: $ACR_NAME"
echo "  - Resource Group: $RESOURCE_GROUP"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

# Delete Helm releases
echo ""
echo "🗑️  Deleting Helm Releases..."
helm uninstall calculator 2>/dev/null || echo "Calculator release not found"
helm uninstall weather 2>/dev/null || echo "Weather release not found"
helm uninstall traffic 2>/dev/null || echo "Traffic release not found"

echo ""
echo "⏳ Waiting for resources to be deleted..."
sleep 20

# Delete AKS Cluster
echo ""
echo "☸️  Deleting AKS Cluster: $CLUSTER_NAME"
az aks delete \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --yes --no-wait

# Delete entire resource group (includes ACR)
echo ""
echo "📦 Deleting Resource Group: $RESOURCE_GROUP"
echo "This includes the Container Registry and all associated resources."
az group delete \
  --name $RESOURCE_GROUP \
  --yes --no-wait

echo ""
echo "✅ Cleanup initiated!"
echo ""
echo "Resources are being deleted in the background."
echo "This may take 10-15 minutes to complete."
echo ""
echo "You can check the status with:"
echo "  az group show --name $RESOURCE_GROUP"
echo ""
echo "Configuration file (cluster-config.env) remains for reference."
