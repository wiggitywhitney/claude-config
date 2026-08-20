Summarize the design decisions made so far in this session with a strong focus on preventing regression. Produce a structured document with these sections:

## CURRENT APPROACH
The implementation approach that has been chosen. Be specific about what we ARE doing.

## REJECTED APPROACHES — DO NOT SUGGEST THESE
List every approach that was explicitly considered and rejected, with the reason it was rejected.
Format: "- [REJECTED] <approach>: <reason rejected>"
Be exhaustive — this is the most important section.

## KEY DESIGN DECISIONS
Numbered list of concrete decisions made in this session, with rationale.

## HARD CONSTRAINTS
Technical requirements, non-negotiables, environment constraints that drove decisions.

## EXPLICIT DO-NOTs
Bulleted list of specific things NOT to do, derived from decisions above.

## CURRENT STATE
What has been built or decided, and what remains to be done.

After generating the document, save it to `.claude/design-decisions.md` in the current project directory (create `.claude/` if it doesn't exist). Confirm the file was saved.
