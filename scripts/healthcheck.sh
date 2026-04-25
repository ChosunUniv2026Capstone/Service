#!/usr/bin/env bash
set -euo pipefail
url="${1:-${DEMO_PUBLIC_URL:-http://localhost:3100}/health}"
retries="${HEALTHCHECK_RETRIES:-30}"
sleep_seconds="${HEALTHCHECK_SLEEP_SECONDS:-2}"
for attempt in $(seq 1 "$retries"); do
  if curl -fsS "$url"; then
    echo
    echo "healthcheck passed: $url"
    exit 0
  fi
  echo "healthcheck attempt $attempt/$retries failed: $url" >&2
  sleep "$sleep_seconds"
done
echo "healthcheck failed: $url" >&2
exit 1
