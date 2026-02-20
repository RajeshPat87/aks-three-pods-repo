#!/bin/bash

# ==============================================================================
# Azure DevOps to GitHub Migration Script
# ==============================================================================
# This script automates the migration of repository and pipelines from
# Azure DevOps to GitHub using the official GitHub Actions Importer tool.
#
# Prerequisites:
# - GitHub CLI (gh) installed
# - GitHub Actions Importer extension installed
# - Azure CLI installed
# - Git installed
# - Appropriate permissions on both platforms
# ==============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ==============================================================================
# Configuration
# ==============================================================================

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Azure DevOps to GitHub Migration${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Prompt for Azure DevOps details
read -p "Azure DevOps Organization: " ADO_ORG
read -p "Azure DevOps Project: " ADO_PROJECT
read -p "Azure DevOps Repository Name: " ADO_REPO

echo ""

# Prompt for GitHub details
read -p "GitHub Organization/User: " GITHUB_ORG
read -p "GitHub Repository Name: " GITHUB_REPO
read -p "Make repository private? (y/n): " PRIVATE_REPO

echo ""

# ==============================================================================
# Step 1: Prerequisites Check
# ==============================================================================

echo -e "${YELLOW}Step 1: Checking Prerequisites...${NC}"

# Check GitHub CLI
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI (gh) is not installed${NC}"
    echo "Install from: https://cli.github.com/"
    exit 1
fi
echo -e "${GREEN}✓ GitHub CLI installed${NC}"

# Check Azure CLI
if ! command -v az &> /dev/null; then
    echo -e "${RED}Error: Azure CLI is not installed${NC}"
    echo "Install from: https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
fi
echo -e "${GREEN}✓ Azure CLI installed${NC}"

# Check Git
if ! command -v git &> /dev/null; then
    echo -e "${RED}Error: Git is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Git installed${NC}"

# Check GitHub Actions Importer
if ! gh extension list | grep -q "actions-importer"; then
    echo -e "${YELLOW}Installing GitHub Actions Importer extension...${NC}"
    gh extension install github/gh-actions-importer
fi
echo -e "${GREEN}✓ GitHub Actions Importer installed${NC}"

echo ""

# ==============================================================================
# Step 2: Authentication
# ==============================================================================

echo -e "${YELLOW}Step 2: Authenticating...${NC}"

# GitHub authentication
echo "Authenticating with GitHub..."
gh auth status &> /dev/null || gh auth login
echo -e "${GREEN}✓ GitHub authenticated${NC}"

# Azure authentication
echo "Authenticating with Azure..."
az account show &> /dev/null || az login
echo -e "${GREEN}✓ Azure authenticated${NC}"

echo ""

# ==============================================================================
# Step 3: Configure GitHub Actions Importer
# ==============================================================================

echo -e "${YELLOW}Step 3: Configuring GitHub Actions Importer...${NC}"

read -sp "Enter Azure DevOps Personal Access Token: " ADO_PAT
echo ""
read -sp "Enter GitHub Personal Access Token: " GITHUB_PAT
echo ""

# Configure the importer
gh actions-importer configure --no-interactive << EOF
azure-devops
https://dev.azure.com/$ADO_ORG
$ADO_PAT
$GITHUB_PAT
EOF

echo -e "${GREEN}✓ GitHub Actions Importer configured${NC}"
echo ""

# ==============================================================================
# Step 4: Audit Existing Pipelines
# ==============================================================================

echo -e "${YELLOW}Step 4: Auditing Azure DevOps Pipelines...${NC}"

mkdir -p ./migration-audit
gh actions-importer audit azure-devops \
  --organization "$ADO_ORG" \
  --project "$ADO_PROJECT" \
  --output-dir ./migration-audit

echo -e "${GREEN}✓ Audit complete. Results saved to ./migration-audit/${NC}"
echo ""
echo "Review audit results:"
echo "  - audit_summary.md"
echo "  - workflow_usage.csv"
echo ""

read -p "Continue with migration? (y/n): " CONTINUE
if [ "$CONTINUE" != "y" ]; then
    echo "Migration aborted."
    exit 0
fi

echo ""

# ==============================================================================
# Step 5: Create GitHub Repository
# ==============================================================================

echo -e "${YELLOW}Step 5: Creating GitHub Repository...${NC}"

REPO_FLAG="--public"
if [ "$PRIVATE_REPO" == "y" ]; then
    REPO_FLAG="--private"
fi

gh repo create "$GITHUB_ORG/$GITHUB_REPO" \
  $REPO_FLAG \
  --description "Migrated from Azure DevOps" \
  --confirm || echo "Repository might already exist"

echo -e "${GREEN}✓ GitHub repository ready${NC}"
echo ""

# ==============================================================================
# Step 6: Clone and Push Repository
# ==============================================================================

echo -e "${YELLOW}Step 6: Migrating Repository Content...${NC}"

# Create temporary directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Clone from Azure DevOps
echo "Cloning from Azure DevOps..."
git clone "https://$ADO_PAT@dev.azure.com/$ADO_ORG/$ADO_PROJECT/_git/$ADO_REPO" repo
cd repo

# Add GitHub remote
git remote add github "https://github.com/$GITHUB_ORG/$GITHUB_REPO.git"

# Push to GitHub
echo "Pushing to GitHub..."
git push github --all
git push github --tags

echo -e "${GREEN}✓ Repository content migrated${NC}"
echo ""

# ==============================================================================
# Step 7: Migrate Pipelines
# ==============================================================================

echo -e "${YELLOW}Step 7: Converting Azure Pipelines to GitHub Actions...${NC}"

# Get list of pipelines
echo "Fetching pipeline list..."
PIPELINE_LIST=$(az pipelines list \
  --organization "https://dev.azure.com/$ADO_ORG" \
  --project "$ADO_PROJECT" \
  --query "[].name" -o tsv)

echo "Found pipelines:"
echo "$PIPELINE_LIST"
echo ""

# Create workflows directory
mkdir -p .github/workflows

# Convert each pipeline
while IFS= read -r pipeline; do
    echo "Converting pipeline: $pipeline"
    
    # Perform dry run first
    gh actions-importer dry-run azure-devops pipeline \
      --organization "$ADO_ORG" \
      --project "$ADO_PROJECT" \
      --pipeline-name "$pipeline" \
      --output-dir ./dry-run
    
    # Migrate pipeline
    gh actions-importer migrate azure-devops pipeline \
      --organization "$ADO_ORG" \
      --project "$ADO_PROJECT" \
      --pipeline-name "$pipeline" \
      --output-dir .github/workflows \
      --target-url "https://github.com/$GITHUB_ORG/$GITHUB_REPO" || echo "Warning: Conversion may need manual fixes"
    
done <<< "$PIPELINE_LIST"

echo -e "${GREEN}✓ Pipelines converted${NC}"
echo ""

# ==============================================================================
# Step 8: Setup GitHub Secrets
# ==============================================================================

echo -e "${YELLOW}Step 8: Setting up GitHub Secrets...${NC}"

echo ""
echo "Please set up the following secrets in GitHub:"
echo "  1. Go to: https://github.com/$GITHUB_ORG/$GITHUB_REPO/settings/secrets/actions"
echo "  2. Add these secrets:"
echo ""
echo "Required secrets:"
echo "  - AZURE_CREDENTIALS (Service Principal JSON)"
echo "  - AZURE_SUBSCRIPTION_ID"
echo "  - AZURE_TENANT_ID"
echo "  - AZURE_CLIENT_ID"
echo "  - AZURE_CLIENT_SECRET"
echo "  - TF_BACKEND_STORAGE_ACCOUNT"
echo ""

read -p "Have you set up the secrets? (y/n): " SECRETS_DONE

if [ "$SECRETS_DONE" == "y" ]; then
    echo -e "${GREEN}✓ Secrets configured${NC}"
else
    echo -e "${YELLOW}⚠ Remember to configure secrets before running workflows${NC}"
fi

echo ""

# ==============================================================================
# Step 9: Push Workflows to GitHub
# ==============================================================================

echo -e "${YELLOW}Step 9: Pushing Workflows to GitHub...${NC}"

git add .github/workflows
git commit -m "Add GitHub Actions workflows (migrated from Azure Pipelines)"
git push github main

echo -e "${GREEN}✓ Workflows pushed to GitHub${NC}"
echo ""

# ==============================================================================
# Step 10: Summary
# ==============================================================================

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Migration Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Summary:"
echo "  - Source: https://dev.azure.com/$ADO_ORG/$ADO_PROJECT/_git/$ADO_REPO"
echo "  - Target: https://github.com/$GITHUB_ORG/$GITHUB_REPO"
echo ""
echo "Next steps:"
echo "  1. Review workflows: https://github.com/$GITHUB_ORG/$GITHUB_REPO/actions"
echo "  2. Verify secrets are configured"
echo "  3. Test workflow execution"
echo "  4. Update branch protection rules"
echo "  5. Configure environments and approvals"
echo ""
echo "Audit results saved in: ./migration-audit/"
echo "Temporary repo location: $TEMP_DIR/repo"
echo ""
echo -e "${BLUE}Happy coding with GitHub Actions!${NC}"
