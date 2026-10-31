targetScope = 'resourceGroup'

// NOTE:
//   Deploys a Container Registry with networking and retention defaults, called from main.bicep.
//   Requires: the shared lib.bicep with typeNaming and generateName.

//
//   Chapters:
//     DEPLOY CONTAINER REGISTRY   Parameters, validations, the registry and its outputs.
//

import { typeNaming, generateName } from '../utility/lib.bicep'

// ===========================================================================
// ======================   DEPLOY CONTAINER REGISTRY   ======================
// ===========================================================================
//
//   1. Parameters - Naming, Location and Tags   Context passed from module to module.
//   2. Parameters - Container Registry          SKU and network access of the registry.
//   3. Validations                              Fails the deployment on settings that do not fit together.
//   4. Deployment                               The registry with its network rules.
//   5. Outputs                                  Reference and login server for dependent modules.
//

// ---------------------------------------------------------------------------
// Parameters - Naming, Location and Tags
//   Context passed from module to module.
// ---------------------------------------------------------------------------

@description('(Required) Naming context passed from module to module.')
param naming typeNaming

@description('(Optional) The Azure region. Defaults to the location of the resource group.')
param location string = resourceGroup().location

@description('(Optional) Tags for all resources. Defaults to none.')
param tags object = {}

// ---------------------------------------------------------------------------
// Parameters - Container Registry
//   SKU and network access of the registry.
// ---------------------------------------------------------------------------

@description('(Optional) The SKU of the registry. Defaults to Standard, Private access raises it to Premium.')
param sku 'Premium' | 'Standard' | 'Basic' = 'Standard'

@description('(Optional) Network access of the registry. Defaults to public access without IP rules.')
param networking {
  access: 'Public' | 'Restricted' | 'Private'?
  ipRules: string[]?
}?

var paramNetworking = {
  access: networking.?access ?? 'Public'
  ipRules: networking.?ipRules ?? []
}

@description('(Optional) Retention of untagged manifests, Premium only. Defaults to 7 days.')
param retention {
  isEnabled: bool?
  days: int?
}?

var paramRetention = {
  isEnabled: retention.?isEnabled ?? true
  days: retention.?days ?? 7
}

// Private access needs Premium, so the SKU is raised automatically.
var paramSku = paramNetworking.access == 'Private' ? 'Premium' : sku
var varIsPremium = paramSku == 'Premium'

// ---------------------------------------------------------------------------
// Validations
//   Fails the deployment on settings that do not fit together.
// ---------------------------------------------------------------------------

#disable-next-line no-unused-vars
var validation = map(
  [
    {
      details: 'Restricted network access requires sku "Premium".'
      isViolated: paramNetworking.access == 'Restricted' && !varIsPremium
    }
    {
      details: 'IP rules require networking.access "Restricted".'
      isViolated: paramNetworking.access != 'Restricted' && length(paramNetworking.ipRules) > 0
    }
  ],
  err => err.isViolated ? fail('ERROR | ${err.details}') : null
)

// ---------------------------------------------------------------------------
// Deployment
//   The registry with its network rules.
// ---------------------------------------------------------------------------

// Restricted access denies everything except the IP rules.
var varNetworkRuleSet = {
  defaultAction: 'Deny'
  ipRules: map(paramNetworking.ipRules, ipRule => { action: 'Allow', value: ipRule })
}

var varRetentionPolicy = {
  status: paramRetention.isEnabled ? 'enabled' : 'disabled'
  days: paramRetention.days
}

resource resRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: generateName(naming, 'Microsoft.ContainerRegistry/registries')
  location: location
  tags: tags
  sku: {
    name: paramSku
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: paramNetworking.access == 'Private' ? 'Disabled' : 'Enabled'
    networkRuleSet: paramNetworking.access == 'Restricted' ? varNetworkRuleSet : null
    policies: {
      retentionPolicy: varIsPremium ? varRetentionPolicy : null
    }
  }
}

// ---------------------------------------------------------------------------
// Outputs
//   Reference and login server for dependent modules.
// ---------------------------------------------------------------------------

@description('Reference for dependent modules (id, name, location, tags, naming).')
output reference object = {
  id: resRegistry.id
  name: resRegistry.name
  location: resRegistry.location
  tags: resRegistry.tags
  naming: naming
}

@description('The login server of the registry, e.g. for docker login.')
output loginServer string = resRegistry.properties.loginServer
