---
name: code-style
description: Storyline code style for every language and codebase - file headers, chapter/section banners, guard clauses, naming, docs, error handling, logging, file naming. Load BEFORE writing, editing or reviewing code or IaC in any language (PowerShell, Terraform, Bicep, YAML pipelines for GitHub Actions / Azure DevOps, Docker Compose, JavaScript / Node.js, C++), even for a small fix or a single new function, and before /code-review or /simplify. Triggers on "code style", "style guide", "banner", "comments", "naming", "review", "clean up", "refactor".
---

# Code Style

Applies to every language and every codebase. Write code so it reads top to bottom like a story.
When a codebase has its own conventions, they win. The rules here only fill the gaps.

## Scope
- **New and changed code** always follows these rules.
- **A bug fix or feature stays focused:** untouched code around it is not restyled on the side.
- **Refactoring, clean-up and review** put existing code in scope. Before restructuring beyond the requested part (adding chapters, renaming, splitting or moving files), ask the user how far to go:
  - only the touched function or block
  - the whole file
  - the whole module or folder
- When unsure whether a task counts as refactoring, ask instead of assuming.

## Language-specific rules
Before writing or reviewing code in one of these languages, read the matching file from `references/` next to this file with the Read tool (once per session is enough):

| Language | File |
| --- | --- |
| PowerShell | `references/powershell.md` |
| Terraform | `references/terraform.md` |
| Bicep | `references/bicep.md` |
| YAML pipelines (GitHub Actions / Azure DevOps) | `references/yaml-pipelines.md` |
| Docker Compose | `references/docker-compose.md` |
| C++ | `references/cpp.md` |
| JavaScript / Node.js | `references/javascript.md` |

For other languages only the general rules below apply, plus the language's own conventions.

# General

## The story
A codebase is a library, a folder is a shelf, a file is a book. Every rule below gives one part of the library its place in the code:

