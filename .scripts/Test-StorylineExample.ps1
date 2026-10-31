# NOTE:
#   Requires: PowerShell 7. Optional: PSScriptAnalyzer, terraform, bicep, node, docker, helm, kubeconform.
#   A missing tool skips its check and is named in the report, -IsStrict fails instead.
#   C++ is not compiled yet, the examples have no Request.h / Response.h.
#
#   ./.scripts/Test-StorylineExample.ps1                    Checks all example files.
#   ./.scripts/Test-StorylineExample.ps1 -IsStrict          Fails on a missing tool (CI).
#   ./.scripts/Test-StorylineExample.ps1 -Verbose           Also logs every checked file.
#
#   Chapters:
#     SETTINGS         Checked tools, file patterns and the work folder.
#     CHECK EXAMPLES   Runs the checks of every language and reports.

<#
.SYNOPSIS
    Checks that every example file is valid with the tools of its language.

.DESCRIPTION
    Runs the checks named in SKILL.md -> "Errors, logging, tests" (Verify before done)
    against the example files:
    - PowerShell       Parser and PSScriptAnalyzer (Warning and Error).
    - Terraform        terraform fmt -check, init, validate and test.
    - Bicep            bicep build and bicep build-params.
    - JavaScript       node --check.
    - Docker Compose   docker compose config.
    - Helm             helm lint and helm template per values.<env>.yaml.
    - Kubernetes       kubeconform on the rendered charts and every plain manifest.

    Terraform runs in a copy of the folder and Helm renders into the work folder,
    so no .terraform folder, lock file or rendered manifest is left in the repo. Throws when at least one check fails, so CI fails.

.EXAMPLE
    Check the examples before a commit:

    PS> ./.scripts/Test-StorylineExample.ps1
#>

[CmdletBinding()]
param (
    <#
    [Optional]
    The folder to check recursively. Default is the examples folder of the repo.
    #>
    [Parameter(
        Mandatory = $false
    )]
    [System.String]
    $Path = (Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'examples'),

    <#
    [Optional]
    Fails when a tool is missing instead of skipping its check. Default is to skip.
    #>
    [Parameter(
        Mandatory = $false
    )]
    [System.Management.Automation.SwitchParameter]
    $IsStrict
)

Set-StrictMode -Version 1.0
$ErrorActionPreference = 'Stop'

# ===========================================================================
# ===============================   SETTINGS   ==============================
# ===========================================================================
#
#   Tools    The command each language check needs.
#   Files    Which files each check reads and which folders are skipped.
#

# ---------------------------------------------------------------------------
# Tools
#   The command each language check needs.
# ---------------------------------------------------------------------------

# Language => command that has to be found, the check is skipped without it.
$TOOLS = [ordered]@{
    'PowerShell'     = 'Invoke-ScriptAnalyzer'
    'Terraform'      = 'terraform'
    'Bicep'          = 'bicep'
    'JavaScript'     = 'node'
    'Docker Compose' = 'docker'
    'Helm'           = 'helm'
    'Kubernetes'     = 'kubeconform'
}

$ANALYZER_SEVERITY = @('Warning', 'Error')

# Custom resources (cert-manager, ingress controllers) have no built-in schema, they are skipped.
$KUBECONFORM_ARGUMENTS = @('-strict', '-ignore-missing-schemas', '-summary')

# ---------------------------------------------------------------------------
# Files
#   Which files each check reads and which folders are skipped.
# ---------------------------------------------------------------------------

$EXCLUDED_FOLDERS = @('.git', 'node_modules', '.terraform')

$COMPOSE_FILE_NAMES = @('docker-compose.yaml', 'docker-compose.yml', 'compose.yaml', 'compose.yml')

# A required compose variable: ${NAME:?message}, it gets a placeholder value for the check.
$COMPOSE_REQUIRED_VARIABLE_PATTERN = '\$\{(?<name>[A-Za-z0-9_]+):\?'

# The values of one environment next to Chart.yaml: values.dev.yaml, values.prod.yaml.
$HELM_ENVIRONMENT_VALUES_PATTERN = '^values\..+\.ya?ml$'

