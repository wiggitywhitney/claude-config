# Presentation Slide Rules (Quarto + Reveal.js)

Whitney's preferences for conference presentation slides.

## Collaboration Workflow

- **One section at a time**: Make a section, tell Whitney it's ready, wait for feedback before moving on
- **Iterate before advancing**: Do not start the next section until Whitney is happy with the current one
- **Update these rules**: After each iteration round, capture what Whitney liked/disliked so future sections are better from the start
- **Whitney is the visual authority**: I cannot see the rendered output — Whitney's screenshots are ground truth. Do not guess at visual positioning; ask Whitney to describe what needs to change

## Progressive Reveals

- Break concepts across **separate slides** (not Reveal.js fragments within one slide)
- Each click should add exactly **one idea**
- Use `data-transition="none"` on progressive build slides so content appears in place
- For Mermaid diagrams: use invisible placeholder nodes only when they don't push the diagram off the slide. Drop placeholders once the diagram gets too tall.

## Readability at Conference Scale

- Text must **never get cut off** at the bottom of a slide — this is the #1 problem to avoid
- One idea per slide — never cram multiple concepts
- Diagram slides: **max 1 line of text** below the diagram; move details to speaker notes if it doesn't fit
- Headings should fit on **one line** — shorten if they wrap
- Use centered, large text (1.3em+, generous margins) for key moment slides
- The `.spaced` class adds generous line height for text build-up slides

## Content Style

- **No roadmap/agenda slides** — don't list the talk structure upfront
- **No spoilers** — reveal information after the audience experiences it (e.g., don't tell them variant details before they vote)
- Use "**platform**" not "system" when referring to infrastructure making decisions
- Keep text conversational and direct
- Less is more — if a line can be cut, cut it

## Visual Style

- Teal/cyan accent color (#00897B), used sparingly
- Custom SCSS theme layered on Reveal.js default
- Mermaid diagrams with `neutral` theme, rendered as static SVG (`mermaid-format: svg`)
- LR (left-to-right) layout works better than TB (top-to-bottom) for architecture diagrams — fits the slide aspect ratio

## Decorative Images

- Whitney provides PNGs with transparent backgrounds in `slides/images/`
- Images fight with Reveal.js `auto-stretch` — the `width` attribute on `<img>` tags is often ignored
- `data-background-image` in YAML frontmatter works reliably for slide backgrounds
- Images must **never overlap text** — Whitney is the only one who can verify this
- Large images bleeding off the slide edge look better than tiny corner icons
- Bulbs: gentle tilt only (max ~8deg), keep upright. Geometric shapes: full rotation range.
- Resize source files before committing (long side 800px) to keep build fast

## Slide Structure Patterns

- **Text build-up slides**: Same heading, content accumulating line by line, `.spaced` class, `data-transition="none"`
- **Diagram build-up slides**: Each slide adds nodes to the diagram. Use invisible placeholders only when the diagram is small enough to fit with them.
- **Key moment slides**: Centered (`.center`), large inline-styled text, 1-2 sentences max
- **Demo slides**: Simple instructions, link to dashboard, presenter cues in speaker notes
- **Reveal slides** (post-demo): Table showing what the audience didn't know, followed by a centered punchline slide
