variable "name" {
  description = "The name of the container app"
  type        = string
}

variable "container_app_environment_id" {
  description = "The Container App Environment ID"
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "ingress_port" {
  description = "The port to use for ingress"
  type        = number
}

variable "containers" {
  description = "List of container configurations"
  type = list(object({
    name     = string
    image    = string
    cpu      = number
    memory   = string
    env_vars = map(string)
  }))
}

variable "container_image" {
  description = "The container image to use (replaces CONTAINER_IMAGE placeholder)"
  type        = string
}

variable "github_username" {
  description = "GitHub username for container registry"
  type        = string
}

variable "github_token" {
  description = "GitHub token for container registry"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "A map of tags to assign to the resource"
  type        = map(string)
  default     = {}
}