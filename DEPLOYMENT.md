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
- Docker

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
# - Docker: https://docs.docker.com/engine/install/
```

### Step 2: Azure Login

> **Important**: If your subscription is in a specific tenant, login with the tenant ID to avoid `SubscriptionNotFound` errors.

```bash
# Login with tenant ID (recommended)
az login --tenant <your-tenant-id>

# Set the correct subscription
az account set --subscription "<your-subscription-id>"

# Verify
az account show
```

To find your tenant ID:
```bash
az account list --all --output table
```

### Step 3: Create Terraform Backend Storage

```bash
# Create resource group for Terraform state
az group create \
  --name rg-terraform-state \
  --location eastus

# Create storage account (must be globally unique)
STORAGE_NAME="sttfstate$(openssl rand -hex 4)"
echo "Storage Account: $STORAGE_NAME"

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

# If backend config changed, use:
# terraform init -migrate-state   (to migrate existing state)
# terraform init -reconfigure     (clean start, no existing state)

# Review the plan
terraform plan -var-file="dev.tfvars"

# Apply (create infrastructure)
terraform apply -var-file="dev.tfvars" -auto-approve

# Save outputs
terraform output > ../outputs.txt
```

> **Note**: If `terraform apply` fails with `RoleAssignmentExists`, import the existing role assignment:
> ```bash
> terraform import azurerm_role_assignment.aks_acr \
>   <acr-resource-id>/providers/Microsoft.Authorization/roleAssignments/<role-assignment-id>
> ```

### Step 6: Get AKS Credentials

```bash
# Get resource group and cluster name from outputs
RESOURCE_GROUP=$(terraform output -raw resource_group_name)
AKS_CLUSTER=$(terraform output -raw aks_cluster_name)
ACR_NAME=$(terraform output -raw acr_name)

# Grant yourself RBAC access to the cluster
USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)

az role assignment create \
  --assignee $USER_OBJECT_ID \
  --role "Azure Kubernetes Service Cluster Admin Role" \
  --scope $(terraform output -raw aks_cluster_id)

az role assignment create \
  --assignee $USER_OBJECT_ID \
  --role "Azure Kubernetes Service RBAC Cluster Admin" \
  --scope $(terraform output -raw aks_cluster_id)

# Configure kubectl with admin credentials
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_CLUSTER \
  --overwrite-existing \
  --admin

# Verify connection
kubectl get nodes
```

### Step 7: Build and Push Docker Images

```bash
cd ..

# Start Docker daemon (WSL)
sudo service docker start
sudo chmod 666 /var/run/docker.sock

# Login to ACR
az acr login --name $ACR_NAME

# Attach ACR to AKS so nodes can pull images
az aks update \
  --name $AKS_CLUSTER \
  --resource-group $RESOURCE_GROUP \
  --attach-acr $ACR_NAME

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

### Step 8: Install NGINX Ingress Controller

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --wait
```

### Step 9: Deploy Applications with Helm

> **Important**: Always pass `--set image.tag=v1` to match the tag used when pushing images.

```bash
# Deploy calculator
helm upgrade --install calculator ./helm-charts/calculator-chart \
  --set image.repository=${ACR_LOGIN_SERVER}/calculator \
  --set image.tag=v1 \
  --wait --timeout 10m

# Deploy weather
helm upgrade --install weather ./helm-charts/weather-chart \
  --set image.repository=${ACR_LOGIN_SERVER}/weather \
  --set image.tag=v1 \
  --wait --timeout 10m

# Deploy traffic
helm upgrade --install traffic ./helm-charts/traffic-chart \
  --set image.repository=${ACR_LOGIN_SERVER}/traffic \
  --set image.tag=v1 \
  --wait --timeout 10m
```

### Step 10: Apply Ingress

```bash
kubectl apply -f ingress.yaml
```

> **Note**: `ingress.yaml` uses three separate ingress objects (one per service) because each service requires a different URL rewrite rule:
> - `calculator-ingress`: strips `/calculator` prefix → app routes at `/add`, `/subtract`, etc.
> - `weather-ingress`: preserves `/weather/<city>` path → app routes at `/weather/<city>`
> - `traffic-ingress`: preserves `/traffic/<route>` path → app routes at `/traffic/<route>`

### Step 11: Allow External Traffic (NSG Rules)

AKS node pool NSG blocks external traffic by default. Add inbound rules:

```bash
# Get the node pool NSG name
NODE_NSG=$(az network nsg list \
  --resource-group MC_${RESOURCE_GROUP}_${AKS_CLUSTER}_eastus \
  --query '[0].name' -o tsv)

# Allow HTTP
az network nsg rule create \
  --resource-group MC_${RESOURCE_GROUP}_${AKS_CLUSTER}_eastus \
  --nsg-name $NODE_NSG \
  --name allow-http \
  --priority 200 \
  --protocol Tcp \
  --destination-port-ranges 80 \
  --access Allow \
  --direction Inbound
```

Also update the Azure Load Balancer health probe to TCP (the default HTTP probe fails on nginx 404):

```bash
LB_PROBE=$(az network lb probe list \
  --resource-group MC_${RESOURCE_GROUP}_${AKS_CLUSTER}_eastus \
  --lb-name kubernetes \
  --query "[?contains(name,'TCP-80')].name" -o tsv)

