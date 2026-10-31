// NOTE:
//  npm test   (node --test test/unit/banners.parse.test.js)

//
//  Chapters:
//    PARSE BANNERS   Chapters, sections, headers and ranges of parseBanners.
//

// CommonJS on purpose, like the extension it tests.
'use strict'

const assert = require('node:assert')
const { describe, it } = require('node:test')

const { parseBanners } = require('../../src/utils/banners.parse.js')

const CHAPTER_FRAME = '# ' + '='.repeat(75)
const SECTION_FRAME = '# ' + '-'.repeat(75)

// ===========================================================================
// ============================   PARSE BANNERS   ============================
// ===========================================================================
//
//   chapter with sections     Nests the sections below their chapter with title and description.
//   yaml header               Keeps a section before the first chapter on the top level.
//   section without closing   Ignores a section frame without a closing line.
//   indented chapter          Ends the ranges before the closing brace of the block.
//

describe('parseBanners', () => {

    it('nests the sections below their chapter with title and description', () => {
        const lines = [
            CHAPTER_FRAME,
            '# =========================   LOAD AND VALIDATE   =========================',
            CHAPTER_FRAME,
            '#',
            '#   1. Validations   Fails early on equal storage accounts.',
            '#',
            '',
            SECTION_FRAME,
            '# Validations',
            '#   Fails early on equal storage accounts.',
            SECTION_FRAME,
            '',
            '$a = 1',
            '',
        ]

        const banners = parseBanners(lines)

        assert.strictEqual(banners.length, 1)
        assert.deepStrictEqual(
            { title: banners[0].title, startLine: banners[0].startLine, endLine: banners[0].endLine },
            { title: 'LOAD AND VALIDATE', startLine: 0, endLine: 12 },
        )
        assert.deepStrictEqual(
            banners[0].sections.map(section => [section.title, section.description, section.titleLine, section.endLine]),
            [['Validations', 'Fails early on equal storage accounts.', 8, 12]],
        )
    })

    it('keeps a section before the first chapter on the top level', () => {
        const lines = [
            SECTION_FRAME,
            '# Default Values',
            '#   Defaults for every environment.',
            SECTION_FRAME,
            '',
            CHAPTER_FRAME,
            '# =============================   CHART VALUES   ============================',
            CHAPTER_FRAME,
            '',
            'replicas: 1',
        ]

        const banners = parseBanners(lines)

        assert.deepStrictEqual(
            banners.map(banner => [banner.kind, banner.title, banner.endLine]),
            [['section', 'Default Values', 3], ['chapter', 'CHART VALUES', 9]],
        )
    })

    it('ignores a section frame without a closing line', () => {
        const lines = [
            SECTION_FRAME,
            '# Old style',
            '',
            '$a = 1',
        ]

        assert.deepStrictEqual(parseBanners(lines), [])
    })

    it('ends the ranges before the closing brace of the block', () => {
        const lines = [
            'function Get-Sample {',
            '    ' + CHAPTER_FRAME,
            '    # ===========================   READ SAMPLE   =============================',
            '    ' + CHAPTER_FRAME,
            '',
            '    ' + SECTION_FRAME,
            '    # Read',
            '    #   Reads the sample.',
            '    ' + SECTION_FRAME,
            '    $a = 1',
            '}',
        ]

        const [chapter] = parseBanners(lines)

        assert.strictEqual(chapter.endLine, 9)
        assert.strictEqual(chapter.sections[0].endLine, 9)
    })
})
