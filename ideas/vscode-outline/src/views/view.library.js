// NOTE:
//  const { registerLibrary } = require('./view.library.js')
//
//    registerLibrary(context)   The "Storyline" view in the explorer: library → shelves → books → chapters → sections.
//                               The open book and the banner at the cursor are revealed and selected.

//
//  Chapters:
//    LIBRARY TREE   Tree of the whole workspace as library, follows the open file and the cursor.
//

// CommonJS on purpose: the VS Code extension host loads CommonJS without a bundler.
'use strict'

const vscode = require('vscode')

const { BOOK_GLOB, buildLibrary, readBookBanners, findCurrentBanners } = require('../data/_index.js')

const VIEW_ID = 'storyline.banners'

// Icons per node type, books take the file icon of the theme.
const ICONS = {
    library: 'library',
    shelf: 'folder-library',
    chapter: 'symbol-namespace',
    section: 'bookmark',
}

// ===========================================================================
// ============================   LIBRARY TREE   =============================
// ===========================================================================
//
//   LibraryTreeProvider   Hands libraries, shelves, books and banners to the tree, books are read on expand.
//   registerLibrary       Registers the tree and keeps it in sync with files, edits, editor and cursor.
//

/**
 * Hands the library of the workspace to the tree.
 *
 * Library, shelf and book nodes come from buildLibrary, banner nodes are created when a book is expanded.
 * Every node has a stable key, the tree item id, so reveal() finds it again after a refresh.
 *
 * @example
 * vscode.window.createTreeView('storyline.banners', { treeDataProvider: new LibraryTreeProvider() })
 */
class LibraryTreeProvider {
    #onDidChangeTreeData = new vscode.EventEmitter()
    onDidChangeTreeData = this.#onDidChangeTreeData.event

    // Promise of { roots, nodes }, built on first access and after every file change.
    #library = null

    // Banner nodes by key: '<book uri>#<start line>'.
    #bannerNodes = new Map()

    // Library
    refresh() {
        this.#library = null
        this.#bannerNodes.clear()
        this.#onDidChangeTreeData.fire()
    }

    async getLibrary() {
        this.#library ??= buildLibrary()
        return this.#library
    }

    // Books
    async refreshBook(uri) {
        const { nodes } = await this.getLibrary()
        const book = nodes.get(uri.toString())
        if (null != book) this.#onDidChangeTreeData.fire(book)
    }

    async findBook(uri) {
        const { nodes } = await this.getLibrary()
        return nodes.get(uri.toString())
    }

    // Banners
    #toBannerNode(book, banner, parent) {
        const node = {
            type: banner.kind,
            key: `${book.key}#${banner.startLine}`,
            uri: book.uri,
            name: banner.title,
            description: banner.description,
            parentKey: (parent ?? book).key,
            banner,
            book,
        }
        this.#bannerNodes.set(node.key, node)
        return node
    }

    async findBannerNode(book, banner) {
        // Creates the banner nodes of the book and the sections of every chapter, then picks the one at the banner.
        const topLevel = await this.getChildren(book)
        const nested   = topLevel.flatMap(node => [node, ...node.banner.sections.map(section => this.#toBannerNode(book, section, node))])
        return nested.find(node => node.banner.startLine === banner.startLine)
    }

    // TreeDataProvider
    async getChildren(node) {
        const { roots, nodes } = await this.getLibrary()
        if (null == node) return roots

        if (node.type === 'book') {
            const banners = await readBookBanners(node.uri)
            return banners.map(banner => this.#toBannerNode(node, banner, null))
        }
        if (node.type === 'chapter' || node.type === 'section') {
            return node.banner.sections.map(section => this.#toBannerNode(node.book, section, node))
        }
        return node.childKeys.map(key => nodes.get(key))
    }

    async getParent(node) {
        const { nodes } = await this.getLibrary()
        return nodes.get(node.parentKey) ?? this.#bannerNodes.get(node.parentKey)
    }

    getTreeItem(node) {
        const isBanner   = node.type === 'chapter' || node.type === 'section'
        const isExpanded = node.type === 'library' || (node.type === 'chapter' && node.banner.sections.length > 0)
        const isLeaf     = node.type === 'section' || (node.type === 'chapter' && node.banner.sections.length === 0)

        const state = isLeaf
            ? vscode.TreeItemCollapsibleState.None
            : (isExpanded ? vscode.TreeItemCollapsibleState.Expanded : vscode.TreeItemCollapsibleState.Collapsed)

        const item = new vscode.TreeItem(node.name, state)
        item.id          = node.key
        item.description = node.description
        item.tooltip     = isBanner ? `${node.name}\n${node.description}`.trim() : node.uri.fsPath

        // Books take the file icon of the theme, everything else a fixed icon.
        if (node.type === 'book') {
            item.resourceUri = node.uri
            item.command     = { command: 'vscode.open', title: 'Open book', arguments: [node.uri] }
        }
        else {
            item.iconPath = new vscode.ThemeIcon(ICONS[node.type])
        }
        if (isBanner) {
            item.command = { command: 'storyline.revealBanner', title: 'Go to banner', arguments: [node.banner, node.uri] }
        }
        return item
    }
}

/**
 * Registers the library tree and keeps it in sync with created and deleted files, edits, the open editor and the cursor.
 *
 * @param {vscode.ExtensionContext} context   (Required) Holds the tree view, the watcher and the listeners.
 * @returns {void}
 *
 * @example
 * registerLibrary(context)
 */
function registerLibrary(context) {
    const provider = new LibraryTreeProvider()
    const treeView = vscode.window.createTreeView(VIEW_ID, { treeDataProvider: provider })

    // Reveals the open book and selects the banner at the cursor, only while the view is visible, so it never steals the focus.
    // - cursor in a section  => library › shelf › book › chapter › section selected
    // - cursor above banners => the book selected
    const revealCurrent = async editor => {
        if (null == editor || !treeView.visible) return

        const book = await provider.findBook(editor.document.uri)
        if (null == book) return

        const { chapter, section } = findCurrentBanners(editor.document, editor.selection.active.line)
        const current = section ?? chapter
        const target  = null == current ? book : await provider.findBannerNode(book, current)
        if (null == target) return

        await treeView.reveal(target, { select: true, focus: false, expand: true })
    }

    // Handled: right after a refresh the tree may not know the node yet, the next cursor move reveals it.
    const revealQuietly = editor => revealCurrent(editor).catch(() => {})

    // New, deleted or renamed source files change the shelves, edits only the banners of one book.
    const watcher = vscode.workspace.createFileSystemWatcher(BOOK_GLOB, false, true, false)

    context.subscriptions.push(
        treeView,
        watcher,
        watcher.onDidCreate(() => provider.refresh()),
        watcher.onDidDelete(() => provider.refresh()),
        vscode.workspace.onDidChangeWorkspaceFolders(() => provider.refresh()),
        vscode.workspace.onDidChangeTextDocument(event => provider.refreshBook(event.document.uri)),
        vscode.window.onDidChangeActiveTextEditor(revealQuietly),
        vscode.window.onDidChangeTextEditorSelection(event => revealQuietly(event.textEditor)),
        treeView.onDidChangeVisibility(() => revealQuietly(vscode.window.activeTextEditor)),
    )
}

module.exports = { registerLibrary }
