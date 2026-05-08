# YouTube-specific endpoints

Endpoints under `/youtube/*` give you finer control than the universal endpoints in [`video.md`](video.md): per-language transcripts, translation, batch jobs across a playlist or channel, channel/playlist metadata, video listings, and search.

If you only need a single transcript or unified video metadata, prefer `/transcript` and `/metadata` from [`video.md`](video.md) — they're simpler and work the same way for non-YouTube platforms.

Auth: `-H "x-api-key: $SUPADATA_API_KEY"`. Base URL: `https://api.supadata.ai/v1`.

## `GET /youtube/transcript`

YouTube-specific transcript fetch. Always synchronous (no job IDs). Same response shape as the universal `/transcript`.

| Query param | Notes |
|---|---|
| `url` | YouTube URL |
| `videoId` | Alternative to `url` — accepts the 11-char video ID directly |
| `text` | Plain text vs timestamped chunks (default `false`) |
| `chunkSize` | 50–10000, max characters per chunk (only when `text=false`) |
| `lang` | ISO 639-1 preferred language |

If the requested `lang` is unavailable, the API silently falls back to the first available language (the response `lang` field tells you which).

HTTP 206 means "transcript unavailable" — for example, no captions exist on the video. Re-issue against `/transcript` (the universal endpoint) with `mode=generate` to force AI transcription.

## `GET /youtube/transcript/translate`

Translate a YouTube transcript into another language.

| Query param | Notes |
|---|---|
| `url` *or* `videoId` | One of these is required |
| `lang` (required) | Target ISO 639-1 code |
| `text`, `chunkSize` | Same as transcript |

Response: `{ "content": ..., "lang": "<target>", "availableLangs": [...] }`.

## `POST /youtube/transcript/batch` — many transcripts at once

Body (one of `videoIds`, `playlistId`, or `channelId` is required):

```json
{
  "videoIds": ["dQw4w9WgXcQ", "https://www.youtube.com/watch?v=xvFZjo5PgG0"],
  "playlistId": "PLlaN88a7y2_plecYoJxvRFTLHVbIVAOoc",
  "channelId": "@rickastley",
  "limit": 20,
  "lang": "en",
  "text": true
}
```

| Field | Notes |
|---|---|
| `videoIds` | Array of YouTube IDs or full URLs |
| `playlistId` | Playlist URL or ID |
| `channelId` | Channel URL, handle (e.g. `@rickastley`), or ID |
| `limit` | 1–5000, default 10 (only relevant for playlist/channel inputs) |
| `lang` | ISO 639-1 |
| `text` | Plain text vs chunks |

Response: `{ "jobId": "..." }`. Poll `GET /youtube/batch/{jobId}`:

```json
{
  "status": "completed",
  "results": [
    { "videoId": "...", "transcript": { "content": "...", "lang": "en" } },
    { "videoId": "...", "error": { "code": "transcript-unavailable" } }
  ],
  "stats": { "total": 20, "succeeded": 18, "failed": 2 }
}
```

## `GET /youtube/channel`

| Query param | Notes |
|---|---|
| `id` (required) | URL, handle (`@rickastley`), `c/...` URL, or channel ID |

Response:
```json
{
  "id": "UCuAXFkgsw1L7xaCfnd5JJOw",
  "name": "Rick Astley",
  "handle": "@rickastley",
  "description": "...",
  "subscriberCount": 5000000,
  "videoCount": 100,
  "thumbnail": "https://...",
  "banner": "https://..."
}
```

## `GET /youtube/playlist`

| Query param | Notes |
|---|---|
| `id` (required) | Playlist URL or ID |

Response:
```json
{
  "id": "PLlaN...",
  "title": "...",
  "description": "...",
  "videoCount": 25,
  "viewCount": 1000000,
  "channel": { "id": "...", "name": "..." }
}
```

## `GET /youtube/channel/videos`

List video IDs from a channel. Useful as input to the transcript batch endpoint.

| Query param | Notes |
|---|---|
| `id` (required) | Channel URL, handle, or ID |
| `limit` | 1–5000, default 30 |
| `type` | `all` \| `video` \| `short` \| `live` (default `all`) |

Response: `{ "videoIds": ["...", "...", ...], "shortIds": [...], "liveIds": [...] }`.

## `GET /youtube/playlist/videos`

| Query param | Notes |
|---|---|
| `id` (required) | Playlist URL or ID |
| `limit` | 1–5000, default 100 |

Response: `{ "videoIds": ["...", ...] }`.

## `GET /youtube/search`

| Query param | Notes |
|---|---|
| `query` (required) | Search string |
| `type` | `all` \| `video` \| `channel` \| `playlist` \| `movie` (default `all`) |
| `uploadDate` | `all` \| `hour` \| `today` \| `week` \| `month` \| `year` |
| `duration` | `all` \| `short` (<4m) \| `medium` (4–20m) \| `long` (>20m) |
| `features` | comma-separated: `live`, `4k`, `hd`, `subtitles`, `creativeCommons`, `360`, `vr180`, `3d`, `hdr`, `location`, `purchased` |
| `sortBy` | `relevance` \| `uploadDate` \| `viewCount` \| `rating` |
| `limit` | 1–50, default 10 |

Response: `{ "results": [{ "type": "video", "id": "...", "title": "...", ... }] }`.

```bash
curl -sG "https://api.supadata.ai/v1/youtube/search" \
  -H "x-api-key: $SUPADATA_API_KEY" \
  --data-urlencode "query=Never Gonna Give You Up" \
  --data-urlencode "type=video" \
  --data-urlencode "duration=short"
```

## `POST /youtube/video/batch` — metadata for many videos

Body shape mirrors transcript-batch — one of `videoIds`, `playlistId`, `channelId`, plus optional `limit`.

Response: `{ "jobId": "..." }`. Poll `GET /youtube/batch/{jobId}` for results — same job endpoint as transcript batch, the `results` array contains `video` objects.

## URL formats

YouTube accepts every common URL form: `youtu.be/ID`, `youtube.com/watch?v=ID`, `youtube.com/shorts/ID`, `youtube.com/live/ID`, etc. Full list: <https://docs.supadata.ai/youtube/supported-url-formats>.

## Pattern: transcribe an entire channel

```bash
# 1. start a batch transcript job for the whole channel
JOB=$(curl -sX POST "https://api.supadata.ai/v1/youtube/transcript/batch" \
  -H "x-api-key: $SUPADATA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{ "channelId": "@rickastley", "limit": 100, "text": true }' \
  | jq -r '.jobId')

# 2. poll until completed
while :; do
  RES=$(curl -s "https://api.supadata.ai/v1/youtube/batch/$JOB" \
    -H "x-api-key: $SUPADATA_API_KEY")
  STATUS=$(echo "$RES" | jq -r '.status')
  [ "$STATUS" = "completed" ] && break
  [ "$STATUS" = "failed" ] && { echo "$RES" >&2; exit 1; }
  sleep 5
done
echo "$RES" | jq '.results'
```
