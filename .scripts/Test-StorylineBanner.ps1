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
    - Every section has a description below the title, indented by 3 spaces,
      and a closing line of '-' below it.

    Source files (not Markdown, whose snippets are excerpts) are also checked
    for the structure rules from SKILL.md -> "The story" and "Comments":
    - Every chapter has a description right below the frame.
    - The numbered entries of a flow chapter match the sections of the chapter.
    - A file with chapters lists them as 'Chapters:' in the header,
      and the list matches the chapters in order.
    - A Terraform module is one book, every .tf file one chapter. The header
      of main.tf lists every file of the module with its chapter title.

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
#   Line length, title spacing and the line patterns.
# ---------------------------------------------------------------------------

$BANNER_WIDTH  = 75
$TITLE_SPACING = '   '

# A banner line is a comment character, one space and at least five '=' or '-'.
$BANNER_PATTERN = '^(?<prefix>//|#) (?<body>[=-]{5,}.*)$'

# A chapter title line: '=' left, the title with spacing, '=' right.
$TITLE_PATTERN = "^(?<left>=+)$TITLE_SPACING(?<title>.+?)$TITLE_SPACING(?<right>=+)$"

# ---------------------------------------------------------------------------
# Structure
#   Patterns for descriptions, sections and the table of contents.
# ---------------------------------------------------------------------------

# The frame lines of a chapter and of a section, without the comment character.
$CHAPTER_FRAME = '=' * $BANNER_WIDTH
$SECTION_LINE  = '-' * $BANNER_WIDTH

# The description of a section is indented by 3 spaces, one of them follows the comment character.
$SECTION_INDENT = '  '

# A numbered entry of a flow chapter: '1. Name   Explanation', the name ends at two spaces.
$NUMBERED_ENTRY_PATTERN = '^\d+\.\s+(?<name>.+?)(\s{2,}.*)?$'

# The table of contents in the header starts with this line, every entry is a chapter title.
$TOC_HEADER        = 'Chapters:'
$TOC_ENTRY_PATTERN = '^(?<title>[A-Z][A-Z0-9 /-]*?)(\s{2,}.*)?$'

# In the main.tf of a Terraform module every entry is a file and its chapter: 'variables.tf   VARIABLES'.
$MODULE_TOC_FILE          = 'main.tf'
$MODULE_TOC_ENTRY_PATTERN = '^(?<file>[\w.-]+\.tf)\s{2,}(?<title>[A-Z][A-Z0-9 /-]*?)(\s{2,}.*)?$'

# ---------------------------------------------------------------------------
# Files
#   Checked extensions, comment characters and skipped folders.
# ---------------------------------------------------------------------------

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
#   5. Check modules     Tests the TOC in main.tf of every Terraform module.
#   6. Report            Lists all findings and fails when there is one.
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
#   Lists all files with a checked extension.
# ---------------------------------------------------------------------------

$Files = Get-ChildItem -Path $Path -Recurse -File
| Where-Object -Property Extension -IN $FILE_EXTENSIONS
| Where-Object { $null -EQ ($_.FullName -split '[\\/]' | Where-Object { $_ -IN $EXCLUDED_FOLDERS }) }

Write-Verbose "[Test-StorylineBanner] Found $($Files.Count) files below '$Path'."

# ---------------------------------------------------------------------------
# Check format
#   Tests every banner line for length and centering and records the structure.
# ---------------------------------------------------------------------------

$Findings = [System.Collections.Generic.List[System.String]]::new()

# One entry per file with structure checks: its chapters and its table of contents.
$Structures = [System.Collections.Generic.List[System.Object]]::new()

