#!/usr/bin/env bash
set -euo pipefail
SERVICE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
service_version=""
reset_demo_data="false"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --service-version) service_version="$2"; shift 2 ;;
    --reset-demo-data)
      if [ "$#" -ge 2 ] && [ "${2#--}" = "$2" ]; then
        reset_demo_data="$2"; shift 2
      else
        reset_demo_data="true"; shift
      fi
      ;;
    --reset-demo-data=*) reset_demo_data="${1#*=}"; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
case "$service_version" in v[0-9]*.[0-9]*.[0-9]*) ;; *) echo "--service-version must be vX.Y.Z" >&2; exit 2 ;; esac
case "$reset_demo_data" in true|false) ;; *) echo "--reset-demo-data must be true or false" >&2; exit 2 ;; esac
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
compose_files=(
  --project-directory "$SERVICE_ROOT"
  --env-file "$env_file"
  -f "$SERVICE_ROOT/compose.yml"
  -f "$SERVICE_ROOT/compose.image.yml"
  -f "$SERVICE_ROOT/compose.demo.yml"
)
if [ "$reset_demo_data" = "true" ]; then
  docker compose "${compose_files[@]}" stop backend postgres 2>/dev/null || true
  docker compose "${compose_files[@]}" rm --force --stop postgres 2>/dev/null || true
  if docker volume inspect "${project}_postgres-data" >/dev/null 2>&1; then
    docker volume rm "${project}_postgres-data"
  fi
fi
docker compose "${compose_files[@]}" pull
docker compose "${compose_files[@]}" up -d
echo "$current_db_digest" > "$state_dir/db.digest"
"$SERVICE_ROOT/scripts/healthcheck.sh" "${DEMO_PUBLIC_URL:-https://smart-class.org}/health"
