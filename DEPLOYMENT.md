# Azure DevOps Deployment Guide

This guide explains how to deploy the AKS infrastructure and applications using Azure DevOps pipelines with Terraform.

## 📋 Prerequisites

### Azure Requirements
- Azure Subscription with Owner or Contributor access
- Azure DevOps Organization and Project
- Service Principal with appropriate permissions

### Tools (for local development)
- Terraform >= 1.5.0
- Azure CLI >= 2.50.0
- kubectl >= 1.28.0
- Helm >= 3.13.0

## 🚀 Deployment Options

You have **TWO** deployment options:

### Option 1: Azure DevOps Pipelines (Recommended for Production)
Fully automated CI/CD deployment using Azure DevOps.

### Option 2: Local Terraform Deployment
Manual deployment from your local machine for development/testing.

---

## 📦 Option 1: Azure DevOps Pipeline Deployment

### Step 1: Setup Azure DevOps

#### 1.1 Create Service Connection

1. Go to **Azure DevOps** → Your Project → **Project Settings** → **Service Connections**
2. Click **New Service Connection** → **Azure Resource Manager**
3. Select **Service Principal (automatic)**
4. Configure:
   - **Scope level**: Subscription
   - **Subscription**: Select your Azure subscription
   - **Service connection name**: `azure-service-connection`
5. Grant access permission to all pipelines
6. Click **Save**

#### 1.2 Create ACR Service Connection

1. First, get your ACR details after infrastructure deployment OR create manually:
   ```bash
   az acr create --name <unique-acr-name> --resource-group <rg-name> --sku Standard
   ```

2. In Azure DevOps:
   - **Project Settings** → **Service Connections** → **New service connection**
   - Select **Docker Registry**
   - Select **Azure Container Registry**
   - Choose your subscription and ACR
   - Service connection name: `acr-service-connection`

### Step 2: Update Pipeline Variables

Edit the pipeline files and update these variables:

**In `pipelines/infra-deploy-pipeline.yml`:**
```yaml
variables:
  - name: azureServiceConnection
    value: 'azure-service-connection'  # Your service connection name
  - name: backendStorageAccountName
    value: 'sttfstateaks<unique>'  # Make this globally unique
```

**In `pipelines/app-deploy-pipeline.yml`:**
```yaml
variables:
  - name: azureServiceConnection
    value: 'azure-service-connection'
  - name: dockerRegistryServiceConnection
    value: 'acr-service-connection'
```

### Step 3: Create Pipelines

#### 3.1 Create Infrastructure Pipeline

