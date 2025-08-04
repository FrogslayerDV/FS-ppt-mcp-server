variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-ppt-mcp"
}

variable "environment_name" {
  description = "Environment name (prod, staging, dev)"
  type        = string
  default     = "prod"
}

variable "github_username" {
  description = "GitHub username for container registry"
  type        = string
}

variable "github_token" {
  description = "GitHub token for container registry access"
  type        = string
  sensitive   = true
}

variable "container_image" {
  description = "Container image to deploy"
  type        = string
  default     = "ghcr.io/yourusername/ppt-mcp-server:latest"
}

variable "containers_file" {
  description = "Path to the container definitions YAML file"
  type        = string
  default     = "container-definitions.yml"
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}