#!/usr/bin/env bash
# Scrape a single web page to Markdown via Supadata.
#
# Usage:
#   scrape.sh <url> [--no-links] [--lang en] [--full]
#
#   --full  print the full JSON response (default: print just .content)
#
# Env: SUPADATA_API_KEY required. Needs `curl` and `jq`.

set -euo pipefail

if [ -z "${SUPADATA_API_KEY:-}" ]; then
  echo "error: SUPADATA_API_KEY is not set" >&2
  exit 1
fi

if [ $# -lt 1 ]; then
  echo "usage: $0 <url> [--no-links] [--lang en] [--full]" >&2
  exit 2
fi

URL=$1; shift
NO_LINKS="false"
LANG="en"
FULL=false

while [ $# -gt 0 ]; do
  case "$1" in
    --no-links) NO_LINKS=true; shift ;;
    --lang)     LANG=$2; shift 2 ;;
    --full)     FULL=true; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

BODY=$(curl -sSG "https://api.supadata.ai/v1/web/scrape" \
  -H "x-api-key: $SUPADATA_API_KEY" \
  --data-urlencode "url=$URL" \
  --data-urlencode "noLinks=$NO_LINKS" \
  --data-urlencode "lang=$LANG")

if $FULL; then
  printf '%s\n' "$BODY"
else
  printf '%s\n' "$BODY" | jq -r '.content // .error // empty'
fi
