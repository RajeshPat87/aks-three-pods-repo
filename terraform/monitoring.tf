# ============================================================================
# Monitoring and Logging
# ============================================================================

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "aks" {
  count               = var.enable_monitoring ? 1 : 0
  name                = "log-${local.resource_suffix}"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_analytics_retention_days
  tags                = local.common_tags
}

# Log Analytics Solution for Containers
resource "azurerm_log_analytics_solution" "container_insights" {
  count                 = var.enable_monitoring ? 1 : 0
  solution_name         = "ContainerInsights"
  location              = azurerm_resource_group.aks.location
  resource_group_name   = azurerm_resource_group.aks.name
  workspace_resource_id = azurerm_log_analytics_workspace.aks[0].id
  workspace_name        = azurerm_log_analytics_workspace.aks[0].name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }

  tags = local.common_tags
}
