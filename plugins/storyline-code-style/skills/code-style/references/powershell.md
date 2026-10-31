# Code Style: PowerShell
- PowerShell 7, 4 spaces. One function per file, folders by domain, the `.psm1` dot-sources the list explicitly, one `meta.json` per module.
  ```
  Utils/
    Utils.psm1
    meta.json
    Config/Get-UtilsConfig.ps1
    CloudSync/Sync-UtilsCloudFile.ps1
    tests/
  ```
  ```powershell
  # Utils.psm1
  . $PSScriptRoot/Config/Get-UtilsConfig.ps1
  . $PSScriptRoot/CloudSync/Sync-UtilsCloudFile.ps1
  ```
- Verb-Noun with a module prefix (`Get-UtilsConfig`, `Invoke-AzureRest`), aliases for frequent commands (`[Alias('tf')]`).
  ```powershell
  function Invoke-TerraformCommand {
      [Alias('tf')]
      [CmdletBinding()]
      param (...)
  }
  ```
- Comment-based help with `.SYNOPSIS`, `.DESCRIPTION` and `.EXAMPLE` (`PS> …`).
  ```powershell
  <#
  .SYNOPSIS
      Syncs a local file with its copy in Azure Blob Storage.

  .DESCRIPTION
      Uploads or downloads the file of a sync profile, depending on which side is newer.
      Skips the sync when the last run is still inside the interval.

  .EXAMPLE
      Sync the notes database with the default interval:

      PS> Sync-UtilsCloudFile -ProfileName notes
  #>
  ```
- Parameters in a multi-line layout, full .NET types and TAB completion where possible: `ValidateSet` for a fixed list, `ArgumentCompleter` for values only known at runtime.
  ```powershell
  <#
  [Required]
  The name of the cloud sync profile, one JSON file per profile in the profiles folder.
  #>
  [Parameter(
      Mandatory = $true
  )]
  [ArgumentCompleter({
      param ($CommandName, $ParameterName, $WordToComplete)
      Get-ChildItem -Path (Join-Path -Path $HOME -ChildPath '.utils/profiles') -Filter "$WordToComplete*.json"
      | Select-Object -ExpandProperty BaseName
  })]
  [System.String]
  $ProfileName,

  <#
  [Optional]
  The direction of the sync. Default is Both.
  #>
  [Parameter(
      Mandatory = $false
  )]
  [ValidateSet('Upload', 'Download', 'Both')]
  [System.String]
  $Direction = 'Both',
  ```
- Pipelines with a leading `|`, no backtick continuation:
  ```powershell
  $SubscriptionId = Get-AzSubscription
  | Where-Object -Property Name -EQ -Value $Name
  | Select-Object -ExpandProperty Id
  ```
- Operators and blocks in uppercase: `-EQ`, `-NOT`, `-LIKE`, `BEGIN/PROCESS/CLEAN`.
  ```powershell
  if (-NOT $IsForced -AND $item.Name -LIKE 'tmp-*') {
      continue
  }
  ```
- `$null = …` to suppress output, splatting hashtables (`@UploadConfig`) for parameter sets.
  ```powershell
  $null = New-Item -ItemType Directory -Path $backupPath

  $UploadConfig = @{
      Container = 'backups'
      Context   = $storageContext
      Force     = $true
  }
  Set-AzStorageBlobContent @UploadConfig -File $FilePath -Blob (Split-Path $FilePath -Leaf)
  ```
- `Write-Verbose "[FunctionName] …"` at every decision point.
  ```powershell
  Write-Verbose "[Sync-UtilsCloudFile] Cloud copy is newer ($cloudDate > $localDate) -> downloading."
  ```
- Named loops (`:MOVE_BLOBS`) for `continue`/`break` out of inner loops.
  ```powershell
  :MOVE_BLOBS foreach ($blob in $blobs) {
      foreach ($pattern in $ExcludePatterns) {
          if ($blob.Name -LIKE $pattern) {
              Write-Verbose "[Move-StorageBlob] '$($blob.Name)' matches '$pattern' -> skipping."
              continue MOVE_BLOBS
          }
      }
      ...
  }
  ```
- `SupportsShouldProcess` for mutating operations. Reset changed context in `CLEAN` (PowerShell 7.3+, also runs on errors and Ctrl+C). Below 7.3 use `try`/`finally` instead.
  ```powershell
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (...)

  BEGIN {
      $previousContext = Get-AzContext
      $null = Set-AzContext -Subscription $SubscriptionId
  }
  PROCESS {
      if ($PSCmdlet.ShouldProcess($blob.Name, "Move to '$Target'")) {
          ...
      }
  }
  CLEAN {
      $null = Set-AzContext -Context $previousContext
  }
  ```
- `throw [System.ArgumentException]::new('…')` with a concrete type, a bare `throw` only to rethrow.
  ```powershell
  try {
      $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
  }
  catch {
      Write-Verbose "[Get-UtilsConfig] Failed to read '$ConfigPath'."
      throw
  }

  if ($null -EQ $config.Profiles) {
      throw [System.InvalidOperationException]::new("Config '$ConfigPath' must contain a 'Profiles' section.")
  }
  ```
- Parameters and central values in PascalCase, local helper values in camelCase.
  ```powershell
  param ([System.String] $ProfileName)

  $SyncProfile = Get-UtilsCloudSyncProfile -Name $ProfileName
  $localDate   = (Get-Item -Path $SyncProfile.Path).LastWriteTime
  ```
- Tests with Pester in `tests/` per module, `BeforeAll.ps1`/`AfterAll.ps1` for setup.
  ```powershell
  BeforeAll {
      . $PSScriptRoot/BeforeAll.ps1
  }

  Describe 'Get-UtilsResourceName' {
      It 'generates the expected name for <Type>' -ForEach @(
          @{ Type = 'vnet'; Expected = 'vnet-euwe-tst-01' }
          @{ Type = 'kv';   Expected = 'kv-euwe-tst-01' }
      ) {
          Get-UtilsResourceName -Type $Type -Environment tst | Should -Be $Expected
      }
  }
  ```
- **Strict from the first line:** every script and every `.psm1` sets `Set-StrictMode -Version 1.0` and `$ErrorActionPreference = 'Stop'` right after `param` (in `BEGIN` when the script uses blocks). Function files inherit both from the `.psm1`. Version 1.0 catches misspelled variables, `Latest` would also throw on missing properties and break checks like `$null -EQ $Config.Profiles`. `Stop` does not cover native commands, check `$LASTEXITCODE` after them.
  ```powershell
  param (...)

  Set-StrictMode -Version 1.0
  $ErrorActionPreference = 'Stop'

  terraform init -input=false
  if ($LASTEXITCODE -NE 0) {
      throw [System.InvalidOperationException]::new("terraform init must succeed, got exit code $LASTEXITCODE.")
  }
  ```
- **Verify** per `SKILL.md` → "Errors, logging, tests": parse every changed file, run `Invoke-ScriptAnalyzer -Severity Warning, Error` and the Pester tests of the module.
  ```powershell
  Invoke-ScriptAnalyzer -Path ./Utils -Recurse -Severity Warning, Error
  Invoke-Pester -Path ./Utils/tests
  ```
