# Vals Secrets Management

Whitney uses [vals](https://github.com/helmfile/vals) to inject secrets from Google Secret Manager (and other backends). Secrets are never exported to `.zshrc` or committed to repos. Per-repo config lives in `.vals.yaml`.

```bash
# Run a command with secrets injected
vals exec -f .vals.yaml -- command arg1 arg2

# Export all secrets into the current shell session
eval "$(vals env -f .vals.yaml)"
```

**Claude Code usage:** When a command needs a secret from `.vals.yaml`, wrap the entire command with `vals exec` so the secret is injected as an environment variable. Never extract, store, or inline the secret value.

```bash
# CORRECT — wrap with bash -c so the secret expands inside the vals exec environment
vals exec -f .vals.yaml -- bash -c 'curl -s "https://api.example.com" \
  -H "Authorization: Bearer ${AIRTABLE_PAT}"'

# WRONG — secret is extracted and inlined as plaintext
export AIRTABLE_PAT=$(vals eval ...)
curl -s "https://api.example.com" -H "Authorization: Bearer $AIRTABLE_PAT"
```
