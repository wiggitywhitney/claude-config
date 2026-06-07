# yt-dlp Gotchas

## Format selector: `best[ext=mp4]` picks the combined stream — use it first

`best` / `b` in yt-dlp means a single-file format containing both video and audio. `best[ext=mp4]` selects the best available combined MP4 without requiring ffmpeg to merge separate streams. Put it first in the fallback chain for environments where ffmpeg may not be installed.

Recommended chain for YouTube Shorts:
```text
best[ext=mp4]/bv*[ext=mp4][vcodec^=avc1]+ba[ext=m4a]/best
```

For YouTube Shorts, format 18 (360p combined MP4) is typically the only single-file option. 360p is acceptable for cross-posting.

## ffmpeg-absent merge exits 0, not error — check for the output file

When `--merge-output-format mp4` is requested but ffmpeg is absent, yt-dlp prints a **WARNING** and exits **0** while writing separate stream files (`video.f137.mp4`, `video.f140.m4a`). The merged output file is never created. You cannot rely on exit code alone to detect this — either check that the expected output path exists, or avoid the merge entirely with a pre-merged format selector.

## `mweb` player client is less stable in 2025/2026

`--extractor-args "youtube:player-client=default,mweb"` still works but is flagged as less stable. It was introduced as a workaround for YouTube's SABR streaming issue. Prefer installing a JS runtime (Node v20+, Deno, bun) and using `--js-runtimes node` instead of relying on mweb.

## Node v20+ required for `--js-runtimes node`

yt-dlp dropped support for older Node.js runtimes in November 2025. Use Node v20+ or Deno. `AnimMouse/setup-yt-dlp@v3` in GitHub Actions handles this automatically.

## GitHub Actions: use `AnimMouse/setup-yt-dlp@v3`

This action installs yt-dlp, ffmpeg, and the required JS runtime in one step. Add it before any step that runs yt-dlp:

```yaml
- name: Set up yt-dlp
  uses: AnimMouse/setup-yt-dlp@v3
```

## "Sign in to confirm you're not a bot" in CI — `yt-dlp -U` does NOT fix this

GitHub Actions runners use shared datacenter IPs that YouTube flags as bots. Keeping yt-dlp current addresses version issues but not IP reputation. The full error message is:
```text
ERROR: [youtube] VIDEO_ID: Sign in to confirm you're not a bot. Use --cookies-from-browser or --cookies for authentication.
```

**Recommended headless fix: `bgutil-ytdlp-pot-provider`** — maintained by a yt-dlp maintainer, generates per-video PO tokens without a browser. Requires yt-dlp ≥ 2025.05.22 and Node ≥20. Check [releases](https://github.com/Brainicism/bgutil-ytdlp-pot-provider/releases) for the latest tag before pinning a version.

```yaml
- name: Install bgutil PO token provider
  run: |
    pip install bgutil-ytdlp-pot-provider
    git clone --single-branch --branch 1.3.1 https://github.com/Brainicism/bgutil-ytdlp-pot-provider.git /tmp/bgutil
    cd /tmp/bgutil/server && npm ci && npx tsc
```

This uses the **Script method** — a Node.js process is spawned per yt-dlp call, with no persistent service required. yt-dlp picks up the installed plugin automatically; no extra CLI flags are needed.

**Do NOT let a yt-dlp failure skip the dispatch entirely.** Even with bgutil, "Providing a PO token does not guarantee bypassing 403 errors." Always catch the error and fall back to posting text + YouTube link instead.

## Chrome cookies unreadable since Chrome 127 (July 2024)

Chrome 127+ introduced app-bound encryption. No external process can decrypt the cookie store regardless of privilege level. Cookie extraction tutorials before mid-2024 no longer work for Chrome.

Firefox stores cookies in plain SQLite (no encryption) and is the only viable browser cookie source. But cookies expire every ~2 weeks — not suitable for automated CI without manual rotation.

**Never use browser extensions to export cookies.** The popular "Get cookies.txt" Chrome extension was malware — it silently sent all cookies (banking, login sessions, everything) to its developer. Google removed it from the Chrome Web Store.

## PO tokens are per-video and expire in ~6 hours

YouTube binds PO tokens to the video ID. Static tokens stored in secrets won't work. Per-video token generation (via bgutil or similar) is required for each download.
