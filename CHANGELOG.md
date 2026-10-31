# Changelog

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
