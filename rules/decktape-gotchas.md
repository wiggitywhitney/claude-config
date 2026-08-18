---
paths: ["**/*.qmd", "**/_quarto.yml", "**/decktape*"]
---

# decktape Gotchas

For converting reveal.js (including Quarto reveal.js) presentations to PDF.

- **Do not append `?print-pdf` to the target URL.** decktape captures each slide individually via headless Chrome — it does not use reveal.js's built-in print stylesheet. Loading the print stylesheet alongside decktape's capture stalls slide generation.
- **Point decktape at a locally-served HTTP URL, not a `file://` path.** If a `quarto preview` (or other dev server) is already running, point decktape directly at that address instead of starting a second server.
- **Match `--size` to the deck's configured reveal.js viewport**, or slides get rescaled/cropped relative to what was authored. For Quarto decks, check the rendered `_output/*.html`'s embedded reveal config (`width`/`height`) rather than guessing.
- **Quarto has no built-in decktape integration** (tracked in quarto-cli#4677, unscheduled as of 2026). Run decktape as a separate manual step after `quarto render`/`quarto preview` — not via a Quarto flag. Quarto's own `--to pdf` reveal.js mode is unreliable across browsers; prefer decktape.
- **Prefer a native/npx install over the official Docker image on macOS.** The Docker image runs headless Chrome on Linux, which can produce different font rendering/substitution than a native macOS Chrome — one reported case disliked the Docker output and got expected results after installing decktape locally.
- **Fragments vs. separate slides**: decktape's README does not document a confirmed `--fragments` flag/behavior — treat any fragment-splitting claim as unverified. If a deck uses reveal.js fragments (in-slide reveals) rather than fully separate slides for progressive builds, verify PDF output slide-by-slide rather than assuming 1 fragment = 1 PDF page.
- **Pre-rendered SVG diagrams (e.g. Quarto's `mermaid-format: svg`) sidestep decktape's async-content risk.** If diagrams are baked into static SVG at build time rather than drawn client-side by a JS library on page load, there's no need to tune `--load-pause`/`--buffer-timeout` to wait for diagram rendering.
- Basic command shape: `npx decktape <url> <output.pdf> --size <W>x<H>` — defaults to the `automatic` command, which auto-detects the `reveal` plugin.
