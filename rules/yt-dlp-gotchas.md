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
