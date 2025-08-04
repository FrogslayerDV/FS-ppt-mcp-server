resource "azurerm_container_app_environment" "env" {
  name                       = var.environment_name
  resource_group_name        = var.resource_group_name
  location                   = var.resource_group_location
  log_analytics_workspace_id = var.log_analytics_workspace_id
  
  tags = var.tags
}