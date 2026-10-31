# NOTE:
#   Requires: PowerShell 7 on Windows (System.Drawing, fonts Segoe UI and Cascadia Mono).
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
$MARGIN = 60

# GitHub dark theme colors.
$COLOR_BACKGROUND = [System.Drawing.ColorTranslator]::FromHtml('#0d1117')
$COLOR_PANEL      = [System.Drawing.ColorTranslator]::FromHtml('#161b22')
$COLOR_BORDER     = [System.Drawing.ColorTranslator]::FromHtml('#30363d')
$COLOR_TITLE      = [System.Drawing.ColorTranslator]::FromHtml('#e6edf3')
$COLOR_MUTED      = [System.Drawing.ColorTranslator]::FromHtml('#8b949e')
$COLOR_BANNER     = [System.Drawing.ColorTranslator]::FromHtml('#7ee787')
$COLOR_COMMENT    = [System.Drawing.ColorTranslator]::FromHtml('#a5d6ff')
$COLOR_CODE       = [System.Drawing.ColorTranslator]::FromHtml('#d2a8ff')
$COLOR_LABEL      = [System.Drawing.ColorTranslator]::FromHtml('#f0883e')

# Sizes in pixels, so the system DPI scaling does not change the result.
$FONT_TITLE    = [System.Drawing.Font]::new('Segoe UI', 58, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$FONT_SUBTITLE = [System.Drawing.Font]::new('Segoe UI', 25, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$FONT_CAPTION  = [System.Drawing.Font]::new('Segoe UI', 17, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$FONT_SMALL    = [System.Drawing.Font]::new('Segoe UI', 14, [System.Drawing.FontStyle]::Italic, [System.Drawing.GraphicsUnit]::Pixel)
$FONT_NOTICE   = [System.Drawing.Font]::new('Segoe UI', 20, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$FONT_EMOJI    = [System.Drawing.Font]::new('Segoe UI Emoji', 26, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$FONT_CODE     = [System.Drawing.Font]::new('Cascadia Mono', 15, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$LINE_HEIGHT   = 22

# The library on the left: a folder tree with the shelf, its label and the books.
$LIBRARY_LINES = @(
    @{ Text = 'src/';                           Color = $COLOR_TITLE;   Note = 'library' }
    @{ Text = '├─ keyvault/';                   Color = $COLOR_TITLE;   Note = 'shelf' }
    @{ Text = '│  ├─ README.md';                Color = $COLOR_LABEL;   Note = 'shelf label' }
    @{ Text = '│  ├─ Move-KeyVaultSecret.ps1';  Color = $COLOR_BANNER;  Note = 'book' }
    @{ Text = '│  └─ Get-KeyVaultSecret.ps1';   Color = $COLOR_COMMENT; Note = 'book' }
    @{ Text = '└─ storage/';                    Color = $COLOR_TITLE;   Note = 'shelf' }
    @{ Text = '   ├─ README.md';                Color = $COLOR_LABEL;   Note = 'shelf label' }
    @{ Text = '   └─ Sync-StorageFile.ps1';     Color = $COLOR_COMMENT; Note = 'book' }
)

# The open book on the right: a real chapter banner from the style, 75 characters wide.
$BOOK_LINES = @(
    @{ Text = '# ==========================================================================='; Color = $COLOR_BANNER }
    @{ Text = '# ======================   LOAD AND VALIDATE SECRETS   ======================'; Color = $COLOR_BANNER }
    @{ Text = '# ==========================================================================='; Color = $COLOR_BANNER }
    @{ Text = '#'; Color = $COLOR_COMMENT }
    @{ Text = '#   1. Context       Switches to the given subscription.'; Color = $COLOR_COMMENT }
    @{ Text = '#   2. Validations   Fails early on equal or missing Key Vaults.'; Color = $COLOR_COMMENT }
    @{ Text = '#   3. Secrets       Loads all enabled secrets of the source.'; Color = $COLOR_COMMENT }
    @{ Text = '#'; Color = $COLOR_COMMENT }
    @{ Text = ''; Color = $COLOR_COMMENT }
    @{ Text = '# ---------------------------------------------------------------------------'; Color = $COLOR_BANNER }
    @{ Text = '# Context'; Color = $COLOR_COMMENT }
    @{ Text = ''; Color = $COLOR_COMMENT }
    @{ Text = '$PreviousContext = Get-AzContext'; Color = $COLOR_CODE }
)

$LANGUAGES = 'PowerShell  ·  Terraform  ·  Bicep  ·  GitHub Actions  ·  Azure DevOps  ·  Docker Compose  ·  JavaScript  ·  C++'
$AI_NOTICE = 'AI generated artwork'
$AI_ICON   = [System.Char]::ConvertFromUtf32(0x1F916)   # robot face

# ---------------------------------------------------------------------------
# Draw

$bitmap = [System.Drawing.Bitmap]::new($WIDTH, $HEIGHT)
$bitmap.SetResolution(96, 96)

$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
$graphics.Clear($COLOR_BACKGROUND)

$titleBrush = [System.Drawing.SolidBrush]::new($COLOR_TITLE)
$mutedBrush = [System.Drawing.SolidBrush]::new($COLOR_MUTED)
$panelBrush = [System.Drawing.SolidBrush]::new($COLOR_PANEL)
$borderPen  = [System.Drawing.Pen]::new($COLOR_BORDER, 2)

# AI notice with a robot icon in the top right corner.
$noticeSize = $graphics.MeasureString($AI_NOTICE, $FONT_NOTICE)
$iconSize   = $graphics.MeasureString($AI_ICON, $FONT_EMOJI)
$noticeX    = $WIDTH - $MARGIN - $noticeSize.Width
$graphics.DrawString($AI_ICON, $FONT_EMOJI, $mutedBrush, $noticeX - $iconSize.Width - 4, 44)
$graphics.DrawString($AI_NOTICE, $FONT_NOTICE, $mutedBrush, $noticeX, 50)

# Title and tagline.
$graphics.DrawString('Storyline Code Style', $FONT_TITLE, $titleBrush, $MARGIN, 50)
$graphics.DrawString('A code style skill for Claude Code. Every file reads top to bottom like a story.', $FONT_SUBTITLE, $mutedBrush, $MARGIN + 4, 128)
$graphics.DrawString('The codebase is a library, a folder is a shelf, a file is a book.', $FONT_SUBTITLE, $mutedBrush, $MARGIN + 4, 162)

# Two panels: the library on the left, the open book on the right.
$panelTop    = 230
$panelHeight = 340
$libraryPanel = [System.Drawing.Rectangle]::new($MARGIN, $panelTop, 400, $panelHeight)
$bookPanel    = [System.Drawing.Rectangle]::new($libraryPanel.Right + 24, $panelTop, $WIDTH - $MARGIN - $libraryPanel.Right - 24, $panelHeight)

foreach ($panel in @($libraryPanel, $bookPanel)) {
    $graphics.FillRectangle($panelBrush, $panel)
    $graphics.DrawRectangle($borderPen, $panel)
}

# Library: tree on the left of the panel, the role of each line on the right.
$graphics.DrawString('The library', $FONT_CAPTION, $mutedBrush, $libraryPanel.X + 16, $libraryPanel.Y + 12)
$y = $libraryPanel.Y + 48
foreach ($line in $LIBRARY_LINES) {
    $graphics.DrawString($line.Text, $FONT_CODE, [System.Drawing.SolidBrush]::new($line.Color), $libraryPanel.X + 16, $y)
    $graphics.DrawString($line.Note, $FONT_SMALL, $mutedBrush, $libraryPanel.Right - 110, $y + 3)
    $y += $LINE_HEIGHT + 8
}

# Book: the chapter of the highlighted file.
$graphics.DrawString('The book: Move-KeyVaultSecret.ps1', $FONT_CAPTION, $mutedBrush, $bookPanel.X + 16, $bookPanel.Y + 12)
$y = $bookPanel.Y + 48
foreach ($line in $BOOK_LINES) {
    $graphics.DrawString($line.Text, $FONT_CODE, [System.Drawing.SolidBrush]::new($line.Color), $bookPanel.X + 16, $y)
    $y += $LINE_HEIGHT
}

# Footer: the languages.
$graphics.DrawString($LANGUAGES, $FONT_CAPTION, $mutedBrush, $MARGIN + 4, $HEIGHT - 48)

$bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose()
$bitmap.Dispose()

Write-Host "[New-SocialPreview] Wrote $WIDTH x $HEIGHT PNG to '$OutputPath'."
