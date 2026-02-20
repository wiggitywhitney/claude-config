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
eval $(vals eval -f .vals.yaml --output shell)
```

**View resolved secret values:**
```bash
vals eval -f .vals.yaml
```

## Per-Repo Configuration

Each repo has its own `.vals.yaml` (gitignored) defining which secrets to pull. Check `.vals.yaml` in any repo for its available secrets.
