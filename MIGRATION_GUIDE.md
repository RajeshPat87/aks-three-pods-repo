# Migration Guide: Azure DevOps to GitHub Actions

Complete guide for migrating your AKS Three Pods repository from Azure DevOps to GitHub with automated pipeline conversion.

> **This guide is customized for:**
> - ADO Organization: `RajeshPatibandla` | Project: `AKS`
> - GitHub Account: `RajeshPat87` | Repo: `aks-three-pods-repo`
> - Authentication: **Managed Identity + OIDC** (no client secrets)

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Migration Tools](#migration-tools)
- [Prerequisites](#prerequisites)
- [Migration Steps](#migration-steps)
- [Post-Deployment Configuration](#post-deployment-configuration)
- [Comparison](#comparison)
- [Troubleshooting — All Issues Encountered](#troubleshooting--all-issues-encountered)
- [Microservice Validation](#microservice-validation)
- [Test Results](#test-results)
- [Best Practices](#best-practices)

---

## Overview

This guide covers migrating:
- Source code from Azure DevOps Git to GitHub
- Azure Pipelines YAML to GitHub Actions workflows
- Service connections to GitHub secrets (OIDC)
- Environments and approvals

### What Changes

| Azure DevOps | GitHub |
|--------------|--------|
| Azure Repos | GitHub Repository |
| Azure Pipelines | GitHub Actions |
| Service Connections (Managed Identity) | Federated Credentials + OIDC |
| Environments | GitHub Environments |
| Variable Groups | Repository/Environment Secrets |
| Build Agents | GitHub-hosted runners |

### What Stays the Same

- Azure infrastructure — Still deploys to Azure
- Terraform code — No changes needed
- Applications — Same Docker images
- Helm charts — Same Kubernetes configs

---

## Architecture

### Full Traffic Flow

```
Internet
    |
    v
Azure Load Balancer (Public IP: 48.217.218.240)
    |  port 80/443
    v
Subnet NSG: nsg-aks-dev-eus  [rg-aks-dev-eus]
    |  AllowHTTPInbound (priority 105)
    v
AKS Node Subnet: snet-aks-dev-eus (vnet-dev-eus)
    |
    v
NIC NSG: aks-agentpool-39859110-nsg  [MC_ resource group]
    |
    v
VMSS Node (iptables -> NodePort 32160)
    |
    v
NGINX Ingress Controller Pod (10.0.1.77)
    |
    |-- /calculator/* --> calculator-calculator-chart:80 --> Pod:8080
    |-- /weather/*    --> weather-weather-chart:80       --> Pod:8080
    +-- /traffic/*    --> traffic-traffic-chart:80       --> Pod:8080
```

### Resource Inventory

| Resource | Name | Resource Group |
|---|---|---|
| AKS Cluster | aks-dev-eus | rg-aks-dev-eus |
| ACR | acrdevw52one | rg-aks-dev-eus |
| VNet | vnet-dev-eus | rg-aks-dev-eus |
| AKS Subnet | snet-aks-dev-eus | rg-aks-dev-eus |
| Subnet NSG | nsg-aks-dev-eus | rg-aks-dev-eus |
| Azure LB | kubernetes | MC_rg-aks-dev-eus_aks-dev-eus_eastus |
| VMSS | aks-agentpool-23371792-vmss | MC_rg-aks-dev-eus_aks-dev-eus_eastus |
| NIC NSG | aks-agentpool-39859110-nsg | MC_rg-aks-dev-eus_aks-dev-eus_eastus |

### GitHub Actions Pipeline Stages

```
Push to main
    |
    v
Stage 1: deploy-infrastructure
    Terraform init + apply (AKS, ACR, VNet, NSG)
    |
    v
Stage 2: build-images  [matrix: calculator, weather, traffic]
    Docker build + push to ACR
    |
    v
Stage 3: deploy-apps
    Helm upgrade --install (all 3 charts)
    NGINX ingress controller install
```

---

## Migration Tools

### 1. GitHub CLI + Actions Importer

Official Microsoft/GitHub tool for converting Azure DevOps pipelines.

### 2. Git — Code Migration

Used to pull from ADO and push to GitHub.

---

## Prerequisites

### Required Tools

```bash
# Install GitHub CLI (Ubuntu/WSL)
(type -p wget >/dev/null || (sudo apt update && sudo apt install wget -y)) \
&& sudo mkdir -p -m 755 /etc/apt/keyrings \
&& wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
&& sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
&& sudo apt update \
&& sudo apt install gh -y

# Install GitHub Actions Importer extension
gh extension install github/gh-actions-importer

# Update to latest importer image
gh actions-importer update
```

### Required Access

- **Azure DevOps PAT** with scopes:
  - `Build (Read)`, `Agent Pools (Read)`, `Code (Read)`, `Release (Read)`
  - `Service Connections (Read)`, `Task Groups (Read)`, `Variable Groups (Read)`

- **GitHub PAT** with scopes: `repo`, `workflow`

- **Azure**: Managed Identity `Deploy` with Federated Credentials configured

---

## Migration Steps

### Step 1: Authenticate GitHub CLI

```bash
gh auth login
# Select: GitHub.com -> HTTPS -> Login with a web browser
```

Verify:
```bash
gh auth status
# Should show: Logged in as RajeshPat87
# Token scopes: gist, read:org, repo, workflow
```

---

### Step 2: Install & Configure Actions Importer

```bash
# Install
gh extension install github/gh-actions-importer
gh actions-importer update

# Configure
gh actions-importer configure
```

When prompted:
| Prompt | Value |
|--------|-------|
| CI Provider | `Azure DevOps` |
| GitHub PAT | Your GitHub token |
| GitHub Base URL | `https://github.com` |
| ADO PAT | Your Azure DevOps token |
| ADO Base URL | `https://dev.azure.com` |
| ADO Organization | `RajeshPatibandla` |
| ADO Project | `AKS` |

---

### Step 3: Audit Existing Pipelines

```bash
gh actions-importer audit azure-devops \
  --organization RajeshPatibandla \
  --project AKS \
  --output-dir ./audit-results
```

Review results:
```bash
cat audit-results/audit_summary.md
```

Output files:
- `audit-results/audit_summary.md` — Overview
- `audit-results/workflow_usage.csv` — Usage stats
- `audit-results/pipelines/AKS/infra_app_all/` — Converted workflow preview

---

### Step 4: Setup Azure OIDC (Managed Identity Federated Credential)

> **Note:** This project uses **Managed Identity + OIDC** instead of Service Principal secrets.

#### 4.1 Add Federated Credential on Azure

1. Go to Azure Portal -> **Managed Identities** -> search `Deploy`
2. Left menu -> **Settings** -> **Federated credentials**
3. Click **+ Add Credential**

| Field | Value |
|-------|-------|
| Scenario | `Configure a GitHub issued token to impersonate this application` |
| Organization | `RajeshPat87` |
| Repository | `aks-three-pods-repo` |
| Entity | `Branch` |
| Branch | `main` |
| Name | `github-actions-main` |

4. Click **Add**

> **Critical:** Also add a second federated credential for the GitHub environment:

| Field | Value |
|-------|-------|
| Entity | `Environment` |
| Environment name | `development` |
| Name | `gh-env-development` |

This is required because `deploy-apps` job uses `environment: development`, which changes the OIDC subject claim from `ref:refs/heads/main` to `environment:development`.

```bash
# Add environment federated credential via CLI
az identity federated-credential create \
  --name gh-env-development \
  --identity-name <managed-identity-name> \
  --resource-group <rg> \
  --issuer https://token.actions.githubusercontent.com \
  --subject repo:RajeshPat87/aks-three-pods-repo:environment:development \
  --audiences api://AzureADTokenExchange
```

#### 4.2 Collect Azure Identity Values

| Value | ID |
|-------|----|
| Client ID | `f3714cae-5dad-446d-bab4-67691c40c66e` |
| Tenant ID | `d57df211-4f37-47c0-81ed-dd6296f7638c` |
| Subscription ID | `fde7e51a-4a45-4843-b161-b4193587c43d` |

#### 4.3 Assign Kubernetes RBAC Role to Managed Identity

```bash
az role assignment create \
  --assignee f3714cae-5dad-446d-bab4-67691c40c66e \
  --role "Azure Kubernetes Service RBAC Cluster Admin" \
  --scope /subscriptions/fde7e51a-4a45-4843-b161-b4193587c43d/resourceGroups/rg-aks-dev-eus/providers/Microsoft.ContainerService/managedClusters/aks-dev-eus
```

---

### Step 5: Create GitHub Repository

```bash
gh repo create RajeshPat87/aks-three-pods-repo \
  --private \
  --description "AKS deployment with Terraform and GitHub Actions"
```

---

### Step 6: Migrate Code from ADO to GitHub

```bash
# Initialize git in project folder
cd ~/aks-three-pods-repo
git init
git branch -m main

# Add ADO as origin
git remote add origin https://RajeshPatibandla@dev.azure.com/RajeshPatibandla/AKS/_git/aks-three-pods-repo

# Pull code from ADO (use ADO PAT when prompted for password)
git add .
git commit -m "Initial local files"
git pull origin main --allow-unrelated-histories --no-rebase
# If conflicts: accept ADO version
git checkout --theirs .
git add .
git commit -m "Merge: accept ADO version as source of truth"

# Remove large files & secrets from history
git filter-branch --force --index-filter \
  "git rm -rf --cached --ignore-unmatch terraform/.terraform/" \
  --prune-empty --tag-name-filter cat -- --all

git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch .env.local" \
  --prune-empty --tag-name-filter cat -- --all

# Add to .gitignore
echo "terraform/.terraform/" >> .gitignore
echo ".env.local" >> .gitignore
git add .gitignore
git commit -m "Remove large files and secrets, update gitignore"

# Add GitHub as remote and push
git remote add github https://github.com/RajeshPat87/aks-three-pods-repo.git
git reflog expire --expire=now --all
git gc --prune=now --aggressive
git push github --all --force
git push github --tags
```

---

### Step 7: Setup GitHub Secrets

> **OIDC approach — No `AZURE_CLIENT_SECRET` needed!**

```bash
# Azure Identity (OIDC)
gh secret set AZURE_CLIENT_ID --body "f3714cae-5dad-446d-bab4-67691c40c66e" -R RajeshPat87/aks-three-pods-repo
gh secret set AZURE_TENANT_ID --body "d57df211-4f37-47c0-81ed-dd6296f7638c" -R RajeshPat87/aks-three-pods-repo
gh secret set AZURE_SUBSCRIPTION_ID --body "fde7e51a-4a45-4843-b161-b4193587c43d" -R RajeshPat87/aks-three-pods-repo

# Terraform Backend
gh secret set TF_BACKEND_STORAGE_ACCOUNT --body "sttfstate16243d65" -R RajeshPat87/aks-three-pods-repo

# ACR Details
gh secret set ACR_NAME --body "acrdevw52one" -R RajeshPat87/aks-three-pods-repo
gh secret set ACR_LOGIN_SERVER --body "acrdevw52one.azurecr.io" -R RajeshPat87/aks-three-pods-repo
```

Verify:
```bash
gh secret list -R RajeshPat87/aks-three-pods-repo
```

#### Required Secrets Summary

| Secret | Value | Purpose |
|--------|-------|---------|
| `AZURE_CLIENT_ID` | `f3714cae-...` | Managed Identity Client ID |
| `AZURE_TENANT_ID` | `d57df211-...` | Azure AD Tenant |
| `AZURE_SUBSCRIPTION_ID` | `fde7e51a-...` | Azure Subscription |
| `TF_BACKEND_STORAGE_ACCOUNT` | `sttfstate16243d65` | Terraform state storage |
| `ACR_NAME` | `acrdevw52one` | Container registry name |
| `ACR_LOGIN_SERVER` | `acrdevw52one.azurecr.io` | Container registry URL |

---

### Step 8: Setup GitHub Environments

```bash
# Get your GitHub user ID
gh api users/RajeshPat87 --jq '.id'
# Returns: 63461203

# Create development environment
gh api repos/RajeshPat87/aks-three-pods-repo/environments/development \
  --method PUT \
  --field wait_timer=0 \
  --field "reviewers[][type]=User" \
  --field "reviewers[][id]=63461203"
```

> Use `development` (not `production`) — must match the federated credential subject.

---

### Step 9: Test Workflows

```bash
# Trigger Full Deployment workflow
gh workflow run full-deploy.yml -R RajeshPat87/aks-three-pods-repo

# Monitor run
gh run watch -R RajeshPat87/aks-three-pods-repo

# View logs
gh run list -R RajeshPat87/aks-three-pods-repo
gh run view RUN_ID -R RajeshPat87/aks-three-pods-repo
```

Or via GitHub UI:
`github.com/RajeshPat87/aks-three-pods-repo` -> **Actions** -> **Full Deployment** -> **Run workflow**

---

### Step 10: Validate Deployment

```bash
# Get AKS credentials
az aks get-credentials \
  --resource-group rg-aks-dev-eus \
  --name aks-dev-eus

kubelogin convert-kubeconfig -l azurecli

# Verify pods and services
kubectl get pods
kubectl get services
kubectl get ingress
```

---

## Post-Deployment Configuration

These steps are required after the first successful pipeline run.

### 1. Add NSG Rule for Port 80 (Subnet-Level)

The Terraform-created subnet NSG (`nsg-aks-dev-eus`) only allows port 443 by default. Add port 80 for HTTP ingress traffic:

```bash
az network nsg rule create \
  --resource-group rg-aks-dev-eus \
  --nsg-name nsg-aks-dev-eus \
  --name AllowHTTPInbound \
  --priority 105 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --source-address-prefixes Internet \
  --source-port-ranges '*' \
  --destination-address-prefixes '*' \
  --destination-port-ranges 80
```

> **Why two NSGs?** AKS creates its own NIC-level NSG in the MC_ resource group. The subnet NSG in the user's VNet resource group is evaluated FIRST. Both must allow port 80.

### 2. Fix Azure LB Health Probe

The Azure Load Balancer health probe defaults to HTTP GET `/` on the NGINX NodePort. NGINX returns 404 for `/` (no matching ingress rule), which causes the LB to mark all backends as unhealthy and drop all traffic.

Fix by creating a TCP probe (checks port is open, not HTTP status):

```bash
MC_RG="MC_rg-aks-dev-eus_aks-dev-eus_eastus"

# Create TCP probe
az network lb probe create \
  --resource-group $MC_RG \
  --lb-name kubernetes \
  --name "ingress-tcp-probe-80" \
  --protocol Tcp \
  --port 32160 \
  --interval 5 \
  --threshold 2

# Update LB rule to use TCP probe
az network lb rule update \
  --resource-group $MC_RG \
  --lb-name kubernetes \
  --name "a1b3e899841974d7fa487e8bec283f26-TCP-80" \
  --probe-name "ingress-tcp-probe-80"
```

Or annotate the ingress-nginx service to trigger CCM to update the probe:

```bash
kubectl annotate svc ingress-nginx-controller -n ingress-nginx \
  service.beta.kubernetes.io/azure-load-balancer-health-probe-protocol=tcp \
  --overwrite
```

### 3. Apply Ingress Rules

```bash
kubectl apply -f ingress.yaml
kubectl get ingress app-ingress
# Should show ADDRESS: 48.217.218.240
```

---

## GitHub Actions Workflows (Already Migrated)

Workflows are in `.github/workflows/`:

| Workflow File | Description | Trigger |
|---------------|-------------|---------|
| `full-deploy.yml` | Full Deployment (Infrastructure + Apps) | push to main, workflow_dispatch |
| `infra-deploy.yml` | Infrastructure only (Terraform) | workflow_dispatch |
| `app-deploy.yml` | Applications only (Docker + Helm) | workflow_dispatch |

### Key Workflow Patterns Used

```yaml
# OIDC authentication (no client secret)
- uses: azure/login@v1
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

# ACR login server fetched directly (not via cross-job output)
- name: Get ACR Login Server
  id: acr-server
  run: |
    ACR_SERVER=$(az acr show --name ${{ secrets.ACR_NAME }} --query loginServer -o tsv)
    echo "login_server=$ACR_SERVER" >> $GITHUB_OUTPUT

# kubelogin required for AAD-integrated AKS
- name: Install kubelogin
  run: |
    az aks install-cli
    kubelogin convert-kubeconfig -l azurecli

# Helm with atomic rollback and stuck release cleanup
- name: Clean Up Stuck Helm Releases
  run: |
    for release in calculator weather traffic; do
      STATUS=$(helm status $release --output json 2>/dev/null | jq -r '.info.status' 2>/dev/null || echo "not-found")
      if [[ "$STATUS" == "pending-install" || "$STATUS" == "pending-upgrade" || "$STATUS" == "pending-rollback" ]]; then
        helm uninstall $release --wait 2>/dev/null || true
      fi
    done

- name: Deploy with Helm
  run: |
    helm upgrade --install calculator ./helm-charts/calculator-chart --wait --timeout 10m --atomic --cleanup-on-fail
    helm upgrade --install weather ./helm-charts/weather-chart --wait --timeout 10m --atomic --cleanup-on-fail
    helm upgrade --install traffic ./helm-charts/traffic-chart --wait --timeout 10m --atomic --cleanup-on-fail
```

---

## Feature Comparison

| Feature | Azure DevOps | GitHub Actions |
|---------|--------------|----------------|
| YAML Syntax | Azure Pipelines | GitHub Actions |
| Authentication | Managed Identity (OIDC) | Federated Credential (OIDC) |
| Stages | `stages:` | `jobs:` |
| Variables | `variables:` | `env:` / secrets |
| Artifacts | Pipeline artifacts | GitHub artifacts |
| Environments | Environments + Gates | GitHub Environments + Reviewers |

### Task Mapping

| Azure DevOps Task | GitHub Action |
|-------------------|---------------|
| `TerraformInstaller@0` | `hashicorp/setup-terraform@v2` |
| `AzureCLI@2` | `azure/cli@v1` |
| `Docker@2` | `docker/build-push-action@v5` |
| `HelmDeploy@0` | `azure/setup-helm@v3` + script |
| `Kubernetes@1` | `azure/setup-kubectl@v3` + script |

---

## Troubleshooting — All Issues Encountered

### Issue 1 — Docker Build: Invalid Image Tag

**Error:**
```
ERROR: invalid tag "/calculator:8": repository name must be canonical
```

**Root Cause:**
The `build-images` job used `needs.deploy-infrastructure.outputs.acr_login_server` which was empty. Cross-job outputs only work when the producing job explicitly writes to `$GITHUB_OUTPUT`. The ACR output step failed silently, resulting in the tag `/calculator:8` instead of `acrdevw52one.azurecr.io/calculator:8`.

**Fix:**
Query ACR login server directly inside `build-images` job:
```yaml
- name: Get ACR Login Server
  id: acr-server
  run: |
    ACR_SERVER=$(az acr show --name ${{ secrets.ACR_NAME }} --query loginServer -o tsv)
    echo "login_server=$ACR_SERVER" >> $GITHUB_OUTPUT
```

**Interview Answer:**
> Cross-job output passing is unreliable when the upstream step fails silently. The safer pattern is to re-query the resource directly in the consuming job.

---

### Issue 2 — OIDC Login Fails: Subject Mismatch

**Error:**
```
AADSTS70021: No matching federated identity record found for presented assertion.
```

**Root Cause:**
GitHub OIDC tokens carry a `sub` (subject) claim that changes based on the trigger context. When `environment: production` was added to the job, the subject changed from `ref:refs/heads/main` to `environment:production`. No matching federated credential existed for that subject.

**Fix:**
Add a federated credential for the environment subject:
```bash
az identity federated-credential create \
  --subject repo:RajeshPat87/aks-three-pods-repo:environment:development
```
And change the workflow environment from `production` to `development` to match.

**Interview Answer:**
> Azure AD federated credentials do exact string matching on the OIDC `sub` claim. GitHub generates different subjects per context: branch, environment, PR. You must create one federated credential per subject pattern.

---

### Issue 3 — kubelogin Not Found

**Error:**
```
exec: "kubelogin": executable file not found in $PATH
```

**Root Cause:**
AKS clusters with Azure AD integration require `kubelogin` to exchange Azure CLI tokens for Kubernetes-compatible tokens. The `azure/aks-set-context@v3` action writes a kubeconfig referencing `kubelogin` but does NOT install it.

**Fix:**
```yaml
- name: Install kubelogin
  run: |
    az aks install-cli
    kubelogin convert-kubeconfig -l azurecli
```

**Interview Answer:**
> `azure/aks-set-context` writes the kubeconfig but doesn't install `kubelogin`. AAD-integrated AKS clusters require it for non-interactive auth in CI pipelines.

---

### Issue 4 — Kubernetes RBAC Forbidden

**Error:**
```
Error from server (Forbidden): pods is forbidden: User cannot list resource "pods"
```

**Root Cause:**
Azure AD authentication (who you are) and Kubernetes RBAC (what you can do) are separate layers. The Managed Identity was authenticated to Azure AD but had no Kubernetes RBAC role inside the cluster.

**Fix:**
```bash
az role assignment create \
  --assignee <managed-identity-client-id> \
  --role "Azure Kubernetes Service RBAC Cluster Admin" \
  --scope /subscriptions/.../managedClusters/aks-dev-eus
```

**Interview Answer:**
> AKS has two independent authorization layers: Azure RBAC (cluster management) and Kubernetes RBAC (API operations). Both must be configured separately.

---

### Issue 5 — Helm Release Stuck in Pending State

**Error:**
```
Error: INSTALLATION FAILED: another operation (install/upgrade/rollback) is in progress
```

**Root Cause:**
A previous pipeline run timed out mid-deployment, leaving the Helm release in `pending-install` state. Helm uses a lock stored in Kubernetes Secrets that was never released.

**Fix:**
```bash
for release in calculator weather traffic; do
  STATUS=$(helm status $release --output json 2>/dev/null | jq -r '.info.status' 2>/dev/null || echo "not-found")
  if [[ "$STATUS" == "pending-install" || "$STATUS" == "pending-upgrade" || "$STATUS" == "pending-rollback" ]]; then
    helm uninstall $release --wait 2>/dev/null || true
  fi
done
```

Also use `--atomic --cleanup-on-fail` to prevent future occurrences.

**Interview Answer:**
> Helm stores release state in Kubernetes Secrets. Interrupted pipelines leave the state as `pending-*`. `--atomic` auto-rolls back on failure; `--cleanup-on-fail` removes new resources on failed installs.

---

### Issue 6 — Azure Public IP Quota Exceeded

**Error:**
```
PublicIPCountLimitReached: Cannot create more than 3 public IP addresses
```

**Root Cause:**
All three app services were `type: LoadBalancer`, each requesting a dedicated Azure Public IP. Combined with the NGINX ingress controller's LB IP, this exceeded the subscription's quota.

**Fix:**
Change app services to `ClusterIP` in all `values.yaml` files:
```yaml
service:
  type: ClusterIP  # was LoadBalancer
  port: 80
  targetPort: 8080
```

Only the NGINX Ingress Controller needs a `LoadBalancer` service.

**Interview Answer:**
> In an ingress architecture, only the ingress controller needs a LoadBalancer. App services use ClusterIP and receive traffic from the ingress controller internally. Each LoadBalancer service provisions an Azure Public IP, which is quota-limited.

---

### Issue 7 — NGINX Webhook x509 Certificate Error

**Error:**
```
x509: certificate signed by unknown authority (validating webhook)
```

**Root Cause:**
The NGINX Ingress Controller uses a `ValidatingWebhookConfiguration` with a self-signed TLS certificate. After reinstallation, the certificate changed but the old webhook configuration still held the stale CA bundle.

**Fix:**
```bash
kubectl delete validatingwebhookconfiguration ingress-nginx-admission
```

The NGINX controller recreates it automatically with the correct certificate.

**Interview Answer:**
> Kubernetes admission webhooks use a `caBundle` in the webhook configuration. If the NGINX controller is reinstalled and the secret rotates, the old CA bundle becomes invalid. Deleting the stale `ValidatingWebhookConfiguration` forces recreation with the correct certificate.

---

### Issue 8 — Port 80 Connection Timeout (NSG Layering)

**Error:**
```
curl: (28) Failed to connect to 48.217.218.240 port 80: Connection timed out
nc: connect to 48.217.218.240 port 80 failed: Connection timed out
```

All pods running, all endpoints populated, LB has port 80 rule, NIC-level NSG has Allow-HTTP-80 rule.

**Root Cause — Step by Step Diagnosis:**

| Check | Result |
|---|---|
| `kubectl get pods` | All 6 pods Running 1/1 |
| `kubectl get endpoints` | All 3 services have 2 endpoints |
| `az network lb rule list` | Port 80 rule exists in Azure LB |
| `az network nsg show aks-agentpool-*-nsg --query subnets` | Empty — NIC-level NSG, not subnet |
| `az aks show --query agentPoolProfiles[0].vnetSubnetId` | `snet-aks-dev-eus` in `rg-aks-dev-eus` |
| `az network vnet subnet show --query networkSecurityGroup.id` | `nsg-aks-dev-eus` attached to subnet |
| `az network nsg rule list --nsg-name nsg-aks-dev-eus` | No port 80 rule — only 443 from Internet |

**NSG Evaluation Order (inbound):**
```
Internet Traffic (port 80)
        |
        v
Subnet NSG: nsg-aks-dev-eus
  Priority 100: Allow 443 from Internet
  Priority 110: Allow * from AzureLoadBalancer  <- health probes only (168.63.129.16)
  Priority 120: Allow * from VirtualNetwork
  Priority 4096: DENY ALL  <- port 80 blocked here
        |
        x  (never reaches NIC NSG)
        v
NIC NSG: aks-agentpool-39859110-nsg
  Priority 200: Allow 80 from *  <- never evaluated
```

**Fix:**
```bash
az network nsg rule create \
  --resource-group rg-aks-dev-eus \
  --nsg-name nsg-aks-dev-eus \
  --name AllowHTTPInbound \
  --priority 105 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --source-address-prefixes Internet \
  --source-port-ranges '*' \
  --destination-address-prefixes '*' \
  --destination-port-ranges 80
```

**Interview Answer:**
> Azure evaluates the subnet NSG before the NIC NSG for inbound traffic. We correctly added the allow rule to the NIC NSG but the subnet NSG — in a different resource group from the AKS MC_ group — was blocking port 80. The `AzureLoadBalancer` service tag only permits health probe traffic from `168.63.129.16`, not forwarded user traffic.

---

### Issue 9 — Port 80 Still Timing Out After NSG Fix (LB Health Probe Failing)

**Error:**
```
nc: connect to 48.217.218.240 port 80 failed: Connection timed out
```

NSG correctly configured, LB has port 80 rule, all pods running with active endpoints.

**Root Cause:**
The Azure Load Balancer health probe was:
- Protocol: **HTTP**
- Port: **32160** (NGINX NodePort)
- Path: **`/`**

NGINX ingress controller has no ingress rule matching `/`, so it returns **HTTP 404**. Azure LB considers only HTTP 200 as healthy. With 404, the LB marks all backends as **unhealthy** and **silently drops all traffic** — appearing as a TCP connection timeout.

**Diagnosis:**
```bash
# Confirmed NGINX works (bypasses LB)
kubectl port-forward -n ingress-nginx pod/ingress-nginx-controller-54485bdbc8-tt4pj 8888:80
curl http://localhost:8888/calculator/health
# -> {"service":"calculator","status":"healthy"}  (works via port-forward)

# Confirmed nodes ARE in backend pool
az vmss show \
  --resource-group MC_rg-aks-dev-eus_aks-dev-eus_eastus \
  --name aks-agentpool-23371792-vmss \
  --query "virtualMachineProfile.networkProfile.networkInterfaceConfigurations[0].ipConfigurations[0].loadBalancerBackendAddressPools"
# -> Both aksOutboundBackendPool and kubernetes pools present

# Found failing health probe
az network lb probe show --name "a1b3e899841974d7fa487e8bec283f26-TCP-80"
# -> Protocol: Http, Port: 32160, Path: "/"
```

**Fix:**
Create a TCP probe (checks port is open, no HTTP status validation):
```bash
MC_RG="MC_rg-aks-dev-eus_aks-dev-eus_eastus"

az network lb probe create \
  --resource-group $MC_RG \
  --lb-name kubernetes \
  --name "ingress-tcp-probe-80" \
  --protocol Tcp \
  --port 32160 \
  --interval 5 \
  --threshold 2

az network lb rule update \
  --resource-group $MC_RG \
  --lb-name kubernetes \
  --name "a1b3e899841974d7fa487e8bec283f26-TCP-80" \
  --probe-name "ingress-tcp-probe-80"
```

**Result after fix:**
```
Connection to 48.217.218.240 80 port [tcp/http] succeeded!
{"service":"calculator","status":"healthy"}
```

**Interview Answer:**
> The Azure LB health probe used HTTP GET `/` on the NGINX NodePort. NGINX returned 404 because no ingress rule matched `/`. The LB interpreted 404 as unhealthy and silently dropped all inbound TCP traffic. Port-forward worked because it bypasses the LB entirely. Changing the probe to TCP (which only verifies the port is open) resolved the issue immediately.

---

## Microservice Validation

**Ingress IP:** `48.217.218.240`

### Calculator Service — All Endpoints

```bash
BASE="http://48.217.218.240"

# Health check
curl $BASE/calculator/health

# Add
curl -X POST $BASE/calculator/add \
  -H "Content-Type: application/json" \
  -d '{"a": 10, "b": 5}'

# Subtract
curl -X POST $BASE/calculator/subtract \
  -H "Content-Type: application/json" \
  -d '{"a": 10, "b": 5}'

# Multiply
curl -X POST $BASE/calculator/multiply \
  -H "Content-Type: application/json" \
  -d '{"a": 10, "b": 5}'

# Divide
curl -X POST $BASE/calculator/divide \
  -H "Content-Type: application/json" \
  -d '{"a": 10, "b": 5}'

# Edge case — divide by zero (expects 400)
curl -X POST $BASE/calculator/divide \
  -H "Content-Type: application/json" \
  -d '{"a": 10, "b": 0}'
```

### Weather Service — All Endpoints

```bash
# Health check
curl $BASE/weather/health

# List available cities
curl $BASE/weather/weather

# Get weather by city
curl $BASE/weather/weather/london
curl $BASE/weather/weather/newyork
curl $BASE/weather/weather/tokyo
curl $BASE/weather/weather/sydney

# Unknown city (expects 404)
curl $BASE/weather/weather/mumbai
```

Available cities: `newyork`, `london`, `tokyo`, `sydney`

### Traffic Service — All Endpoints

```bash
# Health check
curl $BASE/traffic/health

# List all routes with live traffic data
curl $BASE/traffic/traffic

# Get specific route traffic
curl $BASE/traffic/traffic/I-95
curl "$BASE/traffic/traffic/Route-66"
curl "$BASE/traffic/traffic/Highway-101"
curl $BASE/traffic/traffic/I-405

# Unknown route (expects 404)
curl $BASE/traffic/traffic/I-99
```

Available routes: `I-95`, `Route-66`, `Highway-101`, `I-405`

---

## Test Results

### Infrastructure

| Component | Status | Details |
|---|---|---|
| AKS Cluster | Running | aks-dev-eus, eastus |
| ACR | Running | acrdevw52one.azurecr.io |
| VMSS Nodes | 2 nodes | vmss000002, vmss000003 |
| NGINX Ingress | Running | IP: 48.217.218.240 |

### Pod Status

```
NAME                                           READY   STATUS    RESTARTS
calculator-calculator-chart-5d8dbb4f9d-nb9nw   1/1     Running   0
calculator-calculator-chart-5d8dbb4f9d-v4pqx   1/1     Running   0
traffic-traffic-chart-7d48c5f978-4vhrw         1/1     Running   0
traffic-traffic-chart-7d48c5f978-6hf6d         1/1     Running   0
weather-weather-chart-797945f496-gjm2z         1/1     Running   0
weather-weather-chart-797945f496-j4pbr         1/1     Running   0
ingress-nginx-controller-54485bdbc8-tt4pj      1/1     Running   0
```

### Endpoint Status

```
NAME                          ENDPOINTS
calculator-calculator-chart   10.0.1.28:8080, 10.0.1.72:8080
traffic-traffic-chart         10.0.1.208:8080, 10.0.1.211:8080
weather-weather-chart         10.0.1.38:8080, 10.0.1.88:8080
```

### Functional Test Results

| Test | Endpoint | Expected | Result |
|---|---|---|---|
| Calculator Health | `GET /calculator/health` | `{"status":"healthy"}` | PASS |
| Calculator Add | `POST /calculator/add {"a":10,"b":5}` | `{"result":15}` | PASS |
| Calculator Subtract | `POST /calculator/subtract {"a":10,"b":5}` | `{"result":5}` | PASS |
| Calculator Multiply | `POST /calculator/multiply {"a":10,"b":5}` | `{"result":50}` | PASS |
| Calculator Divide | `POST /calculator/divide {"a":10,"b":5}` | `{"result":2.0}` | PASS |
| Calculator Divide by Zero | `POST /calculator/divide {"a":10,"b":0}` | HTTP 400 + error | PASS |
| Weather Health | `GET /weather/health` | `{"status":"healthy"}` | PASS |
| Weather List Cities | `GET /weather/weather` | cities array | PASS |
| Weather London | `GET /weather/weather/london` | temp, condition, humidity | PASS |
| Weather Unknown City | `GET /weather/weather/mumbai` | HTTP 404 + error | PASS |
| Traffic Health | `GET /traffic/health` | `{"status":"healthy"}` | PASS |
| Traffic All Routes | `GET /traffic/traffic` | 4 routes with data | PASS |
| Traffic I-95 | `GET /traffic/traffic/I-95` | speed, congestion, incidents | PASS |
| Traffic Unknown Route | `GET /traffic/traffic/I-99` | HTTP 404 + error | PASS |

### NSG Rules (Final State)

**Subnet NSG — nsg-aks-dev-eus (rg-aks-dev-eus):**

| Name | Priority | Direction | Access | Port | Source |
|---|---|---|---|---|---|
| AllowKubernetesAPIInbound | 100 | Inbound | Allow | 443 | Internet |
| AllowHTTPInbound | 105 | Inbound | Allow | 80 | Internet |
| AllowLoadBalancerInbound | 110 | Inbound | Allow | * | AzureLoadBalancer |
| AllowVnetInbound | 120 | Inbound | Allow | * | VirtualNetwork |
| DenyAllInbound | 4096 | Inbound | Deny | * | * |

---

## Best Practices

- Use **OIDC** instead of client secrets — no credentials to rotate
- Never commit `.env.local`, `.terraform/`, or credential files
- Add `required_reviewers` to production environment
- Use `--atomic` and `--cleanup-on-fail` in Helm deployments
- Always do a dry run before full migration
- Use `ClusterIP` for app services behind an ingress controller — only the ingress needs `LoadBalancer`
- Check **both** NSG layers (subnet NSG + NIC NSG) when troubleshooting AKS connectivity
- Use **TCP health probes** for NGINX ingress LB — HTTP probes fail if NGINX returns non-200 for the probe path
- Add the `kubelogin` install step explicitly — AAD-integrated AKS clusters require it in CI

---

## Post-Migration Checklist

- [x] Code pushed to GitHub
- [x] GitHub Actions workflows visible
- [x] OIDC federated credentials configured (branch + environment)
- [x] All secrets set in GitHub
- [x] Development environment with reviewer configured
- [x] Terraform deployed all infrastructure
- [x] Docker images built and pushed to ACR
- [x] All three services deployed via Helm
- [x] NGINX ingress controller deployed
- [x] Subnet NSG port 80 rule added
- [x] LB health probe changed to TCP
- [x] All microservice endpoints validated
- [ ] Archive (don't delete) Azure DevOps pipelines
- [ ] Set up branch protection rules on GitHub
- [ ] Enable Dependabot for dependency updates
- [ ] Automate NSG rule and LB probe fix in Terraform or post-deploy step

---

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Azure Login with OIDC](https://github.com/Azure/login)
- [Workload Identity Federation](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation)
- [Terraform GitHub Actions](https://github.com/hashicorp/setup-terraform)
- [AKS Load Balancer Annotations](https://learn.microsoft.com/en-us/azure/aks/load-balancer-standard)
- [NGINX Ingress Controller on AKS](https://learn.microsoft.com/en-us/azure/aks/ingress-basic)

---

**Migration completed and all services validated end-to-end.**
- Infrastructure: Terraform on GitHub Actions with OIDC
- Images: ACR (acrdevw52one.azurecr.io)
- Cluster: AKS (aks-dev-eus, eastus)
- Ingress: http://48.217.218.240
