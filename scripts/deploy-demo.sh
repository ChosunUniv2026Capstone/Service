#!/usr/bin/env bash
set -euo pipefail
SERVICE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
service_version=""
reset_demo_data="false"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --service-version) service_version="$2"; shift 2 ;;
    --reset-demo-data) reset_demo_data="true"; shift ;;
    --reset-demo-data=*) reset_demo_data="${1#*=}"; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
case "$service_version" in v[0-9]*.[0-9]*.[0-9]*) ;; *) echo "--service-version must be vX.Y.Z" >&2; exit 2 ;; esac
manifest="$SERVICE_ROOT/manifests/releases/${service_version}.yml"
[ -f "$manifest" ] || { echo "missing manifest: $manifest" >&2; exit 1; }
"$SERVICE_ROOT/scripts/validate-release-manifest.sh" "$manifest"
env_file="$SERVICE_ROOT/.env.release"
"$SERVICE_ROOT/scripts/render-release-env.sh" "$manifest" > "$env_file"
# shellcheck disable=SC1090
set -a; . "$env_file"; set +a
project="${COMPOSE_PROJECT_NAME:-smart-class-demo}"
state_dir="$SERVICE_ROOT/.deploy-state"
mkdir -p "$state_dir"
current_db_digest="$(awk '/^  db:/{in_db=1; next} in_db && /^  [A-Za-z]/{in_db=0} in_db && /^    digest:/{print $2}' "$manifest")"
reset_required="$(awk '/^  db:/{in_db=1; next} in_db && /^  [A-Za-z]/{in_db=0} in_db && /^    resetRequired:/{print $2}' "$manifest")"
previous_db_digest="$(cat "$state_dir/db.digest" 2>/dev/null || true)"
if [ "$reset_required" = "true" ] && [ "$reset_demo_data" != "true" ] && { [ -z "$previous_db_digest" ] || [ "$previous_db_digest" != "$current_db_digest" ]; }; then
  echo "DB reset required for changed/unknown DB digest; rerun with --reset-demo-data" >&2
  exit 1
fi
if [ -n "${GHCR_READ_TOKEN:-}" ]; then
  echo "$GHCR_READ_TOKEN" | docker login ghcr.io -u "${GHCR_READ_USER:-oauth2}" --password-stdin
fi
if [ "$reset_demo_data" = "true" ]; then
  docker volume rm "${project}_postgres-data" 2>/dev/null || true
fi
docker compose --project-directory "$SERVICE_ROOT" \
  --env-file "$env_file" \
  -f "$SERVICE_ROOT/compose.yml" \
  -f "$SERVICE_ROOT/compose.image.yml" \
  -f "$SERVICE_ROOT/compose.demo.yml" \
  pull
docker compose --project-directory "$SERVICE_ROOT" \
  --env-file "$env_file" \
  -f "$SERVICE_ROOT/compose.yml" \
  -f "$SERVICE_ROOT/compose.image.yml" \
  -f "$SERVICE_ROOT/compose.demo.yml" \
  up -d
echo "$current_db_digest" > "$state_dir/db.digest"
"$SERVICE_ROOT/scripts/healthcheck.sh" "${DEMO_PUBLIC_URL:-https://smart-class.org}/health"
