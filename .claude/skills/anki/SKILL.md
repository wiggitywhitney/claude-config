---
name: anki
description: Create Anki cards from the current conversation. Invoke when learning a concept and want to capture it for spaced repetition.
allowed-tools: Read, Write, AskUserQuestion
---

# Anki Card-Making Skill

## User Configuration (customize before use)

- **ANKI_CARDS_DIR**: `/Users/whitney.lee/Documents/Journal/make Anki cards`
- **ANKI_FINISHED_DIR**: `/Users/whitney.lee/Documents/Journal/make Anki cards/finished`
- **ANKI_IMAGES_DIR**: `/Users/whitney.lee/Documents/Journal/images`

---

You are helping Whitney create Anki cards from a conversation she just had. The goal is to capture key concepts while they're fresh.

## Two-Phase Workflow

### Phase 1: Create Card-Ready Document

1. Review the conversation above this skill invocation
2. Extract the key concepts that are worth remembering
3. Structure them in a card-ready format (organized by theme, with clear concepts)
4. Present the document to the user
5. Ask: **"Save to make Anki cards directory?"** OR **"Make cards now?"**

### Phase 2a: Save Document (if user chooses "save")

Save to: `/Users/whitney.lee/Documents/Journal/make Anki cards/[topic].md`

The user can manually make cards later from this document.

### Phase 2b: Make Cards (if user chooses "make cards now")

1. Generate actual START/END block cards following the rules below
2. Present cards for user approval
3. After approval, save to: `/Users/whitney.lee/Documents/Journal/make Anki cards/finished/CARDS MADE - [topic].md`

---

## Card Rules

### Card Front
- Teaching-style, friendly, clear
- 1-2 sentences of context + clear question
- Context must NOT give away the answer
- If a question can be split into multiple cards, split it
- Prefer simpler, focused questions

### Tone and Language
- Write like you're explaining to someone technical but new to this concept
- Use simple, direct words - no jargon without explanation
- Friendly but not fluffy - get to the point
- When introducing a term (like "semantic conventions"), explain what it is
- Avoid assuming prior knowledge of the specific domain

### Personal Memory Anchors
- When possible, tie concepts to Whitney's actual experience: "Whitney, when you implemented X in project Y, you hit this problem"
- Personal context makes concepts stickier and easier to recall
- Reference specific projects, conversations, or moments of discovery
- Example: Instead of "This causes orphaned spans," write "This is why your tool spans in cluster-whisperer were showing up in separate traces"

### Card Back
- **Short answer: 30 words or fewer**
- Followed by: **CONTEXT:** section (1-3 sentences explaining why)
- Explanation is encouraged, even when the answer is short
- **Lists on separate lines**: When the answer is a list, put each item on its own numbered line. No inline comma-separated lists for answers.

### Code Blocks
- Use code blocks to illustrate concepts when it makes the point clearer or more concrete
- **Always label code blocks with the correct language identifier**: `typescript`, `javascript`, `yaml`, `bash`, `go`, `python`, etc.
- Code examples work well in the CONTEXT section to show "what this looks like in practice"
- Can also use on card fronts to ask "what's wrong with this code?" style questions
- Keep code snippets short and focused - just enough to illustrate the point
- Add comments in the code when they help highlight the key insight

### Coverage
- Every important concept covered at least twice (different angles)
- Complex concepts may get more cards
- "Why" cards only when clearly supported by the source (no speculation)

### Concepts Over Details
- Focus on the "why" and the concept, not nitty-gritty implementation details
- Don't ask humans to recall specific schemas, JSON structures, or exact syntax
- Good: "Why does Datadog need a structured format for message content?"
- Bad: "What does the parts array JSON structure look like?"
- If a detail is only useful when copy-pasting into code, it doesn't belong on a card

### No Trivia
- Focus on technology and concepts, not historical facts
- Don't ask "who created X" or "what year was X invented" - these are trivia, not useful knowledge
- If the creator/origin is mentioned, fold it into CONTEXT, not the question
- Good: "What problem does the Ralph Wiggum technique solve?"
- Bad: "Who created the Ralph Wiggum technique?"

### Time-Sensitive Content
- Add "(as of [Month Year])" to card fronts when the content is likely to change
- Examples: ecosystem states, library priorities, "what exists vs doesn't exist yet", roadmap items
- Do NOT add dates to stable concepts: definitions, architectural patterns, "what is X" cards
- When in doubt, ask: "Will this fact still be true in 2 years?" If uncertain, add the date.

