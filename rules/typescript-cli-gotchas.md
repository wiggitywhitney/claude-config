# TypeScript tsc CLI Gotchas

Verified against TypeScript 5.9.x and 6.0 (March 2026). Relevant whenever invoking `tsc` programmatically or from a tool that passes individual files on the command line.

## TS5112 is a new hard error in tsc 6.0

Running `tsc file.ts` when a `tsconfig.json` is discoverable now fails:

```text
error TS5112: tsconfig.json is present but will not be loaded if files are specified
on commandline. Use '--ignoreConfig' to skip this error.
```

- Fires for any tsconfig in the CWD or any ancestor directory (tsc walks up).
- It is a hard error (non-zero exit), not a warning.
- Not present in any 5.x release — it is a 6.0 breaking change.
- Motivation: AI agents ran `tsc foo.ts` expecting defaults, silently ignoring tsconfig, then tried to fix false errors.

## `--ignoreConfig` is the fix — but only exists in tsc 6.0+

```bash
tsc --noEmit --ignoreConfig --strict [other flags] file.ts
```

- On tsc 5.x, `--ignoreConfig` is an unknown flag and will itself error.
- Must version-gate: call `tsc --version`, parse the major version, add the flag only for major >= 6.
- Both `--ignoreConfig` and `--ignore-config` are accepted.

## tsc writes errors to stdout, not stderr — always has, still does

This is "Working as Intended" (GitHub issues #615, #9526, #12844, all closed By Design).

- Type errors, TS5112, and most diagnostics go to **stdout**.
- stderr is used only for infrastructure/config errors (e.g., missing tsconfig when required).
- Any tool that only reads stderr from a tsc child process will silently miss errors.
- Always capture both streams and join them. This behavior has not changed in 5.x → 6.x.

## New tsc 6.0 defaults when no tsconfig is loaded

When running `tsc --ignoreConfig file.ts`, the 6.0 defaults differ significantly from 5.x:

| Option | tsc 5.x default | tsc 6.0 default |
|---|---|---|
| `strict` | `false` | `true` |
| `module` | `commonjs` | `esnext` |
| `target` | `es5` | `es2025` |
| `types` | all @types/* | `[]` (none) |

Always pass explicit flags (`--strict`, `--module`, `--target`, etc.) — do not rely on defaults.

## Deprecated 5.x flags are now hard errors in tsc 6.0

Passing any of these to tsc 6.0 fails:
- `--target es5`
- `--moduleResolution node` or `node10`
- `--baseUrl`
- `--outFile`
- `--module amd` / `umd` / `systemjs` / `none`

## `--noCheck` flag (tsc 5.6+, public CLI)

Disables full type checking; only critical parse/emit errors are reported. Internal-only in 5.5, became a public CLI flag in 5.6 (September 2024). Use for emit-only pipelines where type checking runs separately. Does not suppress TS5112.

## Recommended version-gated invocation pattern

```typescript
const version = getTscMajorVersion(tsc); // parse from `tsc --version` output

const args = [
  '--noEmit',
  '--strict',
  '--skipLibCheck',
  ...(version >= 6 ? ['--ignoreConfig'] : []),
  '--module', moduleFlag,
  '--moduleResolution', moduleResolutionFlag,
  '--target', 'ES2022',
  filePath,
];

// Capture both stdout AND stderr — errors go to stdout by design
execFileSync(tsc, args, { stdio: ['pipe', 'pipe', 'pipe'] });
// On error: join error.stdout and error.stderr before reporting
```
