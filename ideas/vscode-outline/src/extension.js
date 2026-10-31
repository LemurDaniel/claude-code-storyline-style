// NOTE:
//  Entry point of the extension, VS Code calls activate() once after startup.
//
//    Editor        colored bands behind every chapter and section, marks in the scrollbar.
//    CodeLens      above every chapter: position, sections, previous and next chapter.
//    Explorer      "Storyline" view below the files, the tree follows the cursor.
//    Status bar    "CHAPTER › Section" of the cursor, a click opens the quick pick.
//    Outline       Outline view, breadcrumbs, Ctrl+Shift+O and folding.

//
//  Chapters:
//    ACTIVATE EXTENSION   Registers every view and command.
//

// CommonJS on purpose: the VS Code extension host loads CommonJS without a bundler.
'use strict'

const vscode = require('vscode')

const { registerCommands } = require('./commands/commands.banners.js')
const { clearBanners } = require('./data/_index.js')
const views = require('./views/_index.js')

const EXTENSION_NAME = 'Storyline Outline'

// ===========================================================================
// =========================   ACTIVATE EXTENSION   ==========================
// ===========================================================================
//
//   activate   Registers the commands first, the views call them.
//

/**
 * Registers every view and command of the extension.
 *
 * @param {vscode.ExtensionContext} context   (Required) Holds every registration, VS Code disposes them on deactivate.
 * @returns {void}
 *
 * @example
 * activate(context)   // called by VS Code, see activationEvents in package.json
 */
function activate(context) {
    const log = vscode.window.createOutputChannel(EXTENSION_NAME, { log: true })
    context.subscriptions.push(log)

    registerCommands(context)
    views.forEach(registerView => registerView(context))

    context.subscriptions.push(vscode.workspace.onDidCloseTextDocument(clearBanners))
    log.info(`[${EXTENSION_NAME}] Registered decorations, CodeLens, side bar, status bar, outline and commands.`)
}

module.exports = { activate }
