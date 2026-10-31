// NOTE:
//  const { registerCodeLens } = require('./view.codelens.js')
//
//    registerCodeLens(context)   One line above every chapter: position, sections, previous and next chapter.

//
//  Chapters:
//    CHAPTER LENSES   The CodeLens provider for the chapter banners.
//

// CommonJS on purpose: the VS Code extension host loads CommonJS without a bundler.
'use strict'

const vscode = require('vscode')

const { getBanners } = require('../data/_index.js')

// ===========================================================================
// ===========================   CHAPTER LENSES   ============================
// ===========================================================================
//
//   toLenses           The lenses of one chapter: position, sections, previous, next.
//   registerCodeLens   Registers the provider for every file.
//

/**
 * Builds the lenses above one chapter.
 *
 * @param {object[]} chapters   (Required) Every chapter of the document, in line order.
 * @param {number}   position   (Required) The index of the chapter in chapters.
 * @returns {vscode.CodeLens[]} 'Chapter 1/2 · 3 sections', then '↑ previous' and '↓ next' where they exist.
 *
 * @example
 * toLenses(chapters, 0)   // [Chapter 1/2 · 3 sections, ↓ MOVE SECRETS]
 */
function toLenses(chapters, position) {
    const chapter  = chapters[position]
    const range    = new vscode.Range(chapter.startLine, 0, chapter.startLine, 0)
    const previous = chapters[position - 1]
    const next     = chapters[position + 1]

    const sectionCount = chapter.sections.length === 1 ? '1 section' : `${chapter.sections.length} sections`
    const lenses = [
        new vscode.CodeLens(range, { title: `Chapter ${position + 1}/${chapters.length} · ${sectionCount}`, command: 'storyline.goToBanner' }),
    ]
    if (null != previous) {
        lenses.push(new vscode.CodeLens(range, { title: `↑ ${previous.title}`, command: 'storyline.revealBanner', arguments: [previous] }))
    }
    if (null != next) {
        lenses.push(new vscode.CodeLens(range, { title: `↓ ${next.title}`, command: 'storyline.revealBanner', arguments: [next] }))
    }
    return lenses
}

/**
 * Registers the CodeLens provider for every file and untitled document.
 *
 * @param {vscode.ExtensionContext} context   (Required) Holds the registration.
 * @returns {void}
 *
 * @example
 * registerCodeLens(context)
 */
function registerCodeLens(context) {
    const selector = [{ scheme: 'file' }, { scheme: 'untitled' }]

    const provider = {
        provideCodeLenses: document => {
            const chapters = getBanners(document).filter(banner => banner.kind === 'chapter')
            return chapters.flatMap((chapter, position) => toLenses(chapters, position))
        },
    }

    context.subscriptions.push(vscode.languages.registerCodeLensProvider(selector, provider))
}

module.exports = { registerCodeLens }
