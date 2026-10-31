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
- **Chapters and sections as `#` banners**, per `SKILL.md` → "Comments", with a chapter description. Chapters get the `=` frame with a centered title, sections the `# ----` line as in YAML pipelines. No `<# #### #>` blocks and no `#####` lines.
  ```powershell
  # ===========================================================================
  # ======================   LOAD AND VALIDATE CONFIG   =======================
  # ===========================================================================
  #
  #   1. Config        Loads the owner from the config file.
  #   2. Validations   Fails early on a missing owner.
  #

  # ---------------------------------------------------------------------------
  # Config

  $Config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json

  # ---------------------------------------------------------------------------
  # Validations

  if ([System.String]::IsNullOrEmpty($Config.owner)) {
      throw [System.ArgumentException]::new("Config '$ConfigPath' must contain an 'owner'.")
  }
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
      Sync the KeePass database with the default interval:

      PS> Sync-UtilsCloudFile -ProfileName keepass
  #>
  ```
- Parameters in a multi-line layout, full .NET types, `ArgumentCompleter` where possible:
  ```powershell
  <#
  [Required]
  The name of the cloud sync profile.
  #>
  [Parameter(
      Mandatory = $true
  )]
  [ArgumentCompleter({ Invoke-UtilsCompleteSet @args -Set (Get-UtilsCloudSyncProfileName) })]
  [System.String]
  $ProfileName,

  <#
  [Optional]
  The interval in seconds to check for changes. Default is 120 seconds.
  #>
  [Parameter(
      Mandatory = $false
  )]
  [System.Int32]
  $Interval = 120,
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
- Named loops (`:MOVE_SECRETS`) for `continue`/`break` out of inner loops.
  ```powershell
  :MOVE_SECRETS foreach ($secret in $secrets) {
      foreach ($pattern in $ExcludePatterns) {
          if ($secret.Name -LIKE $pattern) {
              Write-Verbose "[Move-KeyVaultSecret] '$($secret.Name)' matches '$pattern' -> skipping."
              continue MOVE_SECRETS
          }
      }
      ...
  }
  ```
- `SupportsShouldProcess` for mutating operations. Reset changed context in `CLEAN`.
  ```powershell
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (...)

  BEGIN {
      $previousContext = Get-AzContext
      $null = Set-AzContext -Subscription $SubscriptionId
  }
  PROCESS {
      if ($PSCmdlet.ShouldProcess($secret.Name, "Move to '$Target'")) {
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