# A plain manifest has both keys at the top level, Chart.yaml only has apiVersion.
$MANIFEST_API_VERSION_PATTERN = '(?m)^apiVersion:\s'
$MANIFEST_KIND_PATTERN        = '(?m)^kind:\s'

# ===========================================================================
# ===========================   CHECK EXAMPLES   ============================
# ===========================================================================
#
#   1. Validations      Fails early on a missing folder.
#   2. Collect          Lists all files, finds the installed tools and
#                       creates the work folder.
#   3. PowerShell       Parses every script and runs PSScriptAnalyzer.
#   4. Terraform        Checks the format, then validates and tests every
#                       module in a copy of the folder.
#   5. Bicep            Builds every template and parameter file.
#   6. JavaScript       Checks the syntax of every file.
#   7. Docker Compose   Renders every compose file with placeholder variables.
#   8. Helm             Lints and renders every chart per values.<env>.yaml.
#   9. Kubernetes       Validates the rendered charts and every plain manifest.
#   10. Cleanup         Removes the work folder.
#   11. Report          Lists all findings and skipped checks, fails on a finding.
#
#   Every native command is judged by its exit code, its output only goes into the finding.
#

# ---------------------------------------------------------------------------
# Validations
#   Fails early on a missing folder.
# ---------------------------------------------------------------------------

if (-NOT (Test-Path -Path $Path -PathType Container)) {
    throw [System.ArgumentException]::new("Path must be an existing folder, got '$Path'.")
}

# ---------------------------------------------------------------------------
# Collect
#   Lists all files, finds the installed tools and creates the work folder.
# ---------------------------------------------------------------------------

$Path  = (Resolve-Path -Path $Path).Path
$Files = Get-ChildItem -Path $Path -Recurse -File
| Where-Object { $null -EQ ($_.FullName -split '[\\/]' | Where-Object { $_ -IN $EXCLUDED_FOLDERS }) }

Write-Verbose "[Test-StorylineExample] Found $($Files.Count) files below '$Path'."

$Findings = [System.Collections.Generic.List[System.String]]::new()
$Skipped  = [System.Collections.Generic.List[System.String]]::new()

# Language => $true when its tool is installed. A missing tool is a finding in strict mode, else a skip.
$IsInstalled = @{}
foreach ($language in $TOOLS.Keys) {
    $IsInstalled[$language] = $null -NE (Get-Command -Name $TOOLS[$language] -ErrorAction SilentlyContinue)
    if ($IsInstalled[$language]) {
        continue
    }

    $message = "$language ($($TOOLS[$language]) not found)"
    if ($IsStrict) {
        $Findings.Add("[Tools] $message")
    }
    else {
        $Skipped.Add($message)
    }
}

# Terraform works in a copy and Docker Compose writes its env files here, removed in Cleanup.
$WorkFolder = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "storyline-examples-$([System.Guid]::NewGuid())"
$null = New-Item -ItemType Directory -Path $WorkFolder

# Runs one native command and returns a finding when its exit code is not 0, else $null.
function Invoke-ExampleCommand {
    param (
        [System.String] $Check,
        [System.String] $Target,
        [System.Management.Automation.ScriptBlock] $Command
    )

    Write-Verbose "[Test-StorylineExample] $Check '$Target'."
    $global:LASTEXITCODE = 0
    $output = & $Command 2>&1

    if ($LASTEXITCODE -EQ 0) {
        return $null
    }
    return "[$Check] $Target`n$(($output | Out-String).TrimEnd())"
}

# ---------------------------------------------------------------------------
# PowerShell
#   Parses every script and runs PSScriptAnalyzer.
# ---------------------------------------------------------------------------

# The parser is part of PowerShell, so it always runs. The analyzer only when installed.
$PowerShellFiles = $Files | Where-Object -Property Extension -IN '.ps1', '.psm1'

