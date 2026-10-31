# Storyline Code Style

A code style skill for [Claude Code](https://claude.com/claude-code): every file reads top to bottom like a story.

File headers say how to call the file, chapter and section banners structure it, guard clauses keep the main path flat,
data is transformed in named stages, and logs leave a narrative trail at every decision point.

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

## Recommended: core rules in your CLAUDE.md

Whether a skill gets loaded is up to the model, and a quick one-line fix may skip it.
Copy this block into your `~/.claude/CLAUDE.md` so the most important rules always apply and the skill gets loaded reliably:

```markdown
# Code Style
**Before writing, changing or reviewing code, load the `storyline-code-style:code-style` skill**, even for small fixes. It holds the full rules and the per-language files.
The rules below always apply, even without the skill:
- The codebase's own conventions win, these rules only fill the gaps.
- New and changed code follows the rules. Untouched code is only restyled in a refactoring, and before going beyond the requested part, ask how far to go.
- Code reads top to bottom: file header with usage and prerequisites, flat main path with guard clauses and early `return`.
- Chapter banner: three lines of `=`, title in UPPERCASE centered. Section: one line of `-`, title below. Lines are 75 characters long. No other banner styles.
- Comments and identifiers in English. Constants in `UPPER_SNAKE`, booleans with `is`/`has`, no magic numbers.
- `null` goes on the left in comparisons (`$null -EQ $x`).
- Never swallow errors silently. Error messages state the expectation. Validations are grouped in a `Validations` section.
- Docs: `[Required]`/`[Optional]` in PowerShell, `(Required)`/`(Optional)` elsewhere, always first. No empty doc skeletons.
- Verbose/debug log with a `[Component]` prefix at every decision point. Mutating operations support WhatIf or dry-run.
```

## License

[MIT](LICENSE)
