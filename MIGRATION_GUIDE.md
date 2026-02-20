# Migration Guide: Azure DevOps to GitHub Actions

Complete guide for migrating your AKS Three Pods repository from Azure DevOps to GitHub with automated pipeline conversion.

## 📋 Table of Contents

- [Overview](#overview)
- [Migration Tools](#migration-tools)
- [Prerequisites](#prerequisites)
- [Migration Steps](#migration-steps)
- [Pipeline Conversion](#pipeline-conversion)
- [Testing](#testing)
- [Comparison](#comparison)

---

## 🎯 Overview

This guide covers migrating:
- ✅ Source code from Azure DevOps Git to GitHub
- ✅ Azure Pipelines YAML to GitHub Actions workflows
- ✅ Service connections to GitHub secrets
- ✅ Environments and approvals

### What Changes

| Azure DevOps | GitHub | 
|--------------|--------|
| Azure Repos | GitHub Repository |
| Azure Pipelines | GitHub Actions |
| Service Connections | Repository Secrets |
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

### 1. GitHub CLI Actions Importer

Official Microsoft/GitHub tool for converting Azure DevOps pipelines.

**Features**:
- Automated YAML conversion
- Audit existing pipelines
- Dry-run migrations
- Forecast compute usage

### 2. Manual Migration Scripts

Custom scripts for repository and configuration migration.

---

## ✅ Prerequisites

### Required Tools

```bash
# Install GitHub CLI
# macOS
brew install gh

# Windows (using winget)
winget install --id GitHub.cli

# Linux
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh
```

```bash
# Install Azure CLI (if not already installed)
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

```bash
# Install GitHub Actions Importer extension
gh extension install github/gh-actions-importer
```

### Required Access

- **Azure DevOps**: 
  - Read access to repository
  - Read access to pipelines
  - Personal Access Token (PAT) with `Build (Read)` and `Code (Read)` scopes

- **GitHub**:
  - Repository admin access
  - Ability to create secrets
  - Personal Access Token with `repo` and `workflow` scopes

- **Azure**:
  - Service Principal or credentials for Azure resources
  - Access to create/manage secrets

---

## 🚀 Migration Steps

### Step 1: Setup GitHub Actions Importer

#### 1.1 Authenticate GitHub CLI

```bash
# Login to GitHub
gh auth login

# Select:
# - GitHub.com
# - HTTPS
# - Login with a web browser
```

#### 1.2 Configure Actions Importer

```bash
# Create configuration file
gh actions-importer configure

# You'll be prompted for:
# 1. Platform: Select "Azure DevOps"
# 2. Azure DevOps URL: https://dev.azure.com/YOUR_ORG
# 3. Azure DevOps PAT: Your personal access token
# 4. GitHub PAT: Your GitHub personal access token
```

#### 1.3 Verify Configuration

```bash
# Test the connection
gh actions-importer audit azure-devops \
  --output-dir ./audit-results
```

---

### Step 2: Audit Existing Pipelines

```bash
# Audit all pipelines in your Azure DevOps project
gh actions-importer audit azure-devops \
  --organization YOUR_ORG \
  --project YOUR_PROJECT \
  --output-dir ./audit-results

# This creates:
# - audit_summary.md - Overview of pipelines
# - workflow_usage.csv - Detailed usage stats
# - pipeline_*.json - Individual pipeline details
```

**Review the audit results** to understand:
- How many pipelines will be converted
- Which features are fully/partially supported
- Manual changes needed

---

### Step 3: Dry Run Pipeline Conversion

Test the conversion without making changes:

```bash
# Dry run for infrastructure pipeline
gh actions-importer dry-run azure-devops pipeline \
  --organization YOUR_ORG \
  --project YOUR_PROJECT \
  --pipeline-id PIPELINE_ID \
  --output-dir ./dry-run-results

# Or specify by pipeline name
gh actions-importer dry-run azure-devops pipeline \
  --organization YOUR_ORG \
  --project YOUR_PROJECT \
  --pipeline-name "infra-deploy-pipeline" \
  --output-dir ./dry-run-results
```

This creates converted workflow files you can review before migration.

---

### Step 4: Migrate Repository

#### 4.1 Create GitHub Repository

```bash
# Using GitHub CLI
gh repo create YOUR_ORG/aks-three-pods-repo \
  --private \
  --description "AKS deployment with Terraform and GitHub Actions"
```

Or create via [GitHub Web UI](https://github.com/new).

#### 4.2 Clone Azure DevOps Repository

```bash
# Clone from Azure DevOps
git clone https://YOUR_ORG@dev.azure.com/YOUR_ORG/YOUR_PROJECT/_git/aks-three-pods-repo
cd aks-three-pods-repo
```

#### 4.3 Add GitHub as Remote and Push

```bash
# Add GitHub remote
git remote add github https://github.com/YOUR_ORG/aks-three-pods-repo.git

# Push all branches to GitHub
git push github --all

# Push all tags
git push github --tags
```

---

### Step 5: Convert Pipelines to GitHub Actions

#### 5.1 Convert Infrastructure Pipeline

```bash
gh actions-importer migrate azure-devops pipeline \
  --organization YOUR_ORG \
  --project YOUR_PROJECT \
  --pipeline-name "infra-deploy-pipeline" \
  --output-dir .github/workflows \
  --target-url https://github.com/YOUR_ORG/aks-three-pods-repo
```

#### 5.2 Convert Application Pipeline

```bash
gh actions-importer migrate azure-devops pipeline \
  --organization YOUR_ORG \
  --project YOUR_PROJECT \
  --pipeline-name "app-deploy-pipeline" \
  --output-dir .github/workflows \
  --target-url https://github.com/YOUR_ORG/aks-three-pods-repo
```

#### 5.3 Convert Full Deployment Pipeline

```bash
gh actions-importer migrate azure-devops pipeline \
  --organization YOUR_ORG \
  --project YOUR_PROJECT \
  --pipeline-name "full-deployment-pipeline" \
  --output-dir .github/workflows \
  --target-url https://github.com/YOUR_ORG/aks-three-pods-repo
```

---

### Step 6: Manual Conversion (Alternative Method)

If automated conversion doesn't work perfectly, use the manual converted workflows provided in this repo:

```bash
# Copy pre-converted workflows
cp -r .github/workflows-converted/* .github/workflows/
```

See the **[Converted Workflows](#converted-workflows)** section below.

---

### Step 7: Setup GitHub Secrets

#### 7.1 Azure Service Principal

Create or use existing Service Principal:

```bash
# Create new Service Principal
az ad sp create-for-rbac \
  --name "github-actions-aks-deploy" \
  --role contributor \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID \
  --sdk-auth

# This outputs JSON - save this entire output
```

#### 7.2 Add Secrets to GitHub

**Via GitHub CLI:**

```bash
# Azure credentials (paste the entire JSON from above)
gh secret set AZURE_CREDENTIALS < azure-credentials.json

# Or set individual values
gh secret set AZURE_SUBSCRIPTION_ID --body "YOUR_SUBSCRIPTION_ID"
gh secret set AZURE_TENANT_ID --body "YOUR_TENANT_ID"
gh secret set AZURE_CLIENT_ID --body "YOUR_CLIENT_ID"
gh secret set AZURE_CLIENT_SECRET --body "YOUR_CLIENT_SECRET"

# Terraform backend storage account name
gh secret set TF_BACKEND_STORAGE_ACCOUNT --body "sttfstateaks"

# ACR details (if pre-created)
gh secret set ACR_NAME --body "YOUR_ACR_NAME"
```

**Via GitHub Web UI:**

1. Go to your repository on GitHub
2. **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret listed above

#### 7.3 Required Secrets Summary

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `AZURE_CREDENTIALS` | Service Principal JSON (recommended) | `{"clientId": "...", "clientSecret": "...", ...}` |
| `AZURE_SUBSCRIPTION_ID` | Azure Subscription ID | `12345678-1234-1234-1234-123456789012` |
| `AZURE_TENANT_ID` | Azure AD Tenant ID | `87654321-4321-4321-4321-210987654321` |
| `AZURE_CLIENT_ID` | Service Principal App ID | `abcdef12-3456-7890-abcd-ef1234567890` |
| `AZURE_CLIENT_SECRET` | Service Principal Password | `your-secret-here` |
| `TF_BACKEND_STORAGE_ACCOUNT` | Terraform state storage | `sttfstateaks` |

---

### Step 8: Setup GitHub Environments

Create environments for deployment approvals:

```bash
# Create production environment via API
gh api repos/YOUR_ORG/aks-three-pods-repo/environments/production \
  --method PUT \
  --field wait_timer=0

# Add protection rules via Web UI:
# Settings → Environments → production → Add protection rule
# - Required reviewers: Add yourself or team
```

---

### Step 9: Test Workflows

#### 9.1 Trigger Test Run

```bash
# Make a small change and push
echo "# Test" >> README.md
git add README.md
git commit -m "Test GitHub Actions workflow"
git push github main
```

#### 9.2 Monitor Workflow

```bash
# Watch workflow runs
gh run watch

# Or view in browser
gh run view --web
```

#### 9.3 View Logs

```bash
# List recent runs
gh run list

# View specific run
gh run view RUN_ID

# Download logs
gh run download RUN_ID
```

---

### Step 10: Validate Deployment

After workflow completes:

```bash
# Get AKS credentials
az aks get-credentials \
  --resource-group rg-aks-dev-eus \
  --name aks-dev-eus

# Verify deployment
kubectl get pods
kubectl get services

# Test applications
curl http://<CALCULATOR_IP>/health
curl http://<WEATHER_IP>/health
curl http://<TRAFFIC_IP>/health
```

---

## 🔄 Converted Workflows

The repository includes pre-converted GitHub Actions workflows in `.github/workflows/`:

### 1. Infrastructure Deployment Workflow

**File**: `.github/workflows/infra-deploy.yml`

Converts: `pipelines/infra-deploy-pipeline.yml`

**Key changes**:
- Azure DevOps tasks → GitHub Actions
- Service connection → Repository secrets
- Artifact publishing → GitHub artifacts
- Environments → GitHub environments

### 2. Application Deployment Workflow

**File**: `.github/workflows/app-deploy.yml`

Converts: `pipelines/app-deploy-pipeline.yml`

**Key changes**:
- Docker tasks → `docker/build-push-action@v5`
- Helm deploy → `azure/setup-helm@v3`
- kubectl → `azure/setup-kubectl@v3`

### 3. Full Deployment Workflow

**File**: `.github/workflows/full-deploy.yml`

Converts: `pipelines/full-deployment-pipeline.yml`

**Features**:
- Multi-stage deployment
- Terraform integration
- Docker builds
- Helm deployments
- Environment approvals

---

## 📊 Feature Comparison

### Azure Pipelines vs GitHub Actions

| Feature | Azure DevOps | GitHub Actions | Migration Notes |
|---------|--------------|----------------|-----------------|
| **YAML Syntax** | Azure Pipelines | GitHub Actions | Automatic conversion |
| **Service Connection** | Service connection name | Repository secrets | Manual setup required |
| **Stages** | `stages:` | `jobs:` | Converted automatically |
| **Jobs** | `jobs:` | `jobs:` | Same concept |
| **Steps** | `steps:` | `steps:` | Same concept |
| **Variables** | `variables:` | `env:` | Converted automatically |
| **Artifacts** | Pipeline artifacts | GitHub artifacts | Different API |
| **Triggers** | `trigger:` | `on:` | Converted automatically |
| **Environments** | Environments | GitHub Environments | Manual setup |
| **Approvals** | Approval gates | Environment protection | Manual setup |
| **Self-hosted agents** | Agent pools | Self-hosted runners | Reconfigure needed |
| **Service containers** | Service containers | Service containers | Compatible |

### Task Mapping

| Azure DevOps Task | GitHub Action | Notes |
|-------------------|---------------|-------|
| `TerraformInstaller@0` | `hashicorp/setup-terraform@v2` | Direct equivalent |
| `AzureCLI@2` | `azure/cli@v1` | Similar functionality |
| `Docker@2` | `docker/build-push-action@v5` | More features |
| `HelmDeploy@0` | `azure/setup-helm@v3` + script | Helm CLI |
| `Kubernetes@1` | `azure/setup-kubectl@v3` + script | kubectl CLI |
| `PublishPipelineArtifact@1` | `actions/upload-artifact@v3` | Different API |
| `DownloadPipelineArtifact@2` | `actions/download-artifact@v3` | Different API |

---

## 🧪 Testing Migration

### Pre-Migration Checklist

- [ ] All source code committed and pushed
- [ ] Service Principal created with correct permissions
- [ ] GitHub repository created
- [ ] GitHub secrets configured
- [ ] GitHub environments created
- [ ] Workflow files reviewed

### Post-Migration Validation

```bash
# 1. Verify repository migration
git clone https://github.com/YOUR_ORG/aks-three-pods-repo.git
cd aks-three-pods-repo
git log --oneline -10  # Check commit history

# 2. Verify workflow syntax
gh workflow list

# 3. Trigger test deployment
git commit --allow-empty -m "Test deployment"
git push origin main

# 4. Monitor execution
gh run watch

# 5. Verify Azure resources
az group show --name rg-aks-dev-eus
az aks show --resource-group rg-aks-dev-eus --name aks-dev-eus

# 6. Test applications
kubectl get all
```

---

## 🔍 Troubleshooting

### Common Issues

#### 1. Workflow Syntax Errors

**Error**: Invalid workflow file

**Solution**:
```bash
# Validate workflow syntax
gh workflow view infra-deploy.yml
```

#### 2. Authentication Failures

**Error**: `Error: Login failed with Error: ...`

**Solution**:
- Verify Service Principal credentials
- Check secret names match workflow file
- Ensure Service Principal has correct role assignments

```bash
# Verify Service Principal
az ad sp show --id YOUR_CLIENT_ID

# Check role assignments
az role assignment list --assignee YOUR_CLIENT_ID
```

#### 3. Terraform Backend Errors

**Error**: `Error: Failed to get existing workspaces`

**Solution**:
```bash
# Verify storage account exists
az storage account show \
  --name YOUR_STORAGE_ACCOUNT \
  --resource-group rg-terraform-state

# Verify container exists
az storage container show \
  --name tfstate \
  --account-name YOUR_STORAGE_ACCOUNT
```

#### 4. Docker Build Failures

**Error**: `Error: Cannot connect to Docker daemon`

**Solution**:
- GitHub-hosted runners have Docker pre-installed
- Check workflow uses standard runner: `ubuntu-latest`
- Review Docker build logs for specific errors

#### 5. Helm Deployment Failures

**Error**: `Error: Kubernetes cluster unreachable`

**Solution**:
```bash
# Verify AKS credentials in workflow
# Check if azure/aks-set-context action is used correctly
```

---

## 💡 Best Practices

### 1. Use Secrets Properly

✅ Store sensitive data in GitHub secrets  
✅ Use environment secrets for environment-specific values  
✅ Never commit secrets to code  

### 2. Leverage Environments

✅ Create separate environments (dev, staging, prod)  
✅ Set up required reviewers for production  
✅ Use environment secrets for environment-specific configs  

### 3. Optimize Workflows

✅ Use caching for dependencies  
✅ Parallelize independent jobs  
✅ Use matrix strategies for multi-environment deployments  

### 4. Monitor and Alert

✅ Enable workflow notifications  
✅ Set up status badges  
✅ Review workflow run history regularly  

---

## 📚 Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GitHub Actions Importer](https://github.com/github/gh-actions-importer)
- [Azure Login Action](https://github.com/Azure/login)
- [Terraform GitHub Actions](https://github.com/hashicorp/setup-terraform)
- [Docker Build Push Action](https://github.com/docker/build-push-action)

---

## 🎯 Next Steps

After successful migration:

1. **Archive Azure DevOps pipelines** (don't delete immediately)
2. **Update documentation** to reference GitHub
3. **Train team** on GitHub Actions
4. **Set up branch protection** rules
5. **Configure CODEOWNERS** file
6. **Enable Dependabot** for dependency updates

---

## 🤝 Support

For migration issues:
1. Check GitHub Actions logs
2. Review workflow syntax
3. Verify secrets are set correctly
4. Test locally where possible
5. Consult GitHub Actions documentation

---

**Migration completed!** 🎉 Your pipelines are now running on GitHub Actions while still deploying to Azure.
