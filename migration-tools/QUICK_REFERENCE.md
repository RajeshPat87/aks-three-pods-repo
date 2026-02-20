# Azure DevOps vs GitHub Actions - Quick Reference

## Side-by-Side Syntax Comparison

### Pipeline Triggers

```yaml
# Azure DevOps
trigger:
  branches:
    include:
      - main
      - develop
  paths:
    include:
      - terraform/**

# GitHub Actions
on:
  push:
    branches:
      - main
      - develop
    paths:
      - 'terraform/**'
```

### Variables

```yaml
# Azure DevOps
variables:
  - name: terraformVersion
    value: '1.6.0'
  - name: environment
    value: 'dev'

# GitHub Actions
env:
  TERRAFORM_VERSION: '1.6.0'
  ENVIRONMENT: 'dev'
```

### Jobs and Stages

```yaml
# Azure DevOps
stages:
  - stage: Build
    displayName: 'Build Stage'
    jobs:
      - job: BuildJob
        displayName: 'Build Application'
        pool:
          vmImage: 'ubuntu-latest'

# GitHub Actions
jobs:
  build:
    name: 'Build Application'
    runs-on: ubuntu-latest
```

### Conditional Execution

```yaml
# Azure DevOps
- job: Deploy
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))

# GitHub Actions
deploy:
  runs-on: ubuntu-latest
  if: success() && github.ref == 'refs/heads/main'
```

### Environment Deployments

```yaml
# Azure DevOps
- deployment: DeployProd
  environment: 'production'
  strategy:
    runOnce:
      deploy:
        steps:
          - script: echo "Deploying"

# GitHub Actions
deploy-prod:
  runs-on: ubuntu-latest
  environment: production
  steps:
    - run: echo "Deploying"
```

### Artifacts

```yaml
# Azure DevOps
- task: PublishPipelineArtifact@1
  inputs:
    targetPath: '$(Build.ArtifactStagingDirectory)'
    artifact: 'drop'

# GitHub Actions
- uses: actions/upload-artifact@v3
  with:
    name: drop
    path: staging/
```

```yaml
# Azure DevOps
- task: DownloadPipelineArtifact@2
  inputs:
    artifact: 'drop'
    path: '$(System.DefaultWorkingDirectory)'

# GitHub Actions
- uses: actions/download-artifact@v3
  with:
    name: drop
    path: ./
```

### Azure CLI

```yaml
# Azure DevOps
- task: AzureCLI@2
  inputs:
    azureSubscription: 'service-connection'
    scriptType: 'bash'
    scriptLocation: 'inlineScript'
    inlineScript: |
      az aks get-credentials --resource-group $RG --name $AKS

# GitHub Actions
- uses: azure/cli@v1
  with:
    inlineScript: |
      az aks get-credentials --resource-group $RG --name $AKS
```

### Terraform

```yaml
# Azure DevOps
- task: TerraformInstaller@0
  inputs:
    terraformVersion: '1.6.0'

- task: TerraformTaskV4@4
  inputs:
    command: 'init'
    workingDirectory: 'terraform'

# GitHub Actions
- uses: hashicorp/setup-terraform@v3
  with:
    terraform_version: 1.6.0

- run: terraform init
  working-directory: terraform
```

### Docker

```yaml
# Azure DevOps
- task: Docker@2
  inputs:
    command: 'buildAndPush'
    repository: 'myapp'
    dockerfile: 'Dockerfile'
    containerRegistry: 'acr-connection'
    tags: |
      $(Build.BuildId)
      latest

# GitHub Actions
- uses: docker/build-push-action@v5
  with:
    context: .
    file: Dockerfile
    push: true
    tags: |
      myacr.azurecr.io/myapp:${{ github.run_number }}
      myacr.azurecr.io/myapp:latest
```

### Helm

```yaml
# Azure DevOps
- task: HelmDeploy@0
  inputs:
    connectionType: 'Azure Resource Manager'
    azureSubscription: 'service-connection'
    azureResourceGroup: 'my-rg'
    kubernetesCluster: 'my-aks'
    command: 'upgrade'
    chartType: 'FilePath'
    chartPath: 'charts/myapp'
    releaseName: 'myapp'
    install: true

# GitHub Actions
- uses: azure/setup-helm@v3
  with:
    version: '3.13.0'

- run: |
    helm upgrade --install myapp charts/myapp
```

### Secrets

```yaml
# Azure DevOps
# Reference variables from Variable Groups or Pipeline Variables
- script: echo "$(MY_SECRET)"

# GitHub Actions  
# Reference secrets from repository/environment secrets
- run: echo "${{ secrets.MY_SECRET }}"
```

### Matrix Strategy

```yaml
# Azure DevOps
strategy:
  matrix:
    Python37:
      python.version: '3.7'
    Python38:
      python.version: '3.8'

# GitHub Actions
strategy:
  matrix:
    python-version: ['3.7', '3.8']
```

