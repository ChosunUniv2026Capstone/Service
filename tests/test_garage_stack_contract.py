import re
from pathlib import Path

SERVICE_ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (SERVICE_ROOT / relative).read_text()


def test_compose_wires_garage_bucket_and_backend_s3_env():
    compose = read("compose.yml")

    assert "garage:" in compose
    assert "dxflrs/garage:v2.3.0" in compose
    assert "--single-node" in compose
    assert "--default-bucket" in compose
    assert "garage-data:/var/lib/garage" in compose
    assert "./garage/garage.toml:/etc/garage.toml:ro" in compose
    assert 'test: ["CMD", "/garage", "status"]' in compose

    assert re.search(r"backend:\n(?:.*\n)*?      OBJECT_STORAGE_PROVIDER: ", compose)
    assert "OBJECT_STORAGE_ENDPOINT: ${OBJECT_STORAGE_ENDPOINT:-http://garage:3900}" in compose
    assert "OBJECT_STORAGE_BUCKET: ${OBJECT_STORAGE_BUCKET:-smart-class}" in compose
    assert "OBJECT_STORAGE_FORCE_PATH_STYLE: ${OBJECT_STORAGE_FORCE_PATH_STYLE:-true}" in compose
    assert "ASSIGNMENT_UPLOAD_MAX_FILE_SIZE_BYTES: ${ASSIGNMENT_UPLOAD_MAX_FILE_SIZE_BYTES:-536870912}" in compose
    assert "garage:\n        condition: service_healthy" in compose
    assert "garage-data:" in compose


def test_garage_config_uses_persistent_paths_and_s3_api_port():
    config = read("garage/garage.toml")

    assert 'metadata_dir = "/var/lib/garage/meta"' in config
    assert 'data_dir = "/var/lib/garage/data"' in config
    assert 'replication_factor = 1' in config
    assert 'api_bind_addr = "[::]:3900"' in config
    assert 's3_region = "garage"' in config


def test_nginx_upload_limits_allow_large_backend_proxied_assets():
    for conf in ["nginx/local.conf", "nginx/demo.conf"]:
        text = read(conf)
        assert "client_max_body_size 512m;" in text
        assert "proxy_read_timeout 300s;" in text
        assert "proxy_send_timeout 300s;" in text


def test_release_env_renderer_exports_storage_defaults():
    renderer = read("scripts/render-release-env.sh")

    for name in [
        "GARAGE_DEFAULT_BUCKET",
        "OBJECT_STORAGE_PROVIDER",
        "OBJECT_STORAGE_ENDPOINT",
        "OBJECT_STORAGE_ACCESS_KEY",
        "OBJECT_STORAGE_SECRET_KEY",
        "ASSIGNMENT_UPLOAD_MAX_FILE_SIZE_BYTES",
    ]:
        assert name in renderer


def test_garage_smoke_script_checks_status_and_bucket():
    script = read("scripts/smoke-garage.sh")

    assert "docker compose" in script
    assert "/garage status" in script
    assert "/garage bucket info" in script
    assert "SERVICE_COMPOSE_FILES" in script
