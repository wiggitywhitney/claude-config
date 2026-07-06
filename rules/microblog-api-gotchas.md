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

## getPages blogID must be the username string, not integer 1

Standard Blogger XML-RPC uses an integer blog ID. Micro.blog uses the **username string** as the blogId:

```javascript
xmlrpcRequest('microblog.getPages', [username, username, token, 100, 0])
//                                   ^^^^^^^^ blogId = username, not 1
```

Passing `1` returns: `"Blog not found with ID 1"`. Passing the username works.

## getPages response uses `id` not `pageID`, and `<i4>` not `<int>`

The standard Blogger API uses `pageID` for the page identifier. Micro.blog uses `id`. If you parse the XML-RPC response and look for `pageID`, you'll silently get null and every page will be skipped.

Also, integer values in the response use the `<i4>` type tag (a valid XML-RPC alias for `<int>`). Parsers that only handle `<int>` will miss these.

```xml
<member><name>id</name><value><i4>849042</i4></value></member>
<!-- NOT: <name>pageID</name> or <int> -->
```

## About page is NOT is_template: true

The `About` page has `is_template: false` in the `getPages` response — it renders the `description` field directly, not via a Hugo template. This means Markdown and HTML both work as-is in the description field. The documentation saying template pages have `is_template: true` applies to Archive, Photos, and Replies — not About.

## Micropub page creation requires array format for mp-channel

When creating pages via Micropub JSON, `mp-channel` must be `["pages"]` (array), not `"pages"` (string). The `mp-navigation` boolean goes at root level, not inside `properties`.

## Cross-posting is feed-based, not API-triggered

Micro.blog cross-posting reads from the blog's RSS/JSON feed — it is NOT triggered by Micropub API calls directly. This means:
- Cross-posting timing depends on feed polling, not post creation
- Per-category filtering is possible only via category-specific feeds (`/categories/name/feed.xml`), but micro.blog has confirmed this is unreliable: "you cannot set automatic crossposting based on the source feed or the category of a post"

## Per-post cross-posting suppression via `mp-syndicate-to[]` (Micropub only)

The Micropub API supports `mp-syndicate-to[]` to control which platforms receive cross-posts for a specific post:

- **Omit the parameter entirely** → micro.blog cross-posts to ALL configured platforms (default)
- **`mp-syndicate-to[]=` (blank value)** → suppress ALL cross-posting for this post
- **`mp-syndicate-to[]=mastodon`** → cross-post to Mastodon only

This is critical when posting to micro.blog AND other platforms directly in the same workflow — without suppression, those platforms receive both the direct post AND a micro.blog syndication duplicate.

```javascript
// Suppress cross-posting (blank value appended to URLSearchParams):
params.append('mp-syndicate-to[]', '');
```

Query available targets: `GET /micropub?q=syndicate-to` returns `uid` and `name` for each configured service.

**Do NOT confuse with feed-based cross-posting** — `mp-syndicate-to[]` only works on Micropub API posts, not on posts published other ways.

## Rescheduling posts creates phantom duplicates

Changing a scheduled post's publication date can cause it to appear at ALL previously scheduled dates. The backend marks old instances as deleted, but the static site generator still renders them. Fix: force a full site rebuild at `https://micro.blog/account/logs` → Rebuild.

## Template pages (About, Archive, Photos) have is_template flag

`microblog.getPages` returns `is_template: true` for built-in pages. These pages use Hugo templates for rendering. Editing their `description` field via `microblog.editPage` updates the raw content, but the final rendered output depends on the theme's template. Test edits on a non-critical page first.

## Micropub `?q=source` response does not return a `photo` property

When querying a post's source via `GET /micropub?q=source&url=<postUrl>`, micro.blog does NOT include a separate `photo` key in `properties` — even for posts that have photos attached. Photos are embedded as `<img src="...">` tags inside `properties.content[0]`.

To check whether a post already has a photo:

```javascript
const data = await res.json();
const content = data.properties?.content?.[0] ?? '';
return content.includes('<img');
```

Do NOT check `data.properties?.photo` — it will always be `undefined`, even on posts with photos.

## Micropub `delete: ["photo"]` returns 500 — use content-replace instead

Sending `{ action: "update", url, delete: ["photo"] }` to remove a photo from an existing post returns a 500 error from micro.blog. Because photos are stored as `<img>` tags in `properties.content[0]` (not as a separate property), there is nothing to delete at the property level.

To remove a photo from an existing post, fetch the content and replace it with the `<img>` tags stripped:

```javascript
// GET current content
const sourceRes = await fetch(`https://micro.blog/micropub?q=source&url=${encodeURIComponent(postUrl)}`, {
  headers: { Authorization: `Bearer ${token}` },
});
const data = await sourceRes.json();
const content = data.properties?.content?.[0] ?? '';
const stripped = content.replace(/<img[^>]*>/g, '').trimEnd();

// Replace content with photos removed
await fetch('https://micro.blog/micropub', {
  method: 'POST',
  headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
  body: JSON.stringify({ action: 'update', url: postUrl, replace: { content: [stripped] } }),
});
```
