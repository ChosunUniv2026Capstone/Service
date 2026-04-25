# Smart Class Service

`Service` is the canonical runtime orchestration repository for the Smart Class demo stack. It owns Docker Compose, nginx runtime config, Service release manifests, and demo deployment scripts. CodexKit delegates here and must not be the runtime source of truth.

## Modes

### Local source mode

Build sibling workspace repos and run through local nginx:

```bash
cp .env.example .env
./scripts/up-local.sh
curl -fsS http://localhost:3100/health
```

Local mode uses build contexts:

- `../Backend`
- `../Front`
- `../PresenceService`
- `../DB`

### Image mode

Run prebuilt GHCR images without local build contexts:

```bash
export BACKEND_IMAGE=ghcr.io/chosununiv2026capstone/backend:sha-...
export FRONT_IMAGE=ghcr.io/chosununiv2026capstone/front:sha-...
export PRESENCE_SERVICE_IMAGE=ghcr.io/chosununiv2026capstone/presence-service:sha-...
export DB_IMAGE=ghcr.io/chosununiv2026capstone/db:sha-...
./scripts/up-image.sh -d
```

### Demo deployment mode

Demo deploys are manifest-pinned Service releases. A deployment reads `manifests/releases/vX.Y.Z.yml`, renders `.env.release`, pulls images, starts compose with demo nginx, and checks `https://smart-class.org/health`.

```bash
./scripts/deploy-demo.sh --service-version v0.1.0 --reset-demo-data false
```

If the manifest says `components.db.resetRequired: true` and the DB image changed, the script fails before `docker compose up` unless `--reset-demo-data true` is supplied. Reset only removes the Service project DB volume.

## Release manifests

Create a manifest on the Release Please release PR branch before merge:

```bash
./scripts/create-release-manifest.sh \
  --service-version v0.1.0 \
  --backend-ref ghcr.io/chosununiv2026capstone/backend:sha-abc123@sha256:... \
  --backend-version v0.1.0 --backend-release https://github.com/ChosunUniv2026Capstone/Backend/releases/tag/v0.1.0 \
  --front-ref ghcr.io/chosununiv2026capstone/front:sha-abc123@sha256:... \
  --front-version v0.1.0 --front-release https://github.com/ChosunUniv2026Capstone/Front/releases/tag/v0.1.0 \
  --presence-ref ghcr.io/chosununiv2026capstone/presence-service:sha-abc123@sha256:... \
  --presence-version v0.1.0 --presence-release https://github.com/ChosunUniv2026Capstone/PresenceService/releases/tag/v0.1.0 \
  --db-ref ghcr.io/chosununiv2026capstone/db:sha-abc123@sha256:... \
  --db-version v0.1.0 --db-release https://github.com/ChosunUniv2026Capstone/DB/releases/tag/v0.1.0 \
  --db-reset-required true
```

Manifests must not use `latest`.

## GitHub Actions configuration

Demo deployment uses GitHub environment `demo-production`.

Required secrets/vars:

- `DEMO_SSH_HOST`
- `DEMO_SSH_USER`
- `DEMO_SSH_KEY`
- `DEMO_PUBLIC_URL=https://smart-class.org`

Optional private GHCR fallback:

- `GHCR_READ_USER`
- `GHCR_READ_TOKEN`

Local operator SSH aliases such as `ssh Capstone-Service` are for manual operations only. GitHub Actions uses explicit host/user/key secrets.
