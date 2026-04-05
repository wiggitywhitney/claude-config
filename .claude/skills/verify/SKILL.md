---
name: verify
description: Pre-PR verification loop that runs build, type check, lint, tests, and security checks. Use before creating pull requests or when you want to validate code quality.
disable-model-invocation: true
argument-hint: "[mode: quick|full|pre-pr]"
allowed-tools: Bash(*)
---

# /verify — Pre-PR Verification Loop

You are running a structured verification process. Follow these phases exactly in order. Do not skip phases. Do not improvise additional phases.

## Script Paths

All scripts are in the `scripts/` subdirectory of this skill's base directory. When running scripts, always use the full path based on the base directory provided above. For example, if the base directory is `/Users/me/.claude/skills/verify`, then `detect-project.sh` is at `/Users/me/.claude/skills/verify/scripts/detect-project.sh`.

In the instructions below, `scripts/` is shorthand for the full path.

## Mode

The verification mode is: **$ARGUMENTS**

If no mode was specified, default to **full**.

| Mode | Phases to Run |
|---|---|
| `quick` | Phase 1 (Build) + Phase 2 (Type Check) only |
| `full` | Phase 1 through Phase 5 |
| `pre-pr` | Phase 1 through Phase 5, with expanded security checks |

## Step 1: Detect Project

Run the detection script to determine project type and available commands:

```bash
bash scripts/detect-project.sh .
```

Read the JSON output. It tells you:
- `project_type`: What kind of project this is
- `commands.build`, `commands.typecheck`, `commands.lint`, `commands.test`: Available commands (null if not available)
- `package_manager`: Which package manager to use

If `project_type` is `unknown`, stop and tell the user: "Could not detect project type. Ensure you're in a project directory with a package.json, tsconfig.json, pyproject.toml, go.mod, or Cargo.toml."

## Step 2: Run Verification Phases

Run each phase **in order**. For each phase:
1. Check if the command is available (not null in detection output)
2. If available, run it using the phase runner script
3. If the phase **fails**: stop immediately, report the error, suggest a fix
4. If the phase **passes**: move to the next phase
5. If a command is not available for a phase, skip it and note that it was skipped

### Phase 1: Build

```bash
bash scripts/verify-phase.sh build "<build-command>" .
```

### Phase 2: Type Check

```bash
bash scripts/verify-phase.sh typecheck "<typecheck-command>" .
```

### Phase 3: Lint

Skip if mode is `quick`.

```bash
bash scripts/verify-phase.sh lint "<lint-command>" .
```

### Phase 4: Security

Skip if mode is `quick`.

```bash
bash scripts/security-check.sh standard .
```

If mode is `pre-pr`, use expanded checks instead:

```bash
bash scripts/security-check.sh pre-pr .
```

### Phase 5: Tests

Skip if mode is `quick`.

```bash
bash scripts/verify-phase.sh test "<test-command>" .
```

## Step 3: Handle Failures

**Critical rule: Stop on first failure.**

**For phases 1, 2, 3, and 5** (run via `verify-phase.sh`): the script emits a `VERIFY_ERROR_CONTEXT:` line with structured JSON:

```text
VERIFY_ERROR_CONTEXT: {"phase":"test","command":"npm test","exit_code":1,"timestamp":"...","output_tail":"<last 20 lines of output>"}
```

Parse this JSON and produce a structured error summary:

```text
## Phase [N] Failed: [phase]

**Command:** [command]
**Exit code:** [exit_code]
**Error:** [1-2 sentences identifying the specific error from output_tail]
**Suggested fix:** [concrete action — not "check the logs"]
```

If `/tmp/verify-last-error-[phase].json` exists when a phase fails, a prior attempt already failed this phase. Reference the prior context if the same error is recurring.

**For Phase 4** (run via `security-check.sh`): no `VERIFY_ERROR_CONTEXT` is emitted. Read the script's output directly to identify what triggered the security check failure and suggest a specific remediation.

After the fix is applied, **restart from Phase 1** — do not resume from where you left off. This ensures earlier fixes don't break later phases.

## Step 4: Report Results

After all phases complete (or if stopped due to failure), present a summary:

```text
## Verification Results

Mode: [quick|full|pre-pr]
Project: [project_type] ([project_dir])

Phase 1 - Build:      [PASSED | FAILED | SKIPPED (no command)]
Phase 2 - Type Check:  [PASSED | FAILED | SKIPPED (no command)]
Phase 3 - Lint:        [PASSED | FAILED | SKIPPED (no command) | SKIPPED (quick mode)]
Phase 4 - Security:    [PASSED | FAILED | SKIPPED (quick mode)]
Phase 5 - Tests:       [PASSED | FAILED | SKIPPED (no command) | SKIPPED (quick mode)]

Overall: [ALL PASSED | FAILED at Phase N]
```

## Rules

- **Never skip a phase** unless the mode excludes it or no command is available
- **Never continue past a failure** — always stop and fix first
- **Always restart from Phase 1** after any fix
- **Run scripts exactly as shown** — do not substitute your own commands
- **Report skipped phases** — make it clear when a phase had no available command
