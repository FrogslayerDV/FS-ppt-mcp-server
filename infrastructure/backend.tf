terraform {
  backend "azurerm" {
    # These values will be provided during initialization
    # resource_group_name  = "rg-ppt-mcp-tfstate"
    # storage_account_name = "stpptmcptfstate12345678"
    # container_name       = "tfstate"
    # key                  = "ppt-mcp.tfstate"
  }
}