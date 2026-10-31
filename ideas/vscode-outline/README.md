# Storyline Outline (idea, proof of concept)
A VS Code extension that reads the chapter and section banners of the storyline code style and makes them stand out in the editor:

- **Colored bands:** a strong band behind the three lines of every chapter, a light band behind every section, titles in bold. Marks in the scrollbar show where chapters and sections start.
- **CodeLens** above every chapter: `Chapter 1/2 · 3 sections`, `↑ previous chapter`, `↓ next chapter`, all clickable.
- **Explorer:** a "Storyline" view below the files with the whole library: shelves (folders, labeled by their README heading or entry point) → books (source files) → chapters → sections. Books are read when expanded, a click on a banner jumps there, also into a file that is not open yet. The open book and the banner at the cursor are revealed and selected.
- **Status bar:** `CHAPTER › Section` of the cursor, a click opens a quick pick of every banner.
- **Keys:** `Ctrl+Alt+PageDown` / `Ctrl+Alt+PageUp` jump to the next or previous banner.
- **Outline, breadcrumbs, Go to Symbol** (`Ctrl+Shift+O`) and **folding** per chapter and section.

It works for every language with `#` or `//` comments, because the banner format is the same everywhere. Markdown is skipped, its snippets are excerpts.

```
src/
  extension.js              Entry point, registers the commands and every view.
  commands/
    commands.banners.js     Quick pick, next, previous and the jump used by library tree and CodeLens.
  views/
    _index.js               Shelf label: every view of the extension.
    view.decorations.js     Colored bands and scrollbar marks.
    view.codelens.js        The line above every chapter.
    view.library.js         The library tree in the explorer.
    view.statusbar.js       The status bar item.
    view.outline.js         Outline symbols and folding ranges.
  data/
    _index.js               Shelf label: banners and library in one import.
    banners.js              Parses each document once per version, finds the banner at the cursor.
    library.js              Shelves and books of the workspace, shelf labels, the banners of a book.
  utils/
    banners.parse.js        Finds chapters and sections and their line ranges, no dependency on VS Code.
test/unit/
  banners.parse.test.js     Tests of the parser with node --test.
media/
  storyline.svg             View icon, shown when the view is dragged into its own container.
```

## Try it
Start a VS Code window with the extension loaded and open any example file:
```powershell
code --extensionDevelopmentPath="$PWD/ideas/vscode-outline" ./examples
```

The colors are theme colors, `settings.json` can override them:
```json
"workbench.colorCustomizations": {
    "storyline.chapterBackground": "#7ee78740",
    "storyline.sectionBackground": "#a5d6ff26"
}
```

Run the parser tests:
```powershell
cd ideas/vscode-outline
npm test   # node --test test/unit/banners.parse.test.js
```

## Open
- [ ] Try it in VS Code: colors in dark and light themes, CodeLens noise, library tree following the cursor, speed in a large workspace.
- [ ] Package as `.vsix` (`npx @vscode/vsce package`) and decide: folder in this repo, own repo or Marketplace.
- [ ] Settings to switch single views off (CodeLens, status bar).
