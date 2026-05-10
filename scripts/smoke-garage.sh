#!/usr/bin/env bash
set -euo pipefail
SERVICE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bucket="${OBJECT_STORAGE_BUCKET:-${GARAGE_DEFAULT_BUCKET:-smart-class}}"
compose_args=(--project-directory "$SERVICE_ROOT")
if [ -n "${SERVICE_COMPOSE_FILES:-}" ]; then
  IFS=':' read -r -a files <<< "$SERVICE_COMPOSE_FILES"
  for file in "${files[@]}"; do
    compose_args+=(-f "$SERVICE_ROOT/$file")
  done
else
  compose_args+=(-f "$SERVICE_ROOT/compose.yml" -f "$SERVICE_ROOT/compose.image.yml")
fi

docker compose "${compose_args[@]}" exec -T garage /garage status >/dev/null
docker compose "${compose_args[@]}" exec -T garage /garage bucket info "$bucket" >/dev/null
echo "garage smoke passed: bucket '$bucket' is available"
