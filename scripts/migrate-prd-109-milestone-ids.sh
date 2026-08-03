#!/usr/bin/env bash
# ABOUTME: One-time migration renaming PRD #109 milestone IDs from short M-numbers
# ABOUTME: to phase-prefixed spelled-out names, disambiguating PRD #84's IDs first.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PRD="${REPO_ROOT}/prds/109-claude-config-audit-redesign.md"

if [[ ! -f "$PRD" ]]; then
  echo "error: $PRD not found" >&2
  exit 1
fi

# Idempotence guard. This migration is one-time and NOT safe to re-run: the
# Decision 34a row quotes the old short forms (`M2`, `M7`, `M7b`) as examples while
# explaining the rename, and a second pass would rewrite those quotations into the
# new IDs — turning an explanation of the migration into nonsense. Detect that the
# migration has already happened and refuse rather than corrupt.
if grep -q 'Milestone A1' "$PRD"; then
  echo "Migration has already run — '$PRD' already contains phase-prefixed IDs."
  echo "Refusing to re-run: the Decision 34a row quotes the old short forms as"
  echo "examples, and a second pass would rewrite those quotations."
  exit 0
fi

before="$(grep -c -o -E '\bM[0-9]+b?\b' "$PRD" || true)"
echo "Short milestone tokens before migration: ${before}"

# ---------------------------------------------------------------------------
# Stage 1 — disambiguate PRD #84's own milestone IDs.
#
# The Milestone D1 section describes PRD #84's internal milestones using the same
# M1..M8 notation as this PRD's. Renaming those to #109's phase IDs would produce
# sentences that read correctly and state something false, which is worse than a
# visibly broken reference. They are rewritten to an explicit, non-colliding form
# BEFORE the global pass, so stage 2 cannot match them.
# ---------------------------------------------------------------------------
perl -0pi -e 's/^\| M([1-5]) \|/| PRD #84 Milestone $1 |/gm' "$PRD"
perl -0pi -e 's/\bThe M5 row\b/The PRD #84 Milestone 5 row/g' "$PRD"
perl -0pi -e 's/\bThe M1 row\b/The PRD #84 Milestone 1 row/g' "$PRD"
perl -0pi -e 's/\bits M7\b/its Milestone 7/g' "$PRD"
perl -0pi -e 's/\bits M8\b/its Milestone 8/g' "$PRD"

# ---------------------------------------------------------------------------
# Stage 2 — rename this PRD's milestones to phase-prefixed names.
#
# Phases: A audit, B research, C design, D disposal and verification.
# M7b is replaced before M7 so the shorter token cannot corrupt the longer one.
# Word boundaries are used rather than a trailing space, because references
# appear before periods, commas, and closing parentheses as well.
# ---------------------------------------------------------------------------
perl -0pi -e 's/\bM7b\b/Milestone D1/g' "$PRD"   # must precede M7

perl -0pi -e 's/\bM1\b/Milestone A1/g'  "$PRD"   # reference repos cloned
perl -0pi -e 's/\bM2\b/Milestone A2/g'  "$PRD"   # load measurement
perl -0pi -e 's/\bM3\b/Milestone A3/g'  "$PRD"   # permissions
perl -0pi -e 's/\bM7\b/Milestone A4/g'  "$PRD"   # repo-native audit

perl -0pi -e 's/\bM4\b/Milestone B2/g'  "$PRD"   # Viktor spike
perl -0pi -e 's/\bM6\b/Milestone B3/g'  "$PRD"   # Michael spike
perl -0pi -e 's/\bM5\b/Milestone B4/g'  "$PRD"   # skill families diffed

perl -0pi -e 's/\bM8\b/Milestone C2/g'  "$PRD"   # spec written
perl -0pi -e 's/\bM9\b/Milestone D2/g'  "$PRD"   # verification pass

after="$(grep -c -o -E '\bM[0-9]+b?\b' "$PRD" || true)"
echo "Short milestone tokens after migration:  ${after}"

if [[ "$after" -ne 0 ]]; then
  echo "WARNING: ${after} short token(s) remain. Inspect before committing:" >&2
  grep -n -o -E '\bM[0-9]+b?\b' "$PRD" >&2 || true
  exit 1
fi

echo "OK: every short milestone token migrated."
echo "Note: Milestone B1 (capability spike) and Milestone C1 (collaborative design) are new"
echo "      and are added by hand, not by this script."
