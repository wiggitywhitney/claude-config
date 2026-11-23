---
paths: ["**/*.qmd", "**/slides/**", "**/_quarto.y*ml", "**/custom.scss", "**/talks/**/*speaker-notes*.md", "**/talks/**/*slides-notes*"]
---

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
- Start progressive sequences with an **empty/minimal slide** (e.g., just the participants in a sequence diagram)
- Split multi-step actions into separate slides (e.g., request and response are two slides, not one)

## Readability at Conference Scale

- Text must **never get cut off** at the bottom of a slide — this is the #1 problem to avoid
- One idea per slide — never cram multiple concepts
- Diagram slides: **max 1 line of text** below the diagram; move details to speaker notes if it doesn't fit
- Headings should fit on **one line** — shorten if they wrap
- Use centered, large text (1.3em+, generous margins) for key moment slides
- The `.spaced` class adds generous line height for text build-up slides
- Remove "Scene X:", "Round X:" prefixes from headings — they add clutter

## Content Style

- **No roadmap/agenda slides** — don't list the talk structure upfront
- **No spoilers** — reveal information after the audience experiences it (e.g., don't tell them variant details before they vote)
- Use "**platform**" not "system" when referring to infrastructure making decisions
- Keep text conversational and direct
- Less is more — if a line can be cut, cut it
- **Key moment slides**: Split question and answer into separate slides (e.g., "What's a span event?" on one slide, answer on the next)

## Visual Style

- Teal/cyan accent color (#00897B), used sparingly
- Custom SCSS theme layered on Reveal.js default
- Mermaid diagrams with `neutral` theme, rendered as static SVG (`mermaid-format: svg`)
- LR (left-to-right) layout works better than TB (top-to-bottom) for architecture diagrams — fits the slide aspect ratio

## Diagram Type Selection

- **Flowcharts** (`flowchart LR`): Good for pipelines and architecture. Keep flat — don't fight Mermaid's nesting/mixed-direction limitations. Use Viktor Farcic's approach: flat nodes with colored styles, communicate hierarchy through color and labels rather than visual nesting.
- **Sequence diagrams**: Best for showing temporal interactions between actors. Support `activate`/`deactivate` bars to visually show span duration. Progressive unrolling works naturally — add one more interaction per slide. Use `Note right of` for span labels next to the activate bar.
- **Block-beta**: Good for showing containment with metadata (e.g., a span containing attributes). Use `columns 1` for vertical stacking. Block labels are broken — use a styled title row as the first child with `classDef`. Box width is determined by the widest child content, not the title — shorten labels to fit.
- **Don't use**: architecture-beta (non-deterministic rendering, cross-group bugs), deeply nested subgraphs with mixed directions.
- **When Mermaid can't do it**: Use the real tool (e.g., live Datadog APM trace view) or a different diagram type instead of fighting.

## Mermaid Caching

- `mermaid-format: svg` renders at build time, not in the browser
- Changes to Mermaid diagrams require `rm -rf .quarto _output && quarto render` to take effect
- The preview server's hot-reload does NOT re-render Mermaid SVGs

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
- **Sequence diagram build-up slides**: Start with empty participants, each slide adds one interaction. Use `activate`/`deactivate` to show span duration.
- **Key moment slides**: Centered (`.center`), large inline-styled text, 1-2 sentences max. Question and answer on separate slides.
- **Demo slides**: Simple instructions, QR code (generated live in Chrome), presenter cues in speaker notes
- **Reveal slides** (post-demo): Table showing what the audience didn't know, followed by a centered punchline slide

## Talk Review Process

How Whitney reviews a talk draft. Her process, set while working on re:Invent 2026 (Nov 2026).

**Read-aloud reviews.** Whitney reads a run of slides out loud, by voice-to-text, with her own asides mixed in ("I wonder if...", "I don't think that's accurate anymore"). Compare what she said with the current speaker notes, field by field, and report back in two parts:
- **Small items in one table:** slide, what she said, what the notes say now, and a recommendation (accept, skip, or no change) with a one-line reason. Her improvised wording counts as a candidate, never as an edit, until she accepts it. She answers by number.
- **Bigger items as a numbered list with a recommendation each.** Then take them one at a time, with options, pros and cons, and a recommendation.
Make no changes until she answers. (Confirmed: re:Invent read-aloud of slides 1 to 5 and 29 to 35E, 2026-11-21.)

**Her numbered replies get renumbered by Markdown.** When she answers "1. Add. 2. Accept. 3, accept... 1. Skip." the list restarts its numbering wherever she breaks a line, so "1." or "3." can mean a later item. Map her answers to your items by their order and by the numbers she types inline ("8, accept"), not by the list markers. If the order is ambiguous, ask.

**Her edits in the shared doc win, even over a fix she approved.** When she changes something herself, sync it into the local copy without arguing for the earlier version. She may also take back a change she approved ("I liked the speaker notes for slide 2 better how they were. Change it back."). Revert it and move on.

**When she asks for research, run the `/research` skill.** Don't hand it to a general-purpose agent. On 2026-11-21 she asked "Did you use the research skill like you're supposed to, which would result in actual documentation?" after a research question about defining success criteria went to a plain agent. Before you answer her question, read the resulting doc and check whether the sources disagree with her, and tell her if they do.

**No paste blocks when syncing a shared doc.** When the talk lives in a shared doc (like a Google Doc) with a local copy, Whitney copies changed text from the local file herself. Report only a numbered list of which slide and field differ, plus any structural steps (re-lettering, new slides). Whitney, 2026-11-21: "I don't need or want paste blocks. I'll copy-paste from the document itself, the local doc, into Google Doc."

**Write lessons down as you go, not at the end.** Whitney, 2026-11-21: "you'll forget as the context fills and fills and fills." Whenever she corrects a talk draft or states a preference that will carry over to other talks, add it to this file in the same turn.

## Speaker Notes Voice

Rules for writing the actual speaker notes content read aloud during a talk (as opposed to slide visuals/structure above).

**Cross-slide narrative bridging with ellipsis.** Speaker notes can end one slide mid-sentence (cliffhanger) and open the next slide with "..." picking up where they left off. The ellipsis signals the continuation; the slide reveal provides the pause.

Example:
> Slide 3 notes end: "This isn't the worst-case scenario though. The worst case is when..."
> Slide 4 notes open: "...Nothing looks broken."

This also works for a list that unrolls one item per slide. End the slide on "The first ingredient is..." and open the next one with "...Observability." Whitney says each item's word as it appears on screen. (Confirmed: Whitney's rewrite of re:Invent slides 29A to 29C, 2026-11-20.)

**Never put a claim in her speaker notes that she can't explain.** If a fact depends on a measure she doesn't understand, cut it, even when it's accurate and sourced. On re:Invent slide 29C, I gave Cognition's definition of good as "a maintainer would merge it." Whitney cut it: "I still don't get what it means that a maintainer would merge it, how you measure that, or what that even means... it's fuzzy." Replace it with something concrete she can say in her own words, or flag it for rework.

**Leave room for her self-aware asides, and keep them when she adds them.** On a sponsored talk she names her bias out loud ("I know, as a Datadog representative, I am biased, but...") and adds a wink ("and spoiler alert, you should too"). Don't write these for her, and don't smooth them out when she does. She also cut a survey stat from the slide and from the notes. Keep supporting data in the slide's history unless she asks to put it on screen. (Confirmed: re:Invent slides 29B and 29C, 2026-11-20.)

**Every slide gets a lead-in from the slide before.** Whitney wants trailing lead-ins on almost every slide, and especially on framework slides that reveal one item at a time (for example, four best practices on four slides). End each slide by handing off to the next one, using the ellipsis pattern above or a short question. (Whitney, re:Invent read-aloud, 2026-11-21.)

**Examples are moments the audience has lived, not categories.** "We're building agents that answer customer questions, run workflows, and take action across systems" is generic. Whitney wanted "describe actual experiences": "When you message an airline to rebook a canceled flight, a customer support chatbot might answer." Tie the examples to the ones the talk uses later, so the two slides echo each other. (Confirmed: re:Invent slide 3A, 2026-11-21.)

**Abstract claims need teeth.** A list like "where a task failed, where the agent took an unexpected path, or where a dependency affected the outcome" doesn't land. Whitney: "they need teeth. I need to feel something with these examples." Cut the abstract line when concrete examples (like screenshots) come right after it, or replace it with one specific case. (Confirmed: re:Invent slide 32E, 2026-11-21.)

**Introduce a running example on its own slide before any product screenshot of it.** On re:Invent 2026, the chatbot's introduction (what it is, what it's built with, what it does) and the first Datadog screenshot of it shared slide 33A. Whitney split them: one slide introduces the chatbot, "that's not a Datadog screenshot," and the next slide is the screenshot. (Confirmed: re:Invent slide 33A, 2026-11-21.)

