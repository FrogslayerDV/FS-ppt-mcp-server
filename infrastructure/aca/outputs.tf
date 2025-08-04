output "id" {
  description = "The ID of the Container App Environment"
  value       = azurerm_container_app_environment.env.id
}

output "name" {
  description = "The name of the Container App Environment"
  value       = azurerm_container_app_environment.env.name
}

output "default_domain" {
  description = "The default domain of the Container App Environment"
  value       = azurerm_container_app_environment.env.default_domain
}