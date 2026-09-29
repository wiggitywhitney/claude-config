---
paths: ["**/*toml*", "**/pyproject*", "src/languages/python/rules/api*.ts"]
---

# TOML Parser Gotchas (npm)

Verified 2026-09-28 by running candidates against real `pyproject.toml` files (Black, HTTPX, pytest, Strawberry, Litestar, FastAPI's full-stack template). Applies when a TypeScript/Node project parses TOML, for example reading Python manifests.

## Do not use `@iarna/toml`

It is the parser older articles recommend most, and it fails on valid real-world TOML. Black's `pyproject.toml` throws "Inline lists must be a single type, not a mix of inline-table and string" because the parser targets TOML 0.5, where mixed-type arrays are illegal. Mixed-type arrays are valid TOML 1.0. It also last changed in 2023.

## Node has no built-in TOML parser

`util.parseToml` and `globalThis.TOML` are undefined on Node v25.8.0. A dependency is required.

## Use `smol-toml`, and pass `unsafeKeyBehaviour: 'throw'` for untrusted files

`smol-toml` is ESM with bundled types and zero runtime dependencies. Since 1.9.0 the `unsafeKeyBehaviour` option controls a document containing a key named `__proto__`: `keep` (the default) returns it as an own property, `drop` silently removes it, `throw` raises. A parsed document never pollutes `Object.prototype` in any parser tested, but never use `Object.assign` or another setter-based merge on a parsed object, because an own `__proto__` key can change the target's prototype. Object spread preserves it as an own data property. Read fields directly.

## Integers beyond 53 bits throw by default

`smol-toml` throws "integer value cannot be represented losslessly" on a valid document that contains one. The option is `integersAsBigInt` in `smol-toml` and `bigint` in `toml`. Wrap every parse in `try`/`catch` and treat any throw as "could not parse."

## Dotted keys and table headers parse to the same shape

`[project]` with `scripts.pytest = "..."` gives the same nested object as a `[project.scripts]` table. pytest's own manifest uses the dotted form. Never detect a table by scanning for its `[header]` text.

## Other candidates, so the search does not repeat

- `@ltd/j-toml` is LGPL-3.0 and needs a license review before use in an Apache-2.0 project. It last changed in 2023.
- `toml` 5.0.0 (2026-07-14) is current and claims TOML 1.1.0, so ignore advice about the old package, which supported only TOML 0.4. It is CommonJS. `import { parse } from 'toml'` works from ESM. It returns offset date-times as `Date` objects, and local date-times, local dates, and local times as strings.
- `smol-toml` returns dates as `TomlDate`, a `Date` subclass.
