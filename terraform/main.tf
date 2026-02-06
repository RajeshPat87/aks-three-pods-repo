# ============================================================================
# Main Terraform Configuration for AKS Infrastructure
# Provider: Azure (azurerm)
# ============================================================================

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  # Backend configuration - will be configured via pipeline
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sttfstate16243d65"
    container_name       = "tfstate"
    key                  = "aks-infrastructure.tfstate"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

# ============================================================================
# Data Sources
# ============================================================================

data "azurerm_client_config" "current" {}

# ============================================================================
# Local Variables
# ============================================================================

locals {
  common_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "AKS-ThreePods"
    Owner       = var.owner_tag
    CostCenter  = var.cost_center
  }
  
  resource_suffix = "${var.environment}-${var.location_short}"
  resource_group_name = var.resource_group_name != "" ? var.resource_group_name : "rg-aks-${local.resource_suffix}"
  aks_cluster_name = var.aks_cluster_name != "" ? var.aks_cluster_name : "aks-${local.resource_suffix}"
  acr_name = "acr${var.environment}${random_string.suffix.result}"
}

# ============================================================================
# Random String for Unique Naming
# ============================================================================

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}
