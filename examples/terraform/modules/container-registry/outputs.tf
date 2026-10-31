output "reference" {
  description = "Reference for dependent modules (id, name, location, tags, naming)."
  value = {
    id       = azurerm_container_registry.main.id
    name     = azurerm_container_registry.main.name
    location = azurerm_container_registry.main.location
    tags     = azurerm_container_registry.main.tags
    naming   = local.naming
  }
}

output "login_server" {
  description = "The login server of the registry, e.g. for 'docker login'."
  value       = azurerm_container_registry.main.login_server
}

output "admin_password" {
  description = "The admin password of the registry, only set when admin_enabled is true."
  value       = azurerm_container_registry.main.admin_password
  sensitive   = true
}
