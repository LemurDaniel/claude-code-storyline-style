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
| `.scripts/Test-StorylineBanner.ps1` | Banner check (format, chapter and section descriptions, numbered steps vs. sections, table of contents), runs locally and in CI |
| `.scripts/Test-StorylineShelf.ps1` | Shelf check (label in every folder with several source files, at most five flat source files), runs locally and in CI |
| `.scripts/Test-StorylineExample.ps1` | Example check (PowerShell parser and PSScriptAnalyzer, terraform fmt/validate/test, bicep build, node --check, docker compose config, helm lint/template, kubeconform), runs locally and in CI |
| `CHANGELOG.md` | One entry per release |
| `.scripts/New-SocialPreview.ps1` | Renders `.github/social-preview.png` (1280x640), uploaded manually under Settings → Social preview |
| `.scripts/New-PluginIcon.ps1` | Renders `plugins/storyline-code-style/.claude-plugin/icon.png` (1024x1024) for the plugin directory listing |
| `.github/workflows/check.banners.yaml` | Runs the banner and the shelf check on every push and PR |
| `.github/workflows/check.examples.yaml` | Installs every tool and runs the example check with `-IsStrict` on every push and PR |
| `.github/workflows/release.yaml` | On every push to `main`: reads the version from `plugin.json`, creates tag and GitHub release when the tag is missing |
| `progress.md` | Goal, decisions, open items, next step |
| `README.md` | The story, contents and installation |

## Local setup
`~/.claude/skills/code-style` is a junction to `plugins/storyline-code-style/skills/code-style`.
Every edit here is live in all local sessions right away, so a broken rule breaks the style everywhere.

## Editing the rules
- **Rules and examples must agree.** Every snippet and every example file follows every rule, including banners, `null` on the left, logging and error handling. A new or changed rule gets checked against all snippets and example files. Snippets change together with their rule, the example files get one pass at the end of a change set, not after every single rule edit.
- **The book metaphor is the frame.** New rules get their place in the glossary under SKILL.md → "The story" (blurb, table of contents, chapter, chapter intro, section, paragraph, epilogue). Three levels only: chapter, section, group comment.
- **SKILL.md owns the general rules.** Language files only add language specifics or restrict the format, they never introduce their own banner style. They link back with `SKILL.md` → "<Section>".
- **Neutral examples only.** No private project names, host paths, internal domains or real IDs. Use placeholders (`<SUBSCRIPTION_ID>`, `rg-sample-dev`) or well-known public tools.
- **Content in English**, short bullets, one example per rule. A "Not like this" example only where the mistake is common.
- **Banners:** 75 characters of `=` or `-` plus the comment character and one space, chapter titles centered. Check after every edit:
  ```powershell
  ./.scripts/Test-StorylineBanner.ps1
  ```
- **Shelves:** a new file goes on its shelf, a folder with several source files has a label. Check after adding or moving files:
  ```powershell
  ./.scripts/Test-StorylineShelf.ps1
  ```
- **Example files must be valid**, check them with the tools of their language. The script skips a missing tool and names it, CI runs it with `-IsStrict`:
  ```powershell
  ./.scripts/Test-StorylineExample.ps1
  ```
- **New language:** add `references/<language>.md`, `examples/<language>/`, a row in the SKILL.md table, the README table, the skill `description` and the keywords in `plugin.json`.

## Context reviews
- 2026-10-31: Went through the [Claude Code 16 tips](https://raw.githubusercontent.com/aishwaryanr/awesome-generative-ai-guide/main/youtube/claude-code-16-tips.md) for this repo. Implemented: example files (tip 3), `progress.md` (tips 10, 12, 16), CI banner check (tip 14).

## Releases
- Bump `version` in `plugin.json` (SemVer): a new or changed rule is minor, a wording or example fix is patch. Add the entry `## <version> - <date>` to `CHANGELOG.md`.
- Release: merging the PR is the release. The workflow tags `v<version>` from `plugin.json` and publishes the CHANGELOG entry, it fails when the entry is missing. No manual tags.

## Workflow
- `main` is protected: changes only via PR, the `banners` check must pass, linear history, no force push. Work on a branch (`feature/<topic>`, `fix/<topic>`), then `gh pr create`.
- Commit messages: short imperative title, bullet list per change below.

## Plugin directory submission
The directory lint flags credential-looking names (`TOKEN`, `PASSWORD`, `SECRET`, `keyFile`, Key Vault), every `$env:` reference, network commands in snippets (`wget`, `sendMail`), real vendor hosts (`dev.azure.com`) and unbalanced apostrophes in code blocks (`today's` made it read to the end of the file). Snippets use `api.example.com`, neutral variable names and no apostrophes inside code blocks. `${{ secrets.* }}` in the pipeline reference is expected and gets confirmed by a reviewer.
