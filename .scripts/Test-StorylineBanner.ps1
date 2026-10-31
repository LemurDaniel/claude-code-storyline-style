# NOTE:
#   Requires: PowerShell 7.
#
#   ./.scripts/Test-StorylineBanner.ps1                   Checks the whole repo.
#   ./.scripts/Test-StorylineBanner.ps1 -Path ./plugins   Checks one folder.
#   ./.scripts/Test-StorylineBanner.ps1 -Verbose          Also logs every checked file.

<#
.SYNOPSIS
    Checks all chapter and section banners against the storyline banner format.

.DESCRIPTION
    Finds every banner line (comment character followed by '=' or '-') in Markdown
    and source files and checks two rules from SKILL.md -> "Comments":
    - Every line is 75 characters long, plus the comment character and one space.
    - The chapter title sits centered, the '=' on both sides differ by at most one.

    Throws when at least one banner breaks a rule, so CI fails.

.EXAMPLE
    Check the repo before a commit:

    PS> ./.scripts/Test-StorylineBanner.ps1
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

# ===========================================================================
# ===============================   SETTINGS   ==============================
# ===========================================================================
#
#   Banner format   Line length, title spacing and the line patterns.
#   Files           Which files are checked and which folders are skipped.
#

# ---------------------------------------------------------------------------
# Banner format

$BANNER_WIDTH  = 75
$TITLE_SPACING = '   '

# A banner line is a comment character, one space and at least five '=' or '-'.
$BANNER_PATTERN = '^(?<prefix>//|#) (?<body>[=-]{5,}.*)$'

# A chapter title line: '=' left, the title with spacing, '=' right.
$TITLE_PATTERN = "^(?<left>=+)$TITLE_SPACING(?<title>.+?)$TITLE_SPACING(?<right>=+)$"

# ---------------------------------------------------------------------------
# Files

$FILE_EXTENSIONS = @('.md', '.ps1', '.psm1', '.tf', '.tfvars', '.hcl', '.bicep', '.bicepparam', '.yaml', '.yml', '.js', '.h', '.cpp')
$EXCLUDED_FOLDERS = @('.git', 'node_modules', '.terraform')

# ===========================================================================
# ============================   CHECK BANNERS   ============================
# ===========================================================================
#
#   1. Validations   Fails early on a missing folder.
#   2. Collect       Lists all files with a checked extension.
#   3. Check         Tests every banner line for length and centering.
#   4. Report        Lists all findings and fails when there is one.
#

# ---------------------------------------------------------------------------
# Validations

if (-NOT (Test-Path -Path $Path -PathType Container)) {
    throw [System.ArgumentException]::new("Path must be an existing folder, got '$Path'.")
}

# ---------------------------------------------------------------------------
# Collect

$Files = Get-ChildItem -Path $Path -Recurse -File
| Where-Object -Property Extension -IN $FILE_EXTENSIONS
| Where-Object { $null -EQ ($_.FullName -split '[\\/]' | Where-Object { $_ -IN $EXCLUDED_FOLDERS }) }

Write-Verbose "[Test-StorylineBanner] Found $($Files.Count) files below '$Path'."

# ---------------------------------------------------------------------------
# Check

$Findings = [System.Collections.Generic.List[System.String]]::new()

foreach ($file in $Files) {
    Write-Verbose "[Test-StorylineBanner] Checking '$($file.FullName)'."
    $lineNumber = 0

    foreach ($line in Get-Content -Path $file.FullName) {
        $lineNumber++

        # Banners inside Markdown code blocks are indented, the indent does not count.
        $bannerMatch = [System.Text.RegularExpressions.Regex]::Match($line.TrimStart(), $BANNER_PATTERN)
        if (-NOT $bannerMatch.Success) {
            continue
        }

        $location = "$($file.FullName):$lineNumber"
        $body     = $bannerMatch.Groups['body'].Value

        # Every banner line is exactly BANNER_WIDTH characters after the comment character.
        if ($body.Length -NE $BANNER_WIDTH) {
            $Findings.Add("$location Banner must be $BANNER_WIDTH characters long, got $($body.Length).")
            continue
        }

        # Plain frame and section lines need no further check.
        $titleMatch = [System.Text.RegularExpressions.Regex]::Match($body, $TITLE_PATTERN)
        if (-NOT $titleMatch.Success) {
            continue
        }

        # The title is centered when both sides differ by at most one '='.
        $leftWidth  = $titleMatch.Groups['left'].Length
        $rightWidth = $titleMatch.Groups['right'].Length
        if ([System.Math]::Abs($leftWidth - $rightWidth) -GT 1) {
            $Findings.Add("$location Title must be centered, got $leftWidth '=' left and $rightWidth '=' right.")
        }
    }
}

# ---------------------------------------------------------------------------
# Report

if ($Findings.Count -EQ 0) {
    Write-Host "[Test-StorylineBanner] All banners in $($Files.Count) files follow the format."
    return
}

$Findings | ForEach-Object { Write-Host $_ }
throw [System.InvalidOperationException]::new("$($Findings.Count) banner lines break the format, see the list above.")