### Recency Check (MANDATORY for fast-changing tools)
Before making cards about tools that change frequently (Claude Code, specific APIs, cloud services, AI frameworks):
- **Check current official documentation** before writing cards — don't rely solely on conversation context
- Use WebFetch on official docs sites (e.g., code.claude.com for Claude Code) or WebSearch to verify current state
- If conversation context conflicts with current docs, **docs win** — the conversation may reflect an older state
- Flag any cards where you couldn't verify recency with a note to the user
- This is especially critical for: Claude Code features, API capabilities, framework versions, ecosystem states

### Future-Self Accessibility
Every card must work for Whitney 4+ months from now with no memory of the original conversation.
- No unexplained references to people, conversations, or context that won't exist at review time
- If a name/reference isn't essential to the concept, remove it
- If it IS essential, explain who they are or provide a link on the card
- Ask: "Will this card make sense to me in 6 months with zero context?"

### Arguments vs Facts
When covering debates or competing viewpoints:
- Be explicit when something is a *claim* or *argument*, not established truth
- Don't frame one side's argument as fact in the CONTEXT section
- Include the counter-argument when relevant
- Use framing like "The argument is..." or "Critics say..." to signal perspective

---

## Content Styles

Whitney uses different card styles for different content types.

### Framework/Mental Model Content
For structured knowledge with themes and sub-points (e.g., "How Complex Systems Fail"):

**Structure:**
- Uses the Anki "Basic" format with Front/Back
- Heavy context repetition - includes framework overview on card fronts so each card reinforces the whole
- Layered drilling: big idea cards → sub-point cards → summary cards
- Consistent source attribution (title + URL) on every card front
- Consistent tags across related cards

### Definitional/Vocabulary Content
For concepts and terminology (e.g., "Scalar vs Vector vs Embedding"):

**Structure:**
- One comprehensive overview card covering everything
- Individual "What is X?" definition cards - simple and direct
- No context repetition needed - cards stand alone

**Question types:**
- "What is X?" - basic definition
- "How does X relate to Y?" - relational understanding
- "Is this three different things or three ways to talk about the same thing?" - conceptual clarity questions that test understanding, not just recall

### Content Approach (both types)
- Group source material into natural themes/chunks - let the content determine how many
- Plain language, no jargon, zero assumptions about prior knowledge
- Focus on big picture and takeaways, not every detail
- **No analogies** - use concrete examples instead. Whitney doesn't like analogies ("think of it like a chef..."). Show real examples of the concept in action.
- **Concrete examples in every answer** (e.g., `[0.2, -0.5, 1.3, 0.8]`)

### When Helping with Cards
- Reformat source material into card-friendly structure before card-making
- Ensure themes are consistent throughout (body and summary should match)
- Be critical about theme titles - they should signal what's interesting/counterintuitive
- **Do NOT add IDs to new cards** - the Anki to Obsidian plugin adds `<!--ID: ...-->` automatically. Only existing cards have IDs; preserve those when editing.
- **Date fast-changing content** - For tools that change frequently (Claude Code, specific APIs, etc.), include "(as of [month] [year])" on the card front so future-Whitney knows whether to trust it or verify.

---

## Card Patterns

### Pattern 1: Glossary/Definition Terms (two cards per term)

```text
TARGET DECK: AWSAIPractitionerCert
START
Basic
Front: What is [term]?
Back: [definition - 30 words or fewer]

CONTEXT: [1-3 sentences explaining why this matters]
END

TARGET DECK: AWSAIPractitionerCert
START
Basic
Front: What term describes this?

[definition without the term name]
Back: [term]

CONTEXT: [explanation]
END
```

### Pattern 2: Sequences/Steps ("which is missing")

For lists or sequences, create one card per item where that item is "the missing one":
- When listing 3+ items on the front, use a numbered list on separate lines (not inline commas)
- Use `?????` for the blank item so it renders correctly in markdown
- **Bold the item name** in the list so it pops visually. The bold part is the label; the parenthetical is the description.
- Add a short parenthetical description to each listed item so the list isn't just bare labels. The description should help the reader recall what each item means without giving away the missing answer.

