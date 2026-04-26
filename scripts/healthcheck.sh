#!/usr/bin/env bash
set -euo pipefail
url="${1:-${DEMO_PUBLIC_URL:-http://localhost:3100}/health}"
retries="${HEALTHCHECK_RETRIES:-30}"
sleep_seconds="${HEALTHCHECK_SLEEP_SECONDS:-2}"
expected_body='{"status":"ok"}'
for attempt in $(seq 1 "$retries"); do
  body="$(curl -fsS "$url" 2>/tmp/smart-class-health.err || true)"
  if [ "$body" = "$expected_body" ]; then
    printf '%s\n' "$body"
    echo "healthcheck passed: $url returned exact body $expected_body"
    exit 0
  fi
  error="$(cat /tmp/smart-class-health.err 2>/dev/null || true)"
  echo "healthcheck attempt $attempt/$retries failed: $url body='$body' error='$error'" >&2
  sleep "$sleep_seconds"
done
echo "healthcheck failed: $url did not return exact body $expected_body" >&2
exit 1
