# NOTE:
#   Requires: PowerShell 7 on Windows (System.Drawing).
#
#   ./.scripts/New-SocialPreview.ps1 -OutputPath ./.github/social-preview.png
#
#   Upload the result under GitHub -> Settings -> General -> Social preview.

[CmdletBinding()]
param (
    <#
    [Required]
    Where to write the 1280x640 PNG.
    #>
    [Parameter(
        Mandatory = $true
    )]
    [System.String]
    $OutputPath
)

Add-Type -AssemblyName System.Drawing

# ---------------------------------------------------------------------------
# Settings

$WIDTH  = 1280
$HEIGHT = 640

$COLOR_BACKGROUND = [System.Drawing.ColorTranslator]::FromHtml('#0d1117')
$COLOR_PANEL      = [System.Drawing.ColorTranslator]::FromHtml('#161b22')
$COLOR_BORDER     = [System.Drawing.ColorTranslator]::FromHtml('#30363d')
$COLOR_TITLE      = [System.Drawing.ColorTranslator]::FromHtml('#e6edf3')
$COLOR_MUTED      = [System.Drawing.ColorTranslator]::FromHtml('#8b949e')
$COLOR_BANNER     = [System.Drawing.ColorTranslator]::FromHtml('#7ee787')
$COLOR_COMMENT    = [System.Drawing.ColorTranslator]::FromHtml('#a5d6ff')
$COLOR_CODE       = [System.Drawing.ColorTranslator]::FromHtml('#d2a8ff')

$FONT_TITLE    = [System.Drawing.Font]::new('Segoe UI', 58, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$FONT_SUBTITLE = [System.Drawing.Font]::new('Segoe UI', 27, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$FONT_CODE     = [System.Drawing.Font]::new('Cascadia Mono', 17, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)

# The code sample is a real chapter banner from the style, 75 characters wide.
$CODE_LINES = @(
    @{ Text = '# ==========================================================================='; Color = $COLOR_BANNER }
    @{ Text = '# ======================   LOAD AND VALIDATE SECRETS   ======================'; Color = $COLOR_BANNER }
    @{ Text = '# ==========================================================================='; Color = $COLOR_BANNER }
    @{ Text = '#'; Color = $COLOR_COMMENT }
    @{ Text = '#   1. Context       Switches to the given subscription, keeps the previous one.'; Color = $COLOR_COMMENT }
    @{ Text = '#   2. Validations   Fails early on equal or missing Key Vaults.'; Color = $COLOR_COMMENT }
    @{ Text = '#   3. Secrets       Loads all enabled secrets of the source.'; Color = $COLOR_COMMENT }
    @{ Text = '#'; Color = $COLOR_COMMENT }
    @{ Text = ''; Color = $COLOR_COMMENT }
    @{ Text = '# ---------------------------------------------------------------------------'; Color = $COLOR_BANNER }
    @{ Text = '# Context'; Color = $COLOR_COMMENT }
    @{ Text = ''; Color = $COLOR_COMMENT }
    @{ Text = '$PreviousContext = Get-AzContext'; Color = $COLOR_CODE }
)

# ---------------------------------------------------------------------------
# Draw

$bitmap   = [System.Drawing.Bitmap]::new($WIDTH, $HEIGHT)
$bitmap.SetResolution(96, 96)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
$graphics.Clear($COLOR_BACKGROUND)

# Title and tagline on the left.
$titleBrush = [System.Drawing.SolidBrush]::new($COLOR_TITLE)
$mutedBrush = [System.Drawing.SolidBrush]::new($COLOR_MUTED)
$graphics.DrawString('Storyline Code Style', $FONT_TITLE, $titleBrush, 60, 70)
$graphics.DrawString('A code style skill for Claude Code.', $FONT_SUBTITLE, $mutedBrush, 64, 150)
$graphics.DrawString('Every file reads top to bottom like a story.', $FONT_SUBTITLE, $mutedBrush, 64, 188)

# Code panel below, like an editor window.
$panel = [System.Drawing.Rectangle]::new(60, 260, $WIDTH - 120, $HEIGHT - 320)
$graphics.FillRectangle([System.Drawing.SolidBrush]::new($COLOR_PANEL), $panel)
$graphics.DrawRectangle([System.Drawing.Pen]::new($COLOR_BORDER, 2), $panel)

$lineHeight = 23
$y = $panel.Y + 18
foreach ($line in $CODE_LINES) {
    $graphics.DrawString($line.Text, $FONT_CODE, [System.Drawing.SolidBrush]::new($line.Color), $panel.X + 24, $y)
    $y += $lineHeight
}

# Footer with the languages.
$graphics.DrawString('PowerShell  ·  Terraform  ·  Bicep  ·  GitHub Actions  ·  Azure DevOps  ·  Docker Compose  ·  JavaScript  ·  C++', [System.Drawing.Font]::new('Segoe UI', 19, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel), $mutedBrush, 64, $HEIGHT - 44)

$bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose()
$bitmap.Dispose()

Write-Host "[New-SocialPreview] Wrote $WIDTH x $HEIGHT PNG to '$OutputPath'."
