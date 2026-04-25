# Service AGENTS

Service owns Smart Class runtime orchestration, compose files, nginx runtime config, release manifests, and demo deployment scripts.

## Rules
- Keep compose files at the repo root.
- Run Docker Compose with `--project-directory "$SERVICE_ROOT"` from wrapper scripts.
- Local mode may use sibling build contexts (`../Backend`, `../Front`, `../PresenceService`, `../DB`).
- Image and demo modes must use manifest-pinned GHCR image refs, never `latest`.
- DB reset must be explicit and limited to this compose project's DB volume.
