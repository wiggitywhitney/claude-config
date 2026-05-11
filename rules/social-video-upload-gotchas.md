# Social Platform Video Upload Gotchas

Covers Bluesky, Mastodon, and LinkedIn video upload APIs.
Relevant when implementing video embedding for short posts in content-manager.

## Bluesky

### Video goes to a separate service, not the PDS

The video upload endpoint is `https://video.bsky.app/xrpc/app.bsky.video.uploadVideo` — NOT the user's PDS. The regular session JWT is rejected. Must acquire a short-lived (30 min) scoped token first:

```javascript
const { data: serviceAuth } = await agent.com.atproto.server.getServiceAuth({
  aud: 'did:web:video.bsky.app',   // hardcode — this is the video service's DID
  lxm: 'com.atproto.repo.uploadBlob',
  exp: Math.floor(Date.now() / 1000) + 60 * 30,
});
```

**Do NOT use `agent.dispatchUrl.host`** — `dispatchUrl` is `undefined` in `@atproto/api` ≥ 0.13.x. Hardcode `'did:web:video.bsky.app'` instead.

### `@atproto/api` has no `app.bsky.video` namespace — use `fetch()` directly

Neither `BskyAgent` nor `AtpAgent` expose `app.bsky.video.uploadVideo` or `app.bsky.video.getJobStatus` as typed methods. Use `fetch()` directly for both the upload POST and the job status poll GET:

```javascript
// Upload
const uploadRes = await fetch(
  `https://video.bsky.app/xrpc/app.bsky.video.uploadVideo?did=${encodeURIComponent(agent.session.did)}&name=video.mp4`,
  { method: 'POST', headers: { Authorization: `Bearer ${serviceAuth.token}`, 'Content-Type': 'video/mp4', 'Content-Length': String(buf.length) }, body: buf }
);
const { jobId } = await uploadRes.json();

// Poll
let blob;
while (!blob) {
  const { jobStatus } = await (await fetch(`https://video.bsky.app/xrpc/app.bsky.video.getJobStatus?jobId=${encodeURIComponent(jobId)}`)).json();
  if (jobStatus.blob) blob = jobStatus.blob;
  else await new Promise(r => setTimeout(r, 1000));
}
```

### `aspectRatio` is required in the video embed

Omitting it causes a silent failure. Vertical shorts use `{ width: 9, height: 16 }`.

```javascript
embed: {
  $type: 'app.bsky.embed.video',
  video: blob,           // BlobRef from job status
  aspectRatio: { width: 9, height: 16 },
}
```

### Upload is async — poll `app.bsky.video.getJobStatus` until blob appears

Upload returns a `jobId`. Must poll until `jobStatus.blob` is populated before creating the post.

### Email verification required

Bluesky-hosted accounts without verified email cannot upload video. Returns an error.

---

## Mastodon (masto.js v7)

### Use `masto.v2.media.create`, NOT `v1.mediaAttachments.create`

The v1 upload endpoint is deprecated. Always use `masto.v2.media.create`.

### Video upload returns 202 — `.url` is `null`

Video processing is async. Must poll `masto.v1.mediaAttachments.$select(id).fetch()` until the `.url` field is populated. Returns 206 (Partial Content) while processing, 200 when done.

```javascript
let ready = attachment;
while (!ready.url) {
  await new Promise(r => setTimeout(r, 2000));
  ready = await masto.v1.mediaAttachments.$select(attachment.id).fetch();
}
```

### Blob only — Stream API is rejected

Since masto.js adopted the web Fetch API, `fs.createReadStream()` does NOT work. Must use:
```javascript
new Blob([fs.readFileSync(path)], { type: 'video/mp4' })
```

### Node 20+ required for masto.js v7

v7.0.0 dropped Node 18 support entirely.

---

## LinkedIn

### Four-step flow — cannot post video URN immediately

1. `POST /rest/videos?action=initializeUpload` → get upload URLs + video URN + uploadToken
2. `PUT` each upload URL with file chunk → save ETag from response header
3. `POST /rest/videos?action=finalizeUpload` with ETags as `uploadedPartIds`
4. Poll `GET /rest/videos/{urn}` until `status === "AVAILABLE"`, then create post

Attempting to create a post with the video URN before it's AVAILABLE returns 400 `MEDIA_ASSET_WAITING_UPLOAD`.

### Strip quotes from ETags

PUT response returns `etag: "abc123"` with surrounding quotes. `uploadedPartIds` expects the value without quotes:
```javascript
const etag = partRes.headers.get('etag').replace(/"/g, '');
```

### Parts are 4MB (4194304 bytes), lastByte is inclusive

```javascript
const chunk = videoBuffer.subarray(firstByte, lastByte + 1); // +1 because lastByte is inclusive
```

For YouTube Shorts (<50MB), there will typically be 1–13 parts.

### `uploadToken` is often empty string — pass it through

For small files the response has `"uploadToken": ""`. Still required in the finalize body.

### Videos API replaced Assets API — old docs are stale

Training data and old tutorials use `registerUpload` / `completeMultiPartUpload` from the Assets API. The current API uses `initializeUpload` / `finalizeUpload` from the Videos API (`/rest/videos`).

### Post body: video goes in `content.media.id`

```json
{
  "content": {
    "media": {
      "title": "Short video title",
      "id": "urn:li:video:C5F10AQG..."
    }
  }
}
```

No additional scopes needed beyond `w_member_social`.
