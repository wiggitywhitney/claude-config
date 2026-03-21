# Quarto + Reveal.js + Mermaid Capabilities

What the slide tech stack can do. Use these features when building presentation slides.

## Text & Layout

- **r-fit-text**: Auto-sizes text to fill the slide. Use `::: {.r-fit-text}` instead of manual `font-size` inline CSS. Ideal for dramatic statement slides.
- **Columns**: Side-by-side layout with `:::: {.columns}` and `::: {.column width="50%"}`. Good for variant comparisons (A vs B).
- **Tabsets**: Tabbed content with `::: {.panel-tabset}` and `###` headings per tab. Lets audience click between related views on one slide.
- **Callout blocks**: `::: {.callout-tip}` / `warning` / `note` / `caution` / `important`. Styled boxes for key points.
- **Smaller/scrollable**: `{.smaller}` reduces font, `{.scrollable}` adds scroll bar for overflow.

## Animation & Transitions

- **Auto-animate**: Add `auto-animate=true` to two adjacent slide headings. Reveal.js smoothly animates matching elements between them (by text content, `src`, or `data-id`). May not work reliably with Mermaid SVGs — test first.
- **Fragments**: 15+ animation classes beyond basic `.fragment` (fade-in): `.fade-out`, `.fade-up`, `.fade-down`, `.grow`, `.shrink`, `.strike`, `.highlight-red/green/blue`, `.semi-fade-out`, `.fade-in-then-out`. Nest fragments for sequential effects on one element.
- **Custom blur fragment**: Add CSS `.fragment.blur { filter: blur(5px); }` / `.fragment.blur.visible { filter: none; }` to `custom.scss`. Blurs content, unblurs on reveal.
- **r-stack**: Overlapping elements revealed one at a time with `::: {.r-stack}` and `.fragment` on each child. Elements appear in the same position, replacing each other.

## Code

- **Code line highlighting**: `code-line-numbers="|1-3|5-8|10-12"` on a fenced code block. First `|` shows all lines unhighlighted, then highlights sections progressively as you advance. Non-highlighted lines dim. Ideal for walking through YAML configs step by step.
- **Code annotation**: Number annotations in code blocks that expand on click/hover.

## Backgrounds

- **Color/gradient**: `## {background-color="#00897B"}` or `background-color="linear-gradient(...)"`
- **Image**: `## {background-image="image.png" background-size="contain" background-opacity="0.3"}`
- **Video**: `## {background-video="video.mp4" background-video-loop="true" background-video-muted="true"}`
- **Interactive iframe**: `## {background-iframe="https://example.com" background-interactive="true"}` — embeds a live webpage as the slide background. You can click and interact. Use for live Datadog dashboards or APM trace views.

## Mermaid Diagrams (bundled v11.6.0)

All diagram types work in `{mermaid}` code blocks:

- **Flowchart**: `flowchart LR` or `TB`. What we use most. LR fits slide aspect ratio better for pipelines.
- **Sequence diagram**: Shows temporal interactions between participants. Use for request/response flows. Supports `activate`/`deactivate`, `Note over`, `loop`/`alt`/`par`, `rect rgb()` backgrounds.
- **State diagram**: `stateDiagram-v2`. Shows state machine transitions. Ideal for Flagger canary lifecycle (Initializing → Progressing → Promoting → Succeeded/Failed).
- **Timeline**: Chronological events. Experimental — test rendering before relying on it.
- **Mindmap**: Hierarchical concept map using indentation. Node shapes: `[square]`, `(rounded)`, `((circle))`, `)cloud(`, `{{hexagon}}`.
- **Quadrant chart**: Two-axis comparison plot. Could visualize cost vs satisfaction.
- **GitGraph**: Branch/merge visualization.
- **Architecture** (new in v11): System architecture layouts. Very new — test thoroughly.

**Rendering note**: `mermaid-format: svg` (our setting) renders server-side. Newer diagram types (timeline, mindmap, architecture) may have issues. Switch to `mermaid-format: js` if a specific diagram renders incorrectly.

## Custom HTML/CSS/JS

- **Raw HTML**: Works directly in slides. Use for custom layouts, CSS trace visualizations, styled divs.
- **CSS animations**: Define `@keyframes` in `custom.scss`. Example: pulse animation for "LIVE" indicators.
- **Observable JS**: `{ojs}` code cells in `.qmd`. Reactive — inputs update outputs. Can load D3.js via `require("d3@7")`.
- **d3-flame-graph**: Interactive flame graphs via `require("d3-flame-graph@4")` in OJS. Impressive but fragile on stage.
- **CSS trace visualization**: Colored `<div>` bars at different indentation levels to show span nesting. Simpler and more reliable than d3-flame-graph for conference use.

## Presenter Tools

- **Speaker view**: Press `S`. Shows current slide, next slide, elapsed time, speaker notes.
- **Chalkboard**: `chalkboard: true` in YAML. Press `C` to draw on slide, `B` for blank canvas. Good for annotating diagrams live.
- **Overview**: Press `O` for thumbnail grid. Good for jumping to sections during Q&A.
- **Jump to slide**: Press `G`, type number, Enter.
- **PDF export**: Press `E` then `Ctrl+P`, or `quarto render --to pdf`.
- **Scroll view**: Press `R` or append `?view=scroll` to URL.

## Extensions

Install with `quarto add <repo>`:

- **Spotlight** (`mcanouil/quarto-spotlight`): Highlight mouse position on slide
- **Codefocus** (`reuning/codefocus`): Highlight + explain specific code lines
- **Animate** (`mcanouil/quarto-animate`): CSS animations on any element
- **Iconify** (`mcanouil/quarto-iconify`): 200,000+ icons
