#!/bin/bash
# ============================================================================
# Azure DevOps - Complete CLI Setup Script
# 100% Free OSS Security Stack (no paid tools required)
#
# Replaces all GUI steps for: extensions, service connections,
# environments, pipeline variables, and pipelines
#
# Usage:
#   export AZURE_DEVOPS_EXT_PAT="<your-ado-pat-token>"
#   export SPN_CLIENT_SECRET="<your-spn-secret>"
#   ./scripts/setup-ado-cli.sh
# ============================================================================

set -e

# ============================================================================
# CONFIGURATION
# ============================================================================
ADO_ORG="https://dev.azure.com/RajeshPatibandla1987"
ADO_PROJECT="AKS"
SUBSCRIPTION_ID="ce479075-963e-48cb-a26e-2777855a658c"
SUBSCRIPTION_NAME="Azure subscription 1"
TENANT_ID="27c9acfd-5cc5-421b-9ebe-08a1baed5edd"
SPN_CLIENT_ID="097f1b09-e11e-46af-b3b3-9e1f2ea9d429"
ACR_NAME="acrdevmreojy"
RESOURCE_GROUP="rg-aks-dev-eus"
REPO_NAME="aks-three-pods-repo"

# Required: pass as environment variables, never hardcode
# export AZURE_DEVOPS_EXT_PAT="<your-pat>"
# export SPN_CLIENT_SECRET="<your-spn-secret>"

# ============================================================================
# STEP 0: Prerequisites
# ============================================================================
echo "====== Step 0: Login & Configure ======"
export AZURE_DEVOPS_EXT_PAT="${AZURE_DEVOPS_EXT_PAT:?Please set AZURE_DEVOPS_EXT_PAT env var}"
export SPN_CLIENT_SECRET="${SPN_CLIENT_SECRET:?Please set SPN_CLIENT_SECRET env var}"

PAT_B64=$(echo -n ":$AZURE_DEVOPS_EXT_PAT" | base64 -w 0)

az devops configure \
  --defaults organization=$ADO_ORG project=$ADO_PROJECT

az account set --subscription $SUBSCRIPTION_ID
echo "Logged in and configured."

# ============================================================================
# STEP 1: Install ADO Marketplace Extensions (free extensions only)
# ============================================================================
echo ""
echo "====== Step 1: Install ADO Extensions ======"

install_extension() {
  local PUBLISHER=$1
  local EXTENSION=$2
  local NAME=$3
  echo "Installing $NAME..."
  az devops extension install \
    --publisher-id $PUBLISHER \
    --extension-id $EXTENSION \
    --organization $ADO_ORG 2>/dev/null \
    && echo "  $NAME: installed" \
    || echo "  $NAME: already installed or skipped"
}

# Free extensions used by the pipelines
install_extension "AquaSecurityOfficial" "trivy-official"             "Trivy (Aqua) - free"
install_extension "gittools"             "gittools"                   "GitTools - free"
install_extension "ms-securitydevlabs"   "microsoft-security-devlabs" "Microsoft Security DevLabs - free"

echo "Note: SonarCloud and Snyk extensions NOT installed (replaced by Semgrep + pip-audit, both free)"

# ============================================================================
# STEP 2: Create Service Connections
# ============================================================================
echo ""
echo "====== Step 2: Create Service Connections ======"

# 2a. Azure Resource Manager service connection
echo "Creating Azure RM service connection..."
az devops service-endpoint azurerm create \
  --azure-rm-service-principal-id $SPN_CLIENT_ID \
  --azure-rm-subscription-id $SUBSCRIPTION_ID \
  --azure-rm-subscription-name "$SUBSCRIPTION_NAME" \
  --azure-rm-tenant-id $TENANT_ID \
  --name azure-service-connection \
  --project $ADO_PROJECT \
  --organization $ADO_ORG 2>/dev/null || echo "azure-service-connection: already exists"

# Grant all pipelines access
ARM_EP_ID=$(az devops service-endpoint list \
  --project $ADO_PROJECT \
  --query "[?name=='azure-service-connection'].id" -o tsv)

if [ -n "$ARM_EP_ID" ]; then
  az devops service-endpoint update \
    --id $ARM_EP_ID \
    --project $ADO_PROJECT \
    --enable-for-all true
  echo "azure-service-connection: granted to all pipelines"
fi

# 2b. ACR Docker Registry service connection
echo "Creating ACR service connection..."
ACR_LOGIN_SERVER=$(az acr show \
  --name $ACR_NAME \
  --resource-group $RESOURCE_GROUP \
  --query loginServer -o tsv)

