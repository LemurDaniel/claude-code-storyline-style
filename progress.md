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
| 2026-10-31 | The book metaphor is the frame: glossary in SKILL.md → "The story", three levels only (chapter, section, group comment), chapters in plot order, TOC from three chapters on (lowered to two in 0.3.0). | Gives every rule a place in one picture, a fourth banner level would be noise. |
| 2026-10-31 | Terraform: every `.tf` file is one chapter of the module. C++ headers with one class get one chapter as the TOC of the class. | Files with one unit had no banner at all, the module as a whole did not read like a book. |
| 2026-10-31 | Versions stay below 1.0 while the rules are moving: the initial state is 0.1.0, this round is 0.2.0. `release.yaml` tags `v<version>` from `plugin.json` on every push to `main` and publishes the release. | No tag existed yet, so the numbering was free to restart. A manual tag step was forgotten twice. |
| 2026-10-31 | The library frame: codebase = library, folder = shelf, file = book (Terraform: folder = book). Every folder with more than one file has a shelf label, an entry point or a `README.md`. | Whoever opens a folder sees what is on the shelf without opening a file. |
| 2026-10-31 | TOC from two chapters on, not three. | With the old threshold a two-chapter file looked like it had forgotten the list, the reader could not tell rule from omission. |
| 2026-10-31 | From the owner's Terraform naming module: sample input => output comments above reshapes, test files open with a chapter listing their cases. Folded into 0.3.0 (PR #6). Not adopted: error messages with the actual value in tests, deterministic fixtures. | Both patterns were already in the owner's code but missing from the rules. 0.3.0 was not released yet. |
| 2026-10-31 | Banner check also verifies structure: description per chapter, numbered steps vs. sections, TOC vs. chapters. Markdown is exempt, snippets are excerpts. | Rules a script can check do not drift. |
| 2026-10-31 | Priorities: correctness is the boundary, readability the goal, everything else after. Rules serve readability, a deliberate deviation gets a comment. | The owner put readability first and flawless code second. Correctness was moved to a boundary, because readable but wrong code is still a bug. |
| 2026-10-31 | Verify before done as "proofreading" in the glossary, one `Verify` line per language file. Example check `.scripts/Test-StorylineExample.ps1` in CI with `-IsStrict`. | Correctness has to be checked, not assumed. Until now only the banners were checked in CI. |
| 2026-10-31 | PowerShell `Set-StrictMode -Version 1.0`, not `Latest`. | `Latest` throws on missing properties and breaks `$null -EQ $Config.Profiles` checks, 1.0 still catches misspelled variables. |
| 2026-10-31 | Example files get one pass at the end of a change set, not after every rule edit. Snippets still change with their rule. | Owner request: adjusting the examples after every single change is wasted work. |
| 2026-10-31 | Kubernetes: every app is a Helm chart with `values.<env>.yaml` holding only the differences, plain manifests only for cluster-wide resources. Kind first in file names, a fixed image tag that the template enforces. | Taken from the owner manifests (labels, anchors, grouped env and annotations), but full copies per environment and `:latest` tags were the two things to fix. |
| 2026-10-31 | Bicep: one module is one file `module.<name>.bicep`, grouped in category folders with a README, `main.bicep` plus `main.<env>.bicepparam` replace the `example/` folders. | One folder per module with `module.bicep` and `example/` made every tab read `module.bicep`, the module was not a book of its own. |
| 2026-10-31 | No core block in `~/.claude/identity.md`, the sync rule is removed from `CLAUDE.md`. | The section never existed, the junction to the skill is the only source of the rules. |
| 2026-10-31 | TOC in every file with chapters, also with one. Terraform: `main.tf` lists the files of the module (`variables.tf   VARIABLES`), the other `.tf` files have none. | "A single chapter needs no list" left the reader guessing again. In Terraform the folder is the book, so its TOC sits where the book starts. |
| 2026-10-31 | Section = `-` frame (two lines) around the title and a one-line description, indented by 3 spaces. Also for YAML headers. Folded into 0.4.0. | Owner request: sections did not stand out enough next to the `=` chapters. Picked from four variants (frame, title in the line, marker, frame + description). |
| 2026-10-31 | In a flow chapter the section description repeats the numbered step word for word, both stay. | The intro is the overview at the top of the chapter, the section the orientation while scrolling. Functions without chapters had no text at all before, the section description fills that gap. |
| 2026-10-31 | Every file with sections has at least one chapter, only tiny files with one unit have no banner. Workflows with one job lost their job section. | Many PowerShell functions had sections but no chapter, so no intro and no table of contents. "Sections only inside a chapter" is one rule without exceptions, Terraform and `.tfvars` already worked that way. |
| 2026-10-31 | The table of contents is its own comment block below the header, not its last lines. | Owner request: blurb (usage) and table of contents read as two things, the empty line separates them. |
| 2026-10-31 | C++: the groups of a class that fills a whole header chapter are sections. | The chapter description listed them like sections, but the class only had one-line group comments, so they did not stand out. |
| 2026-10-31 | VS Code navigation as a PoC extension in `ideas/vscode-outline/` (outline, Go to Symbol, folding), not the minimap regex or `#region`. | One parser for all languages, the banner format is the same everywhere. The minimap regex works line by line and could not be confirmed for multi-line section titles, `#region` differs per language. |
| 2026-10-31 | VS Code PoC made visible: colored bands, CodeLens, a library tree in the explorer (shelves → books → chapters → sections), status bar and jump keys on top of outline and folding. Sorted into `src/commands`, `src/views`, `src/data`, `src/utils`. | The breadcrumbs alone were too small to notice. The PoC had grown to nine flat files without anyone sorting them. |
| 2026-10-31 | The VS Code extension stays a proof of concept in `ideas/vscode-outline/`, no packaging or Marketplace for now. | Tried by the owner in VS Code. The style itself comes first, the extension is a side track. |
| 2026-10-31 | Rule "Shelve as the code grows" (more than five source files or several roles → shelves), a Scope note and the shelf check `Test-StorylineShelf.ps1` in the `banners` job. | The label rule existed, but nothing said when a flat folder has to be split, so a growing folder slipped through. A script checks what a rule only asks for. |