### Service Connections vs Secrets

| Azure DevOps | GitHub Actions |
|--------------|----------------|
| Service Connection (centralized) | Repository/Environment Secrets |
| Shared across pipelines | Per-repository or per-environment |
| UI-based management | UI or CLI-based |
| Role-based access | Team/collaborator based |

### Checkout Code

```yaml
# Azure DevOps
- checkout: self

# GitHub Actions
- uses: actions/checkout@v4
```

### Working Directory

```yaml
# Azure DevOps
- script: terraform init
  workingDirectory: '$(System.DefaultWorkingDirectory)/terraform'

# GitHub Actions
- run: terraform init
  working-directory: ./terraform
```

### Job Dependencies

```yaml
# Azure DevOps
- job: Deploy
  dependsOn: Build

# GitHub Actions
deploy:
  needs: build
```

### Passing Data Between Jobs

```yaml
# Azure DevOps
# Set output variable
- script: echo "##vso[task.setvariable variable=myVar;isOutput=true]myValue"
  name: setVar

# Use in dependent job
- script: echo $(setVar.myVar)

# GitHub Actions
# Set output
- id: step1
  run: echo "myVar=myValue" >> $GITHUB_OUTPUT

# Use in dependent job
- run: echo "${{ needs.job1.outputs.myVar }}"
```

## Common Tasks Mapping

| Task | Azure DevOps | GitHub Actions |
|------|--------------|----------------|
| **Azure Login** | Service Connection | `azure/login@v1` |
| **Terraform** | `TerraformInstaller@0` | `hashicorp/setup-terraform@v3` |
| **Docker Build** | `Docker@2` | `docker/build-push-action@v5` |
| **Helm** | `HelmDeploy@0` | `azure/setup-helm@v3` + CLI |
| **kubectl** | `Kubernetes@1` | `azure/setup-kubectl@v3` + CLI |
| **Azure CLI** | `AzureCLI@2` | `azure/cli@v1` |
| **Get AKS Context** | Part of Kubernetes task | `azure/aks-set-context@v3` |
| **Publish Artifacts** | `PublishPipelineArtifact@1` | `actions/upload-artifact@v3` |
| **Download Artifacts** | `DownloadPipelineArtifact@2` | `actions/download-artifact@v3` |

## GitHub Actions Advantages

✅ **Marketplace**: 20,000+ pre-built actions  
✅ **Matrix builds**: Easier parallel execution  
✅ **Reusable workflows**: Better modularity  
✅ **Community**: Larger ecosystem  
✅ **Native integration**: With GitHub features  
✅ **Costs**: More free minutes  

## Azure DevOps Advantages

✅ **Enterprise features**: Advanced compliance  
✅ **YAML templates**: More mature  
✅ **Variable groups**: Centralized management  
✅ **Multi-stage approvals**: More granular  
✅ **Azure integration**: Tighter coupling  

## Migration Gotchas

### 1. Service Connections → Secrets

Azure DevOps service connections are **centralized** and shared.  
GitHub secrets are **per-repository** or **per-environment**.

**Action**: Create secrets for each repository.

### 2. Environments

Azure DevOps environments have built-in approval flows.  
GitHub environments require manual protection rule setup.

**Action**: Configure environment protection rules in GitHub.

### 3. YAML Syntax

Some Azure DevOps features don't have direct GitHub equivalents.

**Action**: Review converted workflows and test thoroughly.

### 4. Artifacts

Different APIs and retention policies.

**Action**: Update artifact upload/download steps.

### 5. Self-hosted Agents

Azure DevOps agent pools → GitHub self-hosted runners.

**Action**: Reconfigure runner registration if using self-hosted.

## Quick Command Reference

### GitHub CLI

```bash
# Login
gh auth login

# Create repo
gh repo create org/repo --private

# Set secret
gh secret set SECRET_NAME --body "value"

# List workflows
gh workflow list

# Run workflow
gh workflow run workflow.yml

# Watch run
gh run watch

# View run
gh run view --web
```

### GitHub Actions Importer

```bash
# Install
gh extension install github/gh-actions-importer

# Configure
gh actions-importer configure

# Audit
gh actions-importer audit azure-devops --output-dir ./audit

# Dry run
gh actions-importer dry-run azure-devops pipeline \
  --pipeline-name "my-pipeline" \
  --output-dir ./dry-run

# Migrate
gh actions-importer migrate azure-devops pipeline \
  --pipeline-name "my-pipeline" \
  --output-dir .github/workflows
```

## Best Practices

1. **Test workflows in a separate branch** before merging to main
2. **Use environment secrets** for environment-specific values
3. **Enable branch protection** with required status checks
4. **Set up CODEOWNERS** for workflow approvals
5. **Use caching** for dependencies (`actions/cache@v3`)
6. **Leverage reusable workflows** for common patterns
7. **Monitor workflow usage** and costs
8. **Keep secrets minimal** and rotate regularly