**Never name anyone on stage the audience doesn't know.** A teammate who built the demo, the example, or the slides behind the scenes doesn't get named in the speaker notes. Say "our chatbot," not "Kunal's chatbot." Whitney: "Nobody knows who Kunal is." (Confirmed: re:Invent slide 33A, 2026-11-21.)

**Explain a product term in one plain sentence the first time it comes up.** If the audience might not know what a term means ("a Datadog integration"), add one sentence saying what it does. Prefer that to a new screenshot. (Confirmed: re:Invent slide 31B, 2026-11-21.)

**When a slide shows a product screen, show only what the story needs, not every setup option.** Whitney, while planning the re:Invent slide on writing an evaluator in Datadog (2026-11-23): "I don't want to describe all the setup options... I want to keep it as simple, straightforward, and relevant as possible." Pick the one or two fields that carry the point (for example, the question the judge asks and its answer), and leave model pickers, sampling rates, and filters out of the slide and the notes unless the story turns on them.

**Use the exact technical verb.** An agent framework *emits* telemetry, and Datadog *collects* it. Whitney corrected "it's already being collected" to "it's already wired up to emit telemetry, so we just need to say yes, we want this telemetry, and send it to Datadog. Turn it on." Before writing how a piece of tech behaves, check which side does what. (Confirmed: re:Invent slide 32B, 2026-11-21.)

