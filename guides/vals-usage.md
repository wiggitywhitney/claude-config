# Secrets Management with vals

[vals](https://github.com/helmfile/vals) injects secrets from GCP Secrets Manager at runtime. Most repos use vals for API keys and service account credentials.

## Common Commands

**Run a command with secrets injected:**
```bash
vals exec -f .vals.yaml -- <command>
```

**Run with inherited environment variables (needed for PATH, kubectl, etc.):**
```bash
vals exec -i -f .vals.yaml -- <command>
```

**Export secrets to current shell (for MCP servers, interactive use):**
```bash
eval "$(vals env -export -f .vals.yaml)"
```

**Do not "align" this back to `vals eval --output shell`.** `vals eval` has no `--output` flag — its only output flag is `-o`, taking `yaml` or `json` — so that form fails immediately with `flag provided but not defined: -output`, the export never runs, and every variable is silently absent. Rendering environment variables is a separate subcommand, `vals env`. Verified against vals 0.43.6 on 2026-08-25: the broken form reproduces that error, and `vals env -export -f .vals.yaml` exits 0 emitting one `export NAME=value` line per secret.

Whether `--output shell` existed in some older vals release is **unchecked** — do not repeat this note as proof that it never did. What is established: the installed version rejects it, and it lived in this repo from the 2026-02-11 bootstrap until 2026-08-25 without being run. It reached this file on 2026-03-15, in a commit that *replaced a working `vals env` command* to match two copies elsewhere in the repo that were already wrong — reasoning from internal consistency rather than from vals. Consistency with an unverified copy is how the last correct copy was lost.

**View resolved secret values:**
```bash
vals eval -f .vals.yaml
```

## Per-Repo Configuration

Each repo has its own `.vals.yaml` (gitignored) defining which secrets to pull. Check `.vals.yaml` in any repo for its available secrets.
