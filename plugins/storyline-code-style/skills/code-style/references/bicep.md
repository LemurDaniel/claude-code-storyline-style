# Code Style: Bicep
- 2 spaces. `targetScope` is always explicit in the first line.
  ```bicep
  targetScope = 'resourceGroup'
  ```
- The `bicepconfig.json` in the repo root is the benchmark for the linter. Rules that apply here are set to `error` there.
  ```json
  {
    "analyzers": {
      "core": {
        "rules": {
          "no-unused-params": { "level": "error" },
          "secure-secrets-in-params": { "level": "error" },
          "use-recent-api-versions": { "level": "warning" }
        }
      }
    }
  }
  ```
- Registry modules live under `modules/<category>/<module>/` (`resources`, `patterns`, `utility`) with:
  - `module.bicep` as entry point
  - `version.json` with version, description and `deployment_tests`
  - `example/` with `module.bicep` and `module.bicepparam` for CI test deployments
  ```
  modules/resources/containerRegistry/
    module.bicep
    version.json
    example/
      module.bicep
      module.bicepparam
  ```
  ```json
  {
    "version": "1.2.0",
    "description": "Container Registry with networking and retention defaults.",
    "deployment_tests": ["example/module.bicepparam"]
  }
  ```
- Sections are separated by a `// ----` banner per `SKILL.md` → "Comments", in a fixed order: parameters (naming, location, tags) → parameters (resource) → validations → deployment → outputs. A module with one resource gets by without chapters.
  ```bicep
  // ---------------------------------------------------------------------------
  // Parameters - Naming, Location and Tags
  param naming typeNaming
  param location string = resourceGroup().location
  param tags object = {}

  // ---------------------------------------------------------------------------
  // Parameters - Container Registry
  param sku 'Premium' | 'Standard' | 'Basic' = 'Standard'

  // ---------------------------------------------------------------------------
  // Validations
  ...

  // ---------------------------------------------------------------------------
  // Deployment
  resource resRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = { ... }

  // ---------------------------------------------------------------------------
  // Outputs
  output id string = resRegistry.id
  ```
- **Typed object parameters with optional fields.** A `param*` variable then normalizes the defaults:
  ```bicep
  param networking {
    access: 'Public' | 'Restricted' | 'Private'?
    bypass: 'AzureServices' | 'None'?
    ipRules: string[]?
  }?

  var paramNetworking = {
    access: networking.?access ?? 'Public'
    bypass: networking.?bypass ?? 'AzureServices'
    ipRules: networking.?ipRules ?? []
  }
  ```
- Union types instead of `@allowed` (`'Premium' | 'Standard' | 'Basic'`), `.?` and `??` instead of `contains()` chains.
  ```bicep
  param sku 'Premium' | 'Standard' | 'Basic' = 'Standard'
  var retentionDays = retention.?days ?? 7
  ```
  Not like this:
  ```bicep
  @allowed(['Premium', 'Standard', 'Basic'])
  param sku string = 'Standard'
  var retentionDays = contains(retention, 'days') ? retention.days : 7
  ```
- Prefixes: `res` for resources (`resRegistry`), `param` for normalized parameters, `var` for derived settings (`varAppliedSettings`), `type` for types (`typeNaming`).
  ```bicep
  resource resRegistry '...' = { ... }
  var paramRetention = { days: retention.?days ?? 7 }
  var varIsPremium = paramSku == 'Premium'
  ```
- **Validations grouped** as a list with `fail()`:
  ```bicep
  #disable-next-line no-unused-vars
  var validation = map(
    [
      {
        details: 'IP rules require sku "Premium".'
        isViolated: paramSku != 'Premium' && length(paramNetworking.ipRules) > 0
      }
    ],
    err => err.isViolated ? fail('ERROR | ${err.details}') : null
  )
  ```
- Reusable logic as `@export() func`. Long functions go into their own file (`func.<name>.bicep`) and are exported through a slim wrapper. Types as `@export() type`.
  ```bicep
  // lib.bicep
  import { generateName as _generateName } from 'func.generateName.bicep'

  @export()
  @description('[String] | Generates a resource name from the naming pattern.')
  func generateName(naming typeNaming, resourceType string) string => _generateName(naming, resourceType)

  @export()
  @description('Naming context passed from module to module.')
  type typeNaming = {
    environment: 'dev' | 'tst' | 'prd'
    locationShort: string
    workload: string
  }
  ```
- Every `@export()` has a `@description`. In function families the return type comes first: `'[String] | …'`.
- Overloads become a family with a suffix (`switch`, `switchStr`, `switchInt`, `switchArr`, `…Fail`), all delegating to one core function.
  ```bicep
  @export()
  @description('[Any] | Returns the value of the first matching case or the default.')
  func switch(value string, cases object, default any) any => cases[?value] ?? default

  @export()
  @description('[String] | Typed variant of switch.')
  func switchStr(value string, cases object, default string) string => string(switch(value, cases, default))

  @export()
  @description('[Int] | Typed variant of switch.')
  func switchInt(value string, cases object, default int) int => int(switch(value, cases, default))
  ```
- Outputs return a reference for dependent modules (`id`, `name`, `location`, `tags`, `naming`, `reference`).
  ```bicep
  output reference object = {
    id: resRegistry.id
    name: resRegistry.name
    location: resRegistry.location
    tags: resRegistry.tags
    naming: naming
  }
  ```
- `.bicepparam` with `using`, a `// NOTE:` comment on values that need permissions or prerequisites.
  ```bicep
  using 'module.bicep'

  param sku = 'Premium'

  // NOTE: The deploying identity needs 'User Access Administrator' to assign AcrPull.
  param pullPrincipalIds = ['<PRINCIPAL_ID>']
  ```
- Deployment scripts in PowerShell (`.scripts/Invoke-*Deployment.ps1`). Versioning and CI publish run via `version.json`.
  ```powershell
  ./.scripts/Invoke-BicepDeployment.ps1 -Module resources/containerRegistry -Environment dev -WhatIf
  ```