1. Go to **Pipelines** → **New Pipeline**
2. Select **Azure Repos Git** (or your repo location)
3. Select your repository
4. Choose **Existing Azure Pipelines YAML file**
5. Select `/pipelines/infra-deploy-pipeline.yml`
6. Click **Save** (don't run yet)

#### 3.2 Create Application Pipeline

Repeat the same process for `/pipelines/app-deploy-pipeline.yml`

#### 3.3 OR Create Full Deployment Pipeline

Use `/pipelines/full-deployment-pipeline.yml` for end-to-end deployment

### Step 4: Create Environments

1. Go to **Pipelines** → **Environments**
2. Create two environments:
   - `AKS-Infrastructure` (for infrastructure approval)
   - `AKS-Applications` (for application approval)
3. Add **Approvals and checks** if needed

### Step 5: Run the Pipelines

#### Option A: Full Deployment (Recommended)
```
Run: full-deployment-pipeline.yml
```
This deploys everything in sequence:
1. Infrastructure (Terraform)
2. Build Docker images
3. Deploy applications (Helm)

#### Option B: Separate Pipelines
```
1. Run: infra-deploy-pipeline.yml
2. Wait for completion
3. Run: app-deploy-pipeline.yml
```

### Step 6: Monitor Deployment

1. Watch the pipeline execution in Azure DevOps
2. Approve deployment at approval gates
3. Check outputs for:
   - Resource Group name
   - AKS cluster name
   - ACR login server
   - Service URLs

---

## 💻 Option 2: Local Terraform Deployment

### Step 1: Setup Local Environment

```bash
# Clone repository
git clone <your-repo-url>
cd aks-three-pods-repo

# Install prerequisites
# - Terraform: https://www.terraform.io/downloads
# - Azure CLI: https://docs.microsoft.com/cli/azure/install-azure-cli
# - kubectl: https://kubernetes.io/docs/tasks/tools/
# - Helm: https://helm.sh/docs/intro/install/
```

### Step 2: Azure Login

```bash
az login
az account set --subscription "<your-subscription-id>"
```

### Step 3: Create Terraform Backend Storage

```bash
# Create resource group for Terraform state
az group create \
  --name rg-terraform-state \
  --location eastus

# Create storage account (must be globally unique)
STORAGE_NAME="sttfstate$(openssl rand -hex 4)"

az storage account create \
  --name $STORAGE_NAME \
  --resource-group rg-terraform-state \
  --location eastus \
  --sku Standard_LRS

# Get storage account key
ACCOUNT_KEY=$(az storage account keys list \
  --resource-group rg-terraform-state \
  --account-name $STORAGE_NAME \
  --query '[0].value' -o tsv)

# Create container
az storage container create \
  --name tfstate \
  --account-name $STORAGE_NAME \
  --account-key $ACCOUNT_KEY

echo "Storage Account: $STORAGE_NAME"
```

### Step 4: Configure Terraform Backend

Edit `terraform/main.tf` and update the backend configuration:

```hcl
backend "azurerm" {
  resource_group_name  = "rg-terraform-state"
  storage_account_name = "<your-storage-account-name>"
  container_name       = "tfstate"
  key                  = "aks-infrastructure.tfstate"
}
```

### Step 5: Deploy Infrastructure

```bash
cd terraform

# Initialize Terraform
terraform init

# Review the plan
terraform plan -var-file="dev.tfvars"

# Apply (create infrastructure)
terraform apply -var-file="dev.tfvars" -auto-approve

# Save outputs
terraform output > ../outputs.txt
```

### Step 6: Get AKS Credentials

```bash
# Get resource group and cluster name from outputs
RESOURCE_GROUP=$(terraform output -raw resource_group_name)
AKS_CLUSTER=$(terraform output -raw aks_cluster_name)
ACR_NAME=$(terraform output -raw acr_name)

# Configure kubectl
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER \
  --overwrite-existing

# Verify connection
kubectl get nodes
```

### Step 7: Build and Push Docker Images

```bash
cd ..

# Login to ACR
az acr login --name $ACR_NAME

# Get ACR login server
ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --query loginServer -o tsv)

# Build and push calculator
docker build -t ${ACR_LOGIN_SERVER}/calculator:v1 ./calculator
docker push ${ACR_LOGIN_SERVER}/calculator:v1

# Build and push weather
docker build -t ${ACR_LOGIN_SERVER}/weather:v1 ./weather
docker push ${ACR_LOGIN_SERVER}/weather:v1

# Build and push traffic
docker build -t ${ACR_LOGIN_SERVER}/traffic:v1 ./traffic
docker push ${ACR_LOGIN_SERVER}/traffic:v1
```

### Step 8: Update Helm Charts

```bash
# Update all Helm charts with ACR server
find helm-charts -name "values.yaml" -exec sed -i "s|YOUR_ACR_NAME.azurecr.io|${ACR_LOGIN_SERVER}|g" {} \;
```

### Step 9: Deploy Applications with Helm

```bash
# Deploy calculator
helm upgrade --install calculator ./helm-charts/calculator-chart --wait

# Deploy weather
helm upgrade --install weather ./helm-charts/weather-chart --wait

# Deploy traffic
helm upgrade --install traffic ./helm-charts/traffic-chart --wait
```

### Step 10: Verify Deployment

```bash
# Check pods
kubectl get pods

# Check services
kubectl get services

# Get external IPs (wait 2-3 minutes for assignment)
kubectl get services -w
```

### Step 11: Test Applications

```bash
# Get service IPs
CALC_IP=$(kubectl get service calculator-chart -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
WEATHER_IP=$(kubectl get service weather-chart -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
TRAFFIC_IP=$(kubectl get service traffic-chart -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test calculator
curl -X POST http://$CALC_IP/add \
  -H "Content-Type: application/json" \
  -d '{"a": 10, "b": 5}'

# Test weather
curl http://$WEATHER_IP/weather/london

# Test traffic
curl http://$TRAFFIC_IP/traffic/I-95
```

---

## 📂 Infrastructure Details

### Resources Created

| Resource Type | Name Pattern | Purpose |
|--------------|--------------|---------|
| Resource Group | `rg-aks-{env}-{location}` | Container for all resources |
| Virtual Network | `vnet-{env}-{location}` | Network isolation |
| AKS Subnet | `snet-aks-{env}-{location}` | AKS nodes subnet |
| AppGW Subnet | `snet-appgw-{env}-{location}` | Application Gateway subnet |
| Services Subnet | `snet-services-{env}-{location}` | Additional services |
| NSG (AKS) | `nsg-aks-{env}-{location}` | AKS security rules |
| NSG (AppGW) | `nsg-appgw-{env}-{location}` | App Gateway security rules |
| AKS Cluster | `aks-{env}-{location}` | Kubernetes cluster |
| Container Registry | `acr{env}{random}` | Docker image registry |
| Log Analytics | `log-{env}-{location}` | Monitoring workspace |

### Network Configuration

- **VNet CIDR**: 10.0.0.0/16
- **AKS Subnet**: 10.0.1.0/24
- **App Gateway Subnet**: 10.0.2.0/24
- **Services Subnet**: 10.0.3.0/24
- **Kubernetes Service CIDR**: 10.1.0.0/16
- **DNS Service IP**: 10.1.0.10

### Security Features

✅ Network Security Groups with minimal rules  
✅ Azure AD integration for AKS  
✅ RBAC enabled  
✅ Service endpoints for ACR, Storage, Key Vault  
✅ Managed identities (no passwords)  
✅ Azure Policy integration  
✅ Private endpoints support (optional)

---

## 🔧 Customization

### Change Environment

Edit `terraform/dev.tfvars` or create `prod.tfvars`:

```hcl
environment = "prod"
aks_node_count = 3
aks_node_vm_size = "Standard_DS3_v2"
enable_auto_scaling = true
min_node_count = 2
max_node_count = 10
```

### Enable Auto-scaling

```hcl
enable_auto_scaling = true
min_node_count = 2
max_node_count = 5
```

### Change Region

```hcl
location = "westeurope"
location_short = "weu"
```

---

## 🧹 Cleanup

### Using Terraform

```bash
cd terraform
terraform destroy -var-file="dev.tfvars" -auto-approve
```

### Delete Terraform State Storage

```bash
az group delete --name rg-terraform-state --yes --no-wait
```

### Using Azure Portal

1. Go to Resource Groups
2. Delete `rg-aks-{env}-{location}`
3. Delete `rg-terraform-state`

---

## 🔍 Troubleshooting

### Pipeline Fails at Terraform Init

**Problem**: Backend storage doesn't exist  
**Solution**: Run the backend creation step manually or check storage account name is unique

### Pods in ImagePullBackOff

**Problem**: Can't pull images from ACR  
**Solution**: Verify ACR service connection and AKS-ACR role assignment:
```bash
az aks check-acr --resource-group <rg-name> --name <aks-name> --acr <acr-name>
```

### No External IP for Services

**Problem**: LoadBalancer not provisioned  
**Solution**: Wait 2-3 minutes, check AKS has network permissions:
```bash
kubectl describe service calculator-chart
```

### Terraform State Lock

**Problem**: State is locked  
**Solution**: 
```bash
terraform force-unlock <lock-id>
```

---

## 📊 Monitoring

### View Logs in Azure Portal

1. Go to AKS cluster → **Monitoring** → **Logs**
2. Use queries:
```kusto
ContainerLog
| where LogEntry contains "error"
| order by TimeGenerated desc
```

### View Metrics

```bash
kubectl top nodes
kubectl top pods
```

### Access Container Insights

1. AKS cluster → **Monitoring** → **Insights**
2. View:
   - Cluster health
   - Node performance
   - Container logs
   - Metrics

---

## 💰 Cost Estimation

**Monthly costs (approximate)**:
- AKS nodes (2x Standard_DS2_v2): ~$140
- Load Balancers (3x): ~$54
- ACR Standard: ~$20
- Log Analytics: ~$10
- VNet/NSG: ~$5
- **Total**: ~$230/month

**Cost saving tips**:
- Stop AKS when not in use: `az aks stop`
- Use spot instances for dev
- Reduce node count
- Use Basic ACR for dev

---

## 📚 Additional Resources

- [Terraform Azure Provider Docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [AKS Documentation](https://docs.microsoft.com/azure/aks/)
- [Azure DevOps Pipelines](https://docs.microsoft.com/azure/devops/pipelines/)
- [Helm Documentation](https://helm.sh/docs/)

---

## 🤝 Support

For issues:
1. Check pipeline logs in Azure DevOps
2. Review Terraform state: `terraform show`
3. Check AKS events: `kubectl get events`
4. View pod logs: `kubectl logs <pod-name>`
