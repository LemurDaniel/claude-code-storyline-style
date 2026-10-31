# NOTE:
#   Requires: PowerShell 7.
#
#   ./.scripts/Test-StorylineShelf.ps1                  Checks the whole repo.
#   ./.scripts/Test-StorylineShelf.ps1 -Path ./ideas    Checks one folder.
#   ./.scripts/Test-StorylineShelf.ps1 -Verbose         Also logs every checked folder.

#
#   Chapters:
#     SETTINGS        Source files, labels, the flat limit and the exceptions.
#     CHECK SHELVES   Collects the folders, checks labels and flat folders, reports.
#

<#
.SYNOPSIS
    Checks that every folder of the repo is a shelf with a label and does not grow flat.

.DESCRIPTION
    Checks the shelf rules from SKILL.md -> "The story" for every folder:
    - A folder with more than one source file has a label: an entry point
      (_index.js, main.tf, main.bicep, *.psm1) or a README.md.
    - A folder holds at most five source files besides its label, more get shelves.
      A Terraform module is exempt, the language loads the folder as one book.

    Source files are code files, Markdown and assets do not count.
    Throws when at least one rule is broken, so CI fails.

.EXAMPLE
    Check the repo before a commit:

    PS> ./.scripts/Test-StorylineShelf.ps1
#>

[CmdletBinding()]
param (
    <#
    [Optional]
    The folder to check recursively. Default is the repo root.
    #>
    [Parameter(
        Mandatory = $false
    )]
    [System.String]
    $Path = (Split-Path -Path $PSScriptRoot -Parent)
)

Set-StrictMode -Version 1.0
$ErrorActionPreference = 'Stop'

# ===========================================================================
# ===============================   SETTINGS   ==============================
# ===========================================================================
#
#   Shelves   Source files, label names and the flat limit.
#   Folders   Skipped folders and folders labeled by their parent.
#

# ---------------------------------------------------------------------------
# Shelves
#   Source files, label names and the flat limit.
# ---------------------------------------------------------------------------

$SOURCE_EXTENSIONS = @('.ps1', '.psm1', '.tf', '.tfvars', '.hcl', '.bicep', '.bicepparam', '.yaml', '.yml', '.js', '.h', '.cpp')

# Entry points that bundle the folder, else a README.md lists the files.
$LABEL_NAMES    = @('README.md', '_index.js', 'main.tf', 'main.bicep')
$LABEL_PATTERNS = @('*.psm1')

$MAX_FLAT_FILES = 5

# ---------------------------------------------------------------------------
# Folders
#   Skipped folders and folders labeled by their parent.
# ---------------------------------------------------------------------------

$EXCLUDED_FOLDERS = @('.git', 'node_modules', '.terraform')

# Helm: the README.md of the chart lists its templates, see references/kubernetes.md.
$PARENT_LABELED_FOLDERS = @('templates')

# ===========================================================================
# ============================   CHECK SHELVES   ============================
# ===========================================================================
#
#   1. Validations    Fails early on a missing folder.
#   2. Collect        Lists every folder with its source files and its label.
#   3. Check labels   Every folder with more than one source file has a label.
#   4. Check flat     No folder holds more than five source files besides its label.
#   5. Report         Lists all findings and fails when there is one.
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
#   Lists every folder with its source files and its label.
# ---------------------------------------------------------------------------

$Path    = (Resolve-Path -Path $Path).Path
$Folders = @(Get-Item -Path $Path) + @(Get-ChildItem -Path $Path -Recurse -Directory)
| Where-Object { $null -EQ ($_.FullName.Substring($Path.Length) -split '[\\/]' | Where-Object { $_ -IN $EXCLUDED_FOLDERS }) }

$Shelves = foreach ($folder in $Folders) {
    $files = @(Get-ChildItem -Path $folder.FullName -File)
    $label = $files | Where-Object {
        $name = $_.Name
        $name -IN $LABEL_NAMES -OR $null -NE ($LABEL_PATTERNS | Where-Object { $name -LIKE $_ })
    } | Select-Object -First 1

    [PSCustomObject]@{
        Folder      = $folder.FullName
        Name        = $folder.Name
        SourceFiles = @($files | Where-Object { $_.Extension -IN $SOURCE_EXTENSIONS -AND $_.Name -NE $label.Name })
        Label       = $label
    }
}

Write-Verbose "[Test-StorylineShelf] Found $($Shelves.Count) folders below '$Path'."

# ---------------------------------------------------------------------------
# Check labels
#   Every folder with more than one source file has a label.
# ---------------------------------------------------------------------------

$Findings = [System.Collections.Generic.List[System.String]]::new()

foreach ($shelf in $Shelves) {
    Write-Verbose "[Test-StorylineShelf] '$($shelf.Folder)': $($shelf.SourceFiles.Count) source files, label '$($shelf.Label.Name)'."

    if ($shelf.SourceFiles.Count -LE 1 -OR $null -NE $shelf.Label) {
        continue
    }
    if ($shelf.Name -IN $PARENT_LABELED_FOLDERS) {
        Write-Verbose "[Test-StorylineShelf] '$($shelf.Folder)' is labeled by its parent -> skipping."
        continue
    }
    $Findings.Add("$($shelf.Folder) Folder with $($shelf.SourceFiles.Count) source files must have a label: $($LABEL_NAMES -join ', ') or $($LABEL_PATTERNS -join ', ').")
}

# ---------------------------------------------------------------------------
# Check flat
#   No folder holds more than five source files besides its label.
# ---------------------------------------------------------------------------

foreach ($shelf in $Shelves) {
    if ($shelf.SourceFiles.Count -LE $MAX_FLAT_FILES) {
        continue
    }

    # A Terraform module is one book, its .tf files are the chapters and must stay in one folder.
    $isTerraformModule = $null -NE ($shelf.SourceFiles | Where-Object -Property Extension -EQ '.tf')
    if ($isTerraformModule) {
        Write-Verbose "[Test-StorylineShelf] '$($shelf.Folder)' is a Terraform module -> skipping the flat limit."
        continue
    }
    $Findings.Add("$($shelf.Folder) Folder must hold at most $MAX_FLAT_FILES source files besides its label, got $($shelf.SourceFiles.Count). Sort them into shelves by role or domain.")
}

# ---------------------------------------------------------------------------
# Report
#   Lists all findings and fails when there is one.
# ---------------------------------------------------------------------------

if ($Findings.Count -EQ 0) {
    Write-Host "[Test-StorylineShelf] All $($Shelves.Count) folders are labeled shelves."
    return
}

$Findings | ForEach-Object { Write-Host $_ }
throw [System.InvalidOperationException]::new("$($Findings.Count) folders break the shelf rules, see the list above.")
