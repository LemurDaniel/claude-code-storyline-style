// NOTE:
//  const { registerStatusBar } = require('./view.statusbar.js')
//
//    registerStatusBar(context)   Shows "CHAPTER › Section" of the cursor, a click opens the quick pick.

//
//  Chapters:
//    STATUS BAR   The item with the banner at the cursor.
//

// CommonJS on purpose: the VS Code extension host loads CommonJS without a bundler.
'use strict'

const vscode = require('vscode')

const { findCurrentBanners } = require('../data/_index.js')

// Left side, right of the git branch and the problems.
const STATUS_BAR_PRIORITY = 50

// ===========================================================================
// =============================   STATUS BAR   ==============================
// ===========================================================================
//
//   registerStatusBar   Creates the item and updates it on every editor switch, edit and cursor move.
//

/**
 * Creates the status bar item and updates it on every editor switch, edit and cursor move.
 *
 * @param {vscode.ExtensionContext} context   (Required) Holds the item and the listeners.
 * @returns {void}
 *
 * @example
 * registerStatusBar(context)
 */
function registerStatusBar(context) {
    const item = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, STATUS_BAR_PRIORITY)
    item.command = 'storyline.goToBanner'
    item.tooltip = 'Go to chapter or section'

    // Hidden in files without banners, so the item only shows up where it has something to say.
    // - chapter and section => '$(book) LOAD AND VALIDATE SECRETS › Validations'
    // - YAML header only    => '$(book) Default Values'
    const update = () => {
        const editor = vscode.window.activeTextEditor
        const { chapter, section } = null == editor
            ? { chapter: null, section: null }
            : findCurrentBanners(editor.document, editor.selection.active.line)

        const parts = [chapter?.title, section?.title].filter(title => null != title)
        if (parts.length === 0) {
            item.hide()
            return
        }
        item.text = `$(book) ${parts.join(' › ')}`
        item.show()
    }

    context.subscriptions.push(
        item,
        vscode.window.onDidChangeActiveTextEditor(update),
        vscode.window.onDidChangeTextEditorSelection(update),
        vscode.workspace.onDidChangeTextDocument(update),
    )
    update()
}

module.exports = { registerStatusBar }
