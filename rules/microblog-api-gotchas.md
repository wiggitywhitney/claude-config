---
paths: ["src/**/*.js", "**/*microblog*", "**/*micro.blog*"]
---

# Micro.blog API Gotchas

## Two separate auth tokens — Micropub and XML-RPC use different ones

Micro.blog has two independent app tokens:
- **Micropub token** (labeled "content-manager" or similar in Edit Apps): Bearer auth for `POST /micropub`
- **MarsEdit token**: HTTP Basic auth for XML-RPC at `https://micro.blog/xmlrpc`

Using the Micropub token for XML-RPC returns `403 User not authorized` with no helpful error message. Always check which token a method requires.

## XML-RPC editPage parameter order is non-obvious

`microblog.editPage` takes: `[pageID, username, password, contentStruct]` — NOT `[blogID, ...]`.
`microblog.getPages` takes: `[blogID, username, password, count, offset]`.

Getting the order wrong produces `"Page title can't be blank"` (500) — not a parameter order error.

## Micropub page creation requires array format for mp-channel

When creating pages via Micropub JSON, `mp-channel` must be `["pages"]` (array), not `"pages"` (string). The `mp-navigation` boolean goes at root level, not inside `properties`.

## Cross-posting is feed-based, not API-triggered

Micro.blog cross-posting reads from the blog's RSS/JSON feed — it is NOT triggered by Micropub API calls directly. This means:
- Cross-posting timing depends on feed polling, not post creation
- There is no API parameter to control which platforms receive a specific post
- Per-category filtering is possible only via category-specific feeds (`/categories/name/feed.xml`)
- No per-post cross-posting toggle exists in any API

## Rescheduling posts creates phantom duplicates

Changing a scheduled post's publication date can cause it to appear at ALL previously scheduled dates. The backend marks old instances as deleted, but the static site generator still renders them. Fix: force a full site rebuild at `https://micro.blog/account/logs` → Rebuild.

## Template pages (About, Archive, Photos) have is_template flag

`microblog.getPages` returns `is_template: true` for built-in pages. These pages use Hugo templates for rendering. Editing their `description` field via `microblog.editPage` updates the raw content, but the final rendered output depends on the theme's template. Test edits on a non-critical page first.

## Cross-posting has no per-post API control

9 platforms supported (see `docs/research/microblog-api.md` for current list). LinkedIn image cross-posting is reportedly planned but not yet implemented. There is no API to selectively cross-post a single post — it's all or nothing per feed.
