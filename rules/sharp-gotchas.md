---
paths: ["**/*.js", "**/*.ts", "**/package.json"]
description: sharp image processing library gotchas for Node.js
---

# sharp Gotchas

Verified 2026-06-18 against sharp 0.35.1. Applies when using sharp for image resize and format conversion in Node.js.

## Node.js >= 20.9.0 required (Node-API v9)

sharp 0.35.x requires Node-API v9. Node 18 will fail at install or runtime. CI and production should run Node 20.9+. If a project's `engines` field is lower, update it.

## macOS: globally installed libvips via Homebrew triggers source build

Prebuilt binaries are distributed as separate `@img/sharp-*` scoped optional dependencies, not fetched via a postinstall script. `brew install vips` installs libvips globally, and sharp's dependency resolution can detect it and build from source instead of using the prebuilt `@img/sharp-*` package — the source build often fails because `node-addon-api` isn't available. Fix:

```bash
SHARP_IGNORE_GLOBAL_LIBVIPS=1 npm install sharp
```

## `fit: 'inside'` must be specified explicitly — default is `'cover'`

The default `fit` is `'cover'`, which crops to fill both dimensions. For proportional resize without cropping, always specify `fit: 'inside'`:

```javascript
sharp(buffer)
  .resize(1920, 1920, { fit: 'inside', withoutEnlargement: true })
  .jpeg({ quality: 90 })
  .toBuffer();
```

`withoutEnlargement: true` prevents upscaling small images. Both defaults are wrong for general thumbnail resizing.

## Buffer input works directly — no temp file needed

```javascript
const outputBuffer = await sharp(inputBuffer).jpeg({ quality: 90 }).toBuffer();
```

No need to write to disk first. `sharp(buffer)` accepts a Node.js `Buffer` directly.

## CJS: `require('sharp')` works — official docs show ESM

The published package exports both CJS and ESM via conditional exports. `require('sharp')` in `"type": "commonjs"` projects works without any ESM shim.

## Cross-platform package-lock.json and CI (npm bug #4828)

sharp installs platform-specific prebuilt binaries as optional dependencies. If the lock file was generated on macOS and CI runs on Linux, `npm ci` may not resolve the Linux binary. In practice, `ubuntu-latest` + Node 22 handles this correctly with default npm settings (optional deps enabled). If CI fails with "cannot find sharp module", add `--include=optional` to the `npm ci` command.
