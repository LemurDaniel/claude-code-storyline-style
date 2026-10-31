// NOTE:
//  const { buildLibrary, readBookBanners } = require('./library.js')
//
//    buildLibrary()          The workspace as library: shelves (folders) and books (source files).
//    readBookBanners(uri)    The chapters and sections of one book, live for an open document.

//
//  Chapters:
//    BUILD LIBRARY   Shelves, books, shelf labels and the banners of a book.
//

// CommonJS on purpose: the VS Code extension host loads CommonJS without a bundler.
'use strict'

const path = require('node:path')
const vscode = require('vscode')

const { parseBanners } = require('../utils/banners.parse.js')
const { getBanners } = require('./banners.js')

// Books are source files, Markdown and assets do not stand on the shelves.
const SOURCE_EXTENSIONS = ['ps1', 'psm1', 'tf', 'tfvars', 'hcl', 'bicep', 'bicepparam', 'yaml', 'yml', 'js', 'h', 'cpp']
const BOOK_GLOB         = `**/*.{${SOURCE_EXTENSIONS.join(',')}}`
const EXCLUDE_GLOB      = '**/{node_modules,.git,.terraform}/**'
const MAX_BOOKS         = 5000

// A shelf without README.md is labeled by its entry point.
const ENTRY_POINT_NAMES      = ['_index.js', 'main.tf', 'main.bicep']
const ENTRY_POINT_EXTENSIONS = ['.psm1']

// ===========================================================================
// ============================   BUILD LIBRARY   ============================
// ===========================================================================
//
//   readShelfLabel    The first heading of the README.md, else the entry point of a folder.
//   buildLibrary      Every workspace folder as library with its shelves and books.
//   readBookBanners   The chapters and sections of one book.
//

/**
 * Reads the label of a shelf: the first heading of its README.md, else the name of its entry point.
 *
 * @param {vscode.Uri} folderUri   (Required) The folder of the shelf.
 * @returns {Promise<string>} The label, '' when the shelf has none.
 *
 * @example
 * await readShelfLabel(vscode.Uri.file('/repo/examples/powershell'))   // 'PowerShell examples'
 */
async function readShelfLabel(folderUri) {
    const entries = await vscode.workspace.fs.readDirectory(folderUri)
    const names   = entries
        .filter(([, type]) => type === vscode.FileType.File)
        .map(([name]) => name)

    if (names.includes('README.md')) {
        const text = Buffer.from(await vscode.workspace.fs.readFile(vscode.Uri.joinPath(folderUri, 'README.md'))).toString('utf-8')
        // '# PowerShell examples\n| File | Content |' => 'PowerShell examples'
        const heading = /^#\s+(.+)$/m.exec(text)
        if (null != heading) return heading[1].trim()
    }

    return names.find(name => ENTRY_POINT_NAMES.includes(name) || ENTRY_POINT_EXTENSIONS.includes(path.extname(name))) ?? ''
}

/**
 * Builds the library of every workspace folder: shelves for the folders, books for the source files.
 *
 * Folders without a source file anywhere below do not show up.
 *
 * @returns {Promise<{ roots: object[], nodes: Map<string, object> }>}
 *          The libraries and every node by key: { type, key, uri, name, description, parentKey, childKeys }.
 *
 * @example
 * const { roots, nodes } = await buildLibrary()
 */
async function buildLibrary() {
    const nodes = new Map()
    const roots = []
    const addNode = node => {
        nodes.set(node.key, node)
        nodes.get(node.parentKey)?.childKeys.push(node.key)
        return node
    }

    for (const folder of vscode.workspace.workspaceFolders ?? []) {
        roots.push(addNode({ type: 'library', key: folder.uri.toString(), uri: folder.uri, name: folder.name, description: '', parentKey: null, childKeys: [] }))
    }

    // One shelf per folder on the way to a book.
    // - 'examples/powershell/Move-KeyVaultSecret.ps1' => shelves 'examples', 'examples/powershell', book 'Move-KeyVaultSecret.ps1'
    const files = await vscode.workspace.findFiles(BOOK_GLOB, EXCLUDE_GLOB, MAX_BOOKS)
    for (const file of files) {
        const folder = vscode.workspace.getWorkspaceFolder(file)
        if (null == folder) continue

        const segments = path.relative(folder.uri.fsPath, file.fsPath).split(path.sep)
        let parent = nodes.get(folder.uri.toString())
        for (const segment of segments.slice(0, -1)) {
            const uri = vscode.Uri.joinPath(parent.uri, segment)
            parent = nodes.get(uri.toString())
                ?? addNode({ type: 'shelf', key: uri.toString(), uri, name: segment, description: '', parentKey: parent.key, childKeys: [] })
        }
        addNode({ type: 'book', key: file.toString(), uri: file, name: segments.at(-1), description: '', parentKey: parent.key, childKeys: [] })
    }

    // Shelves first, then books, each in alphabetical order, like the file explorer.
    const order = { shelf: 0, book: 1 }
    for (const node of nodes.values()) {
        node.childKeys.sort((leftKey, rightKey) => {
            const left  = nodes.get(leftKey)
            const right = nodes.get(rightKey)
            return order[left.type] - order[right.type] || left.name.localeCompare(right.name)
        })
    }

    const labeled = [...nodes.values()].filter(node => node.type !== 'book')
    await Promise.all(labeled.map(async node => {
        node.description = await readShelfLabel(node.uri)
    }))

    return { roots, nodes }
}

/**
 * Reads the chapters and sections of one book. An open document is read live, with unsaved edits.
 *
 * @param {vscode.Uri} uri   (Required) The source file of the book.
 * @returns {Promise<object[]>} Top-level banners as returned by parseBanners.
 *
 * @example
 * await readBookBanners(vscode.Uri.file('/repo/examples/powershell/Get-UtilsConfig.ps1'))
 */
async function readBookBanners(uri) {
    const openDocument = vscode.workspace.textDocuments.find(document => document.uri.toString() === uri.toString())
    if (null != openDocument) return getBanners(openDocument)

    const text = Buffer.from(await vscode.workspace.fs.readFile(uri)).toString('utf-8')
    return parseBanners(text.split(/\r?\n/))
}

module.exports = { BOOK_GLOB, buildLibrary, readBookBanners }