foreach ($file in $PowerShellFiles) {
    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref] $null, [ref] $parseErrors)
    foreach ($parseError in $parseErrors) {
        $Findings.Add("[Parser] $($file.FullName):$($parseError.Extent.StartLineNumber) $($parseError.Message)")
    }

    if (-NOT $IsInstalled['PowerShell']) {
        continue
    }
    Invoke-ScriptAnalyzer -Path $file.FullName -Severity $ANALYZER_SEVERITY
    | ForEach-Object { $Findings.Add("[$($_.RuleName)] $($file.FullName):$($_.Line) $($_.Message)") }
}

# ---------------------------------------------------------------------------
# Terraform
#   Checks the format, then validates and tests every module.
# ---------------------------------------------------------------------------

# A module is every folder with its own .tf files. The copy keeps init from writing into the repo.
$TerraformModules = $Files
| Where-Object -Property Extension -EQ '.tf'
| Select-Object -ExpandProperty DirectoryName -Unique

if ($IsInstalled['Terraform'] -AND $TerraformModules.Count -GT 0) {
    $Findings.Add((Invoke-ExampleCommand -Check 'terraform fmt' -Target $Path -Command { terraform "-chdir=$Path" fmt -check -recursive -no-color }))

    Copy-Item -Path (Join-Path -Path $Path -ChildPath '*') -Destination $WorkFolder -Recurse
    foreach ($module in $TerraformModules) {
        # 'examples/terraform/modules/x' => '<WorkFolder>/terraform/modules/x'
        $moduleCopy = Join-Path -Path $WorkFolder -ChildPath ([System.IO.Path]::GetRelativePath($Path, $module))

        $initFinding = Invoke-ExampleCommand -Check 'terraform init' -Target $module -Command { terraform "-chdir=$moduleCopy" init -backend=false -input=false -no-color }
        if ($null -NE $initFinding) {
            # Without init neither validate nor test can run.
            $Findings.Add($initFinding)
            continue
        }

        $Findings.Add((Invoke-ExampleCommand -Check 'terraform validate' -Target $module -Command { terraform "-chdir=$moduleCopy" validate -no-color }))
        if (Test-Path -Path (Join-Path -Path $moduleCopy -ChildPath 'tests')) {
            $Findings.Add((Invoke-ExampleCommand -Check 'terraform test' -Target $module -Command { terraform "-chdir=$moduleCopy" test -no-color }))
        }
    }
}

# ---------------------------------------------------------------------------
# Bicep
#   Builds every template and parameter file.
# ---------------------------------------------------------------------------

if ($IsInstalled['Bicep']) {
    foreach ($file in $Files | Where-Object -Property Extension -EQ '.bicep') {
        $Findings.Add((Invoke-ExampleCommand -Check 'bicep build' -Target $file.FullName -Command { bicep build $file.FullName --stdout }))
    }
    foreach ($file in $Files | Where-Object -Property Extension -EQ '.bicepparam') {
        $Findings.Add((Invoke-ExampleCommand -Check 'bicep build-params' -Target $file.FullName -Command { bicep build-params $file.FullName --stdout }))
    }
}

# ---------------------------------------------------------------------------
# JavaScript
#   Checks the syntax of every file.
# ---------------------------------------------------------------------------

if ($IsInstalled['JavaScript']) {
    foreach ($file in $Files | Where-Object -Property Extension -EQ '.js') {
        $Findings.Add((Invoke-ExampleCommand -Check 'node --check' -Target $file.FullName -Command { node --check $file.FullName }))
    }
}

# ---------------------------------------------------------------------------
# Docker Compose
#   Renders every compose file with placeholder variables.
# ---------------------------------------------------------------------------

if ($IsInstalled['Docker Compose']) {
    foreach ($file in $Files | Where-Object -Property Name -IN $COMPOSE_FILE_NAMES) {
        # 'PASSWORD: ${GRAFANA_ADMIN:?Set it in .env}' => 'GRAFANA_ADMIN=placeholder'
        $envFile = Join-Path -Path $WorkFolder -ChildPath "$([System.Guid]::NewGuid()).env"
        [System.Text.RegularExpressions.Regex]::Matches((Get-Content -Path $file.FullName -Raw), $COMPOSE_REQUIRED_VARIABLE_PATTERN)
        | ForEach-Object { "$($_.Groups['name'].Value)=placeholder" }
        | Select-Object -Unique
        | Set-Content -Path $envFile

        $Findings.Add((Invoke-ExampleCommand -Check 'docker compose config' -Target $file.FullName -Command { docker compose --env-file $envFile -f $file.FullName config -q }))
    }
}

