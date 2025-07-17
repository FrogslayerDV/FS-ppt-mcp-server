terraform {
  required_version = ">= 1.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.85"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "random_string" "storage_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "azurerm_resource_group" "state" {
  name     = "rg-ppt-mcp-tfstate"
  location = "eastus"

  tags = {
    Purpose     = "OpenTofu State Storage"
    Environment = "shared"
    ManagedBy   = "OpenTofu"
  }
}

resource "azurerm_storage_account" "state" {
  name                     = "stpptmcptfstate${random_string.storage_suffix.result}"
  resource_group_name      = azurerm_resource_group.state.name
  location                 = azurerm_resource_group.state.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  blob_properties {
    versioning_enabled = true
  }

  tags = {
    Purpose     = "OpenTofu State Storage"
    Environment = "shared"
    ManagedBy   = "OpenTofu"
  }
}

resource "azurerm_storage_container" "state" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.state.name
  container_access_type = "private"
}

output "storage_account_name" {
  description = "Name of the storage account for OpenTofu state"
  value       = azurerm_storage_account.state.name
}

output "resource_group_name" {
  description = "Name of the resource group for OpenTofu state"
  value       = azurerm_resource_group.state.name
}

output "container_name" {
  description = "Name of the storage container for OpenTofu state"
  value       = azurerm_storage_container.state.name
}