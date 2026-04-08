# Weaver Gotchas

## v0.22.1 breaking changes (released 2026-03-13)

### Template auto-escaping is now off by default

Previously, Weaver inferred whether to auto-escape based on the template file extension (e.g., `.html` got HTML escaping). As of v0.22.1, auto-escaping is **off by default regardless of extension**. When writing templates that produce HTML or JSON output, explicitly set the escaping mode per-template in `weaver.yaml`:

```yaml
# weaver.yaml — auto_escape is set per-template entry (v0.22.1+)
templates:
  - pattern: "*.html"
    auto_escape: html
  - pattern: "*.json"
    auto_escape: json
  - pattern: "*.txt"
    auto_escape: none
```

If templates are written assuming the old extension-based behavior, output will be unescaped silently — no error, just wrong output.

### Definition schema v2 files must use `file_format`

Any definition schema file that previously declared `version: "2"` must be updated to use:

```yaml
file_format: definition/2
```

The old `version: "2"` key is no longer recognized. Weaver will not error loudly — it will silently ignore or misparse the file.

## spinybacked-orbweaver context

This project uses `weaver registry resolve/diff/live-check` only. No templates or definition schema files exist yet. When codegen is added (planned for a future PRD), write all templates and configuration targeting v0.22.1 behavior from the start — do not assume old defaults.
