---
paths: ["**/*.js", "**/*.jsx", "**/*.mjs", "**/*.cjs", "**/package.json"]
---

# JavaScript Rules

- Use ES module syntax (`import`/`export`) unless the project explicitly uses CommonJS.
- Prefer `const` over `let`. Never use `var`.
- Use optional chaining (`?.`) and nullish coalescing (`??`) over manual null checks.
- Destructure function parameters when accessing multiple properties.
- Use template literals over string concatenation.
- Prefer `async`/`await` over raw Promise chains for readability.
