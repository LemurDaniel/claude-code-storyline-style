targetScope = 'resourceGroup'

// NOTE:
//   Deploys a storage account with private blob containers, called from main.bicep.
//   Requires: the shared lib.bicep with typeNaming and generateName.

import { typeNaming, generateName } from '../utility/lib.bicep'

// ---------------------------------------------------------------------------
// Parameters - Naming, Location and Tags

@description('(Required) Naming context passed from module to module.')
param naming typeNaming

@description('(Optional) The Azure region. Defaults to the location of the resource group.')
param location string = resourceGroup().location

@description('(Optional) Tags for all resources. Defaults to none.')
param tags object = {}

// ---------------------------------------------------------------------------
// Parameters - Storage Account

@description('(Optional) Replication of the account. Defaults to Standard_LRS.')
param sku 'Standard_LRS' | 'Standard_ZRS' | 'Standard_GRS' = 'Standard_LRS'

@description('(Optional) Names of the private blob containers. Defaults to none.')
param containerNames string[] = []

// ---------------------------------------------------------------------------
// Deployment

resource resStorageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: generateName(naming, 'Microsoft.Storage/storageAccounts')
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: sku
  }
  properties: {
    // Access only through Entra ID and role assignments, no shared keys and no public blobs.
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource resBlobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: resStorageAccount
  name: 'default'
}

resource resContainers 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = [
  for containerName in containerNames: {
    parent: resBlobService
    name: containerName
  }
]

// ---------------------------------------------------------------------------
// Outputs

@description('Reference for dependent modules (id, name, location, tags, naming).')
output reference object = {
  id: resStorageAccount.id
  name: resStorageAccount.name
  location: resStorageAccount.location
  tags: resStorageAccount.tags
  naming: naming
}

@description('The blob endpoint, e.g. for the connection of an app.')
output blobEndpoint string = resStorageAccount.properties.primaryEndpoints.blob
