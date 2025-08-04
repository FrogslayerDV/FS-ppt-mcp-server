output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_id" {
  description = "ID of the resource group"
  value       = azurerm_resource_group.main.id
}

output "container_apps_environment_name" {
  description = "Name of the Container Apps Environment"
  value       = module.aca-environment.name
}

output "container_apps_environment_id" {
  description = "ID of the Container Apps Environment"
  value       = module.aca-environment.id
}

output "container_apps" {
  description = "Information about deployed container apps"
  value = {
    for name, app in module.aca-containers : name => {
      name                  = app.name
      app_url               = app.app_url
      outbound_ip_addresses = app.outbound_ip_addresses
      latest_revision_name  = app.latest_revision_name
    }
  }
}

output "container_app_urls" {
  description = "URLs of the deployed container apps"
  value = {
    for name, app in module.aca-containers : name => "https://${app.app_url}"
  }
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
  description = "Commands to manage the Container Apps"
  value = {
    for name, app in module.aca-containers : "${name}_commands" => {
      view_logs      = "az containerapp logs show --name ${app.name} --resource-group ${azurerm_resource_group.main.name} --follow"
      show_app       = "az containerapp show --name ${app.name} --resource-group ${azurerm_resource_group.main.name}"
      list_revisions = "az containerapp revision list --name ${app.name} --resource-group ${azurerm_resource_group.main.name} --output table"
    }
  }
}