## Open items
- [ ] `Move-KeyVaultSecret.ps1`: the section `Restore context` stands in the `CLEAN` block, outside every chapter (found by the outline parser). The banner check does not see code blocks, so it passes. Give `CLEAN` its own epilogue chapter?
- [ ] **Before merging 0.4.0:** owner review of the language files `yaml-pipelines.md`, `terraform.md`, `kubernetes.md`, `javascript.md`, `docker-compose.md`, `cpp.md`.
- [ ] Open question: an empty line after the closing section line in YAML (pipelines, Compose, Kubernetes) like everywhere else, or the frame directly above the key?
- [ ] Add `examples` as a required status check for `main` (Settings → Branches), next to `banners`.
- [ ] YAML pipelines are not validated in the example check yet (`actionlint` for GitHub Actions).
- [ ] Reference file and examples for Dockerfile.
- [ ] kubeconform did not run locally (download into the scratchpad was blocked), only in CI.
- [ ] Rule for detecting the codebase's own conventions (`.editorconfig`, ESLint, `.clang-format`, `bicepconfig.json`, neighbouring files).
- [ ] Evals with `claude plugin eval`: fixed prompts per language, checked against the rules and example files.
- [ ] Run `claude plugin validate .` (the CLI was not on the PATH of the shell) and check `displayName` and the `$schema` URLs.
- [ ] `"skills": ["./skills/"]` in `plugin.json` is the default path, probably removable.
- [ ] Azure DevOps example files (only GitHub Actions so far).
- [ ] C++ examples are not compiled yet (no compiler and no `Request.h` / `Response.h`).

## Next step
Review the six language files listed under open items, then merge the 0.4.0 PR (`feature/priorities`, merging is the release) and make `examples` a required check. Then watch in a real session whether Claude reports `Verified` / `Not verified` at the end of a task.
