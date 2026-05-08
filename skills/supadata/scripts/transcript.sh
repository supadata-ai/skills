#!/usr/bin/env bash
# Fetch a transcript from any Supadata-supported video URL.
# Handles the synchronous (200) and async-job (202) cases.
#
# Usage:
#   transcript.sh <video-url> [--lang en] [--mode auto|native|generate] [--text|--chunks]
#
# Env: SUPADATA_API_KEY required. Needs `curl` and `jq`.

set -euo pipefail

if [ -z "${SUPADATA_API_KEY:-}" ]; then
  echo "error: SUPADATA_API_KEY is not set" >&2
  exit 1
fi

if [ $# -lt 1 ]; then
  echo "usage: $0 <video-url> [--lang en] [--mode auto|native|generate] [--text|--chunks]" >&2
  exit 2
fi

URL=$1; shift
LANG=""
MODE="auto"
TEXT="true"   # default to plain text — easier to consume

while [ $# -gt 0 ]; do
  case "$1" in
    --lang)   LANG=$2; shift 2 ;;
    --mode)   MODE=$2; shift 2 ;;
    --text)   TEXT=true; shift ;;
    --chunks) TEXT=false; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

BASE="https://api.supadata.ai/v1"
ARGS=(-G --data-urlencode "url=$URL" --data-urlencode "text=$TEXT" --data-urlencode "mode=$MODE")
[ -n "$LANG" ] && ARGS+=(--data-urlencode "lang=$LANG")

# Capture body and HTTP status separately.
RESPONSE=$(curl -sS -w '\n%{http_code}' "${ARGS[@]}" \
  -H "x-api-key: $SUPADATA_API_KEY" \
  "$BASE/transcript")
STATUS=$(printf '%s' "$RESPONSE" | tail -n1)
BODY=$(printf '%s' "$RESPONSE" | sed '$d')

case "$STATUS" in
  200)
    printf '%s\n' "$BODY"
    ;;
  202)
    JOB=$(printf '%s' "$BODY" | jq -r '.jobId // empty')
    [ -z "$JOB" ] && { echo "$BODY" >&2; exit 1; }
    echo "transcript job started: $JOB — polling..." >&2
    while :; do
      RES=$(curl -sS "$BASE/transcript/$JOB" -H "x-api-key: $SUPADATA_API_KEY")
      S=$(printf '%s' "$RES" | jq -r '.status // empty')
      case "$S" in
        completed) printf '%s\n' "$RES"; exit 0 ;;
        failed)    printf '%s\n' "$RES" >&2; exit 1 ;;
        *)         sleep 3 ;;
      esac
    done
    ;;
  *)
    printf '%s\n' "$BODY" >&2
    exit 1
    ;;
esac