ACR_PASSWORD=$(az acr credential show \
  --name $ACR_NAME \
  --query passwords[0].value -o tsv)

cat > /tmp/acr-endpoint.json << JSONEOF
{
  "data": {
    "registrytype": "Others",
    "url": "https://${ACR_LOGIN_SERVER}",
    "username": "${ACR_NAME}",
    "password": "${ACR_PASSWORD}"
  },
  "name": "acr-service-connection",
  "type": "dockerregistry",
  "url": "https://${ACR_LOGIN_SERVER}",
  "authorization": {
    "parameters": {
      "username": "${ACR_NAME}",
      "password": "${ACR_PASSWORD}",
      "email": "admin@example.com",
      "registry": "https://${ACR_LOGIN_SERVER}"
    },
    "scheme": "UsernamePassword"
  },
  "isShared": false,
  "isReady": true
}
JSONEOF

az devops service-endpoint create \
  --service-endpoint-configuration /tmp/acr-endpoint.json \
  --project $ADO_PROJECT \
  --organization $ADO_ORG 2>/dev/null || echo "acr-service-connection: already exists"

ACR_EP_ID=$(az devops service-endpoint list \
  --project $ADO_PROJECT \
  --query "[?name=='acr-service-connection'].id" -o tsv)

if [ -n "$ACR_EP_ID" ]; then
  az devops service-endpoint update \
    --id $ACR_EP_ID \
    --project $ADO_PROJECT \
    --enable-for-all true
  echo "acr-service-connection: granted to all pipelines"
fi

echo "Note: snyk-connection and sonarcloud-connection NOT created (tools replaced by pip-audit + Semgrep)"

# ============================================================================
# STEP 3: Create Pipeline Variable Groups
# ============================================================================
echo ""
echo "====== Step 3: Create Pipeline Variable Groups ======"

# Required: pass as environment variables before running this script
# export AZURE_DEVOPS_ACCESS_TOKEN="<your-ado-pat>"   (same as AZURE_DEVOPS_EXT_PAT)
# export GITHUB_ACCESS_TOKEN="<your-github-pat>"
AZURE_DEVOPS_ACCESS_TOKEN="${AZURE_DEVOPS_ACCESS_TOKEN:-${AZURE_DEVOPS_EXT_PAT}}"
: "${AZURE_DEVOPS_ACCESS_TOKEN:?Please set AZURE_DEVOPS_ACCESS_TOKEN env var}"
: "${GITHUB_ACCESS_TOKEN:?Please set GITHUB_ACCESS_TOKEN env var}"

az pipelines variable-group create \
  --name "security-secrets" \
  --variables \
    SEMGREP_APP_TOKEN="optional-for-semgrep-cloud" \
    AZURE_DEVOPS_ACCESS_TOKEN="placeholder" \
    GITHUB_ACCESS_TOKEN="placeholder" \
  --project $ADO_PROJECT \
  --organization $ADO_ORG 2>/dev/null || echo "Variable group 'security-secrets': already exists"

GROUP_ID=$(az pipelines variable-group list \
  --project $ADO_PROJECT \
  --query "[?name=='security-secrets'].id" -o tsv)

if [ -n "$GROUP_ID" ]; then
  az pipelines variable-group variable update \
    --group-id $GROUP_ID \
    --name SEMGREP_APP_TOKEN \
    --value "optional-for-semgrep-cloud" \
    --secret true \
    --project $ADO_PROJECT 2>/dev/null || true

  az pipelines variable-group variable update \
    --group-id $GROUP_ID \
    --name AZURE_DEVOPS_ACCESS_TOKEN \
    --value "$AZURE_DEVOPS_ACCESS_TOKEN" \
    --secret true \
    --project $ADO_PROJECT 2>/dev/null || true

  az pipelines variable-group variable update \
    --group-id $GROUP_ID \
    --name GITHUB_ACCESS_TOKEN \
    --value "$GITHUB_ACCESS_TOKEN" \
    --secret true \
    --project $ADO_PROJECT 2>/dev/null || true

  echo "Variable group 'security-secrets' configured with 3 secret variables:"
  echo "  - SEMGREP_APP_TOKEN          (optional, for Semgrep Cloud)"
  echo "  - AZURE_DEVOPS_ACCESS_TOKEN  (secret - set from env var)"
  echo "  - GITHUB_ACCESS_TOKEN        (secret - set from env var)"
fi

# ============================================================================
# STEP 4: Create ADO Environments
# ============================================================================
echo ""
echo "====== Step 4: Create ADO Environments ======"

