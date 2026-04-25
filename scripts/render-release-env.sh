#!/usr/bin/env bash
set -euo pipefail
manifest="${1:?usage: render-release-env.sh manifests/releases/vX.Y.Z.yml}"
python3 - "$manifest" <<'PY'
import re, sys
from pathlib import Path
text = Path(sys.argv[1]).read_text()
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
