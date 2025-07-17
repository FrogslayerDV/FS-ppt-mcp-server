output "id" {
  description = "ID of the Container Apps Job"
  value       = azurerm_container_app_job.main.id
}

output "name" {
  description = "Name of the Container Apps Job"
  value       = azurerm_container_app_job.main.name
}

output "location" {
  description = "Location of the Container Apps Job"
  value       = azurerm_container_app_job.main.location
}

output "resource_group_name" {
  description = "Resource group name of the Container Apps Job"
  value       = azurerm_container_app_job.main.resource_group_name
}

output "container_app_environment_id" {
  description = "Container Apps environment ID"
  value       = azurerm_container_app_job.main.container_app_environment_id
}

output "workload_profile_name" {
  description = "Workload profile name of the Container Apps Job"
  value       = azurerm_container_app_job.main.workload_profile_name
}

output "event_stream_endpoint" {
  description = "Event stream endpoint of the Container Apps Job"
  value       = azurerm_container_app_job.main.event_stream_endpoint
}