# ---------------------------------------------------------------------------
# Helm
#   Lints and renders every chart per values.<env>.yaml.
# ---------------------------------------------------------------------------

# Every chart is linted and rendered once per values.<env>.yaml, Kubernetes validates the output.
$Charts = @($Files | Where-Object -Property Name -EQ 'Chart.yaml' | Select-Object -ExpandProperty DirectoryName)
$RenderedFolder = Join-Path -Path $WorkFolder -ChildPath 'rendered'

if ($IsInstalled['Helm']) {
    foreach ($chart in $Charts) {
        $chartName = Split-Path -Path $chart -Leaf

        foreach ($values in Get-ChildItem -Path $chart -File | Where-Object -Property Name -Match $HELM_ENVIRONMENT_VALUES_PATTERN) {
            $target = "$chart -f $($values.Name)"

            # 'sample-api' + 'values.dev.yaml' => '<WorkFolder>/rendered/sample-api.dev'
            $outputFolder = Join-Path -Path $RenderedFolder -ChildPath "$chartName$($values.BaseName.Substring('values'.Length))"

            $Findings.Add((Invoke-ExampleCommand -Check 'helm lint' -Target $target -Command { helm lint $chart -f $values.FullName }))
            $Findings.Add((Invoke-ExampleCommand -Check 'helm template' -Target $target -Command { helm template $chartName $chart -f $values.FullName --output-dir $outputFolder }))
        }
    }
}

# ---------------------------------------------------------------------------
# Kubernetes
#   Validates the rendered charts and every plain manifest.
# ---------------------------------------------------------------------------

# Plain manifests live outside every chart, the templates of a chart are checked through their rendered output.
$PlainManifests = $Files
| Where-Object -Property Extension -IN '.yaml', '.yml'
| Where-Object { $candidate = $_; $null -EQ ($Charts | Where-Object { $candidate.FullName.StartsWith($_ + [System.IO.Path]::DirectorySeparatorChar) }) }
| Where-Object { $content = Get-Content -Path $_.FullName -Raw; $content -MATCH $MANIFEST_API_VERSION_PATTERN -AND $content -MATCH $MANIFEST_KIND_PATTERN }

if ($IsInstalled['Kubernetes']) {
    foreach ($manifest in $PlainManifests) {
        $Findings.Add((Invoke-ExampleCommand -Check 'kubeconform' -Target $manifest.FullName -Command { kubeconform @KUBECONFORM_ARGUMENTS $manifest.FullName }))
    }
    if (Test-Path -Path $RenderedFolder) {
        $Findings.Add((Invoke-ExampleCommand -Check 'kubeconform' -Target $RenderedFolder -Command { kubeconform @KUBECONFORM_ARGUMENTS $RenderedFolder }))
    }
}

# ---------------------------------------------------------------------------
# Cleanup
#   Removes the work folder.
# ---------------------------------------------------------------------------

# Removes the work folder created in Collect.
Remove-Item -Path $WorkFolder -Recurse -Force

# ---------------------------------------------------------------------------
# Report
#   Lists all findings and skipped checks, fails on a finding.
# ---------------------------------------------------------------------------

# Invoke-ExampleCommand returns $null for a passed check, List[String].Add turns it into ''.
$Failures = @($Findings | Where-Object { -NOT [System.String]::IsNullOrEmpty($_) })

if ($Skipped.Count -GT 0) {
    Write-Host "[Test-StorylineExample] Not verified: $($Skipped -join ', ')."
}
if ($Failures.Count -EQ 0) {
    Write-Host "[Test-StorylineExample] All $($Files.Count) example files pass the checks of their language."
    return
}

$Failures | ForEach-Object { Write-Host $_ }
throw [System.InvalidOperationException]::new("$($Failures.Count) checks failed, see the list above.")
