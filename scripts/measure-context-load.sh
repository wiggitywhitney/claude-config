#!/usr/bin/env bash
# ABOUTME: Enumerates every rules/ file and skill, reports its Claude Code loading
# ABOUTME: mechanism and byte cost, and emits the PRD #109 Milestone A2 load inventory as markdown.

set -euo pipefail

# Resolve the repo root from this script's location so the output is identical
# regardless of the working directory it is invoked from. An explicit first argument
# overrides it, which is how the bats suite points the script at a fixture tree —
# the same convention check-rule-frontmatter.sh uses.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ $# -gt 0 ]]; then
  REPO_ROOT="$(cd "$1" && pwd)"
else
  REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

GLOBAL_CLAUDE_MD="${REPO_ROOT}/global/CLAUDE.md"
# A second CLAUDE.md carries @-imports as well. Scanning only the global one reported
# rules referenced from here as on-demand, understating the always-loaded total by their
# full byte count and hiding two both-mechanisms violations from the inventory. Optional:
# a repo without one is normal, not an error.
PROJECT_CLAUDE_MD="${REPO_ROOT}/.claude/CLAUDE.md"
RULES_DIR="${REPO_ROOT}/rules"
SKILLS_DIR="${REPO_ROOT}/.claude/skills"

if [[ ! -f "${GLOBAL_CLAUDE_MD}" ]]; then
  echo "error: ${GLOBAL_CLAUDE_MD} not found" >&2
  exit 1
fi

# Checked before any output is created. Without this, a missing rules/ lets find fail
# inside the process substitution while the loop still exits 0, so the script would
# atomically replace a good inventory with one whose rules table is empty — the worst
# possible failure for an evidence file, because it looks like a real measurement of
# zero rules rather than a broken run.
if [[ ! -d "${RULES_DIR}" ]]; then
  echo "error: ${RULES_DIR} not found" >&2
  exit 1
fi

# The generated report states that this script overwrites the inventory, so it has to
# actually do that rather than print to stdout and rely on the caller redirecting —
# otherwise a plain run leaves stale evidence in place while the file claims to be
# current. Build into a temp file and move it into place only on success, so a failure
# partway through cannot truncate the existing inventory.
OUTPUT_PATH="${REPO_ROOT}/docs/research/claude-config-load-inventory.md"
output_tmp="$(mktemp "${OUTPUT_PATH}.tmp.XXXXXX")"
trap 'rm -f "${output_tmp}"' EXIT

exec 3>&1        # keep the real stdout for status messages
exec > "${output_tmp}"

# Claude Code's import parser skips markdown code spans and fenced code blocks, so a
# path written inside backticks is a literal mention rather than an import. Stripping
# both before scanning is what separates the 11 genuinely @-referenced rules from the
# reference pointers that only look like imports.
strip_code() {
  local file="$1"
  # Drop fenced blocks, then inline code spans.
  sed -e '/^[[:space:]]*```/,/^[[:space:]]*```/d' "$file" | sed -e 's/`[^`]*`//g'
}

# An @-reference to a rule file, outside code, in any of the accepted path forms.
# Uses [[:space:]] rather than \s: \s is a GNU extension that POSIX ERE and BSD grep
# do not define, so on macOS's system grep it would match a literal "s" and misclassify
# any reference followed by prose starting with that letter.
# Deliberately `grep -E ... >/dev/null` rather than `grep -qE`. With -q, grep exits the
# instant it matches; if the match is near the top of a file larger than the 64 KB pipe
# buffer, the upstream sed in strip_code is still writing and dies of SIGPIPE. Under
# `set -o pipefail` that non-zero status becomes the pipeline's status, so a rule that
# *did* match is reported as unreferenced and silently vanishes from the always-loaded
# total. Reading all of stdin costs nothing at this file size and removes the trap.
# Regression test: "an @-reference is still found when global/CLAUDE.md exceeds the pipe buffer".
# Scans every CLAUDE.md that can carry imports, not just the global one, and records
# WHICH one matched in REF_SOURCE. The source is not cosmetic: only user-level imports
# were measured surviving compaction, so collapsing both into one boolean would make the
# report assert a measured verdict for the project-level case that the research
# explicitly lists as unknown.
REF_SOURCE=''
is_at_referenced() {
  local rel="$1" md
  REF_SOURCE=''
  for md in "${GLOBAL_CLAUDE_MD}" "${PROJECT_CLAUDE_MD}"; do
    [[ -f "$md" ]] || continue
    if strip_code "$md" | grep -E "@(~/\.claude/|\./)?${rel//./\\.}([[:space:]]|$|\))" >/dev/null; then
      # global wins when both match: a measured verdict is available for that path.
      if [[ "$md" == "${GLOBAL_CLAUDE_MD}" ]]; then
        REF_SOURCE='global'
        return 0
      fi
      REF_SOURCE='project'
    fi
  done
  [[ -n "$REF_SOURCE" ]]
}