**Don't promise something on screen that the slides never show.** If the notes list what the tool collects ("what system prompt you're using"), every item should show up on a later slide, or it goes. (re:Invent slide 32E, 2026-11-21.)

**"Dig into" is an AI-ism.** Say "teach you how to" or "discuss" for what the talk covers. (Also in `writing-voice.md`.)

**CAPS for a single word or short phrase, mid-sentence.** One moment of spoken emphasis, not a style override. "The dashboard that the VP is looking at RIGHT NOW."

**Short interjections and punch-line fragments are acceptable — truncated structural sentences are not.** True interjections ("Uh-oh.") and deliberate punch-line pivots ("Or both." "Total mystery!") land harder as their own sentences. But a sentence that belongs to the argument and happens to be short is not a punch line — write it as a complete sentence. "Not sixteen." is a fragment; "It is one integration instead of sixteen." is the right form. The test: could this fragment stand alone on a protest sign? If yes, it can be a fragment. If it is just a fact left dangling, complete it.

**Playful casual words mid-talk.** "Uh-oh" in a professional conference talk. Keeps energy up, signals trouble without drama.

**Second-person hypothetical over third-person anecdote.** "What if your billing system was wrong for a month?" not "Julien has seen cases where a billing system was wrong for a month." The audience is in the scenario, not watching it from outside.

**Binary consequence framing with a twist.** "You either lose money or reputation. Or both." — states two bad options, then lands the twist ("Or both.") as its own sentence.

**Escalate stakes with a title.** When the scenario needs urgency, swap a generic role for an executive title. "The dashboard that the VP is looking at RIGHT NOW" hits harder than "the dashboard" alone.

**Transition slides get real language, not placeholders.** "[transition]" is not acceptable. Write the actual sentence: "Let's talk about what makes data pipeline observability difficult."
