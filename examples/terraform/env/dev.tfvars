# NOTE:
#   terraform plan -var-file=env/dev.tfvars
#
#   Chapters:
#     CONTAINER REGISTRY - DEV   Settings of the container registry for dev.

# ===========================================================================
# ======================   CONTAINER REGISTRY - DEV   =======================
# ===========================================================================
#
#   Standard SKU with public access and short retention for dev.
#   Run with: terraform plan -var-file=env/dev.tfvars
#

environment = "dev"
location    = "westeurope"

container_registry = {
  # Standard is enough for dev, no geo-replication or network rules needed.
  sku            = "Standard"
  network_access = "Public"

  # Keep untagged manifests for one week.
  retention_policy = {
    days = 7
  }

  tags = {
    cost_center = "<COST_CENTER>"
  }
}
