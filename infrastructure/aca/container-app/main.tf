resource "azurerm_container_app" "app" {
  name                         = var.name
  container_app_environment_id = var.container_app_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"

  template {
    dynamic "container" {
      for_each = var.containers
      content {
        name   = container.value.name
        image  = replace(container.value.image, "$${CONTAINER_IMAGE}", var.container_image)
        cpu    = container.value.cpu
        memory = container.value.memory

        dynamic "env" {
          for_each = container.value.env_vars != null ? container.value.env_vars : {}
          content {
            name  = env.key
            value = env.value
          }
        }
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = var.ingress_port
    transport        = "auto"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  registry {
    server               = "ghcr.io"
    username             = var.github_username
    password_secret_name = "github-token"
  }

  secret {
    name  = "github-token"
    value = var.github_token
  }

  tags = var.tags
}