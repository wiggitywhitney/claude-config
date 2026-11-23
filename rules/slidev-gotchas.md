---
paths: ["**/slides.md", "**/*slidev*", "**/deck/**/*.md"]
---

# Slidev Gotchas

Verified against the sli.dev docs, the GitHub releases page, and a real install of v53.0.0 on 2026-11-02. Full research: `~/Documents/Journal/docs/research/slidev.md`.

## Install

- **v53.0.0 (2026-09-16) requires Node.js 22.12.0 or newer.** Run `node --version` before creating a project.
- **Use `pnpm create slidev`, not npm.** The docs warn that npm re-downloads packages for every new project.
- **A fresh v53.0.0 install with pnpm crashes on startup with `ERR_PACKAGE_PATH_NOT_EXPORTED` for `markdown-it/lib/token.mjs`.** `@comark/markdown-it` declares a peer of `markdown-it@^14`, but pnpm resolved it to 15.0.3, which removed that subpath. A `pnpm.overrides` entry did not fix it. Adding `markdown-it@^14.1.0` as a direct project dependency did (`pnpm add markdown-it@^14.1.0`).
- **Don't put a Slidev project in a folder named `slides/`.** The Quarto/reveal.js rule `presentation-slides.md` fires on `**/slides/**` and would load guidance for a different tool.

## Syntax

- **`---` only separates slides when it has a blank line before and after it.**
- **The first slide's frontmatter is the deck's headmatter.** Deck-wide settings (`theme`, `aspectRatio`, `fonts`) go in the same block as the title slide's settings.
- **`class` or `layout` in the headmatter applies to the first slide only.** To apply them to every slide, nest them under `defaults:` in the headmatter (for example `defaults:` → `layout: center`, `class: text-center`).
- **Only a comment at the very end of a slide is a speaker note.** An HTML comment anywhere else in the slide is treated as a plain comment and silently dropped from the notes.
- **Relative image paths in frontmatter and component props 404 after build.** Put those assets in `public/` and reference them as `/image.png`. Relative paths in plain Markdown images (`![alt](./img.png)`) work.
- **Fonts load only weights 200, 400, and 600 by default.** For bold or black text, set `fonts.weights` explicitly (for example `weights: '700,800,900'`), or the browser fakes the heavier weight.

## Export

- **PDF and PNG export need `playwright-chromium` and its browser.** Install the package with `pnpm add -D playwright-chromium`. pnpm 10 blocks its download script, so export then fails with "Executable doesn't exist at .../chrome-headless-shell". Run `npx playwright-chromium install chromium-headless-shell` once to fix it.
- **A plain `slidev export` drops click steps.** It prints one page per slide with animations off. Use `--with-clicks` for one page per step. `v-click` and `v-mark` are both click-triggered.
- **`--per-slide` isn't in the current CLI's export options.** Don't use it.
- **`--format pptx` exports each slide as an image.** Use `pptx-editable` for selectable text.
- **To check how slides look without a browser, export PNGs and view them:** `npx slidev export --format png --output /tmp/deck-png`.

## Reference

- The dev server also serves a browser exporter at `localhost:3030/export` and an MCP server at `localhost:3030/__mcp`.
