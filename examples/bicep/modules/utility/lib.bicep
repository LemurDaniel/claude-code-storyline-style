// NOTE:
//   Shared types and functions for all modules, imported per module:
//
//   import { typeNaming, generateName } from '../utility/lib.bicep'

// ---------------------------------------------------------------------------
// Types
//   Shared types, imported by every module.
// ---------------------------------------------------------------------------

@export()
@description('Naming context passed from module to module.')
type typeNaming = {
  environment: 'dev' | 'tst' | 'prd'
  locationShort: string
  workload: string
}

// ---------------------------------------------------------------------------
// Functions - Naming
//   Generates resource names from the naming context.
// ---------------------------------------------------------------------------

// Resource types without dashes in their name (e.g. registries, storage accounts) get a compact name.
var varCompactResourceTypes = [
  'Microsoft.ContainerRegistry/registries'
  'Microsoft.Storage/storageAccounts'
]

@export()
@description('[String] | Generates a resource name from the naming context, e.g. "sample-dev-euwe" or "sampledeveuwe".')
func generateName(naming typeNaming, resourceType string) string => contains(varCompactResourceTypes, resourceType)
  ? toLower('${naming.workload}${naming.environment}${naming.locationShort}')
  : toLower('${naming.workload}-${naming.environment}-${naming.locationShort}')
