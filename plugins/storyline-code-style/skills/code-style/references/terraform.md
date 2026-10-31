# Code Style: Terraform
- 2 spaces, `terraform fmt` compliant.
- Split files by kind: `providers.tf`, `backend.tf`, `variables.tf`, `outputs.tf` and `locals.<topic>.tf`. Resources directly in the module go into `main.<topic>.tf`, module calls into `module.<domain>.tf`, related calls of one domain in the same file.
  ```
  backend.tf
  providers.tf
  variables.tf
  outputs.tf
  locals.naming.tf
  locals.tags.tf
  module.networking.tf
  module.monitoring.tf
  main.search.tf.disabled
  ```
- Modules live under `modules/<domain>/<module>/`.
- **The module is the book, every `.tf` file is one chapter.** Each file starts with a chapter banner and description (`SKILL.md` → "Comments"): a flow chapter with numbered sections for `locals.*.tf` and `main.*.tf` with several phases, a collection chapter for `variables.tf` and `outputs.tf`. The description of `main.*.tf` names the locals it uses by their chapter (`resolved in RESOLVE REGISTRY SETTINGS (locals.registry.tf)`).
  ```hcl
  # ===========================================================================
  # ======================   RESOLVE REGISTRY SETTINGS   ======================
  # ===========================================================================
  #
  #   1. Name   Takes the configured name or generates one from the naming context.
  #   2. SKU    Raises the SKU to Premium for private access, derives retention.
  #

  # ---------------------------------------------------------------------------
  # Name
  ```
- Config per environment as `env/<env>.tfvars`, with a chapter banner and description at the top (`SKILL.md` → "Comments") and one comment per block. Run with `terraform plan -var-file=env/dev.tfvars`.
  ```hcl
  # ===========================================================================
  # ======================   CONTAINER REGISTRY - DEV   =======================
  # ===========================================================================
  #
  #   Standard SKU without geo-replication, short retention for dev.
  #

  container_registry = {
    # Standard is enough for dev, no geo-replication needed.
    sku = "Standard"

    # Keep untagged manifests for one week.
    retention_policy = {
      days = 7
    }
  }
  ```
- The main resource of a module is called `main`, module calls carry telling names (`networking_vnet`).
  ```hcl
  resource "azurerm_virtual_network" "main" { ... }

  module "networking_vnet" { ... }
  ```
- **One configuration object per resource** instead of many single variables. Defaults sit directly in the type with `optional(type, default)`:
  ```hcl
  variable "container_registry" {
    nullable    = false
    description = "(Required) The configuration for the container registry."
    type = object({
      name          = optional(string)
      sku           = optional(string, "Standard")
      admin_enabled = optional(bool, false)

      retention_policy = optional(object({
        enabled = optional(bool, true)
        days    = number
      }), { enabled = true, days = 7 })
    })
  }
  ```
- Variables have a `description` (starting with `(Required)` or `(Optional)`), an explicit `type` and `nullable`.
  ```hcl
  variable "location" {
    nullable    = false
    description = "(Optional) The Azure region. Defaults to 'westeurope'."
    type        = string
    default     = "westeurope"
  }
  ```
- **Context as an object:** `resource_group_reference` (id, name, location, tags, naming) is passed from module to module. The RG module returns itself as an output for that.
  ```hcl
  # modules/resourceGroup/outputs.tf
  output "reference" {
    description = "Reference for dependent modules (id, name, location, tags, naming)."
    value = {
      id       = azurerm_resource_group.main.id
      name     = azurerm_resource_group.main.name
      location = azurerm_resource_group.main.location
      tags     = azurerm_resource_group.main.tags
      naming   = local.naming
    }
  }
  ```
- Resource blocks are split into groups inside, with a group comment per `SKILL.md` → "Comments":
  ```hcl
  resource "azurerm_container_registry" "main" {
    # General resource attributes
    name                = ...
    resource_group_name = var.resource_group_reference.name
    tags                = merge(var.resource_group_reference.tags, var.container_registry.tags)

    # Resource specific attributes
    sku = var.container_registry.sku
  }
  ```
