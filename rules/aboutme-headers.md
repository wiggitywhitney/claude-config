# ABOUTME File Headers

Every code file must start with a 1-2 line ABOUTME header describing its purpose. Use the file's native comment syntax:

```python
# ABOUTME: Brief description of this file's purpose
# ABOUTME: What it does or provides
```

```typescript
// ABOUTME: Brief description of this file's purpose
// ABOUTME: What it does or provides
```

## Rules

- Supported file types: `.py`, `.sh`, `.ts`, `.tsx`, `.js`, `.jsx`
- Place after shebang lines (`#!/usr/bin/env ...`) when present
- Exempt: `__init__.py`, config files (JSON/YAML/TOML), markdown, HTML/CSS, generated files, `node_modules`, `.d.ts`, `.min.js`
- A PreToolUse hook enforces this on Write and Edit — missing headers block the operation until added
