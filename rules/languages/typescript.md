---
paths: ["**/*.ts", "**/*.tsx", "**/tsconfig.json"]
---

# TypeScript Rules

## Type System

- Prefer `interface` over `type` for object shapes that may be extended.
- Use `unknown` over `any`. If `any` is truly needed, add an inline comment explaining why.
- Use explicit return types on exported functions. Inferred types are fine for internal helpers.
- Prefer `const` assertions and `as const` for literal types over manual type annotations.
- Avoid enums — use `as const` objects or union types instead.
- Use `satisfies` to validate object literals without widening their type.
- Prefer `readonly` for properties that should not be reassigned.
- Use discriminated unions over optional fields for variant types.

## Imports

- Use `import type` for type-only imports to keep runtime bundles clean.
- Prefer named exports over default exports for grep-ability.
- Order imports: Node builtins, third-party packages, local modules. Alphabetize within each group.

## Error Handling

- Type error classes with a `code` discriminant for programmatic matching.
- Use `unknown` in catch blocks, narrow before accessing properties.
- Never swallow errors silently — log, rethrow, or handle explicitly.

## Async

- Every async call must be awaited, returned, or explicitly voided. No floating promises.
- Use `Promise.allSettled` when partial failure is acceptable; `Promise.all` when any failure should abort.

## Naming

- PascalCase for types and interfaces.
- No `I` prefix on interfaces.
- UPPER_SNAKE_CASE for constants.
- kebab-case for filenames.

## Configuration

- Enable `strict: true` in tsconfig. Do not weaken strictness with per-file `@ts-ignore` unless the comment explains the specific issue.
- Enable `noUncheckedIndexedAccess` — catches real bugs from bracket access on arrays and records.
- Target ES2022+ unless browser support requires lower.
