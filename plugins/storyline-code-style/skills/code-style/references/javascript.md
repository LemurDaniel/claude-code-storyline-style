# Code Style: JavaScript / Node.js
- 4 spaces, unless `.editorconfig` says otherwise. No semicolons. ESM (`import`/`export`, `"type": "module"` in `package.json`), unless the project already uses CommonJS. Relative imports with file extension (`./output.js`). ESLint (flat config) with `@stylistic` is the benchmark.
  ```js
  // eslint.config.js
  import stylistic from '@stylistic/eslint-plugin'

  export default [
      {
          files: ['**/*.js'],
          languageOptions: { sourceType: 'module' },
          plugins: { '@stylistic': stylistic },
          rules: {
              '@stylistic/semi': ['error', 'never'],
              '@stylistic/indent': ['error', 4],
          },
      },
  ]
  ```
- Small projects: folders by role (`commands/`, `routes/`, `views/`, `data/`, `utils/`). When a project grows across several business domains, it is cut by domain (see `SKILL.md`). Files are named `<kind>.<domain>[.<action>].js`, with the kind even when the folder already names it. When a file bundles several units, the kind is plural (`routes.status.js`, `tools.zfs.js` with all ZFS tools), with one unit per file it is singular (`command.repository.download.js`). Consistent within a folder, even when a file currently holds only one unit (`routes.exec.shutdown.js`). Exception: `_index.js` and files in `utils/` and `data/`, which are only named `<domain>[.<action>].js` (`host.exec.js`).
  ```
  src/
    commands/
      _index.js
      command.account.login.js
      command.repository.download.js
    routes/
      _index.js
      routes.status.js
      routes.exec.shutdown.js
    views/
      _index.js
      view.repositories.list.js
    data/
      devops.js
    utils/
      output.js
  ```
- Imports sit at the top in groups: first Node and framework (`fs`, `vscode`), then own modules, classes last.
  ```js
  import fs from 'node:fs'
  import path from 'node:path'
  import vscode from 'vscode'

  import output from '../utils/output.js'
  import config from '../utils/config.js'

  import DevOps from '../data/devops.js'
  ```
- One collection file `_index.js` per folder bundles all modules of the folder. The underscore always sorts it to the top in the explorer, and with ESM Node does not resolve an `index.js` automatically anyway:
  ```js
  import accountLogin from './command.account.login.js'
  import repositoryDownload from './command.repository.download.js'

  export default [
      accountLogin,
      repositoryDownload,
  ]
  ```
- **Same structure for units of the same kind.** Every command follows the same skeleton:
  ```js
  const commandName = 'operation.start'
  async function command(context) {

      output.appendLine(`Invoked command '${commandName}' with '${context?.constructor?.name}'`)
      if (null == context) return

      try {
          ...
      } catch (exception) {
          vscode.window.showErrorMessage(exception.message)
      }

  }

  export default vscode.commands.registerCommand(`devopsscripts.${commandName}`, command)
  ```
- Singletons: the default is the instance as the module's default export. Only for lazy init (expensive constructor, needs config or login) a static getter with a private field.
  ```js
  // Default: the module itself is the singleton.
  class Output { ... }

  export default new Output()
  ```
  ```js
  // Lazy: created on first access.
  class DevOps {
      static #instance = null

      static get instance() {
          return DevOps.#instance ??= new DevOps()
      }
  }
  ```
- Private fields and methods with `#`, derived values as getters, nested helper classes as `static` or class field.
  ```js
  class Repository {
      #name
      #project

      static Status = class { ... }

      get fullName() {
          return `${this.#project}/${this.#name}`
      }

      #buildRemoteUrl() { ... }
  }
  ```
- Parallel calls share one request: `this.#loading ??= this.#load().finally(() => this.#loading = null)`.
  ```js
  #loading = null

  // Five callers at once -> one HTTP request, all await the same promise.
  async getProjects() {
      this.#loading ??= this.#load().finally(() => this.#loading = null)
      return this.#loading
  }
  ```
- One options object instead of many positional parameters: `api.get({ scope, domain, api, query })`.
  ```js
  async get({ scope, domain = 'dev.azure.com', api, query = {} }) { ... }

  await api.get({ scope: project, api: 'git/repositories' })
  ```
  Not like this: `api.get(project, null, 'git/repositories', {}, true)`
- Consistently `?.` and `??` instead of `&&` chains. `null == x` deliberately checks `null` and `undefined` at once, otherwise `===`.
  ```js
  const branch = repository?.defaultBranch ?? 'main'
  if (null == repository) return
  if (status === 'completed') { ... }
  ```
  Not like this: `const branch = repository && repository.defaultBranch || 'main'`
- When rethrowing, errors get context and the original as `cause`. Log the full stack, show the user only the message.
  ```js
  try {
      await pipeline.run()
  } catch (exception) {
      output.appendLine(exception.stack)
      throw new Error(`Pipeline '${pipeline.name}' failed to start: ${exception.message}`, { cause: exception })
  }
  ```
- Array chains (`filter`/`map`/`reduce`) with one step per line.
  ```js
  const totalSize = repositories
      .filter(repository => !repository.isDisabled)
      .map(repository => repository.size)
      .reduce((sum, size) => sum + size, 0)
  ```
- **Chapters and sections as `//` banners** per `SKILL.md` → "Comments", with a chapter description. No `/* #### */` boxes. Inside a class there are no banners, group comments structure it there (see next point).
  ```js
  // ===========================================================================
  // ==========================   SOLVE TREE PUZZLE   ==========================
  // ===========================================================================
  //
  //   1. Parse input   Reads today's input file into a grid.
  //   2. Part 1        Counts the trees visible from outside the grid.
  //

  // ---------------------------------------------------------------------------
  // Parse input
  ```
- Small methods of the same kind sit under a group comment (`// Get Index`, `// Has Node by Index`).
  ```js
  // Get Index
  getParentIndex(index) { return Math.floor((index - 1) / 2) }
  getLeftIndex(index)   { return index * 2 + 1 }
  getRightIndex(index)  { return index * 2 + 2 }

  // Has Node by Index
  hasParent(index) { return index > 0 }
  hasLeft(index)   { return this.getLeftIndex(index) < this.size }
  hasRight(index)  { return this.getRightIndex(index) < this.size }
  ```
- Tests with Mocha under `test/unit/`.
  ```js
  import assert from 'node:assert'
  import MinHeap from '../../src/utils/heap.min.js'

  describe('MinHeap', () => {
      it('returns values in ascending order', () => {
          const heap = new MinHeap()
          ;[5, 1, 3].forEach(value => heap.insert(value))

          assert.deepStrictEqual([heap.pop(), heap.pop(), heap.pop()], [1, 3, 5])
      })
  })
  ```
