variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "resource_group_location" {
  description = "The location of the resource group"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "The ID of the Log Analytics Workspace"
  type        = string
}

variable "environment_name" {
  description = "The name of the container app environment"
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to the resource"
  type        = map(string)
  default     = {}
}