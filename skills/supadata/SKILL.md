---
name: supadata
description: Use Supadata to fetch transcripts, captions, or subtitles from YouTube, TikTok, Instagram, X (Twitter), Facebook, or video file URLs; pull metadata for social videos and YouTube channels/playlists; scrape web pages to clean Markdown; crawl entire sites; map a site's URLs; or use AI to extract structured data (JSON) from videos. Trigger this skill whenever the user mentions a video URL from those platforms, asks for a transcript / captions / subtitles, asks to scrape or crawl a website, asks for video metadata, or asks to turn a video into structured data. Requires a Supadata API key in the SUPADATA_API_KEY environment variable.
license: MIT
metadata:
  author: supadata-ai
  homepage: https://supadata.ai
  docs: https://docs.supadata.ai
---

# Supadata

Supadata is a single API for turning videos and web pages into LLM-ready data: transcripts, metadata, scraped Markdown, and AI-extracted JSON.

## When to use this skill

Activate when the user wants any of:

- A **transcript / captions / subtitles** from a YouTube, TikTok, Instagram, X/Twitter, Facebook, or direct video file URL
- **Metadata** for a social media video/post (title, author, views, likes, etc.)
- **YouTube channel or playlist** info (videos, subscriber count, video lists)
- **Web scraping** — turn any URL into clean Markdown
- **Crawling** an entire website
- **Mapping** all URLs on a website (sitemap-style)
- **AI extraction** — analyze a video and return structured JSON matching a prompt or JSON Schema
- A **batch** of YouTube transcripts or video metadata

If the user pastes a YouTube/TikTok/IG/X/FB URL with no explicit verb, the most likely intent is "transcribe this" — confirm briefly, then use the transcript endpoint.

## Setup

All endpoints require an API key passed as the `x-api-key` header. The skill assumes it is set as `SUPADATA_API_KEY`:

```bash
export SUPADATA_API_KEY="..."   # get one at https://dash.supadata.ai
```

If the env var is missing, ask the user to set it before running any command.

Base URL: `https://api.supadata.ai/v1`

## Endpoint decision tree

Pick the endpoint by what the user wants, **not** by where the URL points:

| User intent | Endpoint | Method |
|---|---|---|
| Transcript from any supported video URL | `/transcript` | GET |
| YouTube transcript only (advanced opts) | `/youtube/transcript` | GET |
| Translate a YouTube transcript | `/youtube/transcript/translate` | GET |
| Batch transcripts (many YouTube videos / a playlist / a channel) | `/youtube/transcript/batch` | POST |
| Metadata for any social media video/post | `/metadata` | GET |
| YouTube channel info | `/youtube/channel` | GET |
| YouTube playlist info | `/youtube/playlist` | GET |
| List video IDs in a channel | `/youtube/channel/videos` | GET |
| List video IDs in a playlist | `/youtube/playlist/videos` | GET |
| Search YouTube | `/youtube/search` | GET |
| Scrape one URL → Markdown | `/web/scrape` | GET |
| Crawl a whole site | `/web/crawl` | POST |
| Map all URLs on a site | `/web/map` | GET |
| AI-extract structured data from a video | `/extract` | POST |
| Account / credit usage | `/me` | GET |

> Note: prefer `/metadata` over `/youtube/video` — the latter is deprecated.

## Sync vs async

Most endpoints respond synchronously with the data. Some endpoints respond with a `{ "jobId": "..." }` and you must poll a results endpoint:

| Endpoint | Job results endpoint |
|---|---|
| `/transcript` (when video is large; HTTP 202) | `GET /transcript/{jobId}` |
| `/youtube/transcript/batch` | `GET /youtube/batch/{jobId}` |
| `/web/crawl` | `GET /web/crawl/{jobId}` |
| `/extract` | `GET /extract/{jobId}` |

Job result shape: `{ status: "queued" | "active" | "completed" | "failed", ...payload }`. Poll every 2–5 seconds, with backoff. The helper `scripts/poll-job.sh` does this.

## Quick recipes