az network lb probe update \
  --resource-group MC_${RESOURCE_GROUP}_${AKS_CLUSTER}_eastus \
  --lb-name kubernetes \
  --name $LB_PROBE \
  --protocol Tcp \
  --path ""
```

### Step 12: Verify Deployment

```bash
# Check pods
kubectl get pods

# Check services (all ClusterIP)
kubectl get services

# Get ingress external IP (wait 2-3 minutes for assignment)
kubectl get ingress -w
```

### Step 13: Test Applications

```bash
# Get Ingress IP
INGRESS_IP=$(kubectl get ingress calculator-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo $INGRESS_IP

# Test calculator
curl -X POST http://$INGRESS_IP/calculator/add \
  -H "Content-Type: application/json" \
  -d '{"a": 10, "b": 5}'
# Expected: {"operation":"add","result":15}

# Test weather
curl http://$INGRESS_IP/weather/london
# Expected: {"city":"london","weather":{...}}

# Test traffic - list all routes
curl http://$INGRESS_IP/traffic
# Expected: {"routes":{...}}

# Test traffic - specific route
curl http://$INGRESS_IP/traffic/I-95
# Expected: {"congestion":"...","current_speed":...}
```

### Available API Endpoints

| Service | Method | Path | Description |
|---------|--------|------|-------------|
| Calculator | POST | `/calculator/add` | Add two numbers |
| Calculator | POST | `/calculator/subtract` | Subtract two numbers |
| Calculator | POST | `/calculator/multiply` | Multiply two numbers |
| Calculator | POST | `/calculator/divide` | Divide two numbers |
| Weather | GET | `/weather/london` | Get London weather |
| Weather | GET | `/weather/tokyo` | Get Tokyo weather |
| Weather | GET | `/weather/newyork` | Get New York weather |
| Weather | GET | `/weather/sydney` | Get Sydney weather |
| Traffic | GET | `/traffic` | List all routes |
| Traffic | GET | `/traffic/I-95` | Get I-95 traffic |
| Traffic | GET | `/traffic/Route-66` | Get Route-66 traffic |
| Traffic | GET | `/traffic/Highway-101` | Get Highway-101 traffic |
| Traffic | GET | `/traffic/I-405` | Get I-405 traffic |

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

### SubscriptionNotFound Error

**Problem**: `az` commands fail with `SubscriptionNotFound`  
**Solution**: Login with the correct tenant:
```bash
az account list --all --output table
az login --tenant <tenant-id>
az account set --subscription "<subscription-id>"
```

### Pipeline Fails at Terraform Init

**Problem**: Backend storage doesn't exist  
**Solution**: Run the backend creation step manually or check storage account name is unique

### Terraform Backend Config Changed

**Problem**: `A change in the backend configuration has been detected`  
**Solution**:
```bash
terraform init -migrate-state   # migrate existing state
# OR
terraform init -reconfigure     # clean start
```

### Pods in ImagePullBackOff

**Problem**: Can't pull images from ACR  
**Solution**: Attach ACR to AKS:
```bash
az aks update \
  --name <aks-name> \
  --resource-group <rg-name> \
  --attach-acr <acr-name>

# Then delete failing pods to force re-pull
kubectl delete pod -l app.kubernetes.io/instance=<service-name>
```

Also verify the image tag matches what was pushed:
```bash
# Must match the tag used in docker push
helm upgrade ... --set image.tag=v1
```

### Docker Not Running (WSL)

**Problem**: `docker: Cannot connect to the Docker daemon`  
**Solution**:
```bash
sudo service docker start
sudo chmod 666 /var/run/docker.sock
```

### No External IP for Ingress

**Problem**: Ingress IP not assigned  
**Solution**: Install NGINX ingress controller first:
```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace --wait
```

### ERR_CONNECTION_TIMED_OUT

**Problem**: External IP times out in browser  
**Solution**: Add NSG rule and fix LB health probe (see Step 11)

### kubectl Forbidden / Portal Shows 403

**Problem**: `User cannot list resource "nodes"`  
**Solution**: Assign both RBAC roles:
```bash
az role assignment create \
  --assignee <user-object-id> \
  --role "Azure Kubernetes Service Cluster Admin Role" \
  --scope <aks-cluster-id>

az role assignment create \
  --assignee <user-object-id> \
  --role "Azure Kubernetes Service RBAC Cluster Admin" \
  --scope <aks-cluster-id>

az aks get-credentials ... --admin
```

### Terraform State Lock

**Problem**: State is locked  
**Solution**:
```bash
terraform force-unlock <lock-id>
```

---

## 📊 Monitoring

### View Logs

```bash
# Pod logs by label
kubectl logs -l app.kubernetes.io/instance=calculator --tail=50
kubectl logs -l app.kubernetes.io/instance=weather --tail=50
kubectl logs -l app.kubernetes.io/instance=traffic --tail=50

# Live pod events
kubectl get events --sort-by='.lastTimestamp'
```

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
