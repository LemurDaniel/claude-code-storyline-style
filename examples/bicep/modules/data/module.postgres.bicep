targetScope = 'resourceGroup'

// NOTE:
//   Deploys a PostgreSQL flexible server with Entra ID authentication only, called from main.bicep.
//   Requires: the shared lib.bicep with typeNaming and generateName.

//
//   Chapters:
//     DEPLOY POSTGRESQL SERVER   Parameters, validations, the server and its outputs.
//

import { typeNaming, generateName } from '../utility/lib.bicep'

// ===========================================================================
// ======================   DEPLOY POSTGRESQL SERVER   =======================
// ===========================================================================
//
//   1. Parameters - Naming, Location and Tags   Context passed from module to module.
//   2. Parameters - PostgreSQL                  Compute, storage and version of the server.
//   3. Validations                              Fails the deployment on settings that do not fit together.
//   4. Deployment                               The flexible server.
//   5. Outputs                                  Reference for dependent modules.
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
// Parameters - PostgreSQL
//   Compute, storage and version of the server.
// ---------------------------------------------------------------------------

@description('(Optional) Compute tier and size. Defaults to the smallest burstable size.')
param sku {
  tier: 'Burstable' | 'GeneralPurpose' | 'MemoryOptimized'?
  name: string?
}?

var paramSku = {
  tier: sku.?tier ?? 'Burstable'
  name: sku.?name ?? 'Standard_B1ms'
}

@description('(Optional) Storage of the server in GB. Defaults to 32.')
param storageSizeGB int = 32

@description('(Optional) Major version of PostgreSQL. Defaults to 16.')
param version '14' | '15' | '16' = '16'

// Zone redundant high availability is not offered for burstable servers.
var varIsHighlyAvailable = paramSku.tier != 'Burstable'

// ---------------------------------------------------------------------------
// Validations
//   Fails the deployment on settings that do not fit together.
// ---------------------------------------------------------------------------

#disable-next-line no-unused-vars
var validation = map(
  [
    {
      details: 'storageSizeGB must be at least 32, got ${storageSizeGB}.'
      isViolated: storageSizeGB < 32
    }
  ],
  err => err.isViolated ? fail('ERROR | ${err.details}') : null
)

// ---------------------------------------------------------------------------
// Deployment
//   The flexible server.
// ---------------------------------------------------------------------------

resource resPostgres 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' = {
  name: generateName(naming, 'Microsoft.DBforPostgreSQL/flexibleServers')
  location: location
  tags: tags
  sku: paramSku
  properties: {
    version: version
    storage: {
      storageSizeGB: storageSizeGB
    }
    // Entra ID only, so the module needs no admin login and the server has no local accounts.
    authConfig: {
      activeDirectoryAuth: 'Enabled'
      passwordAuth: 'Disabled'
      tenantId: tenant().tenantId
    }
    highAvailability: {
      mode: varIsHighlyAvailable ? 'ZoneRedundant' : 'Disabled'
    }
  }
}

// ---------------------------------------------------------------------------
// Outputs
//   Reference for dependent modules.
// ---------------------------------------------------------------------------

@description('Reference for dependent modules (id, name, location, tags, naming).')
output reference object = {
  id: resPostgres.id
  name: resPostgres.name
  location: resPostgres.location
  tags: resPostgres.tags
  naming: naming
}

@description('The host name of the server, e.g. for the connection of an app.')
output fqdn string = resPostgres.properties.fullyQualifiedDomainName
