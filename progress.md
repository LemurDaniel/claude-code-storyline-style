# Progress

## Goal
A public Claude Code plugin whose skill makes Claude write code that reads top to bottom like a story,
consistent across PowerShell, Terraform, Bicep, YAML pipelines, Docker Compose, JavaScript and C++.

## Decisions
| Date | Decision | Why |
| --- | --- | --- |
| 2026-10-31 | Scope rule: only new and changed code follows the rules, refactorings ask how far to go. | A one-line fix must not restyle a whole file, but refactorings must be able to restructure. |
| 2026-10-31 | One source for the rules: `~/.claude/skills/code-style` is a junction to this repo. | The local skill, a German `STYLE.md` and the plugin had drifted apart. |
| 2026-10-31 | No hard enforcement via hooks for now. | Deferred by the owner, the skill and the core block in `CLAUDE.md` come first. |
| 2026-10-31 | Groups inside a unit (class, resource block) use one plain comment line, not `#` + `# title`. | One comment form less, the old two-line form looked like a third banner style. |
| 2026-10-31 | Examples are neutral, no private project details. | The plugin is public, private layouts confuse other users. |
| 2026-10-31 | Banner check as `.scripts/Test-StorylineBanner.ps1`, run locally and in CI. | One real implementation, a check separate from the one writing the rules. |
| 2026-10-31 | Example files live in the repo root (`examples/<language>/`), not in the plugin. | They document how all rules combine and serve as eval references, without adding to the installed skill. |
| 2026-10-31 | The book metaphor is the frame: glossary in SKILL.md → "The story", three levels only (chapter, section, group comment), chapters in plot order, TOC from three chapters on. | Gives every rule a place in one picture, a fourth banner level would be noise. |
| 2026-10-31 | Terraform: every `.tf` file is one chapter of the module. C++ headers with one class get one chapter as the TOC of the class. | Files with one unit had no banner at all, the module as a whole did not read like a book. |
| 2026-10-31 | Versions stay below 1.0 while the rules are moving: the initial state is 0.1.0, this round is 0.2.0. Releases via tag `v<version>` and `release.yaml`. | No tag existed yet, so the numbering was free to restart. |
| 2026-10-31 | The library frame: codebase = library, folder = shelf, file = book (Terraform: folder = book). Every folder with more than one file has a shelf label, an entry point or a `README.md`. | Whoever opens a folder sees what is on the shelf without opening a file. |
| 2026-10-31 | Banner check also verifies structure: description per chapter, numbered steps vs. sections, TOC vs. chapters. Markdown is exempt, snippets are excerpts. | Rules a script can check do not drift. |

## Open items
- [ ] Reference files and examples for Kubernetes manifests / Helm and Dockerfile.
- [ ] Rule for detecting the codebase's own conventions (`.editorconfig`, ESLint, `.clang-format`, `bicepconfig.json`, neighbouring files).
- [ ] Evals with `claude plugin eval`: fixed prompts per language, checked against the rules and example files.
- [ ] Run `claude plugin validate .` (the CLI was not on the PATH of the shell) and check `displayName` and the `$schema` URLs.
- [ ] `"skills": ["./skills/"]` in `plugin.json` is the default path, probably removable.
- [ ] Azure DevOps example files (only GitHub Actions so far).
- [ ] C++ examples are not compiled yet (no compiler and no `Request.h` / `Response.h`).

## Next step
Run `claude plugin validate .`, commit, then tag `v0.2.0` on the merge of PR 2 and `v0.2.1` after the lint fix PR, each tag publishes a release. Afterwards watch how Claude applies the chapter order and TOC rules in a real session.
