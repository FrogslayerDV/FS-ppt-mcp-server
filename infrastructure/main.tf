provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Local values for common tags
locals {
  common_tags = merge(
    {
      Environment = var.environment_name
      ManagedBy   = "OpenTofu"
      Project     = "ppt-mcp-server"
    },
    var.tags
  )
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  
  tags = local.common_tags
}

# Log Analytics Workspace
module "monitoring" {
  source = "./modules/monitoring"
  
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  workspace_name      = "ppt-mcp-logs"
  environment         = var.environment_name
  tags                = local.common_tags
}

# Container Apps Environment
module "container_apps_env" {
  source = "./modules/container-apps-env"
  
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  environment_name           = "ppt-mcp-env"
  log_analytics_workspace_id = module.monitoring.workspace_id
  log_analytics_primary_key  = module.monitoring.primary_shared_key
  environment                = var.environment_name
  tags                       = local.common_tags
}

# Container Apps Job
module "container_apps_job" {
  source = "./modules/container-apps-job"
  
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  container_app_environment_id = module.container_apps_env.id
  job_name                     = "ppt-mcp-job"
  container_image              = var.container_image
  github_username              = var.github_username
  github_token                 = var.github_token
  transport_mode               = var.transport_mode
  log_level                    = var.log_level
  container_cpu                = var.container_cpu
  container_memory             = var.container_memory
  replica_timeout              = var.replica_timeout
  replica_retry_limit          = var.replica_retry_limit
  environment                  = var.environment_name
  tags                         = local.common_tags
}