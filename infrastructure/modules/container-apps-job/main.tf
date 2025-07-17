resource "azurerm_container_app_job" "main" {
  name                         = var.job_name
  location                     = var.location
  resource_group_name          = var.resource_group_name
  container_app_environment_id = var.container_app_environment_id
  
  replica_timeout_in_seconds = var.replica_timeout
  replica_retry_limit        = var.replica_retry_limit
  
  manual_trigger_config {
    parallelism              = 1
    replica_completion_count = 1
  }
  
  template {
    container {
      name   = "ppt-mcp-server"
      image  = var.container_image
      cpu    = var.container_cpu
      memory = var.container_memory
      
      env {
        name  = "TRANSPORT_MODE"
        value = var.transport_mode
      }
      
      env {
        name  = "LOG_LEVEL"
        value = var.log_level
      }
      
      env {
        name  = "PPT_TEMPLATE_PATH"
        value = "/app/templates"
      }
      
      dynamic "env" {
        for_each = var.transport_mode == "http" ? [1] : []
        content {
          name  = "HTTP_PORT"
          value = "8000"
        }
      }
      
      dynamic "env" {
        for_each = var.transport_mode == "http" ? [1] : []
        content {
          name  = "HTTP_HOST"
          value = "0.0.0.0"
        }
      }
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