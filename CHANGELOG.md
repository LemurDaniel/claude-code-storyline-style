# Changelog

## 0.4.0 - 2026-10-31
- Sections stand out more: a `-` frame around the title and a one-line description indented by 3 spaces. In a flow chapter the description repeats the explanation of the numbered step. YAML headers use the same frame, `Name - explanation` titles are split into title and description. The banner check fails on a section without description or closing line.
- Every file with sections has at least one chapter, sections only live inside a chapter. Only a tiny file with one unit (a `.bicepparam`, a values override, a workflow with one job) has no banner. The banner check fails on a section outside a chapter.
- The table of contents is its own comment block below the header (in YAML below the closing line of the header), separated by an empty line and framed by empty comment lines. The banner check fails on a table of contents inside the header.
- C++: the groups of a class that fills a whole header chapter are sections, not group comments.
- PowerShell, JavaScript and C++: the banner bullets that only repeated SKILL.md → "Comments" are removed.
- Bicep: chapters and sections exactly as in SKILL.md, no Bicep-specific banner rule, an empty line after every section title.
- Bicep: one module is one file `module.<name>.bicep` in a category folder with a `README.md`, `main.bicep` is the entry point and `main.<env>.bicepparam` the test deployment. No more folder and `example/` per module.
- Kubernetes manifests / Helm: new `references/kubernetes.md` and `examples/kubernetes/` (plain issuer manifest, Helm chart with values per environment). The example check runs helm lint, helm template and kubeconform.
- YAML pipelines and Docker Compose may use chapters, a large file groups its jobs or services into chapters.
- Table of contents in every file with chapters, also with only one. Terraform: the header of `main.tf` lists every `.tf` file of the module with its chapter, the banner check compares the list with the files.
- "The story" in `SKILL.md`: two annotated examples below the glossary, a folder tree (library, shelf, shelf label, call number) and one book with every part named on the left.
- Review checklist grouped by the sections of the rules, one item per rule, so a review walks through every section in order.
- Priorities in `SKILL.md`: correctness is the boundary, readability the goal, everything else comes after. Rules serve readability, a deliberate deviation gets a comment saying why. Reviews report correctness first.
- Verify before done (proofreading): run the parser, linter, formatter check and tests of the language, name every check that could not run. Every language file has a `Verify` line.
- PowerShell: `Set-StrictMode -Version 1.0` and `$ErrorActionPreference = 'Stop'` in every script and `.psm1`, `$LASTEXITCODE` after native commands.
- JavaScript: every promise is awaited or returned.
- Example check `.scripts/Test-StorylineExample.ps1` and workflow `check.examples.yaml`: PowerShell parser and PSScriptAnalyzer, terraform fmt/validate/test, bicep build, node --check, docker compose config on every push and PR.

## 0.3.0 - 2026-10-31
- Table of contents in the header from two chapters on instead of three. A file with chapters always lists them, so the reader never has to guess whether a list is missing or just not required. Banner check and example files updated.
- Show the shape change: a non-obvious parse or reshape gets one comment with a sample input and its result (`azurerm_disk::os => disk`).
- A test file says what it covers: it opens with a chapter that lists its test cases. Terraform example module gets `tests/registry.tftest.hcl` with `mock_provider`.

## 0.2.2 - 2026-10-31
- Plugin directory lint: Key Vault, keepass and keyFile snippets replaced by storage account and notes examples, the healthcheck example uses promtool instead of wget.

## 0.2.1 - 2026-10-31
- Plugin directory lint: SKILL.md snippets no longer resolve a token, build a remote URL or copy a secret value. Neutral examples (region, backup path, blob upload) instead.

## 0.2.0 - 2026-10-31
- "The story" in `SKILL.md`: glossary from library, shelf and book to code, every folder with more than one file has a shelf label (entry point or `README.md`), when a file gets chapters, chapter order (setup → validations → action → epilogue), variables introduced in the chapter where they first act.
- Table of contents in the header for files with three or more chapters, a description for every chapter, cross-references name the chapter.
- Terraform: every `.tf` file starts with a chapter. C++: a header with one class gets a chapter whose description lists the groups.
- Scope rule: only new and changed code follows the rules, refactorings ask how far to go.
- Review checklist for `/code-review` and `/simplify`.
- Example files per language under `examples/`, neutral and without private project details.
- Banner check `.scripts/Test-StorylineBanner.ps1` for format and structure, run in CI on every push and PR.
- Release workflow: a tag `v<version>` publishes a GitHub release with the changelog entry as notes.
- `main` is protected, changes only via PR.

## 0.1.0 - 2026-10-31
First public release.

- Skill `code-style` with general rules for every language: reading flow, comments and banners, structure, data processing, naming, documentation, errors, logging, tests, format.
- Reference files for PowerShell, Terraform, Bicep, YAML pipelines (GitHub Actions / Azure DevOps), Docker Compose, JavaScript / Node.js and C++.
