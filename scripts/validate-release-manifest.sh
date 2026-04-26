#!/usr/bin/env bash
set -euo pipefail
expected_service_version=""
manifest=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --service-version) expected_service_version="${2:?missing --service-version value}"; shift 2 ;;
    --help|-h) echo "usage: validate-release-manifest.sh [--service-version vX.Y.Z] manifests/releases/vX.Y.Z.yml"; exit 0 ;;
    --*) echo "unknown argument: $1" >&2; exit 2 ;;
    *) if [ -n "$manifest" ]; then echo "multiple manifest paths provided" >&2; exit 2; fi; manifest="$1"; shift ;;
  esac
done
[ -n "$manifest" ] || { echo "usage: validate-release-manifest.sh [--service-version vX.Y.Z] manifests/releases/vX.Y.Z.yml" >&2; exit 2; }
[ -f "$manifest" ] || { echo "missing manifest: $manifest" >&2; exit 1; }
if [ -z "$expected_service_version" ]; then
  base="$(basename "$manifest" .yml)"
  case "$base" in v[0-9]*.[0-9]*.[0-9]*) expected_service_version="$base" ;; esac
fi
python3 - "$manifest" "$expected_service_version" <<'PY'
import re
import sys
from pathlib import Path

manifest = Path(sys.argv[1])
expected = sys.argv[2]
text = manifest.read_text()
errors: list[str] = []

SEMVER_RE = re.compile(r"^v[0-9]+\.[0-9]+\.[0-9]+$")
DIGEST_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
URL_RE = re.compile(r"^https://github\.com/[^/]+/[^/]+/(?:releases/tag/[^/]+|actions/runs/[0-9]+)$")
REQUIRED_COMPONENTS = ("backend", "front", "presenceService", "db")
REQUIRED_FIELDS = ("image", "version", "tag", "digest", "release")


def top_field(name: str) -> str:
    match = re.search(rf"^{re.escape(name)}:\s*(.+?)\s*$", text, re.M)
    return match.group(1).strip() if match else ""


def component_block(name: str) -> str:
    match = re.search(rf"^  {re.escape(name)}:\n(?P<body>(?:    [^\n]*\n?)+)", text, re.M)
    return match.group("body") if match else ""


def field(block: str, name: str) -> str:
    match = re.search(rf"^    {re.escape(name)}:\s*(.*?)\s*$", block, re.M)
    return match.group(1).strip().strip('"\'') if match else ""

service_version = top_field("serviceVersion")
if not service_version:
    errors.append("missing serviceVersion")
elif not SEMVER_RE.fullmatch(service_version):
    errors.append(f"serviceVersion must be vX.Y.Z, got {service_version!r}")
elif expected and service_version != expected:
    errors.append(f"serviceVersion {service_version} does not match expected {expected}")

if not top_field("releasedAt"):
    errors.append("missing releasedAt")

if re.search(r"(^|[:\s])latest($|[:\s])", text):
    errors.append("manifest must not contain latest image tags")

for component in REQUIRED_COMPONENTS:
    block = component_block(component)
    if not block:
        errors.append(f"missing components.{component}")
        continue
    values = {name: field(block, name) for name in REQUIRED_FIELDS}
    for name in REQUIRED_FIELDS:
        if not values[name]:
            errors.append(f"missing components.{component}.{name}")
    if values["version"] and not SEMVER_RE.fullmatch(values["version"]):
        errors.append(f"components.{component}.version must be vX.Y.Z, got {values['version']!r}")
    if values["tag"] == "latest":
        errors.append(f"components.{component}.tag must not be latest")
    if values["digest"] and not DIGEST_RE.fullmatch(values["digest"]):
        errors.append(f"components.{component}.digest must be sha256:<64 lowercase hex>, got {values['digest']!r}")
    if values["release"] and not URL_RE.fullmatch(values["release"]):
        errors.append(
            f"components.{component}.release must be a GitHub release tag or Actions run URL, got {values['release']!r}"
        )
    if component == "db":
        reset_required = field(block, "resetRequired")
        if not reset_required:
            errors.append("missing components.db.resetRequired")
        elif reset_required not in {"true", "false"}:
            errors.append(f"components.db.resetRequired must be boolean true/false, got {reset_required!r}")

if errors:
    print(f"release manifest validation failed: {manifest}", file=sys.stderr)
    for error in errors:
        print(f"- {error}", file=sys.stderr)
    raise SystemExit(1)

print(f"release manifest validation passed: {manifest}")
PY
