#!/bin/bash
# ============================================================================
# ADO Setup - Steps 4-7 only (Environments, Approvals, Pipelines, Branch Policies)
# Run this after setup-ado-cli.sh completes Steps 1-3
#
# Usage:
#   export AZURE_DEVOPS_EXT_PAT="<your-pat>"
#   bash scripts/setup-ado-step4-7.sh
# ============================================================================

set -e

ADO_ORG="https://dev.azure.com/RajeshPatibandla1987"
ADO_PROJECT="AKS"
SUBSCRIPTION_ID="ce479075-963e-48cb-a26e-2777855a658c"
REPO_NAME="aks-three-pods-repo"

export AZURE_DEVOPS_EXT_PAT="${AZURE_DEVOPS_EXT_PAT:?Please set AZURE_DEVOPS_EXT_PAT}"
PAT_B64=$(echo -n ":$AZURE_DEVOPS_EXT_PAT" | base64 -w 0)

az devops configure --defaults organization=$ADO_ORG project=$ADO_PROJECT

# ============================================================================
# STEP 4: Create ADO Environments
# ============================================================================
echo ""
echo "====== Step 4: Create ADO Environments ======"

for ENV_NAME in "AKS-Applications" "AKS-Production" "AKS-Infrastructure"; do
  RESPONSE=$(curl -s -X POST \
    "$ADO_ORG/$ADO_PROJECT/_apis/distributedtask/environments?api-version=7.0" \
    -H "Authorization: Basic $PAT_B64" \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"$ENV_NAME\", \"description\": \"$ENV_NAME deployment environment\"}" || echo "{}")
  ENV_ID=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null || echo "")
  if [ -n "$ENV_ID" ]; then
    echo "  Environment '$ENV_NAME': created (id=$ENV_ID)"
  else
    # Check if already exists
    EXISTING=$(curl -s \
      "$ADO_ORG/$ADO_PROJECT/_apis/distributedtask/environments?api-version=7.0" \
      -H "Authorization: Basic $PAT_B64" \
      | python3 -c "
import sys, json
data = json.load(sys.stdin)
envs = data.get('value', [])
match = [e for e in envs if e['name'] == '$ENV_NAME']
print(match[0]['id'] if match else '')
" 2>/dev/null || echo "")
    if [ -n "$EXISTING" ]; then
      echo "  Environment '$ENV_NAME': already exists (id=$EXISTING)"
    else
      echo "  Environment '$ENV_NAME': FAILED - check PAT has 'Environment (Read & Manage)' permission"
    fi
  fi
done

# ============================================================================
# STEP 5: Configure Approvals on AKS-Applications and AKS-Production
# ============================================================================
echo ""
echo "====== Step 5: Configure Environment Approvals ======"

# Get ADO internal user ID (different from Azure AD object ID)
USER_ID=$(curl -s "https://vssps.dev.azure.com/RajeshPatibandla1987/_apis/profile/profiles/me?api-version=7.0" \
  -H "Authorization: Basic $PAT_B64" \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || echo "")

if [ -z "$USER_ID" ]; then
  echo "  Warning: Could not get signed-in user ID - configure approvals manually in ADO UI"
  echo "  Go to: Pipelines > Environments > [env] > Approvals and checks"
else
  echo "  Approver user ID: $USER_ID"

  # Get all environments
  ALL_ENVS=$(curl -s \
    "$ADO_ORG/$ADO_PROJECT/_apis/distributedtask/environments?api-version=7.0" \
    -H "Authorization: Basic $PAT_B64")

  for ENV in "AKS-Applications" "AKS-Production" "AKS-Infrastructure"; do
    ENV_ID=$(echo "$ALL_ENVS" | python3 -c "
import sys, json
envs = json.load(sys.stdin).get('value', [])
match = [e for e in envs if e['name'] == '$ENV']
print(str(match[0]['id']) if match else '')
" 2>/dev/null || echo "")

    if [ -n "$ENV_ID" ]; then
      RESULT=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
        "$ADO_ORG/$ADO_PROJECT/_apis/pipelines/checks/configurations?api-version=7.0-preview" \
        -H "Authorization: Basic $PAT_B64" \
        -H "Content-Type: application/json" \
        -d "{
          \"type\": { \"id\": \"8c6f20a7-a545-4486-9777-f762fafe0d4d\", \"name\": \"Approval\" },
          \"settings\": {
            \"approvers\": [{ \"id\": \"$USER_ID\" }],
            \"instructions\": \"Review security scan results before approving deployment\",
            \"minRequiredApprovers\": 1,
            \"blockedApprovers\": [],
            \"requesterCannotBeApprover\": false
          },
          \"resource\": { \"type\": \"environment\", \"id\": \"$ENV_ID\", \"name\": \"$ENV\" },
          \"timeout\": 43200
        }")
      if [ "$RESULT" = "200" ] || [ "$RESULT" = "201" ]; then
        echo "  Approval configured for '$ENV' (env id=$ENV_ID)"
      else
        echo "  Approval for '$ENV': HTTP $RESULT - may already exist or check permissions"
      fi
    else
      echo "  Could not find environment '$ENV' - skipping"
    fi
  done
