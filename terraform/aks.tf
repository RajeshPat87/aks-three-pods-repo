# ============================================================================
# AKS Cluster
# ============================================================================

resource "azurerm_kubernetes_cluster" "aks" {
  name                = local.aks_cluster_name
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  dns_prefix          = "${local.aks_cluster_name}-dns"
  kubernetes_version  = var.kubernetes_version
  
  tags = local.common_tags

  # Default Node Pool
  default_node_pool {
    name                = "agentpool"
    vm_size             = var.aks_node_vm_size
    vnet_subnet_id      = azurerm_subnet.aks.id
    
    enable_auto_scaling = var.enable_auto_scaling
    node_count          = var.enable_auto_scaling ? null : var.aks_node_count
    min_count           = var.enable_auto_scaling ? var.min_node_count : null
    max_count           = var.enable_auto_scaling ? var.max_node_count : null
    
    max_pods            = var.aks_max_pods
    os_disk_size_gb     = 100
    os_disk_type        = "Managed"
    type                = "VirtualMachineScaleSets"
    
    upgrade_settings {
      max_surge = "10%"
    }

    tags = local.common_tags
  }

  # Identity
  identity {
    type = "SystemAssigned"
  }

  # Network Profile
  network_profile {
    network_plugin     = var.network_plugin
    network_policy     = var.network_policy
    dns_service_ip     = "10.1.0.10"
    service_cidr       = "10.1.0.0/16"
    load_balancer_sku  = "standard"
  }

  # Azure AD Integration
  azure_active_directory_role_based_access_control {
    managed                = true
    azure_rbac_enabled     = var.enable_azure_rbac
  }

  # Add-ons
  oms_agent {
    log_analytics_workspace_id = var.enable_monitoring ? azurerm_log_analytics_workspace.aks[0].id : null
  }

  azure_policy_enabled = var.enable_azure_policy

  # API Server Access Profile
  api_server_access_profile {
    authorized_ip_ranges = var.enable_private_cluster ? null : []
  }

  # Maintenance Window
  maintenance_window {
    allowed {
      day   = "Sunday"
      hours = [0, 1, 2, 3]
    }
  }

  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count
    ]
  }
}

# Role Assignment: AKS to VNet (Network Contributor)
resource "azurerm_role_assignment" "aks_network" {
  scope                = azurerm_virtual_network.aks.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}

# Role Assignment: AKS to ACR (AcrPull)
resource "azurerm_role_assignment" "aks_acr" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}