```text
TARGET DECK: AWSAIPractitionerCert
START
Basic
Front: [context about the sequence]

X has four steps. Which is missing?
1. **Step one** (short description)
2. **Step two** (short description)
3. ?????
4. **Step four** (short description)
Back: **Step three** — [short explanation]

CONTEXT: [why this step matters]
END
```

(One card per item — each gets a turn being the blank)

### Pattern 2b: Numbered Scaffolding (and when to break into "which is missing" instead)

When a card asks about the contents/components of something, state the count on the front: "X contains three things. What are they?"
- Number the items on the back (1, 2, 3) — no "Three things:" label, just the numbered list
- The count on the front gives scaffolding: the learner knows how many things to recall before flipping

**When to use numbered scaffolding vs "which is missing":**
- **1-2 items**: Single card, numbered. Always.
- **3-4 items**: Judgment call — consider breaking into "which is missing" cards. Break them up if:
  - The items are complex to understand (not just names to memorize)
  - The knowledge is brand new (not reinforcing existing fundamentals)
  - This is central to what Whitney is working on (not a side-quest curiosity)
  - If items are simple, familiar, or peripheral, keep as one numbered card.
- **5+ items**: Always use "which is missing" style cards.

### Pattern 3: Conversational Q&A

For concepts that emerged from discussion:

```text
TARGET DECK: AWSAIPractitionerCert
START
Basic
Front: [project/topic context]

[question that arose in conversation]
Back: [short answer - 30 words or fewer]

CONTEXT: [additional explanation from the conversation]
END
```

### Pattern 4: Concept from Multiple Angles

Cover important concepts twice with different framing:

```text
TARGET DECK: AWSAIPractitionerCert
START
Basic
Front: [Context] What does X do?
Back: [Answer]

CONTEXT: [Explanation]
END

TARGET DECK: AWSAIPractitionerCert
START
Basic
Front: [Context] When would you use X?
Back: [Answer from different angle]

CONTEXT: [Different aspect of explanation]
END
```

---

## Card Format (Anki-to-Obsidian compatible)

```text
TARGET DECK: AWSAIPractitionerCert
START
Basic
Front: [question]
Back: [answer]

CONTEXT: [explanation]
Tags: [optional tags]
END
```

Notes:
- **Always include `TARGET DECK: AWSAIPractitionerCert`** before each START block
- No `<!--ID: -->` line needed - Anki adds these on import
- Tags are optional
- TARGET DECK line is optional (only needed for specific decks)

### Embedding Images

**Only add images when the user explicitly requests it or provides images in the conversation.**

Use Obsidian's embed syntax:

```text
TARGET DECK: AWSAIPractitionerCert
START
Basic
Front: What does this diagram show?

![[descriptive-image-name.png]]

Back: This diagram shows [explanation here].
END
```

Rules:
- Images can go on Front, Back, or both
- Rename with descriptive filenames (not `Screenshot 2026-02-02...png`)
- Example filename: `datadog-trace-detail-showing-content.png`
- The user provides image files in the chat interface
- Save images to this directory: `/Users/whitney.lee/Documents/Journal/images/`
- Be careful not to use images in a way that gives away the answer

---

## Style Examples

For reference, you may read these files to see Whitney's card-making style:

- **Conversational style**: `/Users/whitney.lee/Documents/Journal/make Anki cards/finished/CARDS MADE - GitHub & ArgoCD auto sync webhook.md`
- **Glossary style**: `/Users/whitney.lee/Documents/Journal/make Anki cards/AWS AI Practitioner Certification/final_study_materials/master_glossary.md` (first 200 lines)

---

## Handling Arguments

- `/anki` - Make cards from this conversation (infer topic)
- `/anki "specific topic"` - Focus on the specific topic mentioned
- `/anki path/to/file.md` - Make cards from a specific file instead of conversation

---

## Quality Checklist

Before presenting cards:
- [ ] Every card has `TARGET DECK: AWSAIPractitionerCert` before START
- [ ] Every important concept is covered at least twice
- [ ] Card fronts don't give away the answer
- [ ] Answers are 30 words or fewer
- [ ] CONTEXT sections explain why it matters
- [ ] No speculation in "why" cards - only what's supported by source
- [ ] Concepts over details - no JSON schemas or exact syntax to memorize
- [ ] Personal anchors used where relevant
- [ ] Future-self accessible - no unexplained names/references
- [ ] Arguments framed as arguments, not facts
- [ ] Code blocks have language identifiers (typescript, yaml, bash, etc.)
