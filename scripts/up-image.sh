#!/usr/bin/env bash
set -euo pipefail
SERVICE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SERVICE_ROOT"
docker compose --project-directory "$SERVICE_ROOT" \
  -f "$SERVICE_ROOT/compose.yml" \
  -f "$SERVICE_ROOT/compose.image.yml" \
  up "$@"
