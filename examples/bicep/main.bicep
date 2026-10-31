targetScope = 'resourceGroup'

// NOTE:
//   Deploys the registry, the storage account and the database of the sample workload.
//   The values per environment come from main.<env>.bicepparam.
//
//   az deployment group create -g rg-sample-dev -f main.bicep -p main.dev.bicepparam --what-if

//
//   Chapters:
//     DEPLOY SAMPLE WORKLOAD   Parameters, the module calls and the outputs.
//

import { typeNaming } from 'modules/utility/lib.bicep'

// ===========================================================================
// =======================   DEPLOY SAMPLE WORKLOAD   ========================
// ===========================================================================
//
//   1. Parameters               Naming context and tags passed to every module.
//   2. Deployment - Container   Deploys the container registry.
//   3. Deployment - Data        Deploys the storage account and the PostgreSQL server.
//   4. Outputs                  Endpoints of the deployed resources.
//

// ---------------------------------------------------------------------------
// Parameters
//   Naming context and tags passed to every module.
// ---------------------------------------------------------------------------

@description('(Required) Naming context of the environment.')
param naming typeNaming

@description('(Optional) Tags for all resources. Defaults to none.')
param tags object = {}

@description('(Optional) IP ranges that may reach the registry. Defaults to none, the registry stays public.')
param registryIpRules string[] = []

@description('(Optional) Replication of the storage account. Defaults to Standard_LRS.')
param storageSku 'Standard_LRS' | 'Standard_ZRS' | 'Standard_GRS' = 'Standard_LRS'

@description('(Optional) Compute tier and size of the database. Defaults to the smallest burstable size.')
param databaseSku {
  tier: 'Burstable' | 'GeneralPurpose' | 'MemoryOptimized'?
  name: string?
}?

// ---------------------------------------------------------------------------
// Deployment - Container
//   Deploys the container registry.
// ---------------------------------------------------------------------------

module registry 'modules/container/module.registry.bicep' = {
  name: 'registry'
  params: {
    naming: naming
    tags: tags
    // IP rules only take effect with restricted access, which needs Premium.
    sku: empty(registryIpRules) ? 'Standard' : 'Premium'
    networking: {
      access: empty(registryIpRules) ? 'Public' : 'Restricted'
      ipRules: registryIpRules
    }
  }
}

// ---------------------------------------------------------------------------
// Deployment - Data
//   Deploys the storage account and the PostgreSQL server.
// ---------------------------------------------------------------------------

module storage 'modules/data/module.storage.bicep' = {
  name: 'storage'
  params: {
    naming: naming
    tags: tags
    sku: storageSku
    containerNames: [
      'imports'
      'exports'
    ]
  }
}

module postgres 'modules/data/module.postgres.bicep' = {
  name: 'postgres'
  params: {
    naming: naming
    tags: tags
    sku: databaseSku
  }
}

// ---------------------------------------------------------------------------
// Outputs
//   Endpoints of the deployed resources.
// ---------------------------------------------------------------------------

@description('The login server of the registry, e.g. for docker login.')
output registryLoginServer string = registry.outputs.loginServer

@description('The blob endpoint of the storage account.')
output storageBlobEndpoint string = storage.outputs.blobEndpoint

@description('The host name of the database server.')
output postgresFqdn string = postgres.outputs.fqdn
