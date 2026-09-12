# Research: Michael Forrester's LLM Coding Workflow

**Project:** claude-config
**Last Updated:** 2026-08-31

## Update Log

| Date | Summary |
|------|---------|
| 2026-04-07 | Initial research — cloned private repo peopleforrester/llm-coding-workflow, read all key files |
| 2026-04-15 | Re-pulled before PRD #58 implementation. 8 commits merged since initial research — added structured task management (tasks.yaml + tasks.sh), repo-backup system, PRD workflow templates, and new skills (init-state, prd, repo-backup, task). |
| 2026-08-31 | **Full re-read for PRD #109 Milestone B3.** Re-pulled `llm-coding-workflow` (`70257db` → `d8eeb0f`) and every Michael repo that survived the Milestone A1 triage (Decision 31): `claude-dotfiles`, `Brain_spec_skills_claude`, `mcp_best_practices`, `observe-claude-code`, `copilot-cli-enterprise-patterns`, `telemetry-agent`. `agentic-covenants` — discarded at A1 for having "no Claude Code config" — was re-cloned as a narrow, one-time exception (CodeRabbit, 2026-08-24) to answer the rule-enforcement question below only. The audit's own goal changed since April (Decision 64): this pass is oriented around sub-agent orchestration and self-verification — "how much does Michael not have to approve, and does anything check an agent's output before it reaches him" — rather than the original workflow-hygiene framing. **Section "What Whitney Has That Michael Doesn't" below and the older skill-diff entries are unchanged findings, kept for continuity; the two named-question sections and the capability table are new.** |

---

## Full Repo/SHA Table (2026-08-31 pull)

| Repo | Local path | SHA at this pull | Note |
|---|---|---|---|
| `peopleforrester/llm-coding-workflow` | `~/Documents/Repositories/forrester-workflow` | `d8eeb0f` | Primary repo, deep-read |
| `peopleforrester/claude-dotfiles` | `research/repos/claude-dotfiles` | `631ae23` | Decision 31 survivor |
| `peopleforrester/Brain_spec_skills_claude` | `research/repos/Brain_spec_skills_claude` | `9089004` | Decision 31 survivor |
| `peopleforrester/mcp_best_practices` | `research/repos/mcp_best_practices` | `272fb9a` | Decision 31 survivor. Upstream history was force-pushed since the last clone (81 vs. 91 divergent commits) — local clone hard-reset to `origin/main`, no local edits lost |
| `peopleforrester/observe-claude-code` | `research/repos/observe-claude-code` | `1479291` | Decision 31 survivor |
| `peopleforrester/copilot-cli-enterprise-patterns` | `research/repos/copilot-cli-enterprise-patterns` | `02cf5ff` | Decision 31 survivor |
| `peopleforrester/telemetry-agent` | `research/repos/telemetry-agent` | `c73f830` | Decision 31 survivor, unchanged since last pull |
| `peopleforrester/agentic-covenants` | `research/repos/agentic-covenants` | `664c8dd` | **Narrow re-clone exception**, enforcement question only |

---

## Named Question 1: How does he run Claude unattended, and what stops it interrupting him? (Decision 45)

Read from his committed configuration first, per the milestone's own instruction.

**Permission mode.** `claude-config/settings.json` (symlinked to `~/.claude/settings.json`) sets `"defaultMode": "bypassPermissions"`, plus `skipDangerousModePermissionPrompt: true` and `skipAutoPermissionPrompt: true`, with every tool category (`Bash`, `Read`, `Edit`, `Write`, `Glob`, `Grep`, `WebFetch`, `WebSearch`) in `permissions.allow`. This is not a narrow allowlist of specific safe command shapes — it is maximal allow plus bypassed prompting.

**The safety net is a fixed deny list, not narrow allow-scoping.** 16 patterns block destructive absolutes regardless of trust: `rm -rf /`, `rm -rf ~`, `sudo rm -rf*`, `dd if=*`, `dd of=/dev/*`, `mkfs*`, `chmod -R 777*`, `git push --force*`/`-f*`/`--delete*`, and `Read`/`Grep` on private-key file patterns. `claude-config/rules/permission-profiles.md` states the model explicitly: *"Permissions answer: may this command run without asking? Hooks answer: given that it ran, did it pass the gate? Deny list answers: is this forbidden regardless of trust?"* — and *"the deny list only ever grows"*, enforced by tests in both directions when switching tiers.

