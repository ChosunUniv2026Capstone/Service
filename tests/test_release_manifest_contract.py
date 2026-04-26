import os
import re
import shutil
import subprocess
from pathlib import Path

SERVICE_ROOT = Path(__file__).resolve().parents[1]
MANIFEST = SERVICE_ROOT / "manifests" / "releases" / "v0.1.0.yml"
VALIDATOR = SERVICE_ROOT / "scripts" / "validate-release-manifest.sh"
RENDERER = SERVICE_ROOT / "scripts" / "render-release-env.sh"
CREATOR = SERVICE_ROOT / "scripts" / "create-release-manifest.sh"


def run(*args, cwd=SERVICE_ROOT):
    return subprocess.run(args, cwd=cwd, text=True, capture_output=True, check=False)


def write_fixture(tmp_path: Path, transform):
    text = MANIFEST.read_text()
    changed = transform(text)
    tmp_path.mkdir(parents=True, exist_ok=True)
    fixture = tmp_path / "manifest.yml"
    fixture.write_text(changed)
    return fixture


def test_release_manifest_validates_and_renders_pinned_refs():
    validation = run(str(VALIDATOR), "--service-version", "v0.1.0", str(MANIFEST))
    assert validation.returncode == 0, validation.stderr

    rendered = run(str(RENDERER), str(MANIFEST))
    assert rendered.returncode == 0, rendered.stderr
    env = dict(line.split("=", 1) for line in rendered.stdout.strip().splitlines())
    assert env["BACKEND_IMAGE"].startswith("ghcr.io/chosununiv2026capstone/backend:sha-")
    for value in env.values():
        assert "@sha256:" in value
        assert ":latest" not in value


def test_manifest_validator_rejects_required_negative_cases(tmp_path):
    cases = {
        "missing digest": lambda t: re.sub(r"^    digest: sha256:[0-9a-f]{64}\n", "", t, count=1, flags=re.M),
        "latest tag": lambda t: re.sub(r"^    tag: .+$", "    tag: latest", t, count=1, flags=re.M),
        "missing db reset": lambda t: re.sub(r"^    resetRequired: (true|false)\n", "", t, flags=re.M),
        "non boolean db reset": lambda t: re.sub(r"^    resetRequired: (true|false)$", "    resetRequired: maybe", t, flags=re.M),
        "service version mismatch": lambda t: t.replace("serviceVersion: v0.1.0", "serviceVersion: v9.9.9", 1),
        "missing proof link": lambda t: re.sub(r"^    release: https://github.com/ChosunUniv2026Capstone/Backend/.+\n", "", t, count=1, flags=re.M),
        "invalid digest": lambda t: re.sub(r"sha256:[0-9a-f]{64}", "sha256:not-a-digest", t, count=1),
    }
    for name, transform in cases.items():
        fixture = write_fixture(tmp_path / name.replace(" ", "_"), transform)
        result = run(str(VALIDATOR), "--service-version", "v0.1.0", str(fixture))
        assert result.returncode != 0, name
        assert "validation failed" in result.stderr


def test_create_release_manifest_requires_explicit_component_metadata(tmp_path):
    service_copy = tmp_path / "Service"
    shutil.copytree(SERVICE_ROOT, service_copy, ignore=shutil.ignore_patterns(".git", "tests", ".pytest_cache"))
    script = service_copy / "scripts" / "create-release-manifest.sh"
    result = subprocess.run(
        [
            str(script),
            "--service-version", "v1.2.3",
            "--backend-ref", "ghcr.io/chosununiv2026capstone/backend:v1.2.3@sha256:" + "a" * 64,
            "--front-ref", "ghcr.io/chosununiv2026capstone/front:v1.2.3@sha256:" + "b" * 64,
            "--presence-ref", "ghcr.io/chosununiv2026capstone/presence-service:v1.2.3@sha256:" + "c" * 64,
            "--db-ref", "ghcr.io/chosununiv2026capstone/db:v1.2.3@sha256:" + "d" * 64,
            "--backend-version", "v1.2.3",
            "--front-version", "v1.2.3",
            "--presence-version", "v1.2.3",
            "--db-version", "v1.2.3",
            "--backend-release", "https://github.com/ChosunUniv2026Capstone/Backend/releases/tag/v1.2.3",
            "--front-release", "https://github.com/ChosunUniv2026Capstone/Front/releases/tag/v1.2.3",
            "--presence-release", "https://github.com/ChosunUniv2026Capstone/PresenceService/releases/tag/v1.2.3",
            "--db-release", "https://github.com/ChosunUniv2026Capstone/DB/releases/tag/v1.2.3",
            "--db-reset-required", "true",
        ],
        cwd=service_copy,
        text=True,
        capture_output=True,
        check=False,
    )
    assert result.returncode == 0, result.stderr
    manifest = service_copy / "manifests" / "releases" / "v1.2.3.yml"
    validation = subprocess.run([str(service_copy / "scripts" / "validate-release-manifest.sh"), "--service-version", "v1.2.3", str(manifest)], text=True, capture_output=True)
    assert validation.returncode == 0, validation.stderr
