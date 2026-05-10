#!/usr/bin/env bash
set -euo pipefail
manifest="${1:?usage: render-release-env.sh manifests/releases/vX.Y.Z.yml}"
SERVICE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$SERVICE_ROOT/scripts/validate-release-manifest.sh" "$manifest" >/dev/null
python3 - "$manifest" <<'PY'
import os
import re, sys
from pathlib import Path
text = Path(sys.argv[1]).read_text()
defaults = {
    'COMPOSE_PROJECT_NAME': 'smart-class-demo',
    'NGINX_PORT': '3100',
    'DEMO_PUBLIC_URL': 'https://smart-class.org',
    'CORS_ORIGINS': 'https://smart-class.org',
    'GARAGE_RPC_SECRET': '0000000000000000000000000000000000000000000000000000000000000000',
    'GARAGE_DEFAULT_ACCESS_KEY': 'GK00000000000000000000000000',
    'GARAGE_DEFAULT_SECRET_KEY': '0000000000000000000000000000000000000000000000000000000000000000',
    'GARAGE_DEFAULT_BUCKET': 'smart-class',
    'OBJECT_STORAGE_PROVIDER': 's3',
    'OBJECT_STORAGE_ENDPOINT': 'http://garage:3900',
    'OBJECT_STORAGE_BUCKET': 'smart-class',
    'OBJECT_STORAGE_REGION': 'garage',
    'OBJECT_STORAGE_ACCESS_KEY': os.environ.get('GARAGE_DEFAULT_ACCESS_KEY', 'GK00000000000000000000000000'),
    'OBJECT_STORAGE_SECRET_KEY': os.environ.get('GARAGE_DEFAULT_SECRET_KEY', '0000000000000000000000000000000000000000000000000000000000000000'),
    'OBJECT_STORAGE_FORCE_PATH_STYLE': 'true',
    'ASSIGNMENT_UPLOAD_MAX_FILE_SIZE_BYTES': '536870912',
}
for env_name, default in defaults.items():
    print(f"{env_name}={os.environ.get(env_name, default)}")
keys = {
    'backend': 'BACKEND_IMAGE',
    'front': 'FRONT_IMAGE',
    'presenceService': 'PRESENCE_SERVICE_IMAGE',
    'db': 'DB_IMAGE',
}
for component, env_name in keys.items():
    m = re.search(rf"^  {component}:\n(?P<body>(?:    .+\n)+)", text, re.M)
    if not m:
        raise SystemExit(f"missing component {component}")
    body = m.group('body')
    def field(name):
        f = re.search(rf"^    {name}:\s*(.+)\s*$", body, re.M)
        return f.group(1).strip() if f else ''
    image, tag, digest = field('image'), field('tag'), field('digest')
    if not image or not tag:
        raise SystemExit(f"missing image/tag for {component}")
    ref = f"{image}:{tag}"
    if digest:
        ref = f"{ref}@{digest}"
    print(f"{env_name}={ref}")
PY
