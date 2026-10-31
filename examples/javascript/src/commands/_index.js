// NOTE:
//   Shelf label of the commands folder: every command is imported here once and
//   registered by the CLI in this order.
//
//   import commands from './commands/_index.js'

import repositoryDownload from './command.repository.download.js'

export default [
    repositoryDownload,
]
