# AKS Three Pods Deployment

Complete repository for deploying Calculator, Weather, and Live Traffic applications on Azure Kubernetes Service (AKS) using Docker, Kubernetes, and Helm Charts.

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Repository Structure](#repository-structure)
- [Applications](#applications)
- [Detailed Setup Guide](#detailed-setup-guide)
- [Testing](#testing)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)

## 🎯 Overview

This repository contains everything you need to deploy a production-ready AKS cluster with three microservices:

- **Calculator Pod**: RESTful API for mathematical operations
- **Weather Pod**: Mock weather information service
- **Live Traffic Pod**: Real-time traffic monitoring simulation

**Key Features:**
- 2-node AKS cluster
- Azure Container Registry integration
- Helm charts for easy deployment
- Health checks and resource limits
- LoadBalancer services for external access
- Automated deployment scripts

## ✅ Prerequisites

Before you begin, ensure you have:

1. **Azure CLI** - [Install Guide](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
   ```bash
   az --version
   ```

2. **kubectl** - [Install Guide](https://kubernetes.io/docs/tasks/tools/)
   ```bash
   kubectl version --client
   ```

3. **Helm 3** - [Install Guide](https://helm.sh/docs/intro/install/)
   ```bash
   helm version
   ```

4. **Docker** - [Install Guide](https://docs.docker.com/get-docker/)
   ```bash
   docker --version
   ```

5. **Azure Subscription** with appropriate permissions
   ```bash
   az login
   az account show
   ```

6. **jq** (for testing scripts) - [Install Guide](https://stedolan.github.io/jq/download/)
   ```bash
   jq --version
   ```

## 🚀 Quick Start

### Step 1: Clone the Repository

```bash
git clone <your-repo-url>
cd aks-three-pods-repo
```

### Step 2: Setup AKS Cluster

```bash
cd scripts
./1-setup-aks.sh
```

This script will:
- Create an Azure Resource Group
- Create a 2-node AKS cluster
- Create an Azure Container Registry (ACR)
- Connect ACR to AKS
- Save configuration to `cluster-config.env`

⏱️ **Expected Time**: 5-10 minutes

### Step 3: Build and Push Docker Images

```bash
./2-build-images.sh
```

This script will:
- Build Docker images for all three applications
- Push images to your Azure Container Registry

⏱️ **Expected Time**: 3-5 minutes

### Step 4: Deploy Applications

```bash
./3-deploy-apps.sh
```

This script will:
- Update Helm charts with your ACR name
- Deploy all three applications using Helm
- Wait for pods to be ready

⏱️ **Expected Time**: 2-3 minutes

### Step 5: Test Applications

Wait for external IPs to be assigned (check with `kubectl get services`), then:

```bash
./4-test-apps.sh
```

This will test all API endpoints and display results.

## 📁 Repository Structure

```
aks-three-pods-repo/
├── README.md                          # This file
├── calculator/                        # Calculator application
│   ├── Dockerfile
│   ├── app.py
│   └── requirements.txt
├── weather/                           # Weather application
│   ├── Dockerfile
│   ├── app.py
│   └── requirements.txt
├── traffic/                           # Traffic application
│   ├── Dockerfile
│   ├── app.py
│   └── requirements.txt
├── helm-charts/                       # Helm charts
│   ├── calculator-chart/
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   │       ├── _helpers.tpl
│   │       ├── deployment.yaml
│   │       └── service.yaml
│   ├── weather-chart/
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   │       ├── _helpers.tpl
│   │       ├── deployment.yaml
│   │       └── service.yaml
│   └── traffic-chart/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── _helpers.tpl
│           ├── deployment.yaml
│           └── service.yaml
└── scripts/                           # Automation scripts
    ├── 1-setup-aks.sh                # Setup AKS cluster
    ├── 2-build-images.sh             # Build and push images
    ├── 3-deploy-apps.sh              # Deploy applications
    ├── 4-test-apps.sh                # Test applications
    ├── 5-cleanup.sh                  # Cleanup resources
    └── cluster-config.env            # Generated configuration
```

## 🔧 Applications

### Calculator Service

**Endpoints:**
- `GET /health` - Health check
- `POST /add` - Addition
- `POST /subtract` - Subtraction
- `POST /multiply` - Multiplication
- `POST /divide` - Division

**Example:**
```bash
curl -X POST http://<CALCULATOR_IP>/add \
  -H "Content-Type: application/json" \
  -d '{"a": 10, "b": 5}'
```

### Weather Service

**Endpoints:**
- `GET /health` - Health check
- `GET /weather` - List all cities
- `GET /weather/<city>` - Get weather for specific city

**Available Cities:** newyork, london, tokyo, sydney

**Example:**
```bash
curl http://<WEATHER_IP>/weather/london
```

### Traffic Service

**Endpoints:**
- `GET /health` - Health check
- `GET /traffic` - Get all traffic routes
- `GET /traffic/<route>` - Get specific route traffic

**Available Routes:** I-95, Route-66, Highway-101, I-405

**Example:**
```bash
curl http://<TRAFFIC_IP>/traffic/I-95
```

## 📖 Detailed Setup Guide

### Manual Setup (Alternative to Scripts)

If you prefer to run commands manually instead of using scripts:

#### 1. Create AKS Cluster

```bash
RESOURCE_GROUP="myAKSResourceGroup"
CLUSTER_NAME="myAKSCluster"
LOCATION="eastus"

az group create --name $RESOURCE_GROUP --location $LOCATION

az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --node-count 2 \
  --node-vm-size Standard_DS2_v2 \
  --enable-managed-identity \
  --generate-ssh-keys \
  --network-plugin azure

az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME
```

#### 2. Create and Attach ACR

```bash
ACR_NAME="myaksregistry$(date +%s)"

az acr create \
  --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME \
  --sku Basic

az aks update \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --attach-acr $ACR_NAME
```

#### 3. Build and Push Images

```bash
az acr login --name $ACR_NAME

# Calculator
cd calculator
docker build -t ${ACR_NAME}.azurecr.io/calculator:v1 .
docker push ${ACR_NAME}.azurecr.io/calculator:v1

# Weather
cd ../weather
docker build -t ${ACR_NAME}.azurecr.io/weather:v1 .
docker push ${ACR_NAME}.azurecr.io/weather:v1

# Traffic
cd ../traffic
docker build -t ${ACR_NAME}.azurecr.io/traffic:v1 .
docker push ${ACR_NAME}.azurecr.io/traffic:v1
```

#### 4. Update Helm Values

Edit the `values.yaml` files in each Helm chart directory and replace `YOUR_ACR_NAME` with your actual ACR name.

#### 5. Deploy with Helm

```bash
cd ../helm-charts

helm install calculator ./calculator-chart
helm install weather ./weather-chart
helm install traffic ./traffic-chart
```

## 🧪 Testing

### Automated Testing

Use the provided test script:

```bash
cd scripts
./4-test-apps.sh
```

### Manual Testing

Get service IPs:

```bash
kubectl get services
```

Test each service:

```bash
# Calculator
curl http://<CALCULATOR_IP>/health
curl -X POST http://<CALCULATOR_IP>/add \
  -H "Content-Type: application/json" \
  -d '{"a": 10, "b": 5}'

# Weather
curl http://<WEATHER_IP>/health
curl http://<WEATHER_IP>/weather/tokyo

# Traffic
curl http://<TRAFFIC_IP>/health
curl http://<TRAFFIC_IP>/traffic/I-95
```

## 📊 Monitoring

### View Pods

```bash
kubectl get pods
kubectl describe pod <pod-name>
```

### View Logs

```bash
# All calculator pods
kubectl logs -l app.kubernetes.io/name=calculator-chart --tail=50

# Specific pod
kubectl logs <pod-name> -f
```

### View Services

```bash
kubectl get services
kubectl describe service calculator-chart
```

### View Helm Releases

```bash
helm list
helm status calculator
```

### View Events

```bash
kubectl get events --sort-by=.metadata.creationTimestamp
```

## 🔧 Troubleshooting

### Pods Not Starting

```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

Common issues:
- Image pull errors → Check ACR attachment
- CrashLoopBackOff → Check application logs
- Pending state → Check node resources

### No External IP

```bash
kubectl get service <service-name> -o yaml
```

Wait 2-3 minutes for Azure to provision LoadBalancer.

### Image Pull Errors

Verify ACR connection:

```bash
az aks check-acr \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --acr ${ACR_NAME}.azurecr.io
```

### Connection Refused

```bash
# Check if pods are running
kubectl get pods

# Check service endpoints
kubectl get endpoints
```

## 🔄 Scaling

### Scale Deployment

```bash
# Using kubectl
kubectl scale deployment calculator-chart --replicas=3

# Using Helm
helm upgrade calculator ./helm-charts/calculator-chart --set replicaCount=3
```

## 🔄 Updates

### Update Application

```bash
# Build new version
docker build -t ${ACR_NAME}.azurecr.io/calculator:v2 ./calculator
docker push ${ACR_NAME}.azurecr.io/calculator:v2

# Update deployment
helm upgrade calculator ./helm-charts/calculator-chart --set image.tag=v2
```

## 🧹 Cleanup

### Automated Cleanup

```bash
cd scripts
./5-cleanup.sh
```

This will delete:
- All Helm releases
- AKS cluster
- Azure Container Registry
- Resource Group

### Manual Cleanup

```bash
# Delete Helm releases
helm uninstall calculator
helm uninstall weather
helm uninstall traffic

# Delete AKS cluster
az aks delete \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --yes

# Delete resource group
az group delete \
  --name $RESOURCE_GROUP \
  --yes
```

## 💰 Cost Management

**Estimated Monthly Costs** (as of 2025):
- AKS nodes (2x Standard_DS2_v2): ~$140/month
- LoadBalancers (3x): ~$54/month
- ACR (Basic): ~$5/month
- **Total**: ~$200/month

**Cost Saving Tips:**
- Stop cluster when not in use: `az aks stop`
- Use fewer replicas in development
- Use ClusterIP instead of LoadBalancer for internal services
- Delete resources after testing

## 🔐 Security Best Practices

1. **Use Azure Key Vault** for secrets
2. **Enable RBAC** on AKS cluster
3. **Configure Network Policies** for pod-to-pod communication
4. **Use Private Endpoints** for ACR in production
5. **Enable Azure Monitor** for logging and metrics
6. **Scan images** for vulnerabilities

## 📚 Additional Resources

- [AKS Documentation](https://docs.microsoft.com/en-us/azure/aks/)
- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Docker Documentation](https://docs.docker.com/)

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

## 📝 License

This project is open source and available under the MIT License.

---

**Made with ❤️ for AKS learning and development**
