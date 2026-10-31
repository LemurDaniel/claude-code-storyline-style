/*
  Order of precedence for the registry name:
  - Name from the configuration
  - Name generated from the naming context
*/
locals {
  naming = var.resource_group_reference.naming

  # Registry names only allow lowercase alphanumerics, so the generated name has no dashes.
  name_generated = lower("acr${local.naming.workload}${local.naming.environment}${local.naming.location_short}")
  name_final = coalesce([
    # Name from the configuration
    var.container_registry.name,
    # Name generated from the naming context
    local.name_generated,
  ]...)
}

/*
  Derives the SKU dependent settings, Premium unlocks private access and retention.
*/
locals {
  # Private access needs Premium, so the SKU is raised automatically.
  sku_final = (
    var.container_registry.network_access == "Private"
    ? "Premium"
    : var.container_registry.sku
  )
  is_premium = local.sku_final == "Premium"

  # Retention only exists on Premium.
  retention_days = (
    local.is_premium && var.container_registry.retention_policy.enabled
    ? var.container_registry.retention_policy.days
    : null
  )
}
