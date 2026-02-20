# ⚡ Quick Start Guide

Get your AKS cluster with Calculator, Weather, and Traffic pods running in **under 15 minutes**!

## 📦 What You'll Get

- 2-node Azure Kubernetes Service cluster
- 3 microservices deployed with Helm
- Load-balanced external access
- Health checks and monitoring

## 🚀 5-Step Setup

### 1️⃣ Download & Extract

```bash
# If you have the tar.gz file
tar -xzf aks-three-pods-repo.tar.gz
cd aks-three-pods-repo

# OR clone from git
git clone <your-repo-url>
cd aks-three-pods-repo
```

### 2️⃣ Login to Azure

```bash
az login
az account set --subscription "<your-subscription-name>"
```

### 3️⃣ Run Setup Script

```bash
cd scripts
./1-setup-aks.sh
```

⏱️ **Wait 5-10 minutes** for cluster creation.

### 4️⃣ Build & Deploy

```bash
./2-build-images.sh    # Builds Docker images (3-5 min)
./3-deploy-apps.sh     # Deploys to AKS (2-3 min)
```

### 5️⃣ Test

```bash
# Wait for external IPs (check with: kubectl get services)
./4-test-apps.sh       # Tests all endpoints
```

## 🎯 Verify Everything Works

```bash
kubectl get pods
# Should show 6 pods (2 replicas × 3 apps) all Running

kubectl get services
# Should show 3 LoadBalancers with EXTERNAL-IP addresses
```

## 🧪 Try the APIs

After getting the external IPs from `kubectl get services`:

```bash
# Calculator
curl -X POST http://<CALCULATOR_IP>/add \
  -H "Content-Type: application/json" \
  -d '{"a": 10, "b": 5}'

# Weather
curl http://<WEATHER_IP>/weather/london

# Traffic
curl http://<TRAFFIC_IP>/traffic/I-95
```

## 📊 Monitor

```bash
# View pods
kubectl get pods

# View logs
kubectl logs -l app.kubernetes.io/name=calculator-chart

# View all resources
kubectl get all
```

## 🧹 Cleanup (When Done)

```bash
./5-cleanup.sh
```

This deletes everything and stops Azure charges.

## ⚠️ Troubleshooting

**Pods not starting?**
```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

**No external IP?**
Wait 2-3 minutes, then check again:
```bash
kubectl get services -w
```

**Script permission denied?**
```bash
chmod +x scripts/*.sh
```

## 💰 Estimated Costs

~$200/month if left running 24/7. Stop or delete cluster when not in use to save costs!

## 📚 Next Steps

- Read the full [README.md](README.md) for detailed documentation
- Modify applications in `calculator/`, `weather/`, `traffic/` folders
- Customize Helm charts in `helm-charts/` folder
- Scale deployments: `kubectl scale deployment calculator-chart --replicas=3`

---

**Need help?** Check the [README.md](README.md) for full documentation and troubleshooting.
