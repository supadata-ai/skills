# Universal video & social media endpoints

These three endpoints work across every supported platform (YouTube, TikTok, Instagram, X/Twitter, Facebook) and, where relevant, direct file URLs:

- [`GET /transcript`](#get-transcript--universal-transcript) — fetch text/captions
- [`GET /metadata`](#get-metadata--unified-social-media-metadata) — title, author, stats, etc.
- [`POST /extract`](#post-extract--ai-structured-extraction) — AI-extracted JSON

For YouTube-specific features (per-channel listing, batch transcripts, translation, search), see [`youtube.md`](youtube.md).

Auth: every request needs `-H "x-api-key: $SUPADATA_API_KEY"`. Base URL: `https://api.supadata.ai/v1`.

---

## `GET /transcript` — universal transcript

Works for every supported platform and for direct file URLs.

| Query param | Type | Default | Notes |
|---|---|---|---|
| `url` | string (required) | — | Video URL from any supported platform, or a public file URL |
| `lang` | ISO 639-1 string | first available | Preferred transcript language (e.g. `en`, `es`, `pl`) |
| `text` | boolean | `false` | When `true`, returns plain text instead of timestamped chunks |
| `chunkSize` | 50–10000 | — | Max characters per chunk (only when `text=false`) |
| `mode` | `native` \| `auto` \| `generate` | `auto` | `native` only fetches existing captions; `generate` always uses AI; `auto` tries native then falls back. File URLs are always `generate`. |

### Response

- HTTP 200 — synchronous result:
  ```json
  {
    "content": [{ "lang": "en", "text": "Never gonna give...", "offset": 0, "duration": 1500 }],
    "lang": "en",
    "availableLangs": ["en", "es", "fr"]
  }
  ```
  Or, with `text=true`:
  ```json
  { "content": "Never gonna give you up...", "lang": "en", "availableLangs": [...] }
  ```
- HTTP 202 — async, returned for large videos:
  ```json
  { "jobId": "8c6a..." }
  ```
  Poll `GET /transcript/{jobId}` until `status` is `completed` or `failed`. Response shape matches the sync result, with an extra `status` field.

### Examples

Plain text English transcript from a TikTok:
```bash
curl -sG "https://api.supadata.ai/v1/transcript" \
  -H "x-api-key: $SUPADATA_API_KEY" \
  --data-urlencode "url=https://www.tiktok.com/@user/video/1234567890" \
  --data-urlencode "text=true" \
  --data-urlencode "lang=en"
```

Force AI generation (use when native captions are missing):
```bash
curl -sG "https://api.supadata.ai/v1/transcript" \
  -H "x-api-key: $SUPADATA_API_KEY" \
  --data-urlencode "url=https://example.com/video.mp4" \
  --data-urlencode "mode=generate"
```

Async polling pattern:
```bash
JOB=$(curl -sG "https://api.supadata.ai/v1/transcript" \
  -H "x-api-key: $SUPADATA_API_KEY" \
  --data-urlencode "url=$URL" | jq -r '.jobId // empty')
[ -n "$JOB" ] && curl -s "https://api.supadata.ai/v1/transcript/$JOB" \
  -H "x-api-key: $SUPADATA_API_KEY"
```

### Choosing `mode`

- **`auto`** (default) — best for unknown videos: tries native captions first, falls back to AI-generated. Lowest cost on average.
- **`native`** — only return human/auto-uploaded captions. Use when the user explicitly wants the original captions and is OK with failure if none exist.
- **`generate`** — force AI transcription. Use when `auto`/`native` returned `transcript-unavailable`, or when the video is a file URL (file URLs are always `generate` regardless).

AI-generated transcripts cost more credits — avoid `generate` unless needed.

### Language codes

ISO 639-1 two-letter codes (`en`, `es`, `fr`, `de`, `pl`, `ja`, `zh`, …). Full list: <https://docs.supadata.ai/youtube/supported-language-codes>.

---

## `GET /metadata` — unified social media metadata

Works for YouTube, TikTok, Instagram, X (Twitter), and Facebook posts. Prefer this over `/youtube/video` (deprecated) — it returns the same data with a unified shape across platforms.

| Query param | Notes |
|---|---|
| `url` (required) | URL of the video/post |

Response (unified across platforms):
```json
{
  "platform": "youtube",
  "url": "https://...",
  "title": "...",
  "description": "...",
  "author": { "name": "...", "url": "...", "id": "..." },
  "thumbnail": "https://...",
  "duration": 213,
  "publishedAt": "2009-10-25T06:57:33Z",
  "stats": { "views": 1234567, "likes": 1000, "comments": 100 },
  "tags": ["..."]
}
```

```bash
curl -sG "https://api.supadata.ai/v1/metadata" \
  -H "x-api-key: $SUPADATA_API_KEY" \
  --data-urlencode "url=https://www.tiktok.com/@user/video/1234567890"
```

`/metadata` covers single videos and posts. For channel-, playlist-, or search-level metadata, use the YouTube endpoints in [`youtube.md`](youtube.md).

---

## `POST /extract` — AI structured extraction

Turn a video into structured JSON, either by describing what you want in natural language (`prompt`) or by specifying the exact output shape (`schema`).

Supports YouTube, TikTok, Instagram, X (Twitter), and Facebook videos.

### Request body

`prompt` and `schema` are both optional, but at least one must be provided:

```json
{
  "url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
  "prompt": "Extract the main topics and key takeaways",
  "schema": {
    "type": "object",
    "properties": {
      "topics": { "type": "array", "items": { "type": "string" } },
      "summary": { "type": "string" }
    },
    "required": ["topics", "summary"]
  }
}
```

| Field | Required | Notes |
|---|---|---|
| `url` | yes | Video URL on a supported platform |
| `prompt` | one of `prompt`/`schema` | Natural language description of what to extract |
| `schema` | one of `prompt`/`schema` | JSON Schema for the output. AI conforms to it |

Response (always async): `{ "jobId": "..." }` with HTTP 202.

### `GET /extract/{jobId}` — poll for results

```json
{
  "status": "queued" | "active" | "completed" | "failed",
  "data": {
    "topics": ["AI basics", "Machine learning"],
    "summary": "An introduction to AI concepts."
  },
  "schema": { /* echo of the schema used (or AI-generated if none provided) */ },
  "error": null
}
```

If you supplied only a `prompt`, the AI generates its own schema and returns it in the `schema` field — useful for capturing the structure for reuse.

### Three ways to call

**1. Prompt only** (AI picks the structure):
```bash
curl -sX POST "https://api.supadata.ai/v1/extract" \
  -H "x-api-key: $SUPADATA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
    "prompt": "List every product mentioned with brand and approximate price"
  }'
```

**2. Schema only** (no instructions, just the shape):
```bash
curl -sX POST "https://api.supadata.ai/v1/extract" \
  -H "x-api-key: $SUPADATA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://www.tiktok.com/@user/video/1234567890",
    "schema": {
      "type": "object",
      "properties": {
        "products": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "name": { "type": "string" },
              "brand": { "type": "string" },
              "price": { "type": "number" }
            }
          }
        }
      }
    }
  }'
```

**3. Both** — most reliable:
```bash
curl -sX POST "https://api.supadata.ai/v1/extract" \
  -H "x-api-key: $SUPADATA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://www.youtube.com/watch?v=...",
    "prompt": "Extract every product mentioned along with its brand and approximate price in USD",
    "schema": {
      "type": "object",
      "properties": {
        "products": { "type": "array", "items": { "type": "object",
          "properties": {
            "name": { "type": "string" },
            "brand": { "type": "string" },
            "price": { "type": "number" }
          },
          "required": ["name"]
        }}
      },
      "required": ["products"]
    }
  }'
```

Combining both gives the AI explicit instructions *and* a hard output contract. Use this whenever the consumer of the data is downstream code that depends on a stable schema.

### Polling pattern

```bash
JOB=$(curl -sX POST "https://api.supadata.ai/v1/extract" \
  -H "x-api-key: $SUPADATA_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$BODY" | jq -r '.jobId')

while :; do
  RES=$(curl -s "https://api.supadata.ai/v1/extract/$JOB" \
    -H "x-api-key: $SUPADATA_API_KEY")
  STATUS=$(echo "$RES" | jq -r '.status')
  case "$STATUS" in
    completed) echo "$RES" | jq '.data'; break ;;
    failed)    echo "$RES" | jq '.error' >&2; exit 1 ;;
    *)         sleep 3 ;;
  esac
done
```

Or use `scripts/poll-job.sh /extract <jobId>` from this skill.

### Tips for reliable extraction

- **Be specific in the prompt.** "List every product mentioned" beats "summarize". The AI is conservative when the request is vague.
- **Constrain types.** `"type": "number"` instead of `"string"` for prices, `"format": "date"` for dates — the AI coerces.
- **Use `required`** for fields the consumer truly needs. Anything not required may be omitted when the video doesn't mention it.
- **Short videos extract reliably; long videos (1h+) may miss details near the end.** For long-form content, transcribe first (`/transcript` with `text=true`) and pass the transcript to your own LLM with a structured-output schema.

### Cost note

Extract jobs cost more credits than transcript jobs because they run AI on top of the video content. Check `/me` for your remaining credits before kicking off a large batch.
