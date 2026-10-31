// NOTE:
//  const { getBanners, findCurrentBanners, revealBanner } = require('../data/banners.js')
//
//    Every view asks here, so a document is parsed once per version and not once per view.

//
//  Chapters:
//    READ BANNERS   Parsed banners per document version, the banner at the cursor and the jump to a banner.
//

// CommonJS on purpose: the VS Code extension host loads CommonJS without a bundler.
'use strict'

const vscode = require('vscode')

const { parseBanners } = require('../utils/banners.parse.js')

// Snippets in Markdown are excerpts, their banners would clutter every view.
const EXCLUDED_LANGUAGES = ['markdown']

// Document URI => { version, banners }, an edit raises the version and so parses again.
const cache = new Map()

// ===========================================================================
// ============================   READ BANNERS   =============================
// ===========================================================================
//
//   getBanners           Top-level banners of a document, chapters hold their sections.
//   getFlatBanners       Chapters and sections in one list in line order.
//   findCurrentBanners   The chapter and section the cursor stands in.
//   revealBanner         Moves the cursor to a banner and scrolls it to the top.
//   clearBanners         Drops a closed document from the cache.
//

/**
 * Returns the top-level banners of a document, parsed once per document version.
 *
 * @param {vscode.TextDocument} document   (Required) The document to read.
 * @returns {object[]} Chapters with their sections, plus sections before the first chapter. Empty for Markdown.
 *
 * @example
 * getBanners(vscode.window.activeTextEditor.document)
 */
function getBanners(document) {
    if (null == document || EXCLUDED_LANGUAGES.includes(document.languageId)) return []

    const key    = document.uri.toString()
    const cached = cache.get(key)
    if (cached?.version === document.version) return cached.banners

    const banners = parseBanners(document.getText().split(/\r?\n/))
    cache.set(key, { version: document.version, banners })
    return banners
}

/**
 * Returns chapters and sections in one list, in the order they stand in the document.
 *
 * @param {vscode.TextDocument} document   (Required) The document to read.
 * @returns {object[]} Every banner once.
 *
 * @example
 * getFlatBanners(document).map(banner => banner.title)   // ['LOAD AND VALIDATE SECRETS', 'Context', ...]
 */
function getFlatBanners(document) {
    // - [{ CHAPTER, sections: [A, B] }] => [CHAPTER, A, B]
    return getBanners(document).flatMap(banner => [banner, ...banner.sections])
}

/**
 * Finds the chapter and section a line belongs to.
 *
 * @param {vscode.TextDocument} document   (Required) The document to read.
 * @param {number}              line       (Required) The zero-based line, usually the cursor line.
 * @returns {{ chapter: object|null, section: object|null }} Null where the line stands before every banner.
 *
 * @example
 * findCurrentBanners(document, editor.selection.active.line)
 */
function findCurrentBanners(document, line) {
    const topLevel = getBanners(document).findLast(banner => banner.startLine <= line)
    if (null == topLevel) return { chapter: null, section: null }

    // A section before the first chapter (the header of a YAML file) has no chapter.
    if (topLevel.kind === 'section') return { chapter: null, section: topLevel }

    const section = topLevel.sections.findLast(candidate => candidate.startLine <= line) ?? null
    return { chapter: topLevel, section }
}

/**
 * Moves the cursor to the title of a banner and scrolls the banner to the top of the editor.
 *
 * @param {vscode.TextEditor} editor   (Required) The editor that shows the document of the banner.
 * @param {object}            banner   (Required) A chapter or section from getBanners.
 * @returns {void}
 *
 * @example
 * revealBanner(vscode.window.activeTextEditor, chapter)
 */
function revealBanner(editor, banner) {
    if (null == editor || null == banner) return

    const titlePosition = new vscode.Position(banner.titleLine, 0)
    editor.selection = new vscode.Selection(titlePosition, titlePosition)
    editor.revealRange(new vscode.Range(banner.startLine, 0, banner.startLine, 0), vscode.TextEditorRevealType.AtTop)
}

/**
 * Drops a document from the cache, called when it is closed.
 *
 * @param {vscode.TextDocument} document   (Required) The closed document.
 * @returns {void}
 *
 * @example
 * vscode.workspace.onDidCloseTextDocument(clearBanners)
 */
function clearBanners(document) {
    cache.delete(document.uri.toString())
}

module.exports = { getBanners, getFlatBanners, findCurrentBanners, revealBanner, clearBanners }
