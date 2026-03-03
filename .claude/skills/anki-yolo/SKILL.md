---
name: anki-yolo
description: Create and save Anki cards autonomously without approval. Use when cards should just get made.
allowed-tools: Read, Write, Glob, Grep, WebSearch, WebFetch
---

# Anki YOLO — Autonomous Card Making

Make cards and save them immediately. No two-phase workflow, no approval gate.

## Process

1. Review conversation context (or provided args/file)
2. Outline the narrative arc (why it exists, what it is, how it connects, what was surprising)
3. Generate cards following all rules from the `/anki` skill
4. Save directly to: `/Users/whitney.lee/Documents/Journal/make Anki cards/finished/CARDS MADE - [topic].md`
5. Present a brief summary of what was saved (card count and topics covered)

## Constraints

- **Check for existing cards first**: Scan files in the finished directory to avoid duplicating concepts already captured
- **Default to 5 cards max** unless the caller specifies otherwise
- **Architectural level only**: How things fit together, key decisions, surprising patterns. No implementation minutiae.
- **All card rules from `/anki` apply**: card format, granularity, personal anchors, terminology provenance, story-first framing, quality checklist — everything except the two-phase approval workflow

## Card Rules Reference

All card formatting rules, patterns, content styles, and quality standards are defined in the `/anki` skill (`SKILL.md` in the `anki/` directory). Read that file for the full specification. The key rules:

- **Card front**: Teaching-style, 1-2 sentences context + clear question, context must not give away answer
- **Card back**: 30 words or fewer, followed by CONTEXT section (1-3 sentences)
- **Personal anchors required** for project-based cards (name the repo, state the objective, explain the problem)
- **Story-first framing**: Why does this exist? What is it? How does it connect? What was surprising?
- **Coffee test**: Would you explain this to a colleague over coffee? If not, too granular.
- **Format**: `TARGET DECK: AWSAIPractitionerCert` before each START/END block
- **No IDs**: The Anki-to-Obsidian plugin adds these automatically

## Handling Arguments

- `/anki-yolo` — Make cards from this conversation (infer topic, max 5)
- `/anki-yolo "specific topic"` — Focus on the specific topic
- `/anki-yolo 10` — Override the default card limit
- `/anki-yolo path/to/file.md` — Make cards from a specific file
