// NOTE:
//  const { registerCommands } = require('./commands.banners.js')
//
//    storyline.goToBanner       Quick pick of every chapter and section (click on the status bar).
//    storyline.nextBanner       Jumps to the next banner (Ctrl+Alt+PageDown).
//    storyline.previousBanner   Jumps to the previous banner (Ctrl+Alt+PageUp).
//    storyline.revealBanner     Jumps to one banner, used by the library tree and the CodeLens.

//
//  Chapters:
//    JUMP COMMANDS   The four commands that move the cursor to a banner.
//

// CommonJS on purpose: the VS Code extension host loads CommonJS without a bundler.
'use strict'

const vscode = require('vscode')

const { getFlatBanners, findCurrentBanners, revealBanner } = require('../data/_index.js')

// ===========================================================================
// ============================   JUMP COMMANDS   ============================
// ===========================================================================
//
//   goToBanner            Shows every banner in a quick pick, the current one preselected.
//   jumpBanner            Jumps to the next or previous banner from the cursor.
//   openAndRevealBanner   Jumps to a banner, opens its file first when needed.
//   registerCommands      Registers the four commands.
//

/**
 * Shows every chapter and section of the active editor in a quick pick and jumps to the picked one.
 *
 * @returns {Promise<void>} Resolves when the pick is done or cancelled.
 *
 * @example
 * await vscode.commands.executeCommand('storyline.goToBanner')
 */
async function goToBanner() {
    const editor = vscode.window.activeTextEditor
    if (null == editor) return

    const banners = getFlatBanners(editor.document)
    if (banners.length === 0) {
        vscode.window.showInformationMessage('No chapters or sections in this file.')
        return
    }

    // Sections indented below their chapter, the description on the right.
    const items = banners.map(banner => ({
        label: banner.kind === 'chapter' ? `$(book) ${banner.title}` : `      $(bookmark) ${banner.title}`,
        description: banner.description,
        banner,
    }))

    const { chapter, section } = findCurrentBanners(editor.document, editor.selection.active.line)
    const current = items.find(item => item.banner === (section ?? chapter))

    const quickPick = vscode.window.createQuickPick()
    quickPick.items = items
    quickPick.placeholder = 'Go to chapter or section'
    quickPick.matchOnDescription = true
    quickPick.activeItems = null == current ? [] : [current]

    const picked = await new Promise(resolve => {
        quickPick.onDidAccept(() => resolve(quickPick.selectedItems[0]))
        quickPick.onDidHide(() => resolve(undefined))
        quickPick.show()
    })
    quickPick.dispose()

    revealBanner(editor, picked?.banner)
}

/**
 * Jumps from the cursor to the next or the previous banner title.
 *
 * @param {number} direction   (Required) 1 for the next banner, -1 for the previous one.
 * @returns {void}
 *
 * @example
 * jumpBanner(1)
 */
function jumpBanner(direction) {
    const editor = vscode.window.activeTextEditor
    if (null == editor) return

    const line    = editor.selection.active.line
    const banners = getFlatBanners(editor.document)
    const target  = direction > 0
        ? banners.find(banner => banner.titleLine > line)
        : banners.findLast(banner => banner.titleLine < line)

    revealBanner(editor, target)
}

/**
 * Jumps to a banner, opens its file first when it is not the active one (a book in the library tree).
 *
 * @param {object}     banner   (Required) A chapter or section from getBanners or readBookBanners.
 * @param {vscode.Uri} [uri]    (Optional) The file of the banner. Defaults to the active editor.
 * @returns {Promise<void>} Resolves when the cursor stands on the banner.
 *
 * @example
 * await openAndRevealBanner(section, vscode.Uri.file('/repo/examples/powershell/Get-UtilsConfig.ps1'))
 */
async function openAndRevealBanner(banner, uri) {
    const activeEditor = vscode.window.activeTextEditor
    const isActive     = null == uri || activeEditor?.document.uri.toString() === uri.toString()

    const editor = isActive ? activeEditor : await vscode.window.showTextDocument(uri)
    revealBanner(editor, banner)
}

/**
 * Registers the four jump commands.
 *
 * @param {vscode.ExtensionContext} context   (Required) Holds the registrations.
 * @returns {void}
 *
 * @example
 * registerCommands(context)
 */
function registerCommands(context) {
    context.subscriptions.push(
        vscode.commands.registerCommand('storyline.goToBanner', goToBanner),
        vscode.commands.registerCommand('storyline.nextBanner', () => jumpBanner(1)),
        vscode.commands.registerCommand('storyline.previousBanner', () => jumpBanner(-1)),
        vscode.commands.registerCommand('storyline.revealBanner', openAndRevealBanner),
    )
}

module.exports = { registerCommands }
