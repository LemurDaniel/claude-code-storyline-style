# NOTE:
#   Module container-registry, called with a resource group reference and one registry object.
#
#   Chapters:
#     variables.tf         VARIABLES
#     locals.registry.tf   RESOLVE REGISTRY SETTINGS
#     main.tf              DEPLOY CONTAINER REGISTRY
#     outputs.tf           OUTPUTS

# ===========================================================================
# ======================   DEPLOY CONTAINER REGISTRY   ======================
# ===========================================================================
#
#   One registry with the name and SKU resolved in RESOLVE REGISTRY SETTINGS
#   (locals.registry.tf). Restricted access denies everything except the IP
#   rules, the preconditions fail the plan on an invalid combination.
#

resource "azurerm_container_registry" "main" {
  # General resource attributes
  name                = local.name_final
  resource_group_name = var.resource_group_reference.name
  location            = var.resource_group_reference.location
  tags                = merge(var.resource_group_reference.tags, var.container_registry.tags)

  # Resource specific attributes
  sku                           = local.sku_final
  admin_enabled                 = var.container_registry.admin_enabled
  public_network_access_enabled = var.container_registry.network_access != "Private"
  retention_policy_in_days      = local.retention_days

  # Restricted access denies everything except the IP rules.
  dynamic "network_rule_set" {
    for_each = var.container_registry.network_access == "Restricted" ? [var.container_registry.ip_rules] : []

    content {
      default_action = "Deny"

      dynamic "ip_rule" {
        for_each = toset(network_rule_set.value)

        content {
          action   = "Allow"
          ip_range = ip_rule.value
        }
      }
    }
  }

  lifecycle {
    precondition {
      condition     = var.container_registry.network_access != "Restricted" || local.is_premium
      error_message = "container_registry.network_access 'Restricted' requires container_registry.sku = 'Premium'."
    }
    precondition {
      condition     = var.container_registry.network_access == "Restricted" || length(var.container_registry.ip_rules) == 0
      error_message = "container_registry.ip_rules require container_registry.network_access = 'Restricted'."
    }
  }
}
