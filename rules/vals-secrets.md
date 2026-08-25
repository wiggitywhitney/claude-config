# Vals Secrets Management

Whitney uses [vals](https://github.com/helmfile/vals) to inject secrets from Google Secret Manager (and other backends). Secrets are never exported to `.zshrc` or committed to repos. Per-repo config lives in `.vals.yaml`.

```bash
# Run a command with secrets injected
vals exec -f .vals.yaml -- command arg1 arg2

# Export all secrets into the current shell session (for MCP servers, etc.)
eval "$(vals env -export -f .vals.yaml)"
```

**Do not "align" this back to `vals eval --output shell`.** `vals eval` has no `--output` flag — its only output flag is `-o`, taking `yaml` or `json` — so that form fails immediately with `flag provided but not defined: -output`, the export never runs, and every variable is silently absent. Rendering environment variables is a separate subcommand, `vals env`. Verified against vals 0.43.6 on 2026-08-25: the broken form reproduces that error, and `vals env -export -f .vals.yaml` exits 0 emitting one `export NAME=value` line per secret.

Whether `--output shell` existed in some older vals release is **unchecked** — do not repeat this note as proof that it never did. What is established: the installed version rejects it, and it lived in this repo from the 2026-02-11 bootstrap until 2026-08-25 without being run. It reached this file on 2026-03-15, in a commit that *replaced a working `vals env` command* to match two copies elsewhere in the repo that were already wrong — reasoning from internal consistency rather than from vals. Consistency with an unverified copy is how the last correct copy was lost.

**Claude Code usage:** When a command needs a secret from `.vals.yaml`, wrap the entire command with `vals exec` so the secret is injected as an environment variable. Never extract, store, or inline the secret value.

```bash
# CORRECT — wrap with bash -c so the secret expands inside the vals exec environment
vals exec -f .vals.yaml -- bash -c 'curl -s "https://api.example.com" \
  -H "Authorization: Bearer ${AIRTABLE_PAT}"'

# WRONG — secret is extracted and inlined as plaintext
export AIRTABLE_PAT=$(vals eval ...)
curl -s "https://api.example.com" -H "Authorization: Bearer $AIRTABLE_PAT"
```
