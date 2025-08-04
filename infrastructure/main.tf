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

# Container Apps are now defined in aca.tf using YAML configuration