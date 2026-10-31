# NOTE:
#   Requires: PowerShell 7.
#
#   ./.scripts/Test-StorylineBanner.ps1                   Checks the whole repo.
#   ./.scripts/Test-StorylineBanner.ps1 -Path ./plugins   Checks one folder.
#   ./.scripts/Test-StorylineBanner.ps1 -Verbose          Also logs every checked file.
#
#   Chapters:
#     SETTINGS        Banner format, structure patterns and the checked files.
#     CHECK BANNERS   Collects the files, checks format and structure, reports.

<#
.SYNOPSIS
    Checks all chapter and section banners against the storyline banner format.

.DESCRIPTION
    Finds every banner line (comment character followed by '=' or '-') in Markdown
    and source files and checks the format rules from SKILL.md -> "Comments":
    - Every line is 75 characters long, plus the comment character and one space.
    - The chapter title sits centered, the '=' on both sides differ by at most one.

    Source files (not Markdown, whose snippets are excerpts) are also checked
    for the structure rules from SKILL.md -> "The story" and "Comments":
    - Every chapter has a description right below the frame.
    - The numbered entries of a flow chapter match the sections of the chapter.
    - A file with two or more chapters lists them as 'Chapters:' in the header,
      and the list matches the chapters in order.

    Throws when at least one rule is broken, so CI fails.

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

Set-StrictMode -Version 1.0
$ErrorActionPreference = 'Stop'

# ===========================================================================
# ===============================   SETTINGS   ==============================
# ===========================================================================
#
#   Banner format   Line length, title spacing and the line patterns.
#   Structure       Patterns for descriptions, sections and the table of contents.
#   Files           Which files are checked, which comment character they use
#                   and which folders are skipped.
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
# Structure

# The frame lines of a chapter and the line of a section, without the comment character.
$CHAPTER_FRAME = '=' * $BANNER_WIDTH
$SECTION_LINE  = '-' * $BANNER_WIDTH

# A numbered entry of a flow chapter: '1. Name   Explanation', the name ends at two spaces.
$NUMBERED_ENTRY_PATTERN = '^\d+\.\s+(?<name>.+?)(\s{2,}.*)?$'

# The table of contents in the header starts with this line, every entry is a chapter title.
$TOC_HEADER     = 'Chapters:'
$TOC_ENTRY_PATTERN = '^(?<title>[A-Z][A-Z0-9 /-]*?)(\s{2,}.*)?$'
$TOC_MIN_CHAPTERS  = 2

# ---------------------------------------------------------------------------
# Files

$FILE_EXTENSIONS = @('.md', '.ps1', '.psm1', '.tf', '.tfvars', '.hcl', '.bicep', '.bicepparam', '.yaml', '.yml', '.js', '.h', '.cpp')
$EXCLUDED_FOLDERS = @('.git', 'node_modules', '.terraform')

# Markdown snippets are excerpts, so only the banner lines are checked there.
$STRUCTURE_EXTENSIONS = $FILE_EXTENSIONS | Where-Object { $_ -NE '.md' }

# Comment character per extension, '#' for everything not listed here.
$SLASH_COMMENT_EXTENSIONS = @('.js', '.h', '.cpp', '.bicep', '.bicepparam')

# ===========================================================================
# ============================   CHECK BANNERS   ============================
# ===========================================================================
#
#   1. Validations       Fails early on a missing folder.
#   2. Collect           Lists all files with a checked extension.
#   3. Check format      Tests every banner line for length and centering and
#                        records chapters, descriptions, sections and the TOC.
#   4. Check structure   Tests descriptions, numbered entries and the TOC.
#   5. Report            Lists all findings and fails when there is one.
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
# Check format

$Findings = [System.Collections.Generic.List[System.String]]::new()

# One entry per file with structure checks: its chapters and its table of contents.
$Structures = [System.Collections.Generic.List[System.Object]]::new()

