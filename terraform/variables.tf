# ============================================================================
# Terraform Variables
# ============================================================================

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "location_short" {
  description = "Short name for Azure region"
  type        = string
  default     = "eus"
}

variable "owner_tag" {
  description = "Owner tag for resources"
  type        = string
  default     = "DevOps-Team"
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "Engineering"
}

# ============================================================================
# Resource Group Variables
# ============================================================================

variable "resource_group_name" {
  description = "Name of the resource group (leave empty for auto-generated)"
  type        = string
  default     = ""
}

# ============================================================================
# Networking Variables
# ============================================================================

variable "vnet_address_space" {
  description = "Address space for Virtual Network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "aks_subnet_address_prefix" {
  description = "Address prefix for AKS subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "app_gateway_subnet_address_prefix" {
  description = "Address prefix for Application Gateway subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "services_subnet_address_prefix" {
  description = "Address prefix for additional services subnet"
  type        = string
  default     = "10.0.3.0/24"
}

# ============================================================================
# AKS Cluster Variables
# ============================================================================

variable "aks_cluster_name" {
  description = "Name of the AKS cluster (leave empty for auto-generated)"
  type        = string
  default     = ""
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28.3"
}

variable "aks_node_count" {
  description = "Number of nodes in the default node pool"
  type        = number
  default     = 2
  validation {
    condition     = var.aks_node_count >= 1 && var.aks_node_count <= 10
    error_message = "Node count must be between 1 and 10."
  }
}

variable "aks_node_vm_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_DS2_v2"
}

variable "aks_max_pods" {
  description = "Maximum number of pods per node"
  type        = number
  default     = 110
}

variable "enable_auto_scaling" {
  description = "Enable auto-scaling for node pool"
  type        = bool
  default     = false
}

variable "min_node_count" {
  description = "Minimum number of nodes when auto-scaling is enabled"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of nodes when auto-scaling is enabled"
  type        = number
  default     = 5
}

# ============================================================================
# ACR Variables
# ============================================================================

variable "acr_sku" {
  description = "SKU for Azure Container Registry"
  type        = string
  default     = "Standard"
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "ACR SKU must be Basic, Standard, or Premium."
  }
}

# ============================================================================
# Security Variables
# ============================================================================

variable "enable_azure_policy" {
  description = "Enable Azure Policy for AKS"
  type        = bool
  default     = true
}

variable "enable_private_cluster" {
  description = "Enable private AKS cluster"
  type        = bool
  default     = false
}

variable "enable_rbac" {
  description = "Enable Kubernetes RBAC"
  type        = bool
  default     = true
}

variable "enable_azure_rbac" {
  description = "Enable Azure RBAC for Kubernetes authorization"
  type        = bool
  default     = true
}

# ============================================================================
# Monitoring Variables
# ============================================================================

variable "enable_monitoring" {
  description = "Enable Azure Monitor for containers"
  type        = bool
  default     = true
}

variable "log_analytics_retention_days" {
  description = "Log Analytics workspace retention in days"
  type        = number
  default     = 30
}

# ============================================================================
# Network Policy Variables
# ============================================================================

variable "network_plugin" {
  description = "Network plugin to use (azure or kubenet)"
  type        = string
  default     = "azure"
  validation {
    condition     = contains(["azure", "kubenet"], var.network_plugin)
    error_message = "Network plugin must be azure or kubenet."
  }
}

variable "network_policy" {
  description = "Network policy to use (azure or calico)"
  type        = string
  default     = "azure"
  validation {
    condition     = contains(["azure", "calico"], var.network_policy)
    error_message = "Network policy must be azure or calico."
  }
}
