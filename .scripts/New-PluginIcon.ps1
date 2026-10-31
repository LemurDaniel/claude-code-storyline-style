# NOTE:
#   Requires: PowerShell 7 on Windows (System.Drawing).
#
#   ./.scripts/New-PluginIcon.ps1 -OutputPath ./plugins/storyline-code-style/.claude-plugin/icon.png
#
#   The plugin directory takes a square PNG, 512 to 2048 px, under 2 MB. The icon
#   is a chapter banner: three bars, the middle one carries the title.

#
#   Chapters:
#     RENDER PLUGIN ICON   Sets size and colors, draws the icon and saves it.
#

[CmdletBinding()]
param (
    <#
    [Required]
    Where to write the square PNG.
    #>
    [Parameter(
        Mandatory = $true
    )]
    [System.String]
    $OutputPath
)

Set-StrictMode -Version 1.0
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

# ===========================================================================
# =========================   RENDER PLUGIN ICON   ==========================
# ===========================================================================
#
#   1. Settings   Size, margin and colors of the icon.
#   2. Draw       Draws the icon and saves it as PNG.
#

# ---------------------------------------------------------------------------
# Settings
#   Size, margin and colors of the icon.
# ---------------------------------------------------------------------------

$SIZE   = 1024
$MARGIN = 112

$COLOR_BACKGROUND = [System.Drawing.ColorTranslator]::FromHtml('#0d1117')
$COLOR_BANNER     = [System.Drawing.ColorTranslator]::FromHtml('#7ee787')
$COLOR_SECTION    = [System.Drawing.ColorTranslator]::FromHtml('#a5d6ff')
$COLOR_TITLE      = [System.Drawing.ColorTranslator]::FromHtml('#e6edf3')

$BAR_HEIGHT = 56
$BAR_GAP    = 72
$TITLE      = 'STORY'
$FONT_TITLE = [System.Drawing.Font]::new('Cascadia Mono', 150, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)

# ---------------------------------------------------------------------------
# Draw
#   Draws the icon and saves it as PNG.
# ---------------------------------------------------------------------------

$bitmap = [System.Drawing.Bitmap]::new($SIZE, $SIZE)
$bitmap.SetResolution(96, 96)

$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$graphics.Clear($COLOR_BACKGROUND)

$bannerBrush  = [System.Drawing.SolidBrush]::new($COLOR_BANNER)
$sectionBrush = [System.Drawing.SolidBrush]::new($COLOR_SECTION)
$titleBrush   = [System.Drawing.SolidBrush]::new($COLOR_TITLE)

# The three bars of the chapter frame, centered vertically.
$barWidth = $SIZE - 2 * $MARGIN
$frameTop = ($SIZE - (3 * $BAR_HEIGHT + 2 * $BAR_GAP)) / 2 - 60
$graphics.FillRectangle($bannerBrush, $MARGIN, $frameTop, $barWidth, $BAR_HEIGHT)
$graphics.FillRectangle($bannerBrush, $MARGIN, $frameTop + 2 * ($BAR_HEIGHT + $BAR_GAP), $barWidth, $BAR_HEIGHT)

# The middle bar carries the title, the bar is interrupted around it.
$middleTop = $frameTop + $BAR_HEIGHT + $BAR_GAP
$titleSize = $graphics.MeasureString($TITLE, $FONT_TITLE)
$titleX    = ($SIZE - $titleSize.Width) / 2
$sideWidth = $titleX - $MARGIN - 36
$graphics.FillRectangle($bannerBrush, $MARGIN, $middleTop, $sideWidth, $BAR_HEIGHT)
$graphics.FillRectangle($bannerBrush, $SIZE - $MARGIN - $sideWidth, $middleTop, $sideWidth, $BAR_HEIGHT)
$graphics.DrawString($TITLE, $FONT_TITLE, $titleBrush, $titleX, $middleTop + $BAR_HEIGHT / 2 - $titleSize.Height / 2)

# A thin section line below the frame.
$sectionTop = $frameTop + 3 * $BAR_HEIGHT + 2 * $BAR_GAP + 120
$graphics.FillRectangle($sectionBrush, $MARGIN, $sectionTop, $barWidth, 20)

$bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose()
$bitmap.Dispose()

Write-Host "[New-PluginIcon] Wrote $SIZE x $SIZE PNG to '$OutputPath'."
