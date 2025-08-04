locals {
  # Load container configurations from YAML
  container_configs_raw = yamldecode(file(var.containers_file))

  # Process container configs to replace image placeholders
  container_configs = {
    for app_name, config in local.container_configs_raw : app_name => {
      ingress_port = config.ingress_port
      containers = [
        for container in config.containers : {
          name     = container.name
          image    = replace(container.image, "$${CONTAINER_IMAGE}", var.container_image)
          cpu      = container.cpu
          memory   = container.memory
          env_vars = container.env_vars
        }
      ]
    }
  }
}

module "aca-environment" {
  source                     = "./aca"
  resource_group_name        = azurerm_resource_group.main.name
  resource_group_location    = azurerm_resource_group.main.location
  log_analytics_workspace_id = module.monitoring.workspace_id
  environment_name           = "ppt-mcp-env-${var.environment_name}"
  tags                       = local.common_tags
}

module "aca-containers" {
  source   = "./aca/container-app"
  for_each = local.container_configs

  name                         = each.key
  container_app_environment_id = module.aca-environment.id
  resource_group_name          = azurerm_resource_group.main.name
  ingress_port                 = each.value.ingress_port
  containers                   = each.value.containers
  container_image              = var.container_image
  github_username              = var.github_username
  github_token                 = var.github_token
  tags                         = local.common_tags
}