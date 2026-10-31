// NOTE:
//  const { registerOutline } = require('./view.outline.js')
//
//    registerOutline(context)   Outline view, breadcrumbs, Go to Symbol (Ctrl+Shift+O) and folding.

//
//  Chapters:
//    OUTLINE PROVIDERS   Symbols and folding ranges from the banners.
//

// CommonJS on purpose: the VS Code extension host loads CommonJS without a bundler.
'use strict'

const vscode = require('vscode')

const { getBanners, getFlatBanners } = require('../data/_index.js')

const PROVIDER_LABEL = 'Storyline'

// ===========================================================================
// ==========================   OUTLINE PROVIDERS   ==========================
// ===========================================================================
//
//   toSymbol          Turns one banner and its sections into a document symbol.
//   registerOutline   Registers the symbol and folding providers for every file.
//

/**
 * Turns one banner and its sections into a document symbol.
 *
 * @param {vscode.TextDocument} document   (Required) The document the banner belongs to.
 * @param {object}              banner     (Required) A chapter or section from getBanners.
 * @returns {vscode.DocumentSymbol} The symbol, a chapter with its sections as children.
 *
 * @example
 * toSymbol(document, chapter)
 */
function toSymbol(document, banner) {
    const range          = new vscode.Range(banner.startLine, 0, banner.endLine, document.lineAt(banner.endLine).text.length)
    const selectionRange = document.lineAt(banner.titleLine).range
    const kind           = banner.kind === 'chapter' ? vscode.SymbolKind.Namespace : vscode.SymbolKind.Key

    const symbol = new vscode.DocumentSymbol(banner.title, banner.description, kind, range, selectionRange)
    symbol.children = banner.sections.map(section => toSymbol(document, section))
    return symbol
}

/**
 * Registers the symbol and folding providers for every file and untitled document.
 *
 * @param {vscode.ExtensionContext} context   (Required) Holds the registrations.
 * @returns {void}
 *
 * @example
 * registerOutline(context)
 */
function registerOutline(context) {
    const selector = [{ scheme: 'file' }, { scheme: 'untitled' }]

    const symbolProvider = {
        provideDocumentSymbols: document => getBanners(document).map(banner => toSymbol(document, banner)),
    }

    // A chapter folds around its sections, every section folds on its own.
    const foldingProvider = {
        provideFoldingRanges: document => getFlatBanners(document)
            .filter(banner => banner.endLine > banner.startLine)
            .map(banner => new vscode.FoldingRange(banner.startLine, banner.endLine, vscode.FoldingRangeKind.Region)),
    }

    context.subscriptions.push(
        vscode.languages.registerDocumentSymbolProvider(selector, symbolProvider, { label: PROVIDER_LABEL }),
        vscode.languages.registerFoldingRangeProvider(selector, foldingProvider),
    )
}

module.exports = { registerOutline }
