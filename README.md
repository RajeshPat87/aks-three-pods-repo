# AKS Three Pods Deployment with Terraform & Azure DevOps

Complete **production-ready** repository for deploying Calculator, Weather, and Live Traffic applications on Azure Kubernetes Service (AKS) using **Terraform** for infrastructure and **Azure DevOps pipelines** for CI/CD.

## 🎯 What Gets Deployed

**Infrastructure** (via Terraform deployed to **Azure Cloud**):
- ☁️ Azure Kubernetes Service (AKS) cluster - **IN AZURE**
- 🐳 Azure Container Registry (ACR) - **IN AZURE**
- 🌐 Virtual Network with subnets & NSGs - **IN AZURE**
- 📊 Log Analytics workspace - **IN AZURE**
- 🔐 All IAM roles and permissions - **IN AZURE**

**Applications** (deployed to AKS in Azure):
- 🧮 Calculator Pod (2 replicas)
- 🌤️ Weather Pod (2 replicas)
- 🚗 Traffic Pod (2 replicas)

## 🚀 Two Deployment Options

### Option 1: Azure DevOps Pipeline (CI/CD in Cloud) ⭐
- **Where it runs**: Azure DevOps (Microsoft-hosted agents)
- **Where it deploys**: Your Azure subscription
- **Workflow**: Git push → Pipeline runs → Deploys to Azure
- **Best for**: Production, team collaboration

### Option 2: Local Terraform (Your Machine)
- **Where it runs**: Your local computer
- **Where it deploys**: Your Azure subscription  
- **Workflow**: Run terraform commands → Deploys to Azure
- **Best for**: Development, testing, learning

> ⚠️ **Important**: In BOTH cases, all infrastructure is created in **Azure Cloud**, not on your local machine!

## 📁 Repository Structure

```
aks-three-pods-repo/
├── terraform/                     # ← Infrastructure as Code (creates Azure resources)
│   ├── main.tf
│   ├── variables.tf
│   ├── networking.tf             # VNet, Subnets, NSGs
│   ├── aks.tf                    # AKS cluster config
│   ├── acr.tf                    # Container registry
│   └── dev.tfvars
├── pipelines/                     # ← Azure DevOps CI/CD
│   ├── infra-deploy-pipeline.yml # Infrastructure deployment
│   ├── app-deploy-pipeline.yml   # Application deployment
│   └── full-deployment-pipeline.yml # Complete deployment
├── calculator/                    # Calculator app
├── weather/                       # Weather app
├── traffic/                       # Traffic app
├── helm-charts/                   # Kubernetes deployment configs
└── scripts/                       # Helper scripts
```

## 🔄 How It Works

```
┌─────────────────────────────────────────┐
│  YOUR CODE (This Repo)                  │
│  ├── Terraform files                    │
│  ├── Python apps                        │
│  └── Helm charts                        │
└────────────┬────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────┐
│  DEPLOYMENT METHOD                      │
│  ┌────────────┐      ┌───────────────┐ │
│  │ Azure      │  OR  │ Your Local    │ │
│  │ DevOps     │      │ Machine       │ │
│  │ Pipeline   │      │ (Terraform)   │ │
│  └────────────┘      └───────────────┘ │
└────────────┬────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────┐
│  AZURE CLOUD (Everything deploys HERE)  │
│  ┌────────────────────────────────────┐ │
│  │ Resource Group                     │ │
│  │  ├── Virtual Network              │ │
│  │  ├── AKS Cluster (2 nodes)        │ │
│  │  ├── Container Registry           │ │
│  │  ├── Load Balancers (3x)          │ │
│  │  └── Log Analytics                │ │
│  └────────────────────────────────────┘ │
│  ┌────────────────────────────────────┐ │
│  │ Running Pods in AKS                │ │
│  │  ├── Calculator (2 replicas)      │ │
│  │  ├── Weather (2 replicas)         │ │
│  │  └── Traffic (2 replicas)         │ │
│  └────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

## ✅ Prerequisites

### For Azure DevOps Deployment
✅ Azure Subscription with billing enabled  
✅ Azure DevOps Organization (free tier works)  
✅ Service Principal or Service Connection  

### For Local Deployment
✅ Azure Subscription with billing enabled  
✅ [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)  
✅ [Terraform](https://www.terraform.io/downloads) >= 1.5.0  
✅ [kubectl](https://kubernetes.io/docs/tasks/tools/)  
✅ [Helm](https://helm.sh/docs/intro/install/)  
✅ [Docker](https://docs.docker.com/get-docker/)  

## 🚀 Quick Start - Azure DevOps (Cloud)

### Step 1: Setup Azure DevOps Project

1. Go to [dev.azure.com](https://dev.azure.com)
2. Create a new project
3. Import this repository

### Step 2: Create Service Connection

1. Go to **Project Settings** → **Service Connections**
2. Click **New Service Connection** → **Azure Resource Manager**
3. Choose **Service Principal (automatic)**
4. Select your subscription
5. Name it: `azure-service-connection`
6. Click **Save**

### Step 3: Update Pipeline Variables

Edit `pipelines/full-deployment-pipeline.yml`:

```yaml
variables:
  azureServiceConnection: 'azure-service-connection'  # Your connection name
  backendStorageAccountName: 'sttfstateaks123'  # Make unique!
