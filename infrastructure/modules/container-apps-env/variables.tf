variable "environment_name" {
  description = "Name of the Container Apps environment"
  type        = string
}

variable "location" {
  description = "Azure region for the environment"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  type        = string
}

variable "log_analytics_primary_key" {
  description = "Primary key of the Log Analytics workspace"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "Tags to apply to the environment"
  type        = map(string)
  default     = {}
}