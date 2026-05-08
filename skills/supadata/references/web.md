# Web scraping, crawling, and mapping

Auth: `-H "x-api-key: $SUPADATA_API_KEY"`. Base URL: `https://api.supadata.ai/v1`.

## `GET /web/scrape` — single page → Markdown

| Query param | Default | Notes |
|---|---|---|
| `url` (required) | — | Page URL |
| `noLinks` | `false` | When `true`, removes Markdown links (keeps the visible text only) |
| `lang` | `en` | ISO 639-1; sets `Accept-Language` to influence the page's language |

Response:
```json
{
  "url": "https://example.com/article",
  "name": "Page title",
  "description": "Meta description",
  "content": "# Article\n\nFull markdown content..."
}
```

```bash
curl -sG "https://api.supadata.ai/v1/web/scrape" \
  -H "x-api-key: $SUPADATA_API_KEY" \
  --data-urlencode "url=https://supadata.ai/blog/launch" \
  --data-urlencode "noLinks=true"
```

Use this for "give me the article text", "summarize this page", or any one-off extraction. Output is clean enough to feed directly to an LLM.

## `POST /web/crawl` — every page on a site

Body:
```json
{ "url": "https://supadata.ai", "limit": 100 }
```

| Field | Default | Notes |
|---|---|---|
| `url` (required) | — | Starting URL |
| `limit` | 100 | 1–5000, max pages to crawl |

Response: `{ "jobId": "..." }`.

Poll `GET /web/crawl/{jobId}`:

```json
{
  "status": "completed",
  "totalPages": 42,
  "pages": [
    { "url": "...", "name": "...", "description": "...", "content": "# ..." },
    ...
  ],
  "next": "https://api.supadata.ai/v1/web/crawl/<jobId>?skip=100"
}
```

If `pages` is paginated (large crawls), follow the `next` URL or pass `?skip=N` to fetch the remainder.

```bash
JOB=$(curl -sX POST "https://api.supadata.ai/v1/web/crawl" \
  -H "x-api-key: $SUPADATA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{ "url": "https://example.com/docs", "limit": 50 }' | jq -r '.jobId')

while :; do
  RES=$(curl -s "https://api.supadata.ai/v1/web/crawl/$JOB" \
    -H "x-api-key: $SUPADATA_API_KEY")
  STATUS=$(echo "$RES" | jq -r '.status')
  [ "$STATUS" = "completed" ] && break
  [ "$STATUS" = "failed" ] && { echo "$RES" >&2; exit 1; }
  sleep 5
done
echo "$RES" | jq '.pages[] | { url, name }'
```

Crawl is the right tool when the user says "ingest this docs site", "scrape every page on X", or wants a full corpus. If they only need URLs (not page content), use `/web/map` instead — it's faster and cheaper.

## `GET /web/map` — sitemap-style URL discovery

| Query param | Default | Notes |
|---|---|---|
| `url` (required) | — | Site URL |
| `noLinks` | `false` | Same as scrape |
| `lang` | `en` | Same as scrape |

Response: `{ "links": ["https://...", "https://...", ...] }`.

```bash
curl -sG "https://api.supadata.ai/v1/web/map" \
  -H "x-api-key: $SUPADATA_API_KEY" \
  --data-urlencode "url=https://supadata.ai" \
  | jq '.links'
```

Common pattern: map → scrape selected URLs:
```bash
curl -sG "https://api.supadata.ai/v1/web/map" \
  -H "x-api-key: $SUPADATA_API_KEY" \
  --data-urlencode "url=https://example.com" \
  | jq -r '.links[]' \
  | grep '/blog/' \
  | while read -r u; do
      curl -sG "https://api.supadata.ai/v1/web/scrape" \
        -H "x-api-key: $SUPADATA_API_KEY" \
        --data-urlencode "url=$u" \
        | jq -r '.content' > "$(echo "$u" | sed 's|.*/||').md"
    done
```

## Choosing between scrape / crawl / map

| Goal | Use |
|---|---|
| One page → text | `/web/scrape` |
| Whole site → text for every page | `/web/crawl` |
| List of URLs only (no content) | `/web/map` |
| Specific subset of pages on a site | `/web/map` then `/web/scrape` per URL |
