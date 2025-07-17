output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_id" {
  description = "ID of the resource group"
  value       = azurerm_resource_group.main.id
}

output "container_apps_job_name" {
  description = "Name of the Container Apps Job"
  value       = module.container_apps_job.name
}

output "container_apps_job_id" {
  description = "ID of the Container Apps Job"
  value       = module.container_apps_job.id
}

output "container_apps_environment_name" {
  description = "Name of the Container Apps Environment"
  value       = module.container_apps_env.name
}

output "container_apps_environment_id" {
  description = "ID of the Container Apps Environment"
  value       = module.container_apps_env.id
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = module.monitoring.workspace_id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  value       = module.monitoring.workspace_name
}

output "deployment_commands" {
  description = "Commands to execute the Container Apps Job"
  value = {
    start_job = "az containerapp job start --name ${module.container_apps_job.name} --resource-group ${azurerm_resource_group.main.name}"
    view_logs = "az containerapp logs show --name ${module.container_apps_job.name} --resource-group ${azurerm_resource_group.main.name} --follow"
    list_executions = "az containerapp job execution list --name ${module.container_apps_job.name} --resource-group ${azurerm_resource_group.main.name} --output table"
  }
}