```

### Step 4: Create Pipeline

1. Go to **Pipelines** → **New Pipeline**
2. Select your repository
3. Choose **Existing Azure Pipelines YAML file**
4. Select `/pipelines/full-deployment-pipeline.yml`
5. Click **Save and Run**

### Step 5: Watch Deployment

The pipeline will:
1. ✅ Create Terraform backend storage in Azure
2. ✅ Deploy infrastructure (VNet, AKS, ACR) to Azure
3. ✅ Build Docker images
4. ✅ Push images to ACR in Azure
5. ✅ Deploy applications to AKS in Azure
6. ✅ Output service URLs

**Time**: ~15-20 minutes

## 🚀 Quick Start - Local Terraform

### Step 1: Clone & Login

```bash
git clone <your-repo>
cd aks-three-pods-repo
az login
```

### Step 2: Setup Terraform Backend

```bash
# Create storage for Terraform state
STORAGE_NAME="sttfstate$(openssl rand -hex 4)"

az group create --name rg-terraform-state --location eastus

az storage account create \
  --name $STORAGE_NAME \
  --resource-group rg-terraform-state \
  --location eastus \
  --sku Standard_LRS
```

### Step 3: Update Backend Config

Edit `terraform/main.tf`:

```hcl
backend "azurerm" {
  resource_group_name  = "rg-terraform-state"
  storage_account_name = "<your-storage-name>"  # From step 2
  container_name       = "tfstate"
  key                  = "aks-infrastructure.tfstate"
}
```

### Step 4: Deploy Infrastructure to Azure

```bash
cd terraform
terraform init
terraform apply -var-file="dev.tfvars"
```

This creates **everything in Azure**:
- Resource group
- Virtual network
- AKS cluster  
- Container registry
- Networking security

### Step 5: Deploy Applications

```bash
# Get AKS credentials
RESOURCE_GROUP=$(terraform output -raw resource_group_name)
AKS_CLUSTER=$(terraform output -raw aks_cluster_name)
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER

# Build and push images
cd ..
./scripts/2-build-images.sh

# Deploy with Helm
./scripts/3-deploy-apps.sh

# Test
./scripts/4-test-apps.sh
```

## 🏗️ What Gets Created in Azure

| Azure Resource | Example Name | Purpose |
|----------------|--------------|---------|
| Resource Group | `rg-aks-dev-eus` | Container for all resources |
| Virtual Network | `vnet-dev-eus` | Network isolation (10.0.0.0/16) |
| AKS Cluster | `aks-dev-eus` | Kubernetes cluster (2 nodes) |
| Container Registry | `acrdevxyz123` | Docker image storage |
| Load Balancers | `kubernetes` | External access (3x for each app) |
| NSG - AKS | `nsg-aks-dev-eus` | Security rules for AKS |
| NSG - AppGW | `nsg-appgw-dev-eus` | Security rules for gateway |
| Log Analytics | `log-dev-eus` | Monitoring workspace |
| Public IPs | Auto-generated | For load balancers |

**Total Resources**: ~12-15 Azure resources created

## 💰 Cost in Azure

**Monthly costs** (running 24/7):
- 💻 AKS nodes (2x Standard_DS2_v2): ~$140
- ⚖️ Load Balancers (3x): ~$54
- 🐳 ACR Standard: ~$20
- 📊 Log Analytics: ~$10
- 🌐 Networking: ~$10
- **💵 Total**: ~$234/month

**Cost Saving**:
```bash
# Stop AKS when not in use (saves ~60%)
az aks stop --resource-group <rg-name> --name <aks-name>

# Start when needed
az aks start --resource-group <rg-name> --name <aks-name>
```

## 🧪 Testing Your Deployment

```bash
# Get service IPs
kubectl get services

# Test Calculator (Azure load balancer IP)
curl -X POST http://<EXTERNAL-IP>/add \
  -H "Content-Type: application/json" \
  -d '{"a": 10, "b": 5}'

# Test Weather
curl http://<EXTERNAL-IP>/weather/london

# Test Traffic
curl http://<EXTERNAL-IP>/traffic/I-95
```

## 📊 Monitoring in Azure

### Azure Portal
1. Go to Azure Portal → Your AKS cluster
2. **Monitoring** → **Insights**
3. View: Cluster health, Node metrics, Container logs

### Command Line
```bash
kubectl get all
kubectl top nodes
kubectl logs <pod-name>
```

## 🧹 Cleanup (Delete Everything from Azure)

### Using Terraform
```bash
cd terraform
terraform destroy -var-file="dev.tfvars"
```

### Using Azure CLI
```bash
# Delete main resource group
az group delete --name rg-aks-dev-eus --yes

# Delete Terraform state storage
az group delete --name rg-terraform-state --yes
```

This removes **all Azure resources** and stops billing.

## 📚 Documentation

- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Complete deployment guide
- **[QUICKSTART.md](QUICKSTART.md)** - Fast setup guide
- **[Terraform Files](terraform/)** - Infrastructure code

## ❓ FAQ

**Q: Where does this deploy?**  
A: Everything deploys to **Azure Cloud** using your Azure subscription.

**Q: Will this cost money?**  
A: Yes, Azure resources incur costs (~$234/month if running 24/7). Use `az aks stop` to save costs.

**Q: Can I use my free Azure credits?**  
A: Yes! Perfect for learning. Just remember to delete resources when done.

**Q: Do I need a local Kubernetes cluster?**  
A: No! Everything runs in Azure. You just need tools installed to connect.

**Q: Which deployment method should I use?**  
A: Use **Azure DevOps** for production/team use, **Local Terraform** for learning/development.

## 🆘 Troubleshooting

**Pipeline fails**: Check service connection has correct permissions  
**No external IP**: Wait 2-3 minutes for Azure to assign IPs  
**Image pull error**: Verify ACR connection: `az aks check-acr`  
**Terraform errors**: Check backend storage exists  

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed troubleshooting.

---

**🎉 You now have a production-ready AKS deployment in Azure!**

For questions or issues, see [DEPLOYMENT.md](DEPLOYMENT.md) for detailed guides.
