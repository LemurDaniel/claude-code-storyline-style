// NOTE:
//  const { parseBanners } = require('../utils/banners.parse.js')
//
//    parseBanners(document.getText().split(/\r?\n/))   returns the chapters and sections of a file.
//
//    No dependency on VS Code, so the parser runs in plain Node for the tests.

//
//  Chapters:
//    HELPERS         Banner line patterns and the end of a range.
//    PARSE BANNERS   Finds chapters and sections and sets their line ranges.
//

// CommonJS on purpose: the VS Code extension host loads CommonJS without a bundler.
'use strict'

const BANNER_WIDTH = 75

// A frame line: optional indent, comment character, one space, 75 '=' or '-'.
const FRAME_PATTERN = new RegExp(`^\\s*(#|//) (=|-){${BANNER_WIDTH}}$`)

// The middle line of a chapter: '=' left, the title with 3 spaces on each side, '=' right.
const CHAPTER_TITLE_PATTERN = /^\s*(#|\/\/) =+ {3}(?<title>.+?) {3}=+$/

// Any comment line, the text after the comment character is optional.
const COMMENT_PATTERN = /^\s*(#|\/\/)( (?<text>.*))?$/

// ===========================================================================
// ===============================   HELPERS   ===============================
// ===========================================================================
//
//   getFrameCharacter   Returns '=' or '-' for a frame line, null otherwise.
//   getCommentText      Returns the trimmed text of a comment line, null otherwise.
//   trimOutdentedEnd    Ends a range before the first line indented less than the banner.
//   trimBlankEnd        Moves the end of a range up past trailing empty lines.
//

/**
 * Returns the frame character of a banner line.
 *
 * @param {string} line   (Required) One line of the document.
 * @returns {string|null} '=' for a chapter frame, '-' for a section frame, null for any other line.
 *
 * @example
 * getFrameCharacter('# ' + '-'.repeat(75))   // '-'
 */
function getFrameCharacter(line) {
    const match = FRAME_PATTERN.exec(line ?? '')
    return match?.[2] ?? null
}

/**
 * Returns the text of a comment line without the comment character.
 *
 * @param {string} line   (Required) One line of the document.
 * @returns {string|null} The trimmed text, '' for an empty comment line, null for code.
 *
 * @example
 * getCommentText('    //   Fails early.')   // 'Fails early.'
 */
function getCommentText(line) {
    const match = COMMENT_PATTERN.exec(line ?? '')
    if (null == match) return null
    return (match.groups.text ?? '').trim()
}

/**
 * Ends a range before the first non-empty line indented less than its banner, so the closing brace of the enclosing block stays visible.
 *
 * @param {string[]} lines   (Required) All lines of the document.
 * @param {number}   start   (Required) The banner line, its indent is the boundary.
 * @param {number}   end     (Required) Last line of the range before trimming.
 * @returns {number} The last line that still belongs to the banner.
 *
 * @example
 * trimOutdentedEnd(['    # ---', '    $a = 1', '}'], 0, 2)   // 1
 */
function trimOutdentedEnd(lines, start, end) {
    const indent = lines[start].length - lines[start].trimStart().length
    for (let index = start + 1; index <= end; index++) {
        const line = lines[index]
        const isOutdented = line.trim() !== '' && line.length - line.trimStart().length < indent
        if (isOutdented) return index - 1
    }
    return end
}

/**
 * Moves the end of a range up until it ends on a non-empty line, so a fold keeps the empty line before the next banner.
 *
 * @param {string[]} lines   (Required) All lines of the document.
 * @param {number}   start   (Required) First line of the range, the end never moves above it.
 * @param {number}   end     (Required) Last line of the range before trimming.
 * @returns {number} The last non-empty line of the range.
 *
 * @example
 * trimBlankEnd(['a', 'b', '', ''], 0, 3)   // 1
 */
function trimBlankEnd(lines, start, end) {
    let trimmedEnd = end
    while (trimmedEnd > start && lines[trimmedEnd].trim() === '') {
        trimmedEnd--
    }
    return trimmedEnd
}

// ===========================================================================
// ============================   PARSE BANNERS   ============================
// ===========================================================================
//
//   1. Find banners   Collects every chapter and section with its title line.
//   2. Set ranges     Lets every banner run until the next one of its level.
//

/**
 * Finds every chapter and section of a document.
 *
 * Sections before the first chapter (the header of a YAML file) are returned on the top level.
 *
 * @param {string[]} lines   (Required) All lines of the document.
 * @returns {object[]} Top-level banners: { kind, title, description, startLine, titleLine, frameEndLine, endLine, sections }.
 *                     frameEndLine is the last line of the banner itself, endLine the last line of its content.
 *
 * @example
 * parseBanners(fs.readFileSync('Move-KeyVaultSecret.ps1', 'utf-8').split(/\r?\n/))
 * // [{ kind: 'chapter', title: 'LOAD AND VALIDATE SECRETS', sections: [{ title: 'Context', ... }, ...] }, ...]
 */
function parseBanners(lines) {
    if (null == lines) return []

    // ---------------------------------------------------------------------------
    // Find banners
    //   Collects every chapter and section with its title line.
    // ---------------------------------------------------------------------------

    const banners = []
    for (let index = 0; index < lines.length; index++) {
        const frameCharacter = getFrameCharacter(lines[index])

        // Chapter: frame, centered title, frame. The description below is not needed for the outline.
        const titleMatch = CHAPTER_TITLE_PATTERN.exec(lines[index + 1] ?? '')
        if (frameCharacter === '=' && null != titleMatch && getFrameCharacter(lines[index + 2]) === '=') {
            banners.push({ kind: 'chapter', title: titleMatch.groups.title, description: '', startLine: index, titleLine: index + 1, frameEndLine: index + 2, sections: [] })
            index += 2
            continue
        }

        // Section: frame, title, description lines, closing frame. Without a closing frame it is no section.
        if (frameCharacter !== '-') continue
        if (null == getCommentText(lines[index + 1])) continue

        let closingLine = index + 2
        while (closingLine < lines.length && null != getCommentText(lines[closingLine]) && null == getFrameCharacter(lines[closingLine])) {
            closingLine++
        }
        if (getFrameCharacter(lines[closingLine]) !== '-') continue

        // The first description line is the detail next to the title in the outline.
        const description = lines
            .slice(index + 2, closingLine)
            .map(getCommentText)
            .find(text => text !== '') ?? ''

        banners.push({ kind: 'section', title: getCommentText(lines[index + 1]), description, startLine: index, titleLine: index + 1, frameEndLine: closingLine, sections: [] })
        index = closingLine
    }

    // ---------------------------------------------------------------------------
    // Set ranges
    //   Lets every banner run until the next one of its level.
    // ---------------------------------------------------------------------------

    // A chapter runs until the next chapter, a section until the next banner of any kind,
    // both end early at the closing brace of the block they stand in.
    const lastLine = lines.length - 1
    const topLevel = []
    for (const [position, banner] of banners.entries()) {
        const nextChapter = banners.slice(position + 1).find(next => next.kind === 'chapter')
        const nextBanner  = banners[position + 1]
        const rawEnd = banner.kind === 'chapter'
            ? (nextChapter?.startLine ?? lastLine + 1) - 1
            : (nextBanner?.startLine ?? lastLine + 1) - 1
        banner.endLine = trimBlankEnd(lines, banner.startLine, trimOutdentedEnd(lines, banner.startLine, rawEnd))

        const currentChapter = topLevel.findLast(candidate => candidate.kind === 'chapter')
        const isInChapter = banner.kind === 'section' && null != currentChapter && banner.startLine <= currentChapter.endLine
        if (isInChapter) {
            currentChapter.sections.push(banner)
            continue
        }
        topLevel.push(banner)
    }

    return topLevel
}

module.exports = { parseBanners }