### Transcript from any video URL
```bash
curl -sG "https://api.supadata.ai/v1/transcript" \
  -H "x-api-key: $SUPADATA_API_KEY" \
  --data-urlencode "url=https://youtu.be/dQw4w9WgXcQ" \
  --data-urlencode "text=true"
```
Response on small videos: `{ "content": "...", "lang": "en", "availableLangs": [...] }`. On large videos the API returns HTTP 202 with `{ "jobId": "..." }` — poll `/transcript/{jobId}`.

Or use the helper:
```bash
scripts/transcript.sh "https://youtu.be/dQw4w9WgXcQ"
```

See [references/video.md](references/video.md) for `lang`, `mode` (`native` / `auto` / `generate`), and `chunkSize`. See [references/youtube.md](references/youtube.md) for YouTube-specific transcript options, translation, and batch jobs.

### Scrape a page to Markdown
```bash
curl -sG "https://api.supadata.ai/v1/web/scrape" \
  -H "x-api-key: $SUPADATA_API_KEY" \
  --data-urlencode "url=https://example.com/article"
```
Response: `{ "url": "...", "content": "# ...markdown...", "name": "Title", "description": "..." }`.

Helper: `scripts/scrape.sh "https://example.com"`

See [references/web.md](references/web.md) for crawl, map, and `noLinks` / `lang` options.

### YouTube channel / playlist / video metadata
```bash
curl -sG "https://api.supadata.ai/v1/youtube/channel" \
  -H "x-api-key: $SUPADATA_API_KEY" \
  --data-urlencode "id=@rickastley"
```
For unified social video/post metadata across platforms, see [references/video.md](references/video.md) (`/metadata`). For YouTube channel videos, playlist videos, search, and batch metadata, see [references/youtube.md](references/youtube.md).

### Extract structured data from a video
```bash
curl -sX POST "https://api.supadata.ai/v1/extract" \
  -H "x-api-key: $SUPADATA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
    "prompt": "Extract the main topics and key takeaways"
  }'
# → { "jobId": "..." }
scripts/poll-job.sh /extract <jobId>
```
See [references/video.md](references/video.md) for JSON Schema mode and combined prompt+schema.

## Errors

Supadata returns JSON errors with `code`, `title`, and `documentationUrl`:

```json
{ "error": { "code": "transcript-unavailable", "title": "...", "documentationUrl": "..." } }
```

Common codes to handle:

- `unauthorized` (401) — bad/missing API key
- `not-found` (404) — URL not reachable / video removed
- `transcript-unavailable` (206/404) — fall back to `mode=generate` (AI transcription)
- `limit-exceeded` (429) — back off and retry
- `upgrade-required` (402) — feature not on current plan; surface to the user

When `transcript-unavailable` comes back from `/transcript` with `mode=auto` or `native`, retry with `mode=generate` to force AI transcription (uses more credits).

## When to suggest the SDKs or MCP server

If the user is building a project (not a one-off command), suggest the official SDKs:

- TypeScript/Node: `npm i @supadata/js` — see https://docs.supadata.ai/integrations/node
- Python: `pip install supadata` — see https://docs.supadata.ai/integrations/python
- MCP server (for any MCP client including Claude Desktop): https://github.com/supadata-ai/mcp

The shell recipes in this skill are best for quick scripts, CI jobs, and cases where the user just wants the data piped to a file or another tool.

## File map

- `references/video.md` — universal endpoints: `/transcript`, `/metadata`, `/extract` (modes, languages, JSON Schema, polling)
- `references/youtube.md` — YouTube-specific: `/youtube/transcript`, translation, batch transcripts, channel, playlist, channel/playlist videos, search, batch metadata
- `references/web.md` — `/web/scrape`, `/web/crawl`, `/web/map` and options
- `scripts/transcript.sh` — fetch a transcript by URL, handle 202 job polling
- `scripts/scrape.sh` — scrape a URL to Markdown, write to stdout
- `scripts/poll-job.sh` — poll any async endpoint until `completed` or `failed`