fi

# ============================================================================
# STEP 6: Create Pipelines
# ============================================================================
echo ""
echo "====== Step 6: Create Pipelines ======"

GROUP_ID=$(az pipelines variable-group list \
  --project $ADO_PROJECT \
  --query "[?name=='security-secrets'].id" -o tsv 2>/dev/null || echo "")

create_pipeline() {
  local NAME=$1
  local YAML_PATH=$2
  echo "  Creating pipeline: $NAME..."
  az pipelines create \
    --name "$NAME" \
    --yaml-path "$YAML_PATH" \
    --repository $REPO_NAME \
    --repository-type tfsgit \
    --branch main \
    --project $ADO_PROJECT \
    --organization $ADO_ORG \
    --skip-first-run 2>&1 | tail -1 \
    && echo "    $NAME: created" \
    || echo "    $NAME: already exists or skipped"
}

create_pipeline "infra-deploy"    "pipelines/infra-deploy-pipeline.yml"
create_pipeline "app-deploy"      "pipelines/app-deploy-pipeline.yml"
create_pipeline "full-deployment" "pipelines/full-deployment-pipeline.yml"
create_pipeline "pr-security"     "pipelines/pr-security-pipeline.yml"

# Link variable group to pipelines
if [ -n "$GROUP_ID" ]; then
  echo ""
  echo "  Linking variable group '$GROUP_ID' to pipelines..."
  for PIPELINE_NAME in "app-deploy" "pr-security" "full-deployment"; do
    PIPELINE_ID=$(az pipelines show \
      --name "$PIPELINE_NAME" \
      --project $ADO_PROJECT \
      --query id -o tsv 2>/dev/null || echo "")
    if [ -n "$PIPELINE_ID" ]; then
      # Must include full definition - fetch first then patch
      FULL_DEF=$(curl -s \
        "$ADO_ORG/$ADO_PROJECT/_apis/build/definitions/$PIPELINE_ID?api-version=7.0" \
        -H "Authorization: Basic $PAT_B64")
      # Merge variable group into definition
      UPDATED=$(echo "$FULL_DEF" | python3 -c "
import sys, json
d = json.load(sys.stdin)
d['variableGroups'] = [{'id': $GROUP_ID}]
print(json.dumps(d))
" 2>/dev/null || echo "")
      if [ -n "$UPDATED" ]; then
        curl -s -o /dev/null -X PUT \
          "$ADO_ORG/$ADO_PROJECT/_apis/build/definitions/$PIPELINE_ID?api-version=7.0" \
          -H "Authorization: Basic $PAT_B64" \
          -H "Content-Type: application/json" \
          -d "$UPDATED" \
          && echo "    Variable group linked to $PIPELINE_NAME" || true
      fi
    fi
  done
fi

# ============================================================================
# STEP 7: Branch Policies
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

echo "  Repo ID: $REPO_ID"
echo "  PR Pipeline ID: $PR_PIPELINE_ID"

if [ -n "$PR_PIPELINE_ID" ] && [ -n "$REPO_ID" ]; then
  # Query real policy type IDs from this org
  echo "  Fetching policy type IDs..."
  POLICY_TYPES=$(curl -s \
    "$ADO_ORG/$ADO_PROJECT/_apis/policy/types?api-version=7.0" \
    -H "Authorization: Basic $PAT_B64")

  BUILD_POLICY_TYPE=$(echo "$POLICY_TYPES" | python3 -c "
import sys, json
types = json.load(sys.stdin).get('value', [])
match = [t for t in types if 'build' in t.get('displayName','').lower() or 'Build' in t.get('displayName','')]
print(match[0]['id'] if match else '')
" 2>/dev/null || echo "")

  REVIEWER_POLICY_TYPE=$(echo "$POLICY_TYPES" | python3 -c "
import sys, json
types = json.load(sys.stdin).get('value', [])
match = [t for t in types if 'reviewer' in t.get('displayName','').lower() or 'Reviewer' in t.get('displayName','')]
print(match[0]['id'] if match else '')
" 2>/dev/null || echo "")

  echo "  Build policy type ID:    ${BUILD_POLICY_TYPE:-NOT FOUND}"
  echo "  Reviewer policy type ID: ${REVIEWER_POLICY_TYPE:-NOT FOUND}"

  # Policy: require pr-security pipeline to pass
  if [ -n "$BUILD_POLICY_TYPE" ]; then
    R1=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
      "$ADO_ORG/$ADO_PROJECT/_apis/policy/configurations?api-version=7.0" \
      -H "Authorization: Basic $PAT_B64" \
      -H "Content-Type: application/json" \
      -d "{
        \"isEnabled\": true,
        \"isBlocking\": true,
        \"type\": { \"id\": \"$BUILD_POLICY_TYPE\" },
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
      }")
    echo "  PR security build policy: HTTP $R1"
  else
    echo "  Build policy type not found - skipping"
  fi

  # Policy: require min 1 reviewer
  if [ -n "$REVIEWER_POLICY_TYPE" ]; then
    R2=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
      "$ADO_ORG/$ADO_PROJECT/_apis/policy/configurations?api-version=7.0" \
      -H "Authorization: Basic $PAT_B64" \
      -H "Content-Type: application/json" \
      -d "{
        \"isEnabled\": true,
        \"isBlocking\": true,
        \"type\": { \"id\": \"$REVIEWER_POLICY_TYPE\" },
        \"settings\": {
          \"minimumApproverCount\": 1,
          \"creatorVoteCounts\": false,
          \"scope\": [{
            \"repositoryId\": \"$REPO_ID\",
            \"refName\": \"refs/heads/main\",
            \"matchKind\": \"Exact\"
          }]
        }
      }")
    echo "  Min reviewer policy: HTTP $R2"
  else
    echo "  Reviewer policy type not found - skipping"
  fi
else
  echo "  Skipped: REPO_ID='$REPO_ID' PR_PIPELINE_ID='$PR_PIPELINE_ID'"
fi

echo ""
echo "=========================================================="
echo "STEPS 4-7 COMPLETE"
echo "=========================================================="
echo ""
echo "Verify in ADO:"
echo "  Environments: $ADO_ORG/$ADO_PROJECT/_environments"
echo "  Pipelines:    $ADO_ORG/$ADO_PROJECT/_build"
echo "  Branch rules: $ADO_ORG/$ADO_PROJECT/_settings/repositories"
echo ""
echo "Run app pipeline:"
echo "  az pipelines run --name app-deploy --project $ADO_PROJECT"
echo "=========================================================="
