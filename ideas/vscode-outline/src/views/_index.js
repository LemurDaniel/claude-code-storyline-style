// NOTE:
//  const views = require('./views/_index.js')
//
//    views.forEach(registerView => registerView(context))   registers every view of the extension.

// CommonJS on purpose: the VS Code extension host loads CommonJS without a bundler.
'use strict'

const { registerDecorations } = require('./view.decorations.js')
const { registerCodeLens } = require('./view.codelens.js')
const { registerLibrary } = require('./view.library.js')
const { registerStatusBar } = require('./view.statusbar.js')
const { registerOutline } = require('./view.outline.js')

module.exports = [
    registerDecorations,
    registerCodeLens,
    registerLibrary,
    registerStatusBar,
    registerOutline,
]
