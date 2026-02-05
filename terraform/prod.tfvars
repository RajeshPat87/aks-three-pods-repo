# ============================================================================
# Production Environment Variables
# ============================================================================

environment    = "prod"
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

# AKS Configuration - Production settings
kubernetes_version  = "1.28.3"
aks_node_count      = 3              # More nodes for production
aks_node_vm_size    = "Standard_DS3_v2"  # Larger VMs for production
aks_max_pods        = 110
enable_auto_scaling = true           # Enable auto-scaling in prod
min_node_count      = 3
max_node_count      = 10

# ACR Configuration
acr_sku = "Premium"  # Premium for production (geo-replication, better performance)

# Security - Stricter for production
enable_azure_policy    = true
enable_private_cluster = false  # Set to true for higher security
enable_rbac            = true
enable_azure_rbac      = true

# Monitoring - Longer retention for production
enable_monitoring              = true
log_analytics_retention_days   = 90  # 90 days retention

# Network Configuration
network_plugin = "azure"
network_policy = "azure"
