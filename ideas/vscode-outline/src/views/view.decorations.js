// NOTE:
//  const { registerDecorations } = require('./view.decorations.js')
//
//    registerDecorations(context)   Colored bands behind every banner and marks in the scrollbar.
//
//    Colors are theme colors from package.json (storyline.*), a theme or settings.json can override them:
//      "workbench.colorCustomizations": { "storyline.chapterBackground": "#7ee78740" }

//
//  Chapters:
//    PAINT BANNERS   Decoration types, the ranges per banner and the updates on every change.
//

// CommonJS on purpose: the VS Code extension host loads CommonJS without a bundler.
'use strict'

const vscode = require('vscode')

const { getFlatBanners } = require('../data/_index.js')

// ===========================================================================
// ============================   PAINT BANNERS   ============================
// ===========================================================================
//
//   1. Types     One decoration type per part: chapter frame, chapter title, section block, section title.
//   2. Ranges    Sorts the lines of every banner into the four parts.
//   3. Updates   Repaints the visible editors on every switch and edit.
//

/**
 * Registers the decoration types and repaints every visible editor on switch and edit.
 *
 * @param {vscode.ExtensionContext} context   (Required) Holds the decoration types and the listeners.
 * @returns {void}
 *
 * @example
 * registerDecorations(context)
 */
function registerDecorations(context) {

    // ---------------------------------------------------------------------------
    // Types
    //   One decoration type per part: chapter frame, chapter title, section block, section title.
    // ---------------------------------------------------------------------------

    // Chapter: strong band, mark over the full width of the scrollbar.
    const chapterBand = {
        isWholeLine: true,
        backgroundColor: new vscode.ThemeColor('storyline.chapterBackground'),
        overviewRulerColor: new vscode.ThemeColor('storyline.chapterRuler'),
        overviewRulerLane: vscode.OverviewRulerLane.Full,
    }
    // Section: light band, small mark on the right of the scrollbar.
    const sectionBand = {
        isWholeLine: true,
        backgroundColor: new vscode.ThemeColor('storyline.sectionBackground'),
        overviewRulerColor: new vscode.ThemeColor('storyline.sectionRuler'),
        overviewRulerLane: vscode.OverviewRulerLane.Right,
    }

    const types = {
        chapterFrame: vscode.window.createTextEditorDecorationType(chapterBand),
        chapterTitle: vscode.window.createTextEditorDecorationType({ ...chapterBand, fontWeight: 'bold' }),
        sectionBlock: vscode.window.createTextEditorDecorationType(sectionBand),
        sectionTitle: vscode.window.createTextEditorDecorationType({ ...sectionBand, fontWeight: 'bold' }),
    }
    context.subscriptions.push(...Object.values(types))

    // ---------------------------------------------------------------------------
    // Ranges
    //   Sorts the lines of every banner into the four parts.
    // ---------------------------------------------------------------------------

    /**
     * Paints the banners of one editor.
     *
     * @param {vscode.TextEditor} editor   (Required) A visible editor.
     * @returns {void}
     */
    function paint(editor) {
        const ranges = { chapterFrame: [], chapterTitle: [], sectionBlock: [], sectionTitle: [] }
        const toRange = line => new vscode.Range(line, 0, line, 0)

        // A chapter is three lines: frame, title, frame. A section runs from its frame to its closing frame.
        // - chapter at 98 => frame 98, title 99, frame 100
        // - section at 107 with closing frame at 110 => block 107, title 108, block 109 and 110
        for (const banner of getFlatBanners(editor.document)) {
            const isChapter = banner.kind === 'chapter'
            for (let line = banner.startLine; line <= banner.frameEndLine; line++) {
                const isTitle = line === banner.titleLine
                const part = isChapter
                    ? (isTitle ? 'chapterTitle' : 'chapterFrame')
                    : (isTitle ? 'sectionTitle' : 'sectionBlock')
                ranges[part].push(toRange(line))
            }
        }

        for (const [part, type] of Object.entries(types)) {
            editor.setDecorations(type, ranges[part])
        }
    }

    // ---------------------------------------------------------------------------
    // Updates
    //   Repaints the visible editors on every switch and edit.
    // ---------------------------------------------------------------------------

    const paintVisible = () => vscode.window.visibleTextEditors.forEach(paint)

    context.subscriptions.push(
        vscode.window.onDidChangeVisibleTextEditors(paintVisible),
        vscode.workspace.onDidChangeTextDocument(event => vscode.window.visibleTextEditors
            .filter(editor => editor.document === event.document)
            .forEach(paint)),
    )
    paintVisible()
}

module.exports = { registerDecorations }
