# Anki Card-Making Skill

A Claude Code skill for creating Anki cards from conversations.

## How It Works

### Two-Phase Workflow

**Phase 1: Card-Ready Document**
- Claude extracts key concepts from the conversation
- Organizes them by theme
- Presents a structured document for review
- Asks: save for later, or make cards now?

**Phase 2: Output**
- **Save document**: Goes to `~/Documents/Journal/make Anki cards/[topic].md`
- **Make cards**: Generates START/END blocks, saves to `~/Documents/Journal/make Anki cards/finished/CARDS MADE - [topic].md`

## Invocation

```
/anki                     # Make cards from this conversation
/anki "OpenTelemetry"     # Focus on specific topic
/anki docs/concept.md     # Make cards from a file
```

## Card Rules Reference

Full rules are in Whitney's `Anki rules.md`, but the key points:

- **Front**: 1-2 sentences context + clear question (don't give away answer)
- **Back**: 30 words or fewer + CONTEXT section
- **Coverage**: Every concept at least twice (different angles)
- **"Why" cards**: Only when supported by source (no speculation)

## Expanding This Skill

### Adding New Card Patterns

Edit `SKILL.md` and add a new pattern section. Current patterns:
- Glossary/definition (term ↔ definition, two cards)
- Sequences/steps ("which is missing")
- Conversational Q&A
- Concept from multiple angles

To add cloze cards, image cards, etc., add a new `### Pattern N:` section.

### Changing Output Paths

Paths are hardcoded in `SKILL.md`:
- Card-ready documents: `/Users/whitney.lee/Documents/Journal/make Anki cards/`
- Finished cards: `/Users/whitney.lee/Documents/Journal/make Anki cards/finished/`

To change, update the paths in the "Two-Phase Workflow" section.

### Adding TARGET DECK Support

Some card sets need a specific deck. Add to the card format:

```
TARGET DECK: DeckName
START
Basic
...
END
```

### Converting to a Shareable Plugin

To share with others:

1. Replace hardcoded paths with placeholders like `$ANKI_OUTPUT_DIR`
2. Add configuration instructions for setting environment variables
3. Remove Whitney-specific style references
4. Package as a standalone skill or MCP server

## Claude Code Skill Architecture

Skills are markdown files in `~/.claude/skills/[name]/SKILL.md` with:
- YAML frontmatter (name, description, allowed-tools)
- Instructions for Claude when the skill is invoked
- Invoked with `/[name]` or `/[name] args`

See: https://docs.anthropic.com/en/docs/claude-code/skills

## Files

```
~/.claude/skills/anki/
├── SKILL.md    # Main skill instructions (Claude reads this)
└── README.md   # This file (documentation for humans)
```