foreach ($file in $Files) {
    Write-Verbose "[Test-StorylineBanner] Checking '$($file.FullName)'."

    $commentPrefix  = $file.Extension -IN $SLASH_COMMENT_EXTENSIONS ? '//' : '#'
    $commentPattern = "^$([System.Text.RegularExpressions.Regex]::Escape($commentPrefix))(\s(?<text>.*))?$"

    $Chapters = [System.Collections.Generic.List[System.Object]]::new()
    $Toc      = [System.Collections.Generic.List[System.String]]::new()

    # What the next line is expected to be: a frame line, a description line, a section title or a TOC entry.
    $expecting  = $null
    $lineNumber = 0

    foreach ($line in Get-Content -Path $file.FullName) {
        $lineNumber++
        $location = "$($file.FullName):$lineNumber"

        # Banners inside Markdown code blocks and inside blocks are indented, the indent does not count.
        $trimmedLine  = $line.TrimStart()
        $commentMatch = [System.Text.RegularExpressions.Regex]::Match($trimmedLine, $commentPattern)
        $commentText  = $commentMatch.Success ? $commentMatch.Groups['text'].Value.Trim() : $null

        # The lines right after a chapter frame are its description, it ends at the first non-comment line.
        if ($expecting -EQ 'description') {
            if ($commentMatch.Success -AND $commentText -NOTMATCH '^[=-]{5,}') {
                $Chapters[-1].Description.Add($commentText)
                continue
            }
            $expecting = $null
        }

        # The line right after a section line is the section title.
        if ($expecting -EQ 'section title') {
            $expecting = $null
            if ($commentMatch.Success -AND $Chapters.Count -GT 0) {
                $Chapters[-1].Sections.Add($commentText)
            }
            continue
        }

        # The table of contents in the header, one chapter title per line until the first other line.
        if ($expecting -EQ 'toc entry') {
            $tocMatch = [System.Text.RegularExpressions.Regex]::Match([System.String] $commentText, $TOC_ENTRY_PATTERN)
            if ($commentMatch.Success -AND $tocMatch.Success) {
                $Toc.Add($tocMatch.Groups['title'].Value)
                continue
            }
            $expecting = $null
        }
        if ($commentMatch.Success -AND $commentText -EQ $TOC_HEADER -AND $Chapters.Count -EQ 0) {
            $expecting = 'toc entry'
            continue
        }

        $bannerMatch = [System.Text.RegularExpressions.Regex]::Match($trimmedLine, $BANNER_PATTERN)
        if (-NOT $bannerMatch.Success) {
            continue
        }

        $body = $bannerMatch.Groups['body'].Value

        # Every banner line is exactly BANNER_WIDTH characters after the comment character.
        if ($body.Length -NE $BANNER_WIDTH) {
            $Findings.Add("$location Banner must be $BANNER_WIDTH characters long, got $($body.Length).")
            continue
        }

        # A section line, the title follows on the next line.
        if ($body -EQ $SECTION_LINE) {
            $expecting = 'section title'
            continue
        }

        # The closing frame line of a chapter, the description follows.
        if ($body -EQ $CHAPTER_FRAME) {
            $expecting = $expecting -EQ 'frame close' ? 'description' : $null
            continue
        }

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

        $Chapters.Add([PSCustomObject]@{
            Title       = $titleMatch.Groups['title'].Value
            Location    = $location
            Description = [System.Collections.Generic.List[System.String]]::new()
            Sections    = [System.Collections.Generic.List[System.String]]::new()
        })
        $expecting = 'frame close'
    }

    if ($file.Extension -IN $STRUCTURE_EXTENSIONS) {
        $Structures.Add([PSCustomObject]@{
            File     = $file.FullName
            Chapters = $Chapters
            Toc      = $Toc
        })
    }
}

# ---------------------------------------------------------------------------
# Check structure

foreach ($structure in $Structures) {

    foreach ($chapter in $structure.Chapters) {

        # Every chapter has a description with at least one line of text.
        $descriptionText = $chapter.Description | Where-Object { -NOT [System.String]::IsNullOrWhiteSpace($_) }
        if ($null -EQ $descriptionText) {
            $Findings.Add("$($chapter.Location) Chapter '$($chapter.Title)' must have a description below the frame.")
            continue
        }

        # In a flow chapter the numbered names and the section titles must match.
        $numberedNames = $descriptionText
        | ForEach-Object { [System.Text.RegularExpressions.Regex]::Match($_, $NUMBERED_ENTRY_PATTERN) }
        | Where-Object -Property Success
        | ForEach-Object { $_.Groups['name'].Value }

        if ($null -EQ $numberedNames) {
            continue
        }

        foreach ($name in $numberedNames) {
            if ($name -NOTIN $chapter.Sections) {
                $Findings.Add("$($chapter.Location) Chapter '$($chapter.Title)' lists step '$name', but has no section with that title.")
            }
        }
        foreach ($section in $chapter.Sections) {
            if ($section -NOTIN $numberedNames) {
                $Findings.Add("$($chapter.Location) Chapter '$($chapter.Title)' has section '$section', but the description does not list it.")
            }
        }
    }

    # From TOC_MIN_CHAPTERS on the header lists the chapters, and the list matches them in order.
    $chapterTitles = @($structure.Chapters | ForEach-Object { $_.Title })
    $hasToc        = $structure.Toc.Count -GT 0

    if (-NOT $hasToc -AND $chapterTitles.Count -GE $TOC_MIN_CHAPTERS) {
        $Findings.Add("$($structure.File) Header must list the $($chapterTitles.Count) chapters below '$TOC_HEADER', got none.")
        continue
    }
    if ($hasToc -AND (($structure.Toc -join '|') -NE ($chapterTitles -join '|'))) {
        $Findings.Add("$($structure.File) Header lists chapters '$($structure.Toc -join ', ')', but the file has '$($chapterTitles -join ', ')'.")
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