for ENV_NAME in "AKS-Applications" "AKS-Production" "AKS-Infrastructure"; do
  RESPONSE=$(curl -sf -X POST \
    "$ADO_ORG/$ADO_PROJECT/_apis/distributedtask/environments?api-version=7.0" \
    -H "Authorization: Basic $PAT_B64" \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"$ENV_NAME\", \"description\": \"$ENV_NAME deployment environment\"}" 2>&1 || echo "{}")
  ENV_ID=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null || echo "")
  if [ -n "$ENV_ID" ]; then
    echo "Environment '$ENV_NAME': created (id=$ENV_ID)"
  else
    # May already exist - verify
    EXISTING=$(curl -s \
      "$ADO_ORG/$ADO_PROJECT/_apis/distributedtask/environments?api-version=7.0" \
      -H "Authorization: Basic $PAT_B64" \
      | python3 -c "import sys,json; envs=json.load(sys.stdin).get('value',[]); match=[e for e in envs if e['name']=='$ENV_NAME']; print(match[0]['id'] if match else '')" 2>/dev/null || echo "")
    if [ -n "$EXISTING" ]; then
      echo "Environment '$ENV_NAME': already exists (id=$EXISTING)"
    else
      echo "Environment '$ENV_NAME': could not create - check PAT permissions (needs Environment: read & manage)"
    fi
  fi
done

# ============================================================================
# STEP 5: Set Approval on Environments via REST API
# ============================================================================
echo ""
echo "====== Step 5: Configure Environment Approvals ======"

USER_ID=$(az ad signed-in-user show --query id -o tsv 2>/dev/null || echo "")

if [ -z "$USER_ID" ]; then
  echo "Warning: Could not get user ID for approvals - configure approvals manually in ADO UI"
else
  for ENV in "AKS-Applications" "AKS-Production"; do
    ENV_ID=$(curl -s \
      "$ADO_ORG/$ADO_PROJECT/_apis/distributedtask/environments?api-version=7.0" \
      -H "Authorization: Basic $PAT_B64" \
      | python3 -c "import sys,json; envs=json.load(sys.stdin).get('value',[]); print(next((str(e['id']) for e in envs if e['name']=='$ENV'), ''))" 2>/dev/null || echo "")

    if [ -n "$ENV_ID" ]; then
      curl -s -X POST \
        "$ADO_ORG/$ADO_PROJECT/_apis/pipelines/checks/configurations?api-version=7.0" \
        -H "Authorization: Basic $PAT_B64" \
        -H "Content-Type: application/json" \
        -d "{
          \"type\": { \"id\": \"8c6f20a7-a545-4486-9777-f762fafe0d4d\", \"name\": \"Approval\" },
          \"settings\": {
            \"approvers\": [{ \"id\": \"$USER_ID\" }],
            \"instructions\": \"Review security scan results before approving deployment\",
            \"minRequiredApprovers\": 1
          },
          \"resource\": { \"type\": \"environment\", \"id\": \"$ENV_ID\" }
        }" > /dev/null && echo "Approval configured for '$ENV'" || echo "Approval for '$ENV': check manually"
    else
      echo "Could not find environment '$ENV' - skipping approval setup"
    fi
  done
fi

# ============================================================================
# STEP 6: Create Pipelines
# ============================================================================
echo ""
echo "====== Step 6: Create Pipelines ======"

create_pipeline() {
  local NAME=$1
  local YAML_PATH=$2
  echo "Creating pipeline: $NAME..."
  az pipelines create \
    --name "$NAME" \
    --yaml-path "$YAML_PATH" \
    --repository $REPO_NAME \
    --repository-type tfsgit \
    --branch main \
    --project $ADO_PROJECT \
    --organization $ADO_ORG \
    --skip-first-run 2>/dev/null \
    && echo "  $NAME: created" \
    || echo "  $NAME: already exists"
}

create_pipeline "infra-deploy"    "pipelines/infra-deploy-pipeline.yml"
create_pipeline "app-deploy"      "pipelines/app-deploy-pipeline.yml"
create_pipeline "full-deployment" "pipelines/full-deployment-pipeline.yml"
create_pipeline "pr-security"     "pipelines/pr-security-pipeline.yml"

