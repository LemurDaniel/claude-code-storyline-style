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
- **One module is one book:** every module is a single file `module.<name>.bicep`, the name says what it deploys. Modules are grouped by category in `modules/<category>/` (`container/`, `data/`, `network/`), a category with more than one module has a `README.md` listing them. `main.bicep` is the entry point and calls the modules, `main.<env>.bicepparam` holds the values per environment and is the test deployment at the same time.
  ```
  main.bicep
  main.dev.bicepparam
  main.prod.bicepparam
  modules/
    container/
      module.registry.bicep
    data/
      README.md
      module.storage.bicep
      module.postgres.bicep
    utility/
      lib.bicep
  ```
  Not like this: one folder per module with a `module.bicep` and an `example/` folder, so every open tab is called `module.bicep`.
- **Chapters and sections exactly as in `SKILL.md` → "Comments" and "The story"**, nothing Bicep specific. In a module the plot order reads: parameters → validations → deployment → outputs.
  ```bicep
  // ---------------------------------------------------------------------------
  // Parameters

  param naming typeNaming
  param sku 'Premium' | 'Standard' | 'Basic' = 'Standard'

  // ---------------------------------------------------------------------------
  // Validations

  ...
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
- `main.<env>.bicepparam` with `using 'main.bicep'`, only the values that differ from the defaults, a `// NOTE:` comment on values that need permissions or prerequisites.
  ```bicep
  using 'main.bicep'

  param storageSku = 'Standard_ZRS'

  // NOTE: Ranges in CIDR notation, the deploying agent must be inside one of them to push images.
  param registryIpRules = ['<OFFICE_IP_RANGE>']
  ```
- **Verify** per `SKILL.md` → "Errors, logging, tests": `bicep build` per template and `bicep build-params` per `.bicepparam`, no linter warning left.
  ```
  bicep build main.bicep --stdout
  bicep build-params main.dev.bicepparam --stdout
  ```
