# mmdc (Mermaid CLI) Gotchas

## Puppeteer is NOT included — install both together

`npm install -g @mermaid-js/mermaid-cli` alone will silently fail on render. Always install together:
```bash
npm install -g @mermaid-js/mermaid-cli puppeteer
```

## Apple Silicon: Chromium not supported on aarch64-darwin

Set `PUPPETEER_EXECUTABLE_PATH` to system Chrome before running:
```bash
export PUPPETEER_EXECUTABLE_PATH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
mmdc -i diagram.mmd -o diagram.png -s 2
```

## npx requires -p flag

Package name differs from binary name:
```bash
# WRONG — will not find mmdc:
npx mmdc -i input.mmd -o output.png

# CORRECT:
npx -p @mermaid-js/mermaid-cli mmdc -i input.mmd -o output.png
```

## PNG default resolution is low — always use -s 2

```bash
mmdc -i diagram.mmd -o diagram.png -s 2
```

## Node.js API is not semver-stable

Use CLI only. Do not import mmdc programmatically and expect stability across versions.

## Multiline node labels: use markdown string syntax (Mermaid v11)

```mermaid
NODE["`Line one
Line two`"]
```

Backtick after `["` starts a markdown string; literal newline becomes a visible line break. Works in `mermaid-format: svg` mode. Do NOT use `\n` (see gotcha below).

## Long node labels cause invisible text in Mermaid flowcharts with subgraphs (Quarto SVG mode)

When a node label is long enough to require wrapping, Mermaid generates the foreignObject with `display: table; white-space: break-spaces; width: 200px`. The text wraps but gets clipped by the fixed `height="48"` on the foreignObject — resulting in a box with the correct fill/stroke but completely invisible text.

Short labels (≤ ~18 characters) use `display: table-cell; white-space: nowrap` and always render correctly.

**Fix:** Keep node labels short (≤ ~18 characters). If the content is long, put the detail in a speaker note or edge label rather than the node label. The truncation is silent — no error, just blank box.

**Affected context:** Most commonly seen on nodes directly connected from a Mermaid `subgraph` in TD (top-down) layout. In other positions the clipping still occurs but may not be noticed as easily.

## `\n` in node labels with `htmlLabels: false` silently drops the entire node text (Quarto SVG mode)

When `htmlLabels: false` is set via `%%{init}%%`, Mermaid uses SVG `<text>` elements instead of HTML `<foreignObject>`. Any `\n` in a node label causes the entire label text to be silently dropped — the box renders with correct fill/stroke but empty. No error.

Note: Quarto's `mermaid-format: svg` sets `htmlLabels: false` internally — this is the same condition. See `rules/quarto-revealjs-capabilities.md` for the Quarto-specific guidance (use markdown string syntax with backtick instead of `\n`).

**Fix:** Use `—` or another separator instead of `\n`: `GW["Kyverno — no seriously"]`. With default `htmlLabels: true`, `\n` works as a line break via HTML in the foreignObject.