**Named permission tiers exist and are switchable.** `claude-config/permission-profiles.json` defines `conservative` / `balanced` / `autonomous` (the last being `bypassPermissions`), applied via `scripts/permission-profile.sh show|list|diff|apply` with an automatic timestamped backup before any apply. `autonomous` is documented as "the working default on Naruto" — his primary machine.

**Why approval is rarely needed is structural, not command-shaped:**
- `defaultMode: bypassPermissions` removes prompting entirely for allowed tools — the opposite of narrowing what's allowed.
- Destructive operations are excluded by a fixed deny list rather than by scoping the allow list down.
- Hooks are a second, separate gate from the permission prompt — a `PreToolUse` hook still runs *before* the tool executes and can block it outright (exit 2), but it checks a different thing than the prompt does. The explicit design split, in his own words: "prompts answer may-this-run, hooks answer did-it-pass" — the hook is policy enforcement layered on top of an already-permitted tool call, not a second chance to ask.
- Permission posture is **per-user, not global** (`netcup-machine.md`): "Michael's settings.json ships `defaultMode: bypassPermissions`... This stays a deliberate per-user choice" — a new collaborator on his shared VPS must configure their own; it does not propagate.
- Mutating fleet operations (`scripts/fleet.sh sync|run`) require an explicit `--yes` flag rather than an interactive prompt, specifically so "an unattended fan-out cannot hang on a non-TTY."

**Already have / worse / nothing, against Whitney's current setup:** Whitney already runs auto mode (Decision 48) with a comparable allow-broad/deny-narrow shape. The one structural difference worth naming: Michael's deny list is documented as monotonic ("only ever grows") with bidirectional tests enforcing it — that specific invariant-as-a-test pattern is not present in Whitney's config today. **Already have, roughly equivalent**, with one concrete idea (deny-list-only-grows test) not yet adopted.

---

## Named Question 2: How does he stop an agent from ignoring a rule it already agreed to? (Whitney, 2026-08-04)

This question spans four repos with genuinely different answers, ranging from real blocking mechanisms to explicit admissions that no such mechanism exists.

### What blocks, concretely (llm-coding-workflow)

- **`enforce-prd-issue-first.sh`** (PreToolUse, `Edit|Write`) — exit-2 blocks creating `prds/N-slug.md` unless GitHub issue N already exists (checked live via `gh issue view`). Framed explicitly against a real past failure: "stranded PRDs 6 through 11."
- **`block-sensitive-files.sh`** (PreToolUse) — exit-2 blocks writes to `.env`, `*.pem`, `*.key`, and credential/secret/password/token-named files.
- **`check-commit-message.sh`** (PreToolUse, `Bash` matcher on `git commit`) — extracts the commit message across `-m`/heredoc/`--message=` forms and exit-2-blocks AI/Claude/Anthropic attribution, with a scrubbed allowlist so real product names don't false-positive. This is the same rule Whitney enforces via her own commit-message hook, implemented the same way.
- **Tiered native git hooks** — pre-commit runs fast lint/typecheck; pre-push runs secret-scan + unit tests on every push, e2e only on pushes to `main`; a `change-scope.sh` predicate skips irrelevant tiers. Per-repo opt-outs (`.skip-lint`, `.skip-typecheck`) exist, but a bypassed local hook is still caught server-side: "CI remains the backstop."
- **CI** (`.github/workflows/ci.yml`) — ruff, mypy, a check that a generated table (rules README) is actually in sync with source, and unit tests, blocking independent of what happened locally.

