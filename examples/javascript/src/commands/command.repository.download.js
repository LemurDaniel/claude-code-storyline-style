// NOTE:
//  node ./src/cli.js repository.download --owner <OWNER> [--target <FOLDER>] [--force]
//
//    Requires: git on the PATH and a GITHUB_TOKEN that can read the repositories.
//
//    'repository.download --owner octo-org'           clones all repositories of 'octo-org'.
//    'repository.download --owner octo-org --force'   replaces existing folders.
//
//  Chapters:
//    HELPERS                 Target path and clone of one repository.
//    DOWNLOAD REPOSITORIES   Options, validations, loading and cloning all repositories.

import fs from 'node:fs'
import path from 'node:path'
import { execFile } from 'node:child_process'
import { promisify } from 'node:util'

import logger from '../utils/logger.js'
import config from '../utils/config.js'

import GitHub from '../data/github.js'

const COMMAND_NAME = 'repository.download'
const DEFAULT_TARGET_FOLDER = './repositories'

const runFile = promisify(execFile)

// ===========================================================================
// ===============================   HELPERS   ===============================
// ===========================================================================
//
//   getTargetPath     Resolves the local folder of one repository.
//   cloneRepository   Clones one repository, replaces an existing folder only when forced.
//

/**
 * Resolves the local folder of one repository below the target folder.
 *
 * @param {string} targetFolder   (Required) The folder that holds all repositories.
 * @param {object} repository     (Required) The repository as returned by the GitHub API.
 * @returns {string} The absolute path of the repository folder.
 *
 * @example
 * getTargetPath('./repositories', { name: 'api' })
 */
function getTargetPath(targetFolder, repository) {
    return path.resolve(targetFolder, repository.name)
}

/**
 * Clones one repository into its target folder.
 *
 * @param {object}  repository           (Required) The repository as returned by the GitHub API.
 * @param {string}  targetPath           (Required) The local folder to clone into.
 * @param {boolean} [isForced=false]     (Optional) Replaces an existing folder.
 * @returns {Promise<boolean>} True when cloned, false when skipped.
 *
 * @example
 * await cloneRepository({ repository, targetPath: '/repos/api', isForced: true })
 */
async function cloneRepository({ repository, targetPath, isForced = false }) {
    const hasFolder = fs.existsSync(targetPath)

    if (hasFolder && !isForced) {
        logger.debug(`[${COMMAND_NAME}] '${repository.name}' exists at '${targetPath}' -> skipping.`)
        return false
    }
    if (hasFolder) {
        logger.debug(`[${COMMAND_NAME}] '${repository.name}' exists, forced -> replacing '${targetPath}'.`)
        fs.rmSync(targetPath, { recursive: true, force: true })
    }

    // execFile instead of exec, so a repository name can never inject shell commands.
    await runFile('git', ['clone', '--quiet', repository.cloneUrl, targetPath])
    logger.debug(`[${COMMAND_NAME}] Cloned '${repository.name}' into '${targetPath}'.`)
    return true
}

// ===========================================================================
// ========================   DOWNLOAD REPOSITORIES   ========================
// ===========================================================================
//
//   1. Options        Resolves the target folder and the force flag.
//   2. Validations    Fails early on a missing owner.
//   3. Repositories   Loads all repositories of the owner, archived ones are skipped.
//   4. Download       Clones the repositories one after another.
//
//   Errors are logged with their stack, the user only sees the message.
//

/**
 * Downloads all repositories of an owner into a local folder.
 *
 * @param {object}  options                    (Required) The parsed command line options.
 * @param {string}  options.owner              (Required) The user or organization on GitHub.
 * @param {string}  [options.target]           (Optional) The local folder. Defaults to './repositories'.
 * @param {boolean} [options.isForced=false]   (Optional) Replaces existing folders.
 * @returns {Promise<string[]>} The local paths of all downloaded repositories.
 *
 * @example
 * await command({ owner: 'octo-org', isForced: true })
 */
async function command(options) {

    logger.debug(`Invoked command '${COMMAND_NAME}' with '${JSON.stringify(options)}'`)
    if (null == options) return []

    try {

        // ---------------------------------------------------------------------------
        // Options

        // Order of precedence: option > config file > default
        const targetFolder = options.target           // option
            ?? config.repositories?.targetFolder      // config file
            ?? DEFAULT_TARGET_FOLDER                  // default
        const isForced = options.isForced === true

        // ---------------------------------------------------------------------------
        // Validations

        if (typeof options.owner !== 'string' || options.owner.trim() === '') {
            throw new Error(`owner must be a non-empty string, got '${options.owner}'`)
        }

        // ---------------------------------------------------------------------------
        // Repositories

        const repositories = await GitHub.instance.getRepositories({ owner: options.owner })
        const activeRepositories = repositories
            .filter(repository => !repository.isArchived)

        logger.debug(`[${COMMAND_NAME}] Found ${activeRepositories.length} active of ${repositories.length} repositories.`)

        // ---------------------------------------------------------------------------
        // Download

        // One after another on purpose, parallel clones quickly hit the rate limit of the git host.
        const downloadedPaths = []
        for (const repository of activeRepositories) {
            const targetPath = getTargetPath(targetFolder, repository)
            const isCloned   = await cloneRepository({ repository, targetPath, isForced })

            if (isCloned) downloadedPaths.push(targetPath)
        }

        logger.info(`[${COMMAND_NAME}] Downloaded ${downloadedPaths.length} repositories into '${targetFolder}'.`)
        return downloadedPaths

    } catch (exception) {
        logger.error(exception.stack)
        console.error(exception.message)
        process.exitCode = 1
        return []
    }

}

export default { name: COMMAND_NAME, run: command }
