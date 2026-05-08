# Supadata Skill

[![skills.sh](https://skills.sh/b/supadata-ai/skills)](https://skills.sh/supadata-ai/skills)

An [agent skill](https://agentskills.io/specification) that teaches your AI agent to use the [Supadata API](https://supadata.ai) for video transcripts, social media metadata, web scraping, crawling, and AI-powered structured data extraction from videos.

Once installed, your agent will know to:

- Fetch transcripts / captions / subtitles from YouTube, TikTok, Instagram, X (Twitter), Facebook, and direct video file URLs
- Pull unified metadata for any social media video or post
- Get YouTube channel, playlist, video, and search data
- Scrape any web page to clean Markdown
- Crawl a whole website
- Map all URLs on a site
- Extract structured JSON from videos using a prompt or JSON Schema

## Install

```bash
npx skills add supadata-ai/skills
```

That's it. The skill auto-activates when the user mentions a video URL, asks for a transcript, requests web scraping, etc.

### Install for a specific agent

```bash
npx skills add supadata-ai/skills -a claude-code
npx skills add supadata-ai/skills -a cursor
npx skills add supadata-ai/skills -a codex
```

Skills work with [60+ agents](https://skills.sh) including Claude Code, Cursor, Codex, GitHub Copilot, Windsurf, Gemini, OpenCode, and more.

### Install globally

```bash
npx skills add supadata-ai/skills -g
```

## Setup

Export your Supadata API key — get one at [dash.supadata.ai](https://dash.supadata.ai):

```bash
export SUPADATA_API_KEY="..."
```

The skill assumes this env var is present. Without it, the agent will ask the user to set it before running any command.

## What the skill contains

```
skills/supadata/
├── SKILL.md                         # entry point: when to activate, decision tree, quick recipes
├── references/
│   ├── video.md                     # universal endpoints: /transcript, /metadata, /extract
│   ├── youtube.md                   # YouTube-specific: channel, playlist, search, translation, batch
│   └── web.md                       # /web/scrape, /web/crawl, /web/map
└── scripts/
    ├── transcript.sh                # one-shot transcript fetch (handles async jobs)
    ├── scrape.sh                    # one-shot scrape to Markdown
    └── poll-job.sh                  # generic async-job poller
```

The skill follows the [Agent Skills spec](https://agentskills.io/specification) and uses progressive disclosure: `SKILL.md` is small and decision-oriented, with detailed endpoint docs in `references/` loaded only when the agent needs them.

## Other ways to use Supadata

This skill is the lightest-weight option — your agent makes plain HTTPS calls and you keep no extra dependencies.

For larger projects:

- **TypeScript/Node SDK:** [`@supadata/js`](https://github.com/supadata-ai/js)
- **Python SDK:** [`supadata`](https://github.com/supadata-ai/py) on PyPI
- **MCP server:** [`supadata-ai/mcp`](https://github.com/supadata-ai/mcp) — runs as a Model Context Protocol server for Claude Desktop, Cursor, etc.
- **No-code:** [Zapier](https://docs.supadata.ai/integrations/zapier), [Make](https://docs.supadata.ai/integrations/make), [n8n](https://docs.supadata.ai/integrations/n8n), [Active Pieces](https://docs.supadata.ai/integrations/activepieces)

## Links

- API docs: <https://docs.supadata.ai>
- Dashboard: <https://dash.supadata.ai>
- Status: <https://status.supadata.ai>

## License

MIT — see [LICENSE](LICENSE).
