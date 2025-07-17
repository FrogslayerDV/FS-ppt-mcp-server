output "id" {
  description = "ID of the Container Apps environment"
  value       = azurerm_container_app_environment.main.id
}

output "name" {
  description = "Name of the Container Apps environment"
  value       = azurerm_container_app_environment.main.name
}

output "location" {
  description = "Location of the Container Apps environment"
  value       = azurerm_container_app_environment.main.location
}

output "default_domain" {
  description = "Default domain of the Container Apps environment"
  value       = azurerm_container_app_environment.main.default_domain
}

output "static_ip_address" {
  description = "Static IP address of the Container Apps environment"
  value       = azurerm_container_app_environment.main.static_ip_address
}