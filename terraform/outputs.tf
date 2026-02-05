# ============================================================================
# Outputs
# ============================================================================

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.aks.name
}

output "resource_group_id" {
  description = "ID of the resource group"
  value       = azurerm_resource_group.aks.id
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "aks_cluster_id" {
  description = "ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.id
}

output "aks_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.fqdn
}

output "aks_node_resource_group" {
  description = "Resource group containing AKS nodes"
  value       = azurerm_kubernetes_cluster.aks.node_resource_group
}

output "acr_name" {
  description = "Name of the Azure Container Registry"
  value       = azurerm_container_registry.acr.name
}

output "acr_login_server" {
  description = "Login server for ACR"
  value       = azurerm_container_registry.acr.login_server
}

output "acr_id" {
  description = "ID of the Azure Container Registry"
  value       = azurerm_container_registry.acr.id
}

output "vnet_name" {
  description = "Name of the Virtual Network"
  value       = azurerm_virtual_network.aks.name
}

output "vnet_id" {
  description = "ID of the Virtual Network"
  value       = azurerm_virtual_network.aks.id
}

output "aks_subnet_id" {
  description = "ID of the AKS subnet"
  value       = azurerm_subnet.aks.id
}

output "appgw_subnet_id" {
  description = "ID of the Application Gateway subnet"
  value       = azurerm_subnet.appgw.id
}

output "services_subnet_id" {
  description = "ID of the Services subnet"
  value       = azurerm_subnet.services.id
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace"
  value       = var.enable_monitoring ? azurerm_log_analytics_workspace.aks[0].id : null
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics Workspace"
  value       = var.enable_monitoring ? azurerm_log_analytics_workspace.aks[0].name : null
}

output "kube_config" {
  description = "Kubernetes config for AKS cluster (sensitive)"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}

output "aks_identity_principal_id" {
  description = "Principal ID of AKS managed identity"
  value       = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}

output "aks_kubelet_identity_object_id" {
  description = "Object ID of AKS kubelet identity"
  value       = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}