**Explicitly acknowledged as advisory-only, not blocking**, and documented as such in the repo itself: `cascade-decision-check.sh`, `check-rule-frontmatter.sh` ("Advisory only; never blocks"), `check-aboutme.sh` ("NEVER blocks... missing ABOUTME is a style issue, not a correctness issue"), `auto-test-on-stop.sh` ("Non-blocking... never fails the hook"). The `lifecycle-phases.md` 3×3 phase-gate convention (INCEPTION → CONSTRUCTION → OPERATIONS, "no Edit/Write/Bash mutation until 1.3 passes") is **prose-only** — a norm surfaced by hooks and a status line, not itself a blocking gate; the file's own wording ("MANDATORY items cannot be skipped, period") is a stated norm, not an enforced one. The issue-link commit-trailer convention is deliberately warn-only "for now," with a comment explaining the reasoning: "A gate at full strength on day one teaches the `--no-verify` reflex."

**Verdict for this repo: it is not a solved problem, it is a triaged one.** He blocks the failures that recurred badly enough to earn a hook (PRD/issue linkage, sensitive files, commit attribution, secrets, tests) and leaves the rest — cosmetic and slow-to-adopt rules — as prose, explicitly and by design, rather than by oversight.

### The Copilot CLI angle (copilot-cli-enterprise-patterns) — the sharpest illustration of prose vs. structure

This repo is not Claude Code, but its central content is a direct A/B demonstration of exactly this question. `labs/lab-05-break-the-hook/README.md` proves that a prose rule in `AGENTS.md` ("ALWAYS run pytest...") is unreliable, while a `postToolUse` hook surfacing failures forces correction. Its `enterprise/security-deny-rules.md` documents deny-flags that "always win," even under full auto-approve (`--yolo`) — the same "deny list only ever grows" invariant found in the primary repo, restated for a different agent CLI. Its `patterns/autopilot-mode.md` defines an explicit "enforcement floor" required *before* enabling unattended mode: a lint/security PreToolUse hook, a test PostToolUse hook, deny-flags for destructive shell/secret reads, a clean tree, and a disposable branch — a checklist for "may this run unattended," separable from and prerequisite to the unattended-operation question above.

### telemetry-agent — the most structurally-enforced of the four (see also Question about oversight, below)

This one differs sharply from a rule the agent is asked to follow: it uses deterministic **pre-landing gates that block a proposed change from landing at all**, not a rule the agent is trusted to obey. Snapshot-before-edit + hard revert on any per-file failure; a validation chain (syntax → lint → Weaver schema check) with a bounded fix-retry loop that reverts rather than warns when exhausted; a variable-shadowing pre-check run via ts-morph's binder *before* code insertion, specifically because that class of bug "will compile, lint, and pass schema validation... but silently change runtime behavior" — i.e., a bug class invisible to after-the-fact review; hard token/file/span budgets enforced by the Coordinator, not the LLM; and Coordinator-exclusive write access to the one shared file (the OTel SDK init file) so the LLM agent has no tool that can touch it at all. This is enforcement by removing the capability to violate the rule, not by checking whether it was violated.

### agentic-covenants (the narrow re-clone) — a real hook, an honest account of its own bypasses

Re-opened specifically for this question after being discarded at Milestone A1 for "no Claude Code config" — that discard was correct against the question A1 was asking (does this repo contain reusable Claude Code config material, in general); it is not correct against this narrower one. `controls/authorization/client-side/pre_tool_use.sh` + `settings.json` is a real, working Claude Code `PreToolUse` hook: it regex-matches the Bash command against hard-deny patterns (`rm -rf /`, `terraform destroy`, `DROP TABLE`, force-push, fork bombs) and obfuscation patterns (base64-decode, `eval $(`, `curl | sh`), exit-2 blocking on match. `controls/approval-gating/client-side/pre_tool_use_tiered.sh` tiers commands by severity, up to a typed-verbatim-confirmation tier with a session destructive-action counter.

What makes this repo worth citing narrowly rather than wholesale: it is unusually candid that this class of hook is defeatable, and says so in its own `framework/BYPASSES.md` — command obfuscation, an equivalent-but-unlisted command (`kubectl scale --replicas=0` instead of `kubectl delete`), editing the hook file directly if the agent has write access, `--dangerously-skip-permissions` — citing an external study (Adversa GuardFall, June 2026) that found 10 of 11 open-source coding agents had defeatable client-side command guards because "the guard inspects the raw string, and the shell then applies quote removal and variable expansion afterwards." Its `framework/ASSURANCE.md` reports that its own flagship Kyverno admission policy shipped broken — denied everything, and passed all its deny tests while failing every admit test — until tested in both directions; a genuinely useful, concrete data point about the gap between "wrote an enforcement artifact" and "verified it enforces."

