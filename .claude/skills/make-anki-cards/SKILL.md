---
name: make-anki-cards
description: Create Anki cards from a completed PRD or a branch of work, sourced from the PRD document and the full git diff rather than from conversation context. Invoke after finishing a body of work worth capturing for spaced repetition.
category: knowledge-capture
---

# Make Anki Cards From Completed Work

Create flashcards covering a whole body of work — a finished PRD, a merged branch, a completed spike — rather than whatever happens to be in the current conversation.

**This skill decides what to feed the card-maker. It does not make cards.** Card rules, quality scoring, formats, patterns, tags, and style all live in the `/anki` skill; follow that skill for every question about how a card should read. Do not restate its rules here.

## When this skill applies rather than `/anki`

Use `/anki` when the material is the conversation you just had.

Use this skill when the material is a durable artifact — a PRD with its decision log, or a diff — and the conversation is only a partial view of it. The distinction matters because a long implementation runs across several sessions and several compactions, so the conversation holds a fraction of what was decided, and cards sourced from it inherit that gap.

## Process

### Step 1: Identify the source material

Determine what body of work is being captured. Look, in this order:

1. An explicit argument — a PRD number, an issue number, or a branch name.
2. The current git branch, if it matches a PRD or issue pattern.
3. Recent conversation naming a PRD, issue, or completed milestone.

If none of these resolve it, ask which body of work to capture rather than guessing. A wrong guess produces a set of cards about the wrong subject, which is expensive to notice and to undo.

### Step 2: Scan for existing cards first

Read the files in the Anki finished directory — defined as `ANKI_FINISHED_DIR` in the `/anki` skill — and list the concepts already captured that overlap this work.

Do this **before** reading the source material, not after. Reading the PRD first primes you to find every concept in it novel, and the dedupe pass then rubber-stamps what you have already decided to write.

Carry the overlap list into Step 4 as an exclusion list.

### Step 3: Read the whole source, not the recent part

- **The PRD document end to end**: every milestone, the full decision log, the architecture choices, and the requirements. Not only the most recent milestone.
- **The code**: `git diff main...HEAD` to identify the files created or modified, then read the substantive ones.
- **The research documents** the PRD references, where a decision's reasoning lives there rather than in the log row.

The decision log is usually the richest source, because it records what was rejected and why — which is the part that is not recoverable from reading the finished code.

### Step 4: Hand off to `/anki`

Invoke the `/anki` skill with the material gathered above, and tell it explicitly that the source is the PRD and the diff rather than the conversation.

Pass along:

- The exclusion list from Step 2.
- The concepts worth capturing, favouring: architectural decisions and the reasoning behind them; new technologies or patterns introduced; how components fit together; and non-obvious choices from the decision log.
- What to leave alone: implementation minutiae, boilerplate, and anything already familiar.

**Cut aggressively.** A smaller set of concept-driven cards beats a complete inventory of the work. If a card would only make sense to someone who had read this PRD, it is a project note rather than a flashcard.

Two of `/anki`'s rules bite harder on this input than on a conversation, so expect to lean on them rather than restating them: its "each card is an island" rule under Future-Self Accessibility, and its ban on project-internal labels. A PRD is written in milestone and phase identifiers throughout, so cards drafted from one drift toward that vocabulary by default.

## Success criteria

- Existing cards were scanned before the source material was read, and the overlap list was passed to `/anki`.
- Every card traces to the PRD document, its decision log, or the diff — none to conversation context alone.
- The decision log was read, not just the milestones.
- Card count is lower than the number of concepts identified, and the difference was a deliberate cut rather than an omission.
