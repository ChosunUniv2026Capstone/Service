import json
import re
from pathlib import Path

import pytest

WORKSPACE_ROOT = Path(__file__).resolve().parents[2]
COMPONENTS = {
    "Backend": {"release_type": "simple", "version_file": "version.txt", "image": "backend"},
    "PresenceService": {"release_type": "simple", "version_file": "version.txt", "image": "presence-service"},
    "DB": {"release_type": "simple", "version_file": "version.txt", "image": "db"},
    "Front": {"release_type": "node", "version_file": "package.json", "image": "front"},
}


def require_workspace_component(path: Path):
    if not path.exists():
        pytest.skip(f"workspace sibling repo not available: {path}")


def read(path: Path) -> str:
    return path.read_text()


@pytest.mark.parametrize("repo,expected", COMPONENTS.items())
def test_component_release_please_config_and_seed_version(repo, expected):
    root = WORKSPACE_ROOT / repo
    require_workspace_component(root)

    config = json.loads((root / "release-please-config.json").read_text())
    manifest = json.loads((root / ".release-please-manifest.json").read_text())
    package = config["packages"]["."]
    assert package["release-type"] == expected["release_type"]
    assert manifest["."] == "0.1.0"
    assert (root / "CHANGELOG.md").is_file()

    if repo == "Front":
        package_json = json.loads((root / "package.json").read_text())
        assert package_json["version"] == "0.1.0"
    else:
        assert (root / "version.txt").read_text().strip() == "0.1.0"


@pytest.mark.parametrize("repo,expected", COMPONENTS.items())
def test_component_release_please_workflow_publishes_release_images(repo, expected):
    root = WORKSPACE_ROOT / repo
    require_workspace_component(root)
    workflow = read(root / ".github" / "workflows" / "release-please.yml")

    for permission in ["contents: write", "pull-requests: write", "issues: write", "packages: write"]:
        assert permission in workflow
    assert "googleapis/release-please-action@v4" in workflow
    assert "config-file: release-please-config.json" in workflow
    assert "manifest-file: .release-please-manifest.json" in workflow
    assert "release_created == 'true'" in workflow
    assert "docker/build-push-action" in workflow
    assert "v$major.$minor.$patch" in workflow
    assert "v$major.$minor" in workflow
    assert 'if [ "$major" -gt 0 ]; then' in workflow
    assert "sha-$short_sha" in workflow
    assert f"PACKAGE_NAME: {expected['image']}" in workflow


@pytest.mark.parametrize("repo", COMPONENTS)
def test_non_release_image_workflow_avoids_tag_release_assumptions(repo):
    root = WORKSPACE_ROOT / repo
    require_workspace_component(root)
    workflow = read(root / ".github" / "workflows" / "release-image.yml")

    assert "pull_request:" in workflow
    assert "branches:" in workflow
    assert "packages: write" in workflow
    assert "contents: read" in workflow
    assert "tags:" not in workflow.split("permissions:", 1)[0], "release-image workflow must not rely on tag triggers"
    assert "type=raw,value=latest" not in workflow
    assert "type=ref,event=tag" not in workflow
    assert "type=sha,prefix=sha-" in workflow


def test_service_ci_wires_manifest_validator_and_contract_tests():
    service = WORKSPACE_ROOT / "Service"
    workflow = read(service / ".github" / "workflows" / "ci.yml")
    assert "validate-release-manifest.sh" in workflow
    assert "pytest tests/test_release_manifest_contract.py" in workflow


def test_service_release_and_deploy_paths_validate_manifest_before_use():
    service = WORKSPACE_ROOT / "Service"
    release_workflow = read(service / ".github" / "workflows" / "release-please.yml")
    deploy_script = read(service / "scripts" / "deploy-demo.sh")
    renderer = read(service / "scripts" / "render-release-env.sh")
    assert "validate-release-manifest.sh" in release_workflow
    assert re.search(r"validate-release-manifest\.sh.*\$manifest", deploy_script, re.S)
    assert "validate-release-manifest.sh" in renderer
