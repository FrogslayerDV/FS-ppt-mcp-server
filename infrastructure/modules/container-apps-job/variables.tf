variable "job_name" {
  description = "Name of the Container Apps Job"
  type        = string
}

variable "location" {
  description = "Azure region for the job"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "container_app_environment_id" {
  description = "ID of the Container Apps environment"
  type        = string
}

variable "container_image" {
  description = "Container image to deploy"
  type        = string
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

variable "transport_mode" {
  description = "Transport mode for the MCP server"
  type        = string
  default     = "http"
  
  validation {
    condition     = contains(["http", "stdio"], var.transport_mode)
    error_message = "Transport mode must be either 'http' or 'stdio'."
  }
}

variable "log_level" {
  description = "Log level for the application"
  type        = string
  default     = "INFO"
}

variable "container_cpu" {
  description = "CPU allocation for the container"
  type        = number
  default     = 0.25
}

variable "container_memory" {
  description = "Memory allocation for the container"
  type        = string
  default     = "0.5Gi"
}

variable "replica_timeout" {
  description = "Timeout for container replica in seconds"
  type        = number
  default     = 300
}

variable "replica_retry_limit" {
  description = "Retry limit for container replica"
  type        = number
  default     = 1
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "Tags to apply to the job"
  type        = map(string)
  default     = {}
}