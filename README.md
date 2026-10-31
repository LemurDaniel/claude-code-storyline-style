# Storyline Code Style

A code style skill for [Claude Code](https://claude.com/claude-code): every file reads top to bottom like a story.

File headers say how to call the file, chapter and section banners structure it, guard clauses keep the main path flat,
data is transformed in named stages, and logs leave a narrative trail at every decision point.

## The story

A codebase is a library, a folder is a shelf, a file is a book. Every part has its place in the code:

| Library | Code | Form |
| --- | --- | --- |
| Library | Codebase | README at the entrance |
| Shelf | Folder, cut by domain | Every shelf with more than one book has a label |
| Shelf label | Entry point or folder README | `_index.js`, `Utils.psm1`, `main.tf`, `module.bicep`, else `README.md` |
| Call number | File name `<kind>.<topic>[.<variant>]` | Sorts the books on the shelf |
| Book | File | Header, chapters, epilogue (a Terraform module: the folder is the book, each file a chapter) |
| Blurb | File header | Usage and prerequisites |
| Table of contents | Chapter list in the header | Only in files with three or more chapters |
| Chapter | Chapter banner | Three lines of `=`, title in UPPERCASE centered |
| Chapter intro | Chapter description | Numbered steps or one entry per unit, right below the frame |
| Section | Section banner | One line of `-`, title below |
| Paragraph | Group comment | One comment line inside a unit, no banner |
| Epilogue | Cleanup | Context reset, outputs, exports: always last |

Chapters follow the plot: setup → validations → the action → epilogue. Variables are introduced in the chapter
where they first act, and comments that point elsewhere name the chapter they mean.

```powershell
# ===========================================================================
# ======================   LOAD AND VALIDATE SECRETS   ======================
# ===========================================================================
#
#   1. Context       Switches to the given subscription, keeps the previous one.
#   2. Validations   Fails early on equal or missing Key Vaults.
#   3. Secrets       Loads all enabled secrets of the source.
#

# ---------------------------------------------------------------------------
# Context
```

The banner check in [`.scripts/Test-StorylineBanner.ps1`](.scripts/Test-StorylineBanner.ps1) runs in CI and verifies the
banner format, that every chapter has a description, that the numbered steps match the sections and that the table of
contents matches the chapters.

## What's inside

| File | Content |
| --- | --- |
| `SKILL.md` | Scope, general rules for every language (reading flow, comments and banners, structure, naming, docs, errors, logging, tests) and a review checklist |
| `references/powershell.md` | PowerShell 7 |
| `references/terraform.md` | Terraform |
| `references/bicep.md` | Bicep |
| `references/yaml-pipelines.md` | GitHub Actions and Azure DevOps pipelines |
| `references/docker-compose.md` | Docker Compose |
| `references/javascript.md` | JavaScript / Node.js |
| `references/cpp.md` | C++ |

The repo also holds [`examples/`](examples/) with complete example files per language, one simple and one more complex.
They show how all rules work together in one file and are not part of the installed plugin.

Only the skill description sits in context up front. Claude loads `SKILL.md` before writing or reviewing code,
and reads a language file only when it works in that language.

When a codebase has its own conventions, they win. The skill only fills the gaps.

## Installation

In Claude Code:

```
/plugin marketplace add LemurDaniel/claude-code-storyline-style
/plugin install storyline-code-style@storyline-code-style
```

Updates:

```
/plugin marketplace update storyline-code-style
```

## AI notice

This repository is written together with [Claude Code](https://claude.com/claude-code). The rules, the reference files,
the example files and the banner check were drafted by Claude and reviewed, decided and tested by the maintainer.
Decisions and their reasons are logged in [`progress.md`](progress.md). If a rule or an example looks wrong,
open an issue, it is a human call in the end.

## License

[MIT](LICENSE)
