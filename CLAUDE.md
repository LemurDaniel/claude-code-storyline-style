# Storyline Code Style Plugin

A Claude Code plugin with one skill (`code-style`) that makes code read top to bottom like a story.
The repo is the marketplace and the plugin at once. There is no build, only Markdown, JSON and example files.

**At session start read [progress.md](progress.md), at the end of a task update it** (decisions, open items, next step).

## Layout
| Path | Content |
| --- | --- |
| `.claude-plugin/marketplace.json` | Marketplace entry |
| `plugins/storyline-code-style/.claude-plugin/plugin.json` | Plugin manifest with `version` |
| `plugins/storyline-code-style/skills/code-style/SKILL.md` | Scope, general rules, review checklist |
| `plugins/storyline-code-style/skills/code-style/references/*.md` | One file per language, loaded on demand |
| `examples/<language>/` | Complete example files, one simple and one more complex per language. Repo only, not shipped with the plugin |
| `.scripts/Test-StorylineBanner.ps1` | Banner check, runs locally and in CI |
| `.github/workflows/check.banners.yaml` | Runs the banner check on every push and PR |
| `progress.md` | Goal, decisions, open items, next step |
| `README.md` | Installation and the core block for a user's `CLAUDE.md` |

## Local setup
`~/.claude/skills/code-style` is a junction to `plugins/storyline-code-style/skills/code-style`.
Every edit here is live in all local sessions right away, so a broken rule breaks the style everywhere.

## Editing the rules
- **Rules and examples must agree.** Every snippet and every example file follows every rule, including banners, `null` on the left, logging and error handling. A new or changed rule gets checked against all snippets and example files.
- **SKILL.md owns the general rules.** Language files only add language specifics or restrict the format, they never introduce their own banner style. They link back with `SKILL.md` → "<Section>".
- **Neutral examples only.** No private project names, host paths, internal domains or real IDs. Use placeholders (`<SUBSCRIPTION_ID>`, `rg-sample-dev`) or well-known public tools.
- **Content in English**, short bullets, one example per rule. A "Not like this" example only where the mistake is common.
- **Banners:** 75 characters of `=` or `-` plus the comment character and one space, chapter titles centered. Check after every edit:
  ```powershell
  ./.scripts/Test-StorylineBanner.ps1
  ```
- **Example files must be valid**, check them with the language's tools where installed: PowerShell parser, `node --check`, `terraform fmt -check` and `terraform validate`, `bicep build`, `docker compose config`.
- **Keep the core block in sync:** A change to a core rule goes into the README block and into `~/.claude/identity.md` (Code Style section).
- **New language:** add `references/<language>.md`, `examples/<language>/`, a row in the SKILL.md table, the README table, the skill `description` and the keywords in `plugin.json`.

## Context reviews
- 2026-10-31: Went through the [Claude Code 16 tips](https://raw.githubusercontent.com/aishwaryanr/awesome-generative-ai-guide/main/youtube/claude-code-16-tips.md) for this repo. Implemented: example files (tip 3), `progress.md` (tips 10, 12, 16), CI banner check (tip 14).

## Releases
- Bump `version` in `plugin.json` (SemVer): a new or changed rule is minor, a wording or example fix is patch.
- Commit messages: short imperative title, bullet list per change below.
