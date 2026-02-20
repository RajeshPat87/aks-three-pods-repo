# Migration Guide: Azure DevOps to GitHub Actions

Complete guide for migrating your AKS Three Pods repository from Azure DevOps to GitHub with automated pipeline conversion.

> **This guide is customized for:**
> - ADO Organization: `RajeshPatibandla` | Project: `AKS`
> - GitHub Account: `RajeshPat87` | Repo: `aks-three-pods-repo`
> - Authentication: **Managed Identity + OIDC** (no client secrets)

---

## 📋 Table of Contents

- [Overview](#overview)
- [Migration Tools](#migration-tools)
- [Prerequisites](#prerequisites)
- [Migration Steps](#migration-steps)
- [Comparison](#comparison)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

---

## 🎯 Overview

This guide covers migrating:
- ✅ Source code from Azure DevOps Git to GitHub
- ✅ Azure Pipelines YAML to GitHub Actions workflows
- ✅ Service connections to GitHub secrets (OIDC)
- ✅ Environments and approvals

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

✅ **Azure infrastructure** - Still deploys to Azure
✅ **Terraform code** - No changes needed
✅ **Applications** - Same Docker images
✅ **Helm charts** - Same Kubernetes configs

---

## 🛠️ Migration Tools

### 1. GitHub CLI + Actions Importer

Official Microsoft/GitHub tool for converting Azure DevOps pipelines.

### 2. Git — Code Migration

Used to pull from ADO and push to GitHub.

---

## ✅ Prerequisites

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

## 🚀 Migration Steps

### Step 1: Authenticate GitHub CLI

```bash
gh auth login
# Select: GitHub.com → HTTPS → Login with a web browser
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

1. Go to Azure Portal → **Managed Identities** → search `Deploy`
2. Left menu → **Settings** → **Federated credentials**
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

#### 4.2 Collect Azure Identity Values

| Value | ID |
|-------|----|
| Client ID | `f3714cae-5dad-446d-bab4-67691c40c66e` |
| Tenant ID | `d57df211-4f37-47c0-81ed-dd6296f7638c` |
| Subscription ID | `fde7e51a-4a45-4843-b161-b4193587c43d` |

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
gh secret set TF_BACKEND_RESOURCE_GROUP --body "rg-terraform-state" -R RajeshPat87/aks-three-pods-repo
gh secret set TF_BACKEND_CONTAINER --body "tfstate" -R RajeshPat87/aks-three-pods-repo
gh secret set TF_BACKEND_KEY --body "aks-infrastructure.tfstate" -R RajeshPat87/aks-three-pods-repo

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
| `TF_BACKEND_RESOURCE_GROUP` | `rg-terraform-state` | Terraform state RG |
| `TF_BACKEND_CONTAINER` | `tfstate` | Terraform state container |
| `TF_BACKEND_KEY` | `aks-infrastructure.tfstate` | Terraform state file |
| `ACR_NAME` | `acrdevw52one` | Container registry name |
| `ACR_LOGIN_SERVER` | `acrdevw52one.azurecr.io` | Container registry URL |

---

### Step 8: Setup GitHub Environments

```bash
# Get your GitHub user ID
gh api users/RajeshPat87 --jq '.id'
# Returns: 63461203

# Create production environment with required reviewer
gh api repos/RajeshPat87/aks-three-pods-repo/environments/production \
  --method PUT \
  --field wait_timer=0 \
  --field "reviewers[][type]=User" \
  --field "reviewers[][id]=63461203"
```

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
`github.com/RajeshPat87/aks-three-pods-repo` → **Actions** → **Full Deployment** → **Run workflow**

---

### Step 10: Validate Deployment

```bash
# Get AKS credentials
az aks get-credentials \
  --resource-group rg-aks-dev-eus \
  --name aks-dev-eus

# Verify pods and services
kubectl get pods
kubectl get services
kubectl get all

# Test applications
curl http://<CALCULATOR_IP>/health
curl http://<WEATHER_IP>/health
curl http://<TRAFFIC_IP>/health
```

---

## 🔄 GitHub Actions Workflows (Already Migrated)

Workflows are in `.github/workflows/`:

| Workflow File | Description | Trigger |
|---------------|-------------|---------|
| `full-deploy.yml` | Full Deployment (Infrastructure + Apps) | `workflow_dispatch` |
| `infra-deploy.yml` | Infrastructure only (Terraform) | `workflow_dispatch` |
| `app-deploy.yml` | Applications only (Docker + Helm) | `workflow_dispatch` |

---

## 📊 Feature Comparison

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

## 🔍 Troubleshooting

### 1. OIDC Authentication Failure

**Error:** `Login failed` or `401 Unauthorized`

**Fix:**
- Verify federated credential subject matches: `repo:RajeshPat87/aks-three-pods-repo:ref:refs/heads/main`
- Confirm `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` secrets are set
- Ensure workflow has `permissions: id-token: write`

### 2. Terraform Backend Error

**Error:** `Failed to get existing workspaces`

```bash
az storage account show \
  --name sttfstate16243d65 \
  --resource-group rg-terraform-state

az storage container show \
  --name tfstate \
  --account-name sttfstate16243d65
```

### 3. Large File Push Rejected

**Error:** `File exceeds GitHub's 100MB limit`

```bash
# Remove from history
git filter-branch --force --index-filter \
  "git rm -rf --cached --ignore-unmatch terraform/.terraform/" \
  --prune-empty --tag-name-filter cat -- --all
git gc --prune=now --aggressive
git push github --all --force
```

### 4. Secret Detected in Push

**Error:** `GH013: Repository rule violations - Push cannot contain secrets`

```bash
# Remove secret file from history
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch .env.local" \
  --prune-empty --tag-name-filter cat -- --all
git gc --prune=now --aggressive
git push github --all --force
```

> **Regenerate any exposed tokens immediately.**

### 5. Helm Deployment Failure

**Error:** `Kubernetes cluster unreachable`

- Verify `az aks get-credentials` runs before Helm commands
- Check `azure/aks-set-context` action in workflow

---

## 💡 Best Practices

✅ Use **OIDC** instead of client secrets — no credentials to rotate
✅ Never commit `.env.local`, `.terraform/`, or credential files
✅ Add `required_reviewers` to production environment
✅ Use `--atomic` and `--cleanup-on-fail` in Helm deployments
✅ Always do a dry run before full migration

---

## 🎯 Post-Migration Checklist

- [ ] Code pushed to GitHub ✅
- [ ] GitHub Actions workflows visible ✅
- [ ] OIDC federated credential configured ✅
- [ ] All secrets set in GitHub ✅
- [ ] Production environment with reviewer ✅
- [ ] Test workflow run successful
- [ ] Archive (don't delete) Azure DevOps pipelines
- [ ] Set up branch protection rules
- [ ] Enable Dependabot for dependency updates

---

## 📚 Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Azure Login with OIDC](https://github.com/Azure/login)
- [Workload Identity Federation](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation)
- [Terraform GitHub Actions](https://github.com/hashicorp/setup-terraform)

---

**Migration completed!** 🎉 Your pipelines are now running on GitHub Actions with OIDC authentication deploying to Azure.
