# Audit summary

Summary for [Azure DevOps instance](https://dev.azure.com/RajeshPatibandla/AKS/_build)

- GitHub Actions Importer version: **1.3.22543 (64a9c1ce2299531079ffe72e0b7fb0da525c577d)**
- Performed at: **2/20/26 at 12:02**

## Pipelines

Total: **1**

- Successful: **1 (100%)**
- Partially successful: **0 (0%)**
- Unsupported: **0 (0%)**
- Failed: **0 (0%)**

### Job types

Supported: **1 (100%)**

- YAML: **1**

### Build steps

Total: **19**

Known: **19 (100%)**

- Docker@2: **9**
- AzureCLI@2: **6**
- checkout: **2**
- HelmInstaller@1: **1**
- TerraformInstaller@0: **1**

Actions: **23**

- run: **9**
- actions/checkout@v4.1.0: **5**
- docker/login-action@v3.0.0: **3**
- azure/login@v1.6.0: **3**
- azure/setup-helm@v3.5: **1**
- actions/download-artifact@v4.1.0: **1**
- hashicorp/setup-terraform@v3.0.0: **1**

### Triggers

Total: **0**

Actions: **1**

- workflow_dispatch: **1**

### Environment

Total: **9**

Known: **9 (100%)**

- terraformVersion: **1**
- imageTag: **1**
- helmVersion: **1**
- dockerRegistryServiceConnection: **1**
- backendStorageAccountName: **1**
- backendResourceGroupName: **1**
- backendKey: **1**
- backendContainerName: **1**
- azureServiceConnection: **1**

Actions: **9**

- terraformVersion: **1**
- imageTag: **1**
- helmVersion: **1**
- dockerRegistryServiceConnection: **1**
- backendStorageAccountName: **1**
- backendResourceGroupName: **1**
- backendKey: **1**
- backendContainerName: **1**
- azureServiceConnection: **1**

### Other

Total: **3**

Known: **3 (100%)**

- resourceGroupName: **1**
- aksClusterName: **1**
- acrLoginServer: **1**

Actions: **6**

- resourceGroupName: **1**
- aksClusterName: **1**
- acrLoginServer: **1**
- name: **1**
- DOCKER_USERNAME: **1**
- DOCKER_REGISTRY: **1**

### Manual tasks

Total: **6**

Secrets: **6**

- `${{ secrets.AZURE_CREDENTIALS }}`: **3**
- `${{ secrets.DOCKER_PASSWORD }}`: **3**

### Successful

#### AKS/infra_app_all

- [pipelines/AKS/infra_app_all/.github/workflows/infra_app_all.yml](pipelines/AKS/infra_app_all/.github/workflows/infra_app_all.yml)
- [pipelines/AKS/infra_app_all/config.json](pipelines/AKS/infra_app_all/config.json)
- [pipelines/AKS/infra_app_all/source.yml](pipelines/AKS/infra_app_all/source.yml)