**The one thing this repo does not provide**: any mechanism connecting a specific *agreed* rule (its "Charter" document) to the enforcement layer at runtime. That link is manual and human-maintained, and the repo says so outright — nothing checks that the Charter and the actual hooks/RBAC/policies still agree. Everything outside the Claude Code hook fragment (Kyverno, RBAC, seccomp, Terraform, IAM, Sigma/Falco) targets Kubernetes/cloud infrastructure generally, not the coding-agent harness — adoptable only if the target is that kind of infra.

**Already have / worse / nothing:** Whitney's push-gate reviewer trial (Decision 66, concluded 2026-08-26) tested the same category of question — does a mechanism stop a Claude session from ignoring an agreed rule — and reached a compatible conclusion via a different route: CodeRabbit already covers the same-vendor gap better than a home-built same-vendor checker, and the trial's own artefact was judged unneeded complexity. **Already have equivalent evidence** that hand-rolled command-blocking hooks are a known, limited pattern (not a solved one) — Michael's own repos independently confirm the same limitation rather than offering a stronger answer.

---

## Parallel Work: tmux and Netcup

Two distinct mechanisms, worth keeping separate:

**A. `worktree-launch.py`** — a deterministic (non-agentic) Python orchestrator. Given a pipe-delimited task list (`name|prompt`), it shells out `claude --worktree <name> --tmux -p <prompt>` per task, staggered by a configurable delay to avoid overwhelming the system, with a `--dry-run` preview. Each task gets an isolated git worktree (no file conflicts) and its own tmux window. This runs locally, on whichever machine invokes it — nothing Netcup-specific about it.

**B. Netcup as a shared, persistent multi-tenant tmux host.** A Debian VPS is the fleet's "always-on hub" — workstations attach via `ssh -t netcup "tmux attach || tmux new -s main"`. It runs `claude`, `codex`, and `gemini` natively in tmux sessions, multi-tenant via separate Unix users with scoped sudo, tmux naturally isolated per-user (`/tmp/tmux-<uid>/`). `scripts/reap-idle-sessions.sh` sweeps and terminates Claude Code processes idle beyond a cutoff (default 4 days), walking `/proc` ancestry rather than PID heuristics so it never touches attached sessions or itself.

