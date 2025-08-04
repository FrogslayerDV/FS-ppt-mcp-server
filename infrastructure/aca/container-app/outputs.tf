output "app_url" {
  description = "The latest revision FQDN of the container app"
  value       = azurerm_container_app.app.latest_revision_fqdn
}

output "name" {
  description = "The name of the container app"
  value       = azurerm_container_app.app.name
}

output "outbound_ip_addresses" {
  description = "The outbound IP addresses of the container app"
  value       = azurerm_container_app.app.outbound_ip_addresses
}

output "latest_revision_name" {
  description = "The name of the latest revision"
  value       = azurerm_container_app.app.latest_revision_name
}