# Link variable group to each pipeline
if [ -n "$GROUP_ID" ]; then
  for PIPELINE_NAME in "app-deploy" "pr-security" "full-deployment"; do
    PIPELINE_ID=$(az pipelines show \
      --name "$PIPELINE_NAME" \
      --project $ADO_PROJECT \
      --query id -o tsv 2>/dev/null || echo "")

    if [ -n "$PIPELINE_ID" ]; then
      curl -s -X PATCH \
        "$ADO_ORG/$ADO_PROJECT/_apis/build/definitions/$PIPELINE_ID?api-version=7.0" \
        -H "Authorization: Basic $PAT_B64" \
        -H "Content-Type: application/json" \
        -d "{\"variableGroups\": [{\"id\": $GROUP_ID}]}" > /dev/null \
        && echo "Variable group linked to $PIPELINE_NAME" || true
    fi
  done
fi

# ============================================================================
# STEP 7: Enable Branch Policies for PR
# ============================================================================
echo ""
echo "====== Step 7: Branch Policies for PR ======"

REPO_ID=$(az repos show \
  --repository $REPO_NAME \
  --project $ADO_PROJECT \
  --query id -o tsv 2>/dev/null || echo "")

PR_PIPELINE_ID=$(az pipelines show \
  --name "pr-security" \
  --project $ADO_PROJECT \
  --query id -o tsv 2>/dev/null || echo "")

if [ -n "$PR_PIPELINE_ID" ] && [ -n "$REPO_ID" ]; then
  # Require PR security pipeline to pass before merge
  curl -s -X POST \
    "$ADO_ORG/$ADO_PROJECT/_apis/policy/configurations?api-version=7.0" \
    -H "Authorization: Basic $PAT_B64" \
    -H "Content-Type: application/json" \
    -d "{
      \"isEnabled\": true,
      \"isBlocking\": true,
      \"type\": { \"id\": \"fa4e907d-c16b-452d-8106-7efa0cb84489\" },
      \"settings\": {
        \"buildDefinitionId\": $PR_PIPELINE_ID,
        \"queueOnSourceUpdateOnly\": true,
        \"manualQueueOnly\": false,
        \"displayName\": \"PR Security Validation\",
        \"validDuration\": 720,
        \"scope\": [{
          \"repositoryId\": \"$REPO_ID\",
          \"refName\": \"refs/heads/main\",
          \"matchKind\": \"Exact\"
        }]
      }
    }" > /dev/null && echo "Branch policy: PR security scan required before merge to main" || true

  # Require minimum 1 reviewer
  curl -s -X POST \
    "$ADO_ORG/$ADO_PROJECT/_apis/policy/configurations?api-version=7.0" \
    -H "Authorization: Basic $PAT_B64" \
    -H "Content-Type: application/json" \
    -d "{
      \"isEnabled\": true,
      \"isBlocking\": true,
      \"type\": { \"id\": \"fa4e907d-c16b-452d-8106-7efa0cb84490\" },
      \"settings\": {
        \"minimumApproverCount\": 1,
        \"creatorVoteCounts\": false,
        \"scope\": [{
          \"repositoryId\": \"$REPO_ID\",
          \"refName\": \"refs/heads/main\",
          \"matchKind\": \"Exact\"
        }]
      }
    }" > /dev/null && echo "Branch policy: min 1 reviewer required" || true
else
  echo "Warning: Could not set branch policies - REPO_ID=$REPO_ID, PR_PIPELINE_ID=$PR_PIPELINE_ID"
fi

echo ""
echo "=========================================================="
echo "ADO SETUP COMPLETE - FREE OSS SECURITY STACK"
echo "=========================================================="
echo ""
echo "Extensions installed:    Trivy, GitTools, MS Security DevLabs"
echo "Service connections:     azure-service-connection"
echo "                         acr-service-connection"
echo "Variable groups:         security-secrets (SEMGREP_APP_TOKEN - optional)"
echo "Environments:            AKS-Applications, AKS-Production, AKS-Infrastructure"
echo "Approvals:               Configured on AKS-Applications, AKS-Production"
echo "Pipelines created:       infra-deploy, app-deploy, full-deployment, pr-security"
echo "Branch policies:         PR security check + min 1 reviewer on main"
echo ""
echo "Security tools (all free):"
echo "  Secret scan:     GitLeaks"
echo "  SAST:            Semgrep (replaces SonarCloud)"
echo "  SCA:             pip-audit + OWASP Dep Check (replaces Snyk)"
echo "  Dockerfile lint: Hadolint"
echo "  Container scan:  Trivy"
echo "  IaC scan:        TFSec"
echo "  K8s security:    Kyverno + Kubescape (replaces OPA Enterprise)"
echo "  Runtime:         Falco + Microsoft Defender (replaces Aqua)"
echo ""
echo "Run pipelines:"
echo "  az pipelines run --name app-deploy --project $ADO_PROJECT"
echo "  az pipelines run --name full-deployment --project $ADO_PROJECT"
echo "=========================================================="