Cross-machine fan-out (distinct from parallel local agents) goes through `scripts/fleet.sh` + a host registry (`netcup`=local/operator, two boxes reached via Tailscale-mesh SSH, one disabled/corp-MDM-blocked), with `sync` (pull-only, `--ff-only`) and `run "<cmd>"` (requiring an explicit `--yes` flag rather than a prompt, so an unattended fan-out can't hang on a non-TTY).

`tasks.yaml`'s claim/release locking (`claimed_by` as a session identifier) exists specifically because worktree-launch and Netcup both create genuine concurrent-session scenarios — `scripts/tasks.sh` was hardened against concurrent worktree mutations (2026-04-28), which is the same problem this parallel-work mechanism creates for shared state.

**Already have / worse / nothing:** Whitney has neither a persistent shared multi-tenant remote host nor a scripted local worktree-fan-out tool. **Have nothing** for both halves of this capability today.

---

## Capability Inventory: already-have / have-worse / have-nothing

| Capability | Michael | Whitney | Verdict |
|---|---|---|---|
| Permission mode for unattended running | `bypassPermissions` default + monotonic deny list, tiered profiles switchable via script | Auto mode (Decision 48), broad allow / narrow deny | **Already have**, roughly equivalent shape; the deny-list-as-bidirectional-test pattern is a small adoptable idea |
| PR-time / cross-vendor review | None found — no CodeRabbit-equivalent bot referenced anywhere in his repos | CodeRabbit CLI + PR review, mandatory before merge | **Have better** |
| Rule enforcement via blocking hooks | Real exit-2 hooks for PRD/issue linkage, sensitive files, commit attribution; explicitly prose-only elsewhere, and says so in the repo | Comparable hook-based enforcement (commit-message policy, push-gate trial concluded and retired) | **Already have**, same triaged-not-solved shape |
| Pre-landing structural gates on agent-authored code (revert-on-failure, shared-file exclusivity, pre-insertion static checks) | `telemetry-agent`'s Coordinator: snapshot/revert, validation fix-loop, variable-shadowing pre-check, token/span budgets, Coordinator-exclusive shared-file writes | Nothing structurally equivalent — CodeRabbit and the retired reviewer trial both review *after* a diff exists, not before it lands | **Have nothing** — this is the most concrete new idea from this milestone |
| Telemetry/observability of agent sessions | Custom `workflow/` Python package: token/cost, TDD adherence, drift, sycophancy detection, pattern-repetition, decision logs, parsed directly from session JSONL; OTLP export enabled | Nothing equivalent (`/cost-tracker` was removed, Decision 62, for non-use) | **Have nothing**, and Whitney previously had a worse/unused version of a piece of this and discarded it |
| Observability *of tool denials specifically* (making a block visible after the fact) | `observe-claude-code`: pairs one hardcoded deny hook with an OTel trace/log of the denial, explicitly so the block is visible on a dashboard | Nothing — CodeRabbit findings are visible in a PR, but a hook-level deny isn't separately surfaced anywhere | **Have nothing**, low priority — his own demo names this as future/adjacent work, not something to imitate wholesale |
| Structured task queue with dependency tracking and claim locks | `tasks.yaml` + GUPP, hardened against concurrent worktree mutations | Built-in `TaskCreate`/`TaskUpdate`/`TaskList` (no dependency graph, no cross-session claim lock) | **Already have** a simpler adequate substitute for solo work; **have nothing** for the multi-agent claim-lock case, which only matters if parallel worktrees are adopted |
| Compaction-resilient plan execution (`_execution-state.md`, `/plan-execute`, `/long-run`) | Confirmed unchanged in substance since the 2026-04-15 read (only cosmetic frontmatter edits, 2026-08-13) | Rejected deliberately for this repo (PRD #84 Decision 1) in favor of PRD-file-as-state | **Deliberately have a different, adequate equivalent** — this pass finds no new evidence to revisit that decision |
| Parallel local agent fan-out (worktree + tmux) | `worktree-launch.py`, staggered launch, dry-run preview | Nothing scripted | **Have nothing** |
| Persistent shared multi-tenant remote host | Netcup VPS, tmux-per-user, idle-session reaper | Nothing | **Have nothing** |
| Cross-vendor session handoff (Claude ↔ Codex/Gemini transcripts) | `/handoff` skill + vendored "authsec-bridge" tool | Nothing | **Have nothing**, low priority — single-vendor workflow today |

---

## Downstream Impact Flagged to Whitney

**PRD #84 is not invalidated by this pass.** PRD #84's Decision 1 (2026-04-18) rejected both `_execution-state.md` and `tasks.yaml`+GUPP as unneeded — the PRD file already serves as milestone-grain execution state. This pass confirms both Michael systems are functionally unchanged since the decision was made (only a repo-wide skill-description rewording touched either file, 2026-08-13); no new evidence surfaced that would reopen Decision 1. PRD #84 itself is scheduled for retirement under this PRD's Milestone D1, unrelated to this finding.

**The one idea worth carrying into Milestone C1's design discussion**: `telemetry-agent`'s pre-landing structural gates (snapshot/revert, fix-retry validation loop, pre-insertion static checks, Coordinator-exclusive writes to shared files) are a materially different answer to "does anything check an agent's output before it reaches a human" than either CodeRabbit or the retired reviewer-sub-agent trial — both of those review a *finished* diff; this reviews and can revert *before* a change is even proposed as final. Milestone C1 should see this as a distinct design option, not a restatement of the reviewer-trial finding.

---

## Superseded Content (kept below for continuity; see the 2026-08-31 entry above for current findings)

### Ideas for `claude-config` (Coding Workflow) — as of 2026-04-15

#### High confidence — directly applicable, low effort

**`config-sync.sh`** — Detects drift between live `~/.claude/` and the claude-config repo using `rsync --dry-run --itemize-changes`. Supports `--apply live` (update repo from live) and `--apply repo` (adopt repo into live). Implementation at `~/Documents/Repositories/forrester-workflow/scripts/config-sync.sh`. The excludes file (`scripts/config-sync-excludes.txt`) documents every ephemeral `~/.claude/` directory that should never be synced. Note: the dry-run uses `--checksum` for accuracy; apply mode uses size+mtime for speed.

---

**`/post-compact` skill** — Re-anchor context after a `/compact` event. Reads CLAUDE.md, PROJECT_STATE.md, git state, reports orientation. Skip the `tasks.yaml`/`_execution-state.md` awareness for Whitney — she uses Claude Code's built-in task system and PRD files instead.

---

**`auto-reanchor.sh` PostCompact hook** — Fires automatically after every compaction without manual invocation. Whitney's equivalent (adopted PRD #58 M2) reads the active PRD instead of PROJECT_STATE.md.

---

**Stop hook: auto-test** — Runs tests after every Claude response (not just every commit), non-blocking. Whitney's test enforcement remains commit-gated only (PRD #58 M3 skip, reconsidered for autonomous-only use in `michael-autonomous-execution-principles.md`).

---

**`/continue` skill** — Reads TaskList, PRD state, git log/status, summarizes what to pick up next. Adopted for Whitney's version in PRD #58 M4.

---

#### Medium confidence — applicable but more setup

**`/plan-execute` skill** — Compaction-resilient execution with `_execution-state.md` on disk. Confirmed still current as of 2026-08-31 (see above); still not adopted for Whitney per PRD #84 Decision 1.

---

**`/cost-tracker` equivalent** — **Superseded.** Whitney built this in PRD #58 and removed it in Decision 62 (2026-08-20) after determining she never used it.

---

**`/review-recency` skill** — Freshness check for outdated dependency versions, deprecated patterns, stale rules. Complements `/research`. Not yet adopted.

---

**Ralph loop detection** in SessionStart hook — Detects when Claude is cycling on failures via a local state file. Not yet adopted.

---

**Sycophancy detection** — Runs regex patterns against Claude's own responses in session JSONL files, flagging flattery and agree-without-pushback patterns. Not yet adopted; still novel relative to Whitney's setup as of this pass.

---

### Ideas for `Journal` Repo (Personal Assistant Workflow)

**Stop hook for session harvesting**, **`/summary-session` skill**, **weekly JSON trend snapshots**, **`/summary-weekly` skill**, **per-session decision log** — none adopted. **`CURRENT-CONTEXT.md auto-population` was rejected 2026-08-05** after discovering the equivalent nightly job had silently failed for four months (macOS blocked the scheduled task from reading `~/Documents`); do not re-propose without new evidence.

### What Whitney Has That Michael Doesn't (confirmed still true, 2026-08-31)

- CodeRabbit review integration
- PRD workflow with milestone tracking
- Anki card creation from conversations
- vals secrets management
- Presentation slide rules (Quarto + Reveal.js)
- Kyverno/Datadog/k8s-specific tooling
- `/write-prompt` skill for AI agent authoring
- `/write-docs` skill for validated documentation

## Sources

- `~/Documents/Repositories/forrester-workflow/` (`llm-coding-workflow`, `d8eeb0f`) — settings.json, permission-profiles.json, hooks/, skills/, `rules/lifecycle-phases.md`, `rules/netcup-machine.md`, `docs/fleet-architecture.md`, `scripts/fleet.sh`, `scripts/worktree-launch.py`, `scripts/reap-idle-sessions.sh`, `src/workflow/` (Observatory), `tasks.yaml`, `scripts/tasks.sh`
- `research/repos/claude-dotfiles` (`631ae23`)
- `research/repos/Brain_spec_skills_claude` (`9089004`)
- `research/repos/mcp_best_practices` (`272fb9a`)
- `research/repos/observe-claude-code` (`1479291`)
- `research/repos/copilot-cli-enterprise-patterns` (`02cf5ff`)
- `research/repos/telemetry-agent` (`c73f830`)
- `research/repos/agentic-covenants` (`664c8dd`) — narrow re-clone, enforcement question only
