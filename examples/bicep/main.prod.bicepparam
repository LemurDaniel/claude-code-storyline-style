using 'main.bicep'

param naming = {
  environment: 'prd'
  locationShort: 'euwe'
  workload: 'sample'
}

param tags = {
  environment: 'prd'
}

// NOTE: Ranges in CIDR notation, the deploying agent must be inside one of them to push images.
param registryIpRules = [
  '<OFFICE_IP_RANGE>'
  '<BUILD_AGENT_IP_RANGE>'
]

param storageSku = 'Standard_ZRS'

param databaseSku = {
  tier: 'GeneralPurpose'
  name: 'Standard_D2ds_v5'
}
