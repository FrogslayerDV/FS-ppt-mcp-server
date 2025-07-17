output "workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "workspace_name" {
  description = "Name of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.name
}

output "workspace_customer_id" {
  description = "Customer ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.workspace_id
}

output "primary_shared_key" {
  description = "Primary shared key of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.primary_shared_key
  sensitive   = true
}

output "secondary_shared_key" {
  description = "Secondary shared key of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.secondary_shared_key
  sensitive   = true
}