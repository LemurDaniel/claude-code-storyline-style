# ---------------------------------------------------------------------------
# Context

variable "resource_group_reference" {
  nullable    = false
  description = "(Required) Reference of the resource group to deploy into (id, name, location, tags, naming)."
  type = object({
    id       = string
    name     = string
    location = string
    tags     = map(string)
    naming = object({
      environment    = string
      location_short = string
      workload       = string
    })
  })
}

# ---------------------------------------------------------------------------
# Container Registry

variable "container_registry" {
  nullable    = false
  description = "(Required) The configuration for the container registry."
  type = object({
    name           = optional(string)
    sku            = optional(string, "Standard")
    admin_enabled  = optional(bool, false)
    network_access = optional(string, "Public")
    ip_rules       = optional(list(string), [])
    tags           = optional(map(string), {})

    retention_policy = optional(object({
      enabled = optional(bool, true)
      days    = number
    }), { enabled = true, days = 7 })
  })

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.container_registry.sku)
    error_message = "container_registry.sku must be one of: Basic, Standard, Premium."
  }

  validation {
    condition     = contains(["Public", "Restricted", "Private"], var.container_registry.network_access)
    error_message = "container_registry.network_access must be one of: Public, Restricted, Private."
  }
}