- Break longer ternaries in parentheses onto their own lines.
  ```hcl
  sku = (
    var.container_registry.network_access == "Private"
    ? "Premium"
    : var.container_registry.sku
  )
  ```
  Not like this: `cond ? true : false`, the condition already is the bool (`public_network_access_enabled = var.container_registry.network_access == "Public"`).
- `for_each` over maps with a telling key (`token.token_name => …`), not over list indices.
  ```hcl
  resource "azurerm_container_registry_token" "main" {
    for_each = {
      for token in var.container_registry.tokens : token.token_name => token
    }

    name = each.key
    ...
  }
  ```
  Not like this: `count = length(var.tokens)` with `var.tokens[count.index]`
- Validation via `validation` in the variable or `lifecycle { precondition }` with a clear `error_message`.
  ```hcl
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.container_registry.sku)
    error_message = "container_registry.sku must be one of: Basic, Standard, Premium."
  }

  lifecycle {
    precondition {
      condition     = var.container_registry.sku == "Premium" || length(var.container_registry.ip_rules) == 0
      error_message = "IP rules require container_registry.sku = 'Premium'."
    }
  }
  ```
- Secrets in outputs with `sensitive = true`. Outputs get a `description`.
  ```hcl
  output "admin_password" {
    description = "The admin password of the registry, only set when admin_enabled is true."
    value       = azurerm_container_registry.main.admin_password
    sensitive   = true
  }
  ```
- Logic belongs in `locals`, split into named stages. `/* */` above the block explains the flow, `#` goes per line.
  ```hcl
  /*
    Flattens all subnets of all vnets into one map keyed by '<vnet>/<subnet>',
    so every subnet can be created with a single for_each.
  */
  locals {
    subnets_nested    = [for vnet in var.vnets : [for subnet in vnet.subnets : merge(subnet, { vnet = vnet.name })]]
    subnets_flattened = flatten(local.subnets_nested)
    subnets_by_key    = { for subnet in local.subnets_flattened : "${subnet.vnet}/${subnet.name}" => subnet }
  }
  ```
- Fallbacks via `coalesce([...]...)` with one comment per step (see `SKILL.md` → "Processing data").
- Shared values like `tags` and naming run once through `locals` or a naming module.
  ```hcl
  locals {
    tags = merge(var.tags, {
      environment = var.environment
      managed_by  = "terraform"
    })
  }

  module "naming_vnet" {
    source = "../../utility/naming"

    resource_type = "azurerm_virtual_network"
    environment   = var.environment
  }
  ```
- Tests as `tests/<topic>.tftest.hcl` with `command = plan` and `assert` on concrete values. Each file is one chapter, its description lists the `run` blocks by name (`SKILL.md` → "Errors, logging, tests"). `mock_provider` keeps the plan free of credentials.
  ```hcl
  # ===========================================================================
  # ===========================   GENERATE NAMES   ============================
  # ===========================================================================
  #
  #   generates_vnet_name   Builds the name from type, location and environment.
  #

  run "generates_vnet_name" {
    command = plan

    assert {
      condition     = output.name == "vnet-euwe-tst-tftest-01"
      error_message = "Generated name is invalid."
    }
  }
  ```
- Pin versions: `required_version` and `required_providers` with a `~>` constraint in `providers.tf`. The `.terraform.lock.hcl` is committed.
  ```hcl
  terraform {
    required_version = "~> 1.9"

    required_providers {
      azurerm = {
        source  = "hashicorp/azurerm"
        version = "~> 4.0"
      }
    }
  }
  ```
- No real subscription IDs or RG names as defaults in scaffolds. The `env/*.tfvars` are committed, so secrets never go in there, they come from Key Vault or `TF_VAR_*`.
  ```hcl
  provider "azurerm" {
    features {}
    subscription_id = "<SUBSCRIPTION_ID>"
  }
  ```
