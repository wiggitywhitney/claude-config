# LinkedIn REST API Gotchas

Surprises when using the LinkedIn REST API from Node.js. Cross-project reference — see also the project-level `content-manager/.claude/rules/linkedin-api-gotchas.md` for the full set.

## `commentary` field silently truncates on unescaped reserved characters — no error returned

The `commentary` field uses LinkedIn's `little` text format. **13 characters are reserved** and must be backslash-escaped in the field value:

```text
( )  [ ]  { }  @  #  *  _  ~  <  >  \
```

When any of these characters appear **unescaped**, LinkedIn's parser silently drops all text from that character onwards. The API still returns 201 success, but the rendered post shows only the truncated portion — no "see more" link, no error. A GET of the post returns the full original text, making this especially hard to detect programmatically. Affects ALL post types (text-only, image, video).

Social post text commonly contains parentheses (e.g., `(link in bio)`, `(from the podcast)`). The first unescaped `(` after the first sentence causes that sentence to be the entire post.

**Fix:**

```javascript
function escapeLinkedInCommentary(text) {
  return text.replace(/[()[\]{}\@#*_~<>\\]/g, '\\$&');
}
// Usage: commentary: escapeLinkedInCommentary(post.postText)
```

Do NOT apply this to text that intentionally uses `little` format syntax (`@[Name](URN)` mentions). Plain prose should always be escaped.

**Source:** ["When a left or right parenthesis appears anywhere in the commentary, all text from that parenthesis onwards gets silently dropped from the post (no error returned)."](https://learn.microsoft.com/en-us/answers/questions/5741122/issues-when-mentioning-urns-with-special-character) — Microsoft Learn Q&A, confirmed by LinkedIn Support.

## Image alt text goes in `content.media.altText` on the post — NOT during upload

Alt text for images is set in the `POST /rest/posts` body, not during the `initializeUpload` or binary upload steps. Add it as `content.media.altText`. Omit the field entirely (or set `undefined`) when no alt text is available — do not send an empty string.

```json
"content": { "media": { "altText": "Description here", "id": "urn:li:image:..." } }
```

- Maximum 4,086 characters; recommended under 120.
- **GET responses do not return `altText`** — it is write-only in the API. LinkedIn renders it server-side and does not echo it back.
- LinkedIn auto-generates alt text via AI when the field is omitted — so posts without alt text are not inaccessible, but the AI-generated text is generic.

**Source:** [LinkedIn Posts API](https://learn.microsoft.com/en-us/linkedin/marketing/community-management/shares/posts-api?view=li-lms-2026-05), [LinkedIn Image API](https://learn.microsoft.com/en-us/linkedin/marketing/community-management/shares/images-api?view=li-lms-2026-05)

## `content.media` does NOT cause text truncation

The single-image `content.media` format does not impose a lower character limit on `commentary` than text-only posts. The same `little` text field applies to all post types. Apparent truncation on image posts is the reserved-character escaping issue above.

## Refresh tokens require partner approval — NOT available by default

Standard self-serve OAuth returns an access token valid 60 days. Refresh tokens require the Community Management API partner program. Without approval, re-authorization must happen manually every 60 days.

## Two LinkedIn Developer Portal products are required, not one

- **"Share on LinkedIn"** — grants `w_member_social` (posting)
- **"Sign In with LinkedIn using OpenID Connect"** — grants `openid`/`profile` scope needed for `GET /v2/userinfo`

## Use `GET /v2/userinfo` for person ID, NOT `GET /v2/me`

`/v2/me` returns 403 for Standard Tier. Use `/v2/userinfo` and the `sub` field as the member ID.

## `POST /rest/posts` returns 201 with no body — URN is in `x-restli-id` response header

## `Linkedin-Version` header is mandatory on every request (format: YYYYMM)
