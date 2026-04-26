#!/usr/bin/env bash
set -euo pipefail
SERVICE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
service_version=""
released_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
summary="Service release manifest"
backend_ref=""; front_ref=""; presence_ref=""; db_ref=""
backend_version=""; front_version=""; presence_version=""; db_version=""
backend_release=""; front_release=""; presence_release=""; db_release=""
db_reset_required="false"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --service-version) service_version="$2"; shift 2 ;;
    --released-at) released_at="$2"; shift 2 ;;
    --summary) summary="$2"; shift 2 ;;
    --backend-ref) backend_ref="$2"; shift 2 ;;
    --front-ref) front_ref="$2"; shift 2 ;;
    --presence-ref) presence_ref="$2"; shift 2 ;;
    --db-ref) db_ref="$2"; shift 2 ;;
    --backend-version) backend_version="$2"; shift 2 ;;
    --front-version) front_version="$2"; shift 2 ;;
    --presence-version) presence_version="$2"; shift 2 ;;
    --db-version) db_version="$2"; shift 2 ;;
    --backend-release) backend_release="$2"; shift 2 ;;
    --front-release) front_release="$2"; shift 2 ;;
    --presence-release) presence_release="$2"; shift 2 ;;
    --db-release) db_release="$2"; shift 2 ;;
    --db-reset-required) db_reset_required="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
case "$service_version" in v[0-9]*.[0-9]*.[0-9]*) ;; *) echo "--service-version must be vX.Y.Z" >&2; exit 2 ;; esac
case "$db_reset_required" in true|false) ;; *) echo "--db-reset-required must be true or false" >&2; exit 2 ;; esac
for pair in backend_ref front_ref presence_ref db_ref backend_version front_version presence_version db_version backend_release front_release presence_release db_release; do
  if [ -z "${!pair}" ]; then echo "missing --${pair//_/-}" >&2; exit 2; fi
done
split_ref() {
  local ref="$1" image tag digest
  image="${ref%@*}"; digest="${ref#*@}"
  if [ "$image" = "$digest" ]; then digest=""; fi
  tag="${image##*:}"
  if [ "$tag" = "$image" ] || [ "${image#*://}" != "$image" ]; then tag=""; fi
  if [ -n "$tag" ]; then image="${image%:*}"; fi
  printf '%s\n%s\n%s\n' "$image" "$tag" "$digest"
}
readarray -t backend < <(split_ref "$backend_ref")
readarray -t front < <(split_ref "$front_ref")
readarray -t presence < <(split_ref "$presence_ref")
readarray -t db < <(split_ref "$db_ref")
for component in backend front presence db; do
  ref_array="${component}[@]"
  values=("${!ref_array}")
  if [ -z "${values[1]}" ] || [ -z "${values[2]}" ]; then
    echo "--${component}-ref must include tag and sha256 digest" >&2
    exit 2
  fi
done
out="$SERVICE_ROOT/manifests/releases/${service_version}.yml"
mkdir -p "$(dirname "$out")"
cat > "$out" <<YAML
serviceVersion: $service_version
releasedAt: $released_at
components:
  backend:
    image: ${backend[0]}
    version: ${backend_version}
    tag: ${backend[1]:-$service_version}
    digest: ${backend[2]}
    release: ${backend_release}
  front:
    image: ${front[0]}
    version: ${front_version}
    tag: ${front[1]:-$service_version}
    digest: ${front[2]}
    release: ${front_release}
  presenceService:
    image: ${presence[0]}
    version: ${presence_version}
    tag: ${presence[1]:-$service_version}
    digest: ${presence[2]}
    release: ${presence_release}
  db:
    image: ${db[0]}
    version: ${db_version}
    tag: ${db[1]:-$service_version}
    digest: ${db[2]}
    resetRequired: $db_reset_required
    release: ${db_release}
notes:
  summary: $summary
YAML
"$SERVICE_ROOT/scripts/validate-release-manifest.sh" "$out" >/dev/null
echo "$out"