# A rule carries paths: frontmatter only if the key appears inside the leading --- block.
has_paths_frontmatter() {
  local file="$1"
  [[ "$(head -1 "$file")" == "---" ]] || return 1
  # Same no-early-exit reason as is_at_referenced. The output here is only a few
  # frontmatter lines, so SIGPIPE was not reproducible — this is defensive, and it
  # keeps every pipeline in the script following one rule instead of two.
  sed -n '2,/^---$/p' "$file" | grep -E '^paths:' >/dev/null
}

bytes_of() { wc -c < "$1" | tr -d ' '; }

# Token estimate, calibrated against real /context output rather than the usual
# bytes/4 rule of thumb, which understates this repo's markdown by about 30%.
#
# Calibration, from /context on 2026-08-03 (bytes measured here / tokens reported):
#   writing-voice.md   21825 / 7700 = 2.84
#   global/CLAUDE.md   16137 / 5800 = 2.78
#   git-workflow.md     9975 / 3600 = 2.77
#   rules/README.md     7477 / 3100 = 2.41   <- table-heavy, tokenizes denser
#
# Prose sits near 2.8. Table-heavy files reach 2.4. For a cap check the conservative
# choice is the smaller divisor, because it yields the higher token count: a file
# flagged as over the cap should be genuinely over it, not marginally under.
readonly BYTES_PER_TOKEN_PROSE=28   # tenths, to stay in integer arithmetic
readonly BYTES_PER_TOKEN_DENSE=24

est_tokens() { echo $(( $1 * 10 / BYTES_PER_TOKEN_PROSE )); }
est_tokens_conservative() { echo $(( $1 * 10 / BYTES_PER_TOKEN_DENSE )); }

printf '# claude-config Load Inventory\n\n'
printf '<!-- GENERATED FILE — do not hand-edit. Every re-run of\n'
printf '     scripts/measure-context-load.sh overwrites this file completely.\n'
printf '     Analysis and findings live in claude-config-load-findings.md, which\n'
printf '     no script writes to. -->\n\n'
printf '> **Generated file.** Do not hand-edit — `scripts/measure-context-load.sh` overwrites it wholesale on every run.\n'
printf '> Interpretation, findings, and the reconciliation against `/context` live in [claude-config-load-findings.md](claude-config-load-findings.md).\n\n'
printf '**Generated by:** `scripts/measure-context-load.sh` — re-run to reproduce.\n'
printf '**Generated on:** %s\n' "$(date +%Y-%m-%d)"
printf '**Claude Code version:** %s\n' "$(claude --version 2>/dev/null || echo 'unknown')"
printf '**Issue #108 status at measurement time:** merged (the bare-rule-file leak is already fixed; pre-#108 numbers are not comparable)\n\n'
printf 'For rule files, the loading mechanism determines both the byte cost and whether content survives compaction.\n'
printf 'Skills differ: an invoked body is re-injected but truncated to 5,000 tokens from the bottom, so for skills\n'
printf 'size and instruction order also decide what survives. See the Skills section below.\n'
printf 'See `docs/research/claude-code-context-loading-and-compaction.md` for the platform rules this classification applies.\n\n'

# ---------------------------------------------------------------- rules

printf '## Rules\n\n'
printf '| Path | Loading mechanism | Bytes | Loaded in a fresh session | Survives compaction | Why |\n'
printf '|---|---|---:|---|---|---|\n'

total_always=0
total_ondemand=0
count_always=0
count_ondemand=0
count_bare=0

# Tracked separately from total_always because they are not interchangeable: the
# `include` bytes are what the #108 baseline measured, while bare-rule bytes are
# what #108 drove to zero. Summing them produces a figure that cannot be compared
# with the baseline and reads as though it can.
total_included=0
total_bare=0

