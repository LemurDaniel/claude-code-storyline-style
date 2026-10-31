# ===========================================================================
# =======================   TEST REGISTRY SETTINGS   ========================
# ===========================================================================
#
#   generates_name_from_context   Builds the name from workload, environment
#                                 and region when none is configured.
#   raises_sku_for_private        Private access raises the SKU to Premium.
#   rejects_ip_rules_on_public    IP rules fail the plan without Restricted.
#

mock_provider "azurerm" {}

variables {
  resource_group_reference = {
    id       = "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-sample-dev"
    name     = "rg-sample-dev"
    location = "westeurope"
    tags     = {}
    naming = {
      environment    = "dev"
      location_short = "euwe"
      workload       = "sample"
    }
  }
  container_registry = {}
}

run "generates_name_from_context" {
  command = plan

  assert {
    condition     = azurerm_container_registry.main.name == "acrsampledeveuwe"
    error_message = "Generated registry name is invalid."
  }
}

run "raises_sku_for_private" {
  command = plan

  variables {
    container_registry = {
      network_access = "Private"
    }
  }

  assert {
    condition     = azurerm_container_registry.main.sku == "Premium"
    error_message = "Private access must raise the SKU to Premium."
  }
}

run "rejects_ip_rules_on_public" {
  command = plan

  variables {
    container_registry = {
      ip_rules = ["203.0.113.0/24"]
    }
  }

  expect_failures = [azurerm_container_registry.main]
}
