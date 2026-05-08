#!/usr/bin/env bash
# Poll a Supadata async job until it completes.
#
# Usage:
#   poll-job.sh <endpoint> <jobId> [--interval 3] [--timeout 600]
#
# <endpoint> is the path under /v1 that holds the job, e.g.:
#   /transcript          → polls /transcript/<jobId>
#   /extract             → polls /extract/<jobId>
#   /web/crawl           → polls /web/crawl/<jobId>
#   /youtube/batch       → polls /youtube/batch/<jobId>
#
# Prints the final JSON to stdout. Exits non-zero on failure or timeout.
#
# Env: SUPADATA_API_KEY required. Needs `curl` and `jq`.

set -euo pipefail

if [ -z "${SUPADATA_API_KEY:-}" ]; then
  echo "error: SUPADATA_API_KEY is not set" >&2
  exit 1
fi

if [ $# -lt 2 ]; then
  echo "usage: $0 <endpoint> <jobId> [--interval 3] [--timeout 600]" >&2
  exit 2
fi

ENDPOINT=$1
JOB=$2
shift 2

INTERVAL=3
TIMEOUT=600

while [ $# -gt 0 ]; do
  case "$1" in
    --interval) INTERVAL=$2; shift 2 ;;
    --timeout)  TIMEOUT=$2; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Normalize endpoint: strip leading slash, then prefix.
ENDPOINT=${ENDPOINT#/}
URL="https://api.supadata.ai/v1/$ENDPOINT/$JOB"

DEADLINE=$(( $(date +%s) + TIMEOUT ))

while :; do
  RES=$(curl -sS "$URL" -H "x-api-key: $SUPADATA_API_KEY")
  STATUS=$(printf '%s' "$RES" | jq -r '.status // empty')
  case "$STATUS" in
    completed)
      printf '%s\n' "$RES"
      exit 0
      ;;
    failed)
      printf '%s\n' "$RES" >&2
      exit 1
      ;;
    queued|active|"")
      if [ "$(date +%s)" -ge "$DEADLINE" ]; then
        echo "timeout after ${TIMEOUT}s; last response:" >&2
        printf '%s\n' "$RES" >&2
        exit 1
      fi
      sleep "$INTERVAL"
      ;;
    *)
      echo "unexpected status: $STATUS" >&2
      printf '%s\n' "$RES" >&2
      exit 1
      ;;
  esac
done