while IFS= read -r file; do
  rel="${file#"${REPO_ROOT}/"}"
  b="$(bytes_of "$file")"
  scoped=no; referenced=no; ref_source=''
  has_paths_frontmatter "$file" && scoped=yes
  is_at_referenced "$rel" && referenced=yes
  ref_source="$REF_SOURCE"

  if [[ "$scoped" == yes && "$referenced" == yes ]]; then
    mech='**both — defect**'; loaded='yes'; survives='yes'
    why='Carries `paths:` **and** is `@`-referenced, so it loads twice. Violates the one-mechanism rule.'
    total_always=$((total_always + b)); count_always=$((count_always + 1))
    # Counted as included: it is @-referenced, which is what makes it always-loaded.
    total_included=$((total_included + b))
  elif [[ "$referenced" == yes ]]; then
    mech='`include`'; loaded='yes'
    if [[ "$ref_source" == global ]]; then
      survives='yes'
      why='`@`-referenced from `global/CLAUDE.md`; expanded at launch, and re-resolved through its parent after a compaction (observed at 2.1.220).'
    else
      survives='untested'
      why='`@`-referenced from `.claude/CLAUDE.md`; expanded at launch. **Project-level re-resolution after compaction is unmeasured** — the probe recorded no `include` record for a project-level import while all twelve user-level ones returned.'
    fi
    total_always=$((total_always + b)); count_always=$((count_always + 1))
    total_included=$((total_included + b))
  elif [[ "$scoped" == yes ]]; then
    mech='`path_glob_match`'; loaded='no'; survives='**no**'
    why='Loads only when a matching file is read; summarized away by compaction.'
    total_ondemand=$((total_ondemand + b)); count_ondemand=$((count_ondemand + 1))
  else
    mech='`session_start` (bare)'; loaded='yes'; survives='yes'
    why='No frontmatter and no `@`-reference, so it loads unconditionally every session.'
    total_always=$((total_always + b)); count_always=$((count_always + 1))
    count_bare=$((count_bare + 1)); total_bare=$((total_bare + b))
  fi

  printf '| `%s` | %s | %s | %s | %s | %s |\n' "$rel" "$mech" "$b" "$loaded" "$survives" "$why"
done < <(find "${RULES_DIR}" -name '*.md' -type f | sort)

claude_md_bytes="$(bytes_of "${GLOBAL_CLAUDE_MD}")"
claude_md_lines="$(wc -l < "${GLOBAL_CLAUDE_MD}" | tr -d ' ')"

# The project CLAUDE.md is always-loaded in its own right — the compaction probe
# recorded it returning with load_reason: compact. Counting global/CLAUDE.md while
# omitting this one understates the always-loaded set by its full size, the same class
# of omission as the @-referenced file living outside this repository. Reported as its
# own row rather than folded in, because the #108 baseline did not include it and a
# merged figure would invite a comparison that does not hold.
project_md_bytes=0
project_md_count=0
if [[ -f "${PROJECT_CLAUDE_MD}" ]]; then
  project_md_bytes="$(bytes_of "${PROJECT_CLAUDE_MD}")"
  project_md_count=1
fi

printf '\n### Rule totals\n\n'
printf '| Category | Files | Bytes |\n|---|---:|---:|\n'
printf '| `global/CLAUDE.md` itself | 1 | %s |\n' "$claude_md_bytes"
if [[ "$project_md_count" -eq 1 ]]; then
  printf '| `.claude/CLAUDE.md` itself | 1 | %s |\n' "$project_md_bytes"
fi
printf '| Always-loaded rules | %s | %s |\n' "$count_always" "$total_always"
printf '| **Always-loaded total** | **%s** | **%s** |\n' \
  "$((count_always + 1 + project_md_count))" \
  "$((total_always + claude_md_bytes + project_md_bytes))"
printf '| On-demand path-scoped rules | %s | %s |\n' "$count_ondemand" "$total_ondemand"
printf '\n`global/CLAUDE.md` is %s lines against the 200-line target Anthropic documents.\n' "$claude_md_lines"
if [[ "$count_bare" -gt 0 ]]; then
  printf '\n**%s bare rule file(s) found** with neither mechanism. Issue #108 drove this to zero; a non-zero count here is a regression.\n' "$count_bare"
else
  printf '\nNo bare rule files. Issue #108 drove this to zero and it has stayed there.\n'
fi

# ---------------------------------------------------------------- skills

printf '\n## Skills\n\n'
printf 'A skill costs its one-line `description` in every session; the body loads only on invocation.\n'
printf 'After compaction an invoked body is re-injected but truncated to 5,000 tokens, keeping the start of the file.\n\n'
printf '| Skill | Body bytes | Est. tokens | Worst case | Over 5k-token cap | In startup listing | Description bytes |\n'
printf '|---|---:|---:|---:|---|---|---:|\n'