foreach ($file in $Files) {
    Write-Verbose "[Test-StorylineBanner] Checking '$($file.FullName)'."

    $commentPrefix  = $file.Extension -IN $SLASH_COMMENT_EXTENSIONS ? '//' : '#'
    $commentPattern = "^$([System.Text.RegularExpressions.Regex]::Escape($commentPrefix))(\s(?<text>.*))?$"

    $Chapters = [System.Collections.Generic.List[System.Object]]::new()
    $Toc      = [System.Collections.Generic.List[System.String]]::new()

    # Only filled in a Terraform main.tf: one entry per file of the module.
    $ModuleToc = [System.Collections.Generic.List[System.Object]]::new()

    # What the next line is expected to be: a frame line, a description line, a section title or a TOC entry.
    $expecting  = $null
    $section    = $null
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

        # A section line followed by code closes a section whose opening line sat behind a label
        # (the annotated book in SKILL.md), so the check did not see it open.
        if ($expecting -EQ 'section title' -AND -NOT $commentMatch.Success) {
            $expecting = $null
            continue
        }

        # The line right after a section line is the section title.
        if ($expecting -EQ 'section title') {
            $expecting = 'section description'
            $section   = [PSCustomObject]@{
                Title          = $commentText
                HasDescription = $false
            }
            if ($commentMatch.Success -AND $Chapters.Count -GT 0) {
                $Chapters[-1].Sections.Add($commentText)
            }
            continue
        }

        # The lines between the section title and the closing section line are its description.
        # - '#   Fails early on equal storage accounts.' => text '  Fails early ...', indented by 3 spaces
        $isBannerLine = $commentText -MATCH '^[=-]{5,}'
        if ($expecting -EQ 'section description' -AND $commentMatch.Success -AND -NOT $isBannerLine) {
            $descriptionText = $commentMatch.Groups['text'].Value
            if (-NOT [System.String]::IsNullOrWhiteSpace($descriptionText)) {
                $section.HasDescription = $true
                if ($descriptionText -NOTMATCH "^$SECTION_INDENT") {
                    $Findings.Add("$location Description of section '$($section.Title)' must be indented by 3 spaces.")
                }
            }
            continue
        }
        if ($expecting -EQ 'section description' -AND -NOT ($isBannerLine -AND $commentText -EQ $SECTION_LINE)) {
            $Findings.Add("$location Section '$($section.Title)' must be closed by a line of '-' below its description.")
            $expecting = $null
        }

        # The table of contents in the header, one entry per line until the first other line.
        if ($expecting -EQ 'toc entry') {
            $moduleTocMatch = [System.Text.RegularExpressions.Regex]::Match([System.String] $commentText, $MODULE_TOC_ENTRY_PATTERN)
            if ($commentMatch.Success -AND $file.Name -EQ $MODULE_TOC_FILE -AND $moduleTocMatch.Success) {
                $ModuleToc.Add([PSCustomObject]@{
                    File  = $moduleTocMatch.Groups['file'].Value
                    Title = $moduleTocMatch.Groups['title'].Value
                })
                continue
            }

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

        # The closing line of a section, it needs a description above.
        if ($body -EQ $SECTION_LINE -AND $expecting -EQ 'section description') {
            if (-NOT $section.HasDescription) {
                $Findings.Add("$location Section '$($section.Title)' must have a description below the title.")
            }
            $expecting = $null
            continue
        }

        # The opening line of a section, the title follows on the next line.
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
            File      = $file.FullName
            Name      = $file.Name
            Folder    = $file.DirectoryName
            Extension = $file.Extension
            Chapters  = $Chapters
            Toc       = $Toc
            ModuleToc = $ModuleToc
        })
    }
}

# ---------------------------------------------------------------------------
# Check structure
#   Tests descriptions, numbered entries and the TOC.
# ---------------------------------------------------------------------------

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

    # A Terraform file is one chapter of its module, main.tf lists them, see Check modules.
    if ($structure.Extension -EQ '.tf') {
        continue
    }

    # Every file with chapters lists them in the header, and the list matches them in order.
    $chapterTitles = @($structure.Chapters | ForEach-Object { $_.Title })
    $hasToc        = $structure.Toc.Count -GT 0

    if (-NOT $hasToc -AND $chapterTitles.Count -GT 0) {
        $Findings.Add("$($structure.File) Header must list the $($chapterTitles.Count) chapters below '$TOC_HEADER', got none.")
        continue
    }
    if ($hasToc -AND (($structure.Toc -join '|') -NE ($chapterTitles -join '|'))) {
        $Findings.Add("$($structure.File) Header lists chapters '$($structure.Toc -join ', ')', but the file has '$($chapterTitles -join ', ')'.")
    }
}

# ---------------------------------------------------------------------------
# Check modules
#   Tests the TOC in main.tf of every Terraform module.
# ---------------------------------------------------------------------------

# Terraform loads a folder as one module, so the folder is the book and main.tf holds its table of contents.
$Modules = $Structures
| Where-Object -Property Extension -EQ '.tf'
| Group-Object -Property Folder

foreach ($module in $Modules) {
    $mainFile = $module.Group | Where-Object -Property Name -EQ $MODULE_TOC_FILE
    if ($null -EQ $mainFile) {
        $Findings.Add("$($module.Name) Module must have a $MODULE_TOC_FILE that lists its files below '$TOC_HEADER'.")
        continue
    }

    # Compared as sorted lists, the reading order of the files is up to the author.
    # - variables.tf with chapter VARIABLES  => 'variables.tf   VARIABLES'
    $expectedEntries = @($module.Group | ForEach-Object { "$($_.Name)   $(($_.Chapters | Select-Object -First 1).Title)" } | Sort-Object)
    $listedEntries   = @($mainFile.ModuleToc | ForEach-Object { "$($_.File)   $($_.Title)" } | Sort-Object)

    if (($expectedEntries -join '|') -NE ($listedEntries -join '|')) {
        $Findings.Add("$($mainFile.File) Header must list every file of the module with its chapter, expected '$($expectedEntries -join ', ')', got '$($listedEntries -join ', ')'.")
    }
}

# ---------------------------------------------------------------------------
# Report
#   Lists all findings and fails when there is one.
# ---------------------------------------------------------------------------

if ($Findings.Count -EQ 0) {
    Write-Host "[Test-StorylineBanner] All banners in $($Files.Count) files follow the format."
    return
}

$Findings | ForEach-Object { Write-Host $_ }
throw [System.InvalidOperationException]::new("$($Findings.Count) banner lines break the format, see the list above.")
