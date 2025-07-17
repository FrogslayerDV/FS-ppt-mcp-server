variable "workspace_name" {
  description = "Name of the Log Analytics workspace"
  type        = string
}

variable "location" {
  description = "Azure region for the workspace"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "Tags to apply to the workspace"
  type        = map(string)
  default     = {}
}