skill_body_total=0
skill_desc_total=0
skill_count=0
over_cap=0
at_risk=0

if [[ -d "${SKILLS_DIR}" ]]; then
  while IFS= read -r skill_md; do
    name="$(basename "$(dirname "$skill_md")")"
    b="$(bytes_of "$skill_md")"
    t="$(est_tokens "$b")"

    desc="$(sed -n '2,/^---$/p' "$skill_md" | grep -E '^description:' | head -1 | cut -d: -f2- || true)"
    desc_bytes="${#desc}"

    listed='yes'
    if sed -n '2,/^---$/p' "$skill_md" | grep -E '^disable-model-invocation:[[:space:]]*(true|yes|on|1)' >/dev/null; then
      listed='no — user-invoked only'
      desc_bytes=0
    fi

    tw="$(est_tokens_conservative "$b")"

    # Both figures are estimates derived from a bytes-per-token ratio calibrated
    # against /context output for memory files. Neither is a measurement of how this
    # particular file tokenizes, so the labels say "estimated" rather than
    # "confirmed" — see the note under the totals.
    cap='no'
    if [[ "$t" -gt 5000 ]]; then
      cap='**over on both estimates**'; over_cap=$((over_cap + 1))
    elif [[ "$tw" -gt 5000 ]]; then
      cap='over on the dense estimate only'; at_risk=$((at_risk + 1))
    fi

    printf '| `%s` | %s | %s | %s | %s | %s | %s |\n' "$name" "$b" "$t" "$tw" "$cap" "$listed" "$desc_bytes"

    skill_body_total=$((skill_body_total + b))
    skill_desc_total=$((skill_desc_total + desc_bytes))
    skill_count=$((skill_count + 1))
  done < <(find "${SKILLS_DIR}" -name 'SKILL.md' -type f | sort)
fi

printf '\n### Skill totals\n\n'
printf '| Metric | Value |\n|---|---:|\n'
printf '| Skills | %s |\n' "$skill_count"
printf '| Total body bytes (loaded only when invoked) | %s |\n' "$skill_body_total"
printf '| Startup listing cost (descriptions only) | %s |\n' "$skill_desc_total"
printf '| Skills estimated over the 5,000-token cap on both ratios | %s |\n' "$over_cap"
printf '| Skills over on the dense ratio only | %s |\n' "$at_risk"
printf '\n**These counts are estimates, not observations.** The bytes-per-token ratio was\n'
printf 'calibrated against `/context` output for *memory files*; no per-skill tokenization was\n'
printf 'measured. A skill near the boundary could fall on either side. To turn these into\n'
printf 'observations, invoke each skill and read its reported token count from `/context`.\n'
printf 'Do not restate these numbers downstream as confirmed cap violations.\n'

printf '\n## Always-loaded budget\n\n'
printf 'Components are kept separate rather than summed into one figure, because they are not\n'
printf 'interchangeable and only some are comparable with the #108 baseline.\n\n'
printf '| Component | Bytes | Comparable with #108 baseline |\n|---|---:|---|\n'
printf '| `global/CLAUDE.md` | %s | yes |\n' "$claude_md_bytes"
printf '| `@`-referenced rules (`include`) | %s | yes |\n' "$total_included"
printf '| Bare rule files (`session_start`) | %s | no — #108 drove this to zero |\n' "$total_bare"
printf '| Skill descriptions, this repo only | %s | no — not in the baseline |\n' "$skill_desc_total"
printf '\n### Comparison with the #108 post-fix baseline\n\n'
printf 'The baseline covered `global/CLAUDE.md` plus its `@`-referenced rules and nothing else,\n'
printf 'so only those two rows may be compared against it.\n\n'
printf '| | Bytes |\n|---|---:|\n'
printf '| #108 post-fix baseline | 56994 |\n'
printf '| Same components measured now | %s |\n' "$((claude_md_bytes + total_included))"
printf '| Drift | %s |\n' "$((claude_md_bytes + total_included - 56994))"
printf '\n**This is a repository-only lower bound, not the true always-loaded total.**\n'
printf 'At least one always-loaded `@`-import lives outside this repository and cannot be\n'
printf 'measured by a sweep of `rules/`; see `claude-config-load-findings.md`. Any budget set\n'
printf 'from these numbers must be set against observed load rather than against this table.\n'

# Restore stdout and publish atomically.
exec 1>&3
mv "${output_tmp}" "${OUTPUT_PATH}"
trap - EXIT
echo "Wrote ${OUTPUT_PATH}"