| Library | Code | Form |
| --- | --- | --- |
| Library | Codebase | README at the entrance, see [Structure](#structure) |
| Shelf | Folder, cut by domain | Every shelf with more than one book has a label, see below |
| Shelf label | Entry point or folder README | `_index.js`, `Utils.psm1`, `main.tf`, `module.bicep`, else `README.md` |
| Call number | File name `<kind>.<topic>[.<variant>]` | Sorts the books on the shelf, see [Structure](#structure) |
| Book | File | Header, chapters, epilogue |
| Blurb | File header | Usage and prerequisites, see [Reading flow](#reading-flow) |
| Table of contents | Chapter list in the header | Only in files with three or more chapters |
| Chapter | Chapter | Three lines of `=`, title in UPPERCASE, see [Comments](#comments) |
| Chapter intro | Chapter description | Numbered steps or one entry per unit, right below the frame |
| Section | Section | One line of `-`, title below |
| Paragraph | Group comment | One comment line inside a unit, no banner |
| Epilogue | Cleanup | Context reset, outputs, exports: always the last chapter or section |

There are exactly three levels inside a book: chapter, section, group comment. No fourth banner level, sub-chapters are sections.

- **The book is the file**, except where the language loads a folder as one unit (a Terraform module). Then the folder is the book and every file one chapter, see `references/terraform.md`.
- **Every shelf has a label:** A folder with more than one file has an entry point where the language has one (`_index.js`, `Utils.psm1`, `main.tf`, `module.bicep`, the thin pipeline that calls the templates, the header of a `.cpp`). Where it has none, a short `README.md` in the folder lists the files with one line each. Whoever opens the folder knows what stands on the shelf without opening a book.
  ```markdown
  # PowerShell examples
  | File | Content |
  | --- | --- |
  | `Get-UtilsConfig.ps1` | One function with sections only: defaults, read, merge. |
  | `Move-KeyVaultSecret.ps1` | A script with chapters, WhatIf and a CLEAN block. |
  ```

- **When a file gets chapters:** as soon as it tells more than one phase (load, validate, write) or holds more than one kind of unit (helpers plus a main flow). A file with a single phase or a single unit gets by with sections (a Bicep module, `Get-UtilsConfig.ps1`), a tiny file with none (a `.bicepparam`).
- **Chapter order follows the plot:** setup (settings, helpers, context) → validations → the action → epilogue (cleanup, outputs, exports). Helpers either come first as a collection chapter, so the reader meets them before they act, or live in their own file. Never between two steps of the action.
- **No character without an introduction:** a variable, constant or config value is declared in the chapter where it first acts, right before its first use. Not collected at the top of the file and not in a later chapter.
  ```powershell
  # ---------------------------------------------------------------------------
  # Secrets

  $Secrets = Get-AzKeyVaultSecret -VaultName $Source
  | Where-Object -Property Enabled -EQ -Value $true

  $MovedCount   = 0     # counted while moving, reported at the end
  $SkippedCount = 0
  ```

## Reading flow
- **File header with usage and prerequisites:** Whoever opens the file sees at the top how to call it and what has to exist first.
  ```js
  // NOTE:
  //  node .\day09-part1.js [INPUT|TEST]
  //
  //    'node .\day09-part1.js INPUT'   to process today's input from 'day09-input.txt'.
  //    'node .\day09-part1.js TEST'    to process today's test input from 'day09-input-test.txt'.
  ```
  ```powershell
  # NOTE:
  #   Requires: Az.Accounts, Az.KeyVault and a logged in context (Connect-AzAccount).
  #
  #   ./Move-KeyVaultSecret.ps1 -Source kv-old -Target kv-new -WhatIf
  ```
- **Table of contents in the header:** A file with three or more chapters lists them at the end of the header, in file order, with the exact chapter title on the left and one line on the right. The banner check compares the list with the chapters.
  ```cpp
  // NOTE:
  //   Implementation of MiniServer.h.
  //
  //   Chapters:
  //     HELPERS      Status codes and the prefix check.
  //     LIFECYCLE    begin and stop.
  //     ROUTING      Route registration and request handling.
  //     MIDDLEWARE   Middleware registration.
  ```
- **Concept before code:** For algorithms, data structures or unfamiliar mechanisms a short explanation comes first, then the implementation.
  ```js
  // A heap is a binary tree like structure that stores the min (or max) value as root node.
  // Insertion:
  //      Every new value gets inserted at the bottom, then traversed up to its correct spot.
  // Each node can be found via:
  //      - Parent     = (childIndex - 1) / 2
  //      - LeftChild  = parentIndex * 2 + 1
  //      - RightChild = parentIndex * 2 + 2
  class BaseHeap { ... }
  ```
- **Describe first, then implement:** Non-trivial sections start with a block comment holding the decision tree. The code below follows it 1:1.
  ```
  > When the file does NOT exist
      - If cloud data exists, create the local file.
      - Otherwise, do nothing.
  > When the file exists
      - Skip if the last sync is inside the interval.
      - Otherwise upload when no cloud data exists.
  ```
  ```powershell
  # When the file does NOT exist
  if (-NOT (Test-Path -Path $FilePath)) {
      # If cloud data exists, create the local file.
      if ($null -NE $cloudData) {
          $null = Set-Content -Path $FilePath -Value $cloudData
      }
      # Otherwise, do nothing.
      return
  }

  # When the file exists
  # Skip if the last sync is inside the interval.
  if ($lastSync.AddSeconds($Interval) -GT [System.DateTime]::Now) {
      return
  }
  ...
  ```
- **Split files into chapters:** Chapter and section banners structure the file, the format is described under [Comments](#comments), when and in which order under [The story](#the-story).
- **Flat main path:** Guard clauses and early `return` instead of nesting.
  ```js
  if (!user) return
  if (!user.isActive) return

  sendMail(user)
  ```
  Not like this:
  ```js
  if (user) {
      if (user.isActive) {
          sendMail(user)
      }
  }
  ```
- **What belongs together stays together:** State, configuration and functions of a feature sit next to each other, not sorted by visibility or type.
  ```js
  // Cache
  #cache = new Map()
  #cacheTimeout = CACHE_TIMEOUT_MS
  getCached(key) { ... }
  clearCache() { ... }

  // Projects
  #projects = null
  get projects() { ... }
  async reloadProjects() { ... }
  ```

## Comments
Comments look the same in every language, only the comment character changes. A language file may restrict the format (e.g. sections only), but never introduce its own banner style.

| Comment character | Languages |
| --- | --- |
| `//` | JavaScript / Node.js, C++, Bicep |
| `#` | PowerShell, Terraform, YAML, Docker Compose |

- **Two levels of banners:**
  - **Chapter:** three lines of `=`. The title sits in UPPERCASE centered in the middle line, with 3 spaces on each side.
  - **Chapter titles describe the content**, short and as an activity (`RENDER PINNED REPOS AS CARDS`, `SOLVE TREE PUZZLE`). Not generic like `MAIN` or `CODE`. Collection chapters may be called `HELPERS` or `SETTINGS`.
  - **Section** inside a chapter: one line of `-`, the title below it in normal case.
  - Every line is 75 characters long, plus the comment character and one space.
  - A chapter without sections is fine. Small files (a Bicep module, a Compose file) get by with sections alone.
  - No other banner styles, so no `/* #### */` boxes, `<# #### #>` blocks, `/*---- * Title *` blocks, `////` or `#####` lines.
  - YAML pipelines and Docker Compose only use the section level.
- **Group comments inside a unit:** Inside a class, resource block or parameter list there are no banners. A single comment line in normal case above the group structures it (`# General resource attributes`, `// Get Index`).
- **Block comment syntax** (`/* */`, `/** */`, `<# #>`) is only for doc comments and multi-line explanations above a block, never for banners.
- **Chapter description:** Every chapter has one. Right below the frame it says what happens in the chapter. Empty comment lines above and below set it apart.
  - In **flow chapters** the steps are numbered. The section name is on the left, exactly as in the section banner, a one-line explanation on the right, columns aligned. Continuation lines indent to the explanation column. The banner check compares the numbered names with the sections of the chapter.
  - In **collection chapters** (helpers, settings) there is one entry per function or section, without numbers.
  - Something that applies to all steps (e.g. "files are only written on change") goes into its own paragraph below.
- **Block comments:** A short comment per block says *what* it does. The *why* only appears where it is not obvious.
- **Cross-references name the chapter:** When a block depends on or undoes something from another chapter, the comment says which one, with the chapter title as written in its banner (`# Restores the context switched in LOAD AND VALIDATE SECRETS.`). Across files the file name comes first (`// see MiniServer.h, group Routing`).

```js
// ===========================================================================
// ===============================   HELPERS   ===============================
// ===========================================================================
//
//   parseGrid        Turns the raw input into a grid of tree heights.
//   getViewingLine   Collects the trees from one tree to the edge.
//

function parseGrid(input) { ... }
function getViewingLine(grid, x, y, direction) { ... }

// ===========================================================================
// ==========================   SOLVE TREE PUZZLE   ==========================
// ===========================================================================
//
//   1. Parse input   Reads today's input file into a grid.
//   2. Part 1        Counts the trees visible from outside the grid.
//   3. Part 2        Finds the highest scenic score of a single tree.
//                    Ties are resolved by the first tree found.
//

// ---------------------------------------------------------------------------
// Parse input

// Split the input into one grid row per line.
const grid = parseGrid(fs.readFileSync(INPUT_FILE, 'utf-8'))

// ---------------------------------------------------------------------------
// Part 1

const visibleTrees = countVisibleTrees(grid)
```

```powershell
# ===========================================================================
# ======================   LOAD AND VALIDATE CONFIG   =======================
# ===========================================================================
#
#   1. Config        Loads the owner and resolves the GitHub token.
#   2. Validations   Fails early on a missing owner or token.
#

# ---------------------------------------------------------------------------
# Config

$Config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
```

## Structure
- **One thing per file or unit.** The file name matches the main content, folders are cut by domain.
  ```
  Utils/
    Config/
      Get-UtilsConfig.ps1
      Set-UtilsConfig.ps1
    CloudSync/
      Sync-UtilsCloudFile.ps1
  ```
- **File names as a dotted hierarchy** `<kind>.<topic>[.<variant>].<ext>`, so they group themselves in the explorer.
  The kind comes first even when the folder already names it (`routes/routes.status.js`). That keeps the file name
  unique, also in an editor tab or a search. Plural when a file bundles several units (`routes.`,
  `tools.`), singular for one unit per file (`command.`, `main.`), consistent within a folder. Exceptions:
  - entry points (`_index.js`, `main.tf`, `module.bicep`, `Utils.psm1`)
  - files whose name a tool expects (`docker-compose.yaml`, `package.json`, `.clang-format`)
  - languages with their own naming convention (PowerShell `Verb-Noun.ps1`, C++ class names)
  - exceptions named in a language file (e.g. `utils/` and `data/` in JavaScript)
  ```
  main.vnet.tf             locals.generate.tf       locals.pattern.tf
  deploy.infra.dev.yaml    deploy.infra.prod.yaml   tmpl.bicep.infra.deploy.yaml
  config.nginx-reverse-proxy.yaml   service.nginx-reverse-proxy.yaml
  routes.status.js         tools.zfs.js             command.repository.download.js
  ```
- **Disable instead of delete:** What should temporarily not load gets a suffix or prefix (`main.search.tf.disabled`, `#Get-UtilsCacheFile.ps1`).
- **Templates with placeholders** for recurring files (`tmpl.*`, `blueprint.js` with `${{DAY}}`).
  ```js
  // blueprint.js
  const input = fs.readFileSync(`day${{DAY}}-input.txt`, 'utf-8')
  ```
- **One entry point per library** that bundles and exports the modules.
  ```powershell
  # Utils.psm1
  . $PSScriptRoot/Config/Get-UtilsConfig.ps1
  . $PSScriptRoot/Config/Set-UtilsConfig.ps1
  . $PSScriptRoot/CloudSync/Sync-UtilsCloudFile.ps1
  ```
- **One real implementation:** Overloads, shortcuts and wrappers only delegate to it.
  ```cpp
  void MiniServer::get(const std::string &path, const RequestHandler &handler) { addRoute("GET", path, handler); }
  void MiniServer::use(const RequestHandler &handler)                          { use("/", handler); }
  ```
- **No duplicated logic:** Repeated blocks move into a helper.
  ```js
  // Instead of building the same URL in three places:
  function getApiUrl({ organization, project, api }) {
      return `https://dev.azure.com/${organization}/${project}/_apis/${api}?api-version=${API_VERSION}`
  }
  ```
- **Explicit over magic:** Imports and registrations are written out, types are unambiguous, magic numbers are named constants.
  ```js
  const MAX_LIFETIME_EXTENSION_DAYS = 14

  if (extension > MAX_LIFETIME_EXTENSION_DAYS) return
  ```
  Not like this: `if (extension > 14) return`
- **Data in a file or variable, not in logic:** Long lists (IP ranges, mappings) and concrete environment values are not hard-coded. Scaffolds contain placeholders instead of real names.
  ```hcl
  locals {
    allowed_ip_ranges = yamldecode(file("${path.module}/data/allowed-ip-ranges.yaml"))
  }

  variable "subscription_id" {
    description = "(Required) The subscription to deploy into, e.g. '<SUBSCRIPTION_ID>'."
    type        = string
  }
  ```
- **Reused parameter sets** are bundled once as an object or config instead of being written out several times.
  ```powershell
  $UploadConfig = @{
      Container = 'backups'
      Context   = $storageContext
      Force     = $true
  }

  Set-AzStorageBlobContent @UploadConfig -File $keepassFile -Blob 'keepass.kdbx'
  Set-AzStorageBlobContent @UploadConfig -File $keyFile     -Blob 'keepass.key'
  ```
- **Pass a context object:** A parent module hands down a reference (name, location, tags, naming) as one object instead of five single values.
  ```hcl
  module "storage_account" {
    source = "./modules/storage/storage-account"

    resource_group_reference = module.resource_group.reference
    storage_account          = { sku = "Standard_LRS" }
  }
  ```
- **Configuration separate from code:** Environment-dependent values live in config files per environment (`env/<env>.tfvars`, `*.bicepparam`). The code is the same for all environments.
  ```
  env/
    dev.tfvars
    prd.tfvars
  modules/networking/vnet/
  main.tf
  ```

## Processing data
- **Fallback chains as a list with one comment per step.** The order of precedence goes above, one line per step below.
  ```hcl
  /*
    Order of precedence:
    - Match to <resourceType>.<id>
    - Match to <resourceType>.<kind>
    - Match to default
    - Fail with an error, if no pattern is found
  */
  pattern_selected = coalesce([
    # Match to <resourceType>.<id>
    lookup(lookup(local.patterns_provider, local.resource.type, {}), var.naming_id, null),
    # Match to <resourceType>.<kind>
    lookup(lookup(local.patterns_provider, local.resource.type, {}), local.resource.kind, null),
    # Match to default
    lookup(local.patterns_provider, "default", null),
  ]...)
  ```
  ```powershell
  # Order of precedence: parameter > environment variable > config file > default
  $region = @(
      $Region                         # parameter
      $env:UTILS_REGION               # environment variable
      (Get-UtilsConfig).Region        # config file
      'westeurope'                    # default
  ) | Where-Object { -NOT [System.String]::IsNullOrEmpty($_) } | Select-Object -First 1
  ```
- **Transform in named stages:** Every step gets its own name that says what it delivers. No monster expression, no names like `_2`.
  ```hcl
  pattern_compacted  = ...   # raw pattern split into components
  pattern_components = ...   # components with metadata (isRequired, isParameter)
  name_generated     = ...   # components resolved to values
  name_formatted     = ...   # values formatted per index
  name_final         = ...   # joined and lower-cased
  ```
  ```js
  const lines       = input.split('\n')
  const elfCalories = lines.join(',').split(',,').map(group => group.split(',').map(Number))
  const elfTotals   = elfCalories.map(calories => calories.reduce((a, b) => a + b, 0))
  const maxCalories = Math.max(...elfTotals)
  ```

## API and naming
- **Build for the caller:** short, telling entry points, sensible defaults and autocompletion where the language supports it.
  ```powershell
  # The caller only has to name the profile, everything else has a default and completes via TAB.
  Sync-UtilsCloudFile -ProfileName keepass
  ```
- Verbs first, domain as prefix or namespace (`Get-UtilsConfig`, `Http::Router`).
- Booleans carry an `is`/`has` prefix and the real bool type.
  ```js
  const isActive = true          // not: const active = 'yes'
  const hasChildren = node.children.length > 0
  ```
- Constants in `UPPER_SNAKE`, otherwise the language convention applies. Casing stays consistent within a file.
  ```js
  const API_VERSION = '7.1'
  const DEFAULT_TIMEOUT_MS = 30000
  ```
- `null` goes on the left in comparisons (`$null -EQ $x`, `null == node`). In PowerShell this is mandatory, because `$array -EQ $null` filters instead of comparing. Other literals go on the right (`$status -EQ 'Completed'`).
  ```powershell
  if ($null -EQ $Subscription) { ... }   # not: if ($Subscription -EQ $null)
  ```
- Comments and identifiers in English. No typos in names.
  Not like this: `$maxmiumLifetimeExtension`, `"[INORMATION]"`, `Tennant`.

## Documentation
- **Every public unit is documented:** purpose, parameters (with default and whether required or optional), return value and an example. The format is the language's usual one.
  ```js
  /**
   * Downloads all repositories of a project into the local workspace.
   *
   * @param {string}  project              (Required) Name of the Azure DevOps project.
   * @param {boolean} [isForced=false]     (Optional) Overwrites existing folders.
   * @returns {Promise<string[]>} The local paths of all downloaded repositories.
   *
   * @example
   * await downloadRepositories('Platform', true)
   */
  ```
- **Required or optional always comes first**, consistent per language: `[Required]`/`[Optional]` in PowerShell, `(Required)`/`(Optional)` everywhere else.
  ```hcl
  description = "(Optional) The SKU of the container registry. Defaults to 'Standard'."
  ```
- **No empty doc skeletons:** Either fill them in or leave them out.
  Not like this:
  ```powershell
  <#
  .SYNOPSIS
  .DESCRIPTION
  .EXAMPLE
  #>
  ```
- Parameter docs sit right at the parameter, not collected somewhere else.
  ```powershell
  <#
  [Required]
  The name of the cloud sync profile.
  #>
  [Parameter(Mandatory = $true)]
  [System.String]
  $ProfileName,
  ```

## Errors, logging, tests
- **Never swallow errors silently.** Only catch what you can handle and rethrow the rest.
  ```powershell
  try {
      $config = Get-Content -Path $ConfigPath -Raw -ErrorAction Stop | ConvertFrom-Json
  }
  catch [System.Management.Automation.ItemNotFoundException] {
      # Handled: a missing config simply means the defaults apply.
      Write-Verbose "[Get-UtilsConfig] Config '$ConfigPath' not found, using defaults."
      return $DefaultConfig
  }
  # Everything else (e.g. invalid JSON) bubbles up unchanged.
  ```
  Not like this: `catch { }`
- **Error messages state the expectation:** `"X must be a full resource ID in the format: /subscriptions/{id}/..."`
  ```powershell
  throw [System.ArgumentException]::new("Interval must be between 60 and 3600 seconds, got '$Interval'.")
  ```
- Validate input early, but only after the variables are set. Several rules are grouped in their own `Validations` section.
  ```powershell
  # ---------------------------------------------------------------------------
  # Validations

  if ($Source -EQ $Target) {
      throw [System.ArgumentException]::new('Source and Target must be different Key Vaults.')
  }
  if ($null -EQ (Get-AzKeyVault -VaultName $Target)) {
      throw [System.ArgumentException]::new("Target Key Vault '$Target' must exist before moving secrets.")
  }
  ```
- The condition must check exactly what the error message claims.
  ```js
  // Message says "must be a positive number" -> condition checks type AND sign.
  if (typeof count !== 'number' || count <= 0) {
      throw new Error(`count must be a positive number, got '${count}'`)
  }
  ```
- **Logs as a narrative trail:** A debug/verbose log at every decision point, prefixed with the function or component (`[Sync-UtilsCloudFile] …`).
  ```powershell
  Write-Verbose "[Sync-UtilsCloudFile] Local file missing, cloud data found -> creating '$FilePath'."
  Write-Verbose "[Sync-UtilsCloudFile] Last sync at $lastSync is inside the interval -> skipping."
  ```
- Mutating operations support dry-run or WhatIf where possible. Changed context is reset at the end.
  ```powershell
  if ($PSCmdlet.ShouldProcess($secret.Name, "Move to '$Target'")) {
      $null = Set-AzKeyVaultSecret -VaultName $Target -Name $secret.Name -SecretValue $secret.SecretValue
  }
  ```
- **Tests check concrete expected values**, not just "runs through".
  ```powershell
  It 'generates the expected name' {
      Get-UtilsResourceName -Type vnet -Environment tst | Should -Be 'vnet-euwe-tst-01'
  }
  ```
  Not like this: `{ Get-UtilsResourceName -Type vnet } | Should -Not -Throw`

## Format
- The defaults of the language's usual formatter. Indentation and deviations are in the language's file.
- Break long chains line by line, with the operator at the start of the line.
  ```js
  const isDeployable = isApproved
      && hasPassingTests
      && !isFrozen
  ```
  ```hcl
  name = (
    var.is_global
    ? "${local.prefix}-${var.name}"
    : "${local.prefix}-${var.location_short}-${var.name}"
  )
  ```
- License or project headers only go where the codebase already does it.

# Review checklist
Use this list for reviews, `/code-review` and `/simplify`. Report each finding with the rule it breaks and a concrete fix. Respect [Scope](#scope): flag untouched code only in a refactoring or when asked.

- [ ] **Header:** usage and prerequisites at the top of the file, a table of contents from three chapters on. → [Reading flow](#reading-flow)
- [ ] **Shelf label:** a folder with more than one file has an entry point or a `README.md` listing the files. → [The story](#the-story)
- [ ] **Chapters:** a file with several phases or kinds of units has chapters, in plot order: setup → validations → action → epilogue. → [The story](#the-story)
- [ ] **Introductions:** every variable is declared in the chapter where it first acts. → [The story](#the-story)
- [ ] **Banners:** chapters with `=` frame and centered UPPERCASE title, sections with one `-` line, 75 characters, no other banner styles. → [Comments](#comments)
- [ ] **Chapter description:** every chapter has one, numbered steps in flow chapters match the section titles, one entry per unit in collection chapters, columns aligned. → [Comments](#comments)
- [ ] **Cross-references:** comments that point elsewhere name the chapter or file. → [Comments](#comments)
- [ ] **Flat main path:** guard clauses and early `return` instead of nesting. → [Reading flow](#reading-flow)
- [ ] **Decision trees:** non-trivial blocks are described first and the code follows the description 1:1. → [Reading flow](#reading-flow)
- [ ] **Structure:** one thing per file, dotted file names, no duplicated logic, one real implementation. → [Structure](#structure)
- [ ] **Explicit:** no magic numbers, no hard-coded lists or environment values. → [Structure](#structure)
- [ ] **Named stages:** no monster expressions, fallback chains with one comment per step. → [Processing data](#processing-data)
- [ ] **Naming:** verbs first, `is`/`has` booleans with a real bool type, `UPPER_SNAKE` constants, `null` on the left, English without typos. → [API and naming](#api-and-naming)
- [ ] **Docs:** every public unit documented, `(Required)`/`(Optional)` first, no empty skeletons, parameter docs at the parameter. → [Documentation](#documentation)
- [ ] **Errors:** nothing swallowed, messages state the expectation, condition matches the message, validations grouped. → [Errors, logging, tests](#errors-logging-tests)
- [ ] **Logs:** `[Component]` prefix at every decision point. → [Errors, logging, tests](#errors-logging-tests)
- [ ] **Safety:** mutating operations support WhatIf or dry-run, changed context is reset. → [Errors, logging, tests](#errors-logging-tests)
- [ ] **Tests:** assert concrete expected values. → [Errors, logging, tests](#errors-logging-tests)
- [ ] **Language file:** the rules of the matching `references/*.md` are met.
