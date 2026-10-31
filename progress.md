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

## Open items
- [ ] Reference files and examples for Kubernetes manifests / Helm and Dockerfile.
- [ ] Rule for detecting the codebase's own conventions (`.editorconfig`, ESLint, `.clang-format`, `bicepconfig.json`, neighbouring files).
- [ ] Evals with `claude plugin eval`: fixed prompts per language, checked against the rules and example files.
- [ ] Run `claude plugin validate .` (the CLI was not on the PATH of the shell) and check `displayName` and the `$schema` URLs.
- [ ] `"skills": ["./skills/"]` in `plugin.json` is the default path, probably removable.
- [ ] CHANGELOG and a version bump in `plugin.json` for the changes since 1.0.0.
- [ ] Azure DevOps example files (only GitHub Actions so far).
- [ ] C++ examples are not compiled yet (no compiler and no `Request.h` / `Response.h`).

## Next step
Bump `plugin.json` to 1.1.0 with a CHANGELOG entry, then run `claude plugin validate .`.
