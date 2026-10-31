// NOTE:
//  const { getBanners, buildLibrary } = require('../data/_index.js')
//
//    banners.js   The banners of one document, cached per version.
//    library.js   Shelves and books of the workspace.

// CommonJS on purpose: the VS Code extension host loads CommonJS without a bundler.
'use strict'

module.exports = {
    ...require('./banners.js'),
    ...require('./library.js'),
}
