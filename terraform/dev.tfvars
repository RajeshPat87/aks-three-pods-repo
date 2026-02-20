# ============================================================================
# Development Environment Variables
# ============================================================================

environment    = "dev"
location       = "eastus"
location_short = "eus"
owner_tag      = "DevOps-Team"
cost_center    = "Engineering"

# Resource Naming (leave empty for auto-generated names)
resource_group_name = ""
aks_cluster_name    = ""

# Networking
vnet_address_space                 = ["10.0.0.0/16"]
aks_subnet_address_prefix          = "10.0.1.0/24"
app_gateway_subnet_address_prefix  = "10.0.2.0/24"
services_subnet_address_prefix     = "10.0.3.0/24"

# AKS Configuration
kubernetes_version  = "1.28.3"
aks_node_count      = 2
aks_node_vm_size    = "Standard_DS2_v2"
aks_max_pods        = 110
enable_auto_scaling = false
min_node_count      = 1
max_node_count      = 5

# ACR Configuration
acr_sku = "Standard"

# Security
enable_azure_policy    = true
enable_private_cluster = false
enable_rbac            = true
enable_azure_rbac      = true

# Monitoring
enable_monitoring              = true
log_analytics_retention_days   = 30

# Network Configuration
network_plugin = "azure"
network_policy = "azure"
