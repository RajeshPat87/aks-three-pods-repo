# ============================================================================
# Azure Container Registry
# ============================================================================

resource "azurerm_container_registry" "acr" {
  name                = local.acr_name
  resource_group_name = azurerm_resource_group.aks.name
  location            = azurerm_resource_group.aks.location
  sku                 = var.acr_sku
  admin_enabled       = true

  tags = local.common_tags

  # network_rule_set {
  #   default_action = "Allow"
  # }

  # retention_policy {
  #   days    = 7
  #   enabled = true
  # }

  trust_policy {
    enabled = false
  }
}

# Private Endpoint for ACR (Optional - uncomment if needed)
# resource "azurerm_private_endpoint" "acr" {
#   name                = "pe-acr-${local.resource_suffix}"
#   location            = azurerm_resource_group.aks.location
#   resource_group_name = azurerm_resource_group.aks.name
#   subnet_id           = azurerm_subnet.services.id
#   tags                = local.common_tags
#
#   private_service_connection {
#     name                           = "psc-acr-${local.resource_suffix}"
#     private_connection_resource_id = azurerm_container_registry.acr.id
#     is_manual_connection           = false
#     subresource_names              = ["registry"]
#   }
# }
