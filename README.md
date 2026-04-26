# Smart Class Service

`Service`는 Smart Class 데모 스택의 표준 실행/배포 레포지토리입니다. Docker Compose, nginx 런타임 설정, Service 릴리스 매니페스트, 데모 배포 스크립트를 이 레포에서 관리합니다. CodexKit도 런타임 원본을 직접 들고 있지 않고 이 레포를 사용해야 합니다.

## Modes

### Quick setup: 전체 레포 클론 없이 공개 이미지로 바로 실행

Linux에 Docker와 Docker Compose가 설치되어 있다면, `Backend`, `Front`, `PresenceService`, `DB` 레포를 모두 클론하지 않아도 바로 Smart Class 스택을 실행할 수 있습니다. 아래 명령은 이 레포에서 실행에 필요한 `.env`, Compose 파일, nginx 설정만 내려받고, GitHub Packages/GHCR에 공개된 이미지를 사용해 서비스를 띄웁니다.

```bash
mkdir -p smart-class-service/nginx
cd smart-class-service

# 실행에 필요한 최소 파일만 다운로드합니다.
curl -fsSLo .env https://raw.githubusercontent.com/ChosunUniv2026Capstone/Service/main/.env.example
curl -fsSLo compose.yml https://raw.githubusercontent.com/ChosunUniv2026Capstone/Service/main/compose.yml
curl -fsSLo compose.image.yml https://raw.githubusercontent.com/ChosunUniv2026Capstone/Service/main/compose.image.yml
curl -fsSLo nginx/local.conf https://raw.githubusercontent.com/ChosunUniv2026Capstone/Service/main/nginx/local.conf

# plain `docker compose up`이 image mode로 동작하도록 설정합니다.
# Linux Compose의 COMPOSE_FILE 구분자는 `:`입니다.
printf '\nCOMPOSE_FILE=compose.yml:compose.image.yml\n' >> .env

# 공개 GHCR 이미지를 pull하고 서비스를 시작합니다.
docker compose up -d --pull always
curl -fsS http://localhost:3100/health
```

정상이라면 아래 응답이 반환됩니다.

```json
{"status":"ok"}
```

컨테이너가 모두 올라온 뒤 브라우저에서 `http://localhost:3100`을 열면 됩니다. 종료하면서 데모 데이터 볼륨까지 삭제하려면 다음을 실행합니다.

```bash
docker compose down -v
```

#### `.env` 설정 방법

Quick setup은 `.env.example`을 `.env`로 내려받은 뒤 필요한 값만 덧붙이거나 수정하는 방식입니다. 가장 중요한 설정은 `COMPOSE_FILE=compose.yml:compose.image.yml`입니다. 이 값이 있어야 `docker compose up`만 실행해도 로컬 빌드가 아니라 공개 이미지 모드로 실행됩니다.

```bash
cat >> .env <<'EOF_ENV'

# Compose 프로젝트 이름입니다. 여러 스택을 동시에 띄울 때 충돌을 막기 위해 바꿀 수 있습니다.
COMPOSE_PROJECT_NAME=smart-class

# 호스트에서 열 포트입니다. 기본값은 3100입니다.
NGINX_PORT=3100

# image mode를 활성화합니다. Linux에서는 파일 구분자로 `:`를 사용합니다.
COMPOSE_FILE=compose.yml:compose.image.yml

# 로컬 테스트용 기본값입니다. 외부에 공개되는 환경에서는 반드시 바꾸세요.
JWT_SECRET=change-me-for-local-demo
EOF_ENV
```

특정 릴리스/버전을 고정해서 실행하고 싶다면 `.env`에 이미지 값을 추가합니다. 태그만 사용할 수도 있지만, 재현 가능한 데모나 운영 유사 환경에서는 digest까지 고정하는 방식을 권장합니다.

```bash
cat >> .env <<'EOF_ENV'

BACKEND_IMAGE=ghcr.io/chosununiv2026capstone/backend:v0.2.0@sha256:47de92dd133b996a9024120bee2d23b8bf3198090c88f39ddc47f9e19a024754
PRESENCE_SERVICE_IMAGE=ghcr.io/chosununiv2026capstone/presence-service:v0.2.0@sha256:e09dadd83acec809b8395eb933c3b7200e9624f1114fdd45c0012f6df7251f39
DB_IMAGE=ghcr.io/chosununiv2026capstone/db:v0.2.0@sha256:6e033c61d9265fad25ae39dae665d8b3540a8c12a57574fb8b40eaddb6c49f1a
FRONT_IMAGE=ghcr.io/chosununiv2026capstone/front:v0.2.1@sha256:3171d8a93dc5fbf846bb95a3117e8815265ee261cfe0d5ce9c8e96ab7d0039ce
EOF_ENV
```

`.env`를 수정한 뒤에는 다시 실행하면 됩니다.

```bash
docker compose up -d --pull always
curl -fsS http://localhost:3100/health
```

Quick setup에서 이미지 값을 따로 지정하지 않으면 `compose.image.yml`의 기본값인 공개 `edge` 태그를 사용합니다. 처음 시험 실행에는 편하지만, 특정 상태를 재현해야 하는 경우에는 위 예시처럼 release tag 또는 digest-pinned image ref를 `.env`에 명시하세요.

### Local source mode: 로컬 소스 빌드 실행

형제 디렉터리에 있는 각 서비스 레포를 빌드해서 로컬 nginx로 실행합니다.

```bash
cp .env.example .env
./scripts/up-local.sh
curl -fsS http://localhost:3100/health
```

Local mode는 다음 build context를 사용합니다.

- `../Backend`
- `../Front`
- `../PresenceService`
- `../DB`

### Image mode: 사전 빌드 이미지 실행

로컬 build context 없이 GHCR 이미지를 사용해 실행합니다.

```bash
export BACKEND_IMAGE=ghcr.io/chosununiv2026capstone/backend:sha-...
export FRONT_IMAGE=ghcr.io/chosununiv2026capstone/front:sha-...
export PRESENCE_SERVICE_IMAGE=ghcr.io/chosununiv2026capstone/presence-service:sha-...
export DB_IMAGE=ghcr.io/chosununiv2026capstone/db:sha-...
./scripts/up-image.sh -d
```

또는 `.env`에 같은 값을 저장해도 됩니다.

```bash
cat >> .env <<'EOF_ENV'
BACKEND_IMAGE=ghcr.io/chosununiv2026capstone/backend:sha-...
FRONT_IMAGE=ghcr.io/chosununiv2026capstone/front:sha-...
PRESENCE_SERVICE_IMAGE=ghcr.io/chosununiv2026capstone/presence-service:sha-...
DB_IMAGE=ghcr.io/chosununiv2026capstone/db:sha-...
EOF_ENV
./scripts/up-image.sh -d
```

### Demo deployment mode: 데모 서버 배포

데모 배포는 manifest-pinned Service release를 기준으로 합니다. 배포 스크립트는 `manifests/releases/vX.Y.Z.yml`을 읽어 `.env.release`를 렌더링하고, 이미지를 pull한 뒤 demo nginx 설정으로 Compose를 시작하고 `https://smart-class.org/health`를 확인합니다.

```bash
./scripts/deploy-demo.sh --service-version v0.1.0 --reset-demo-data false
```

매니페스트에 `components.db.resetRequired: true`가 있고 DB 이미지가 변경된 경우, `--reset-demo-data true`를 명시하지 않으면 `docker compose up` 전에 실패합니다. reset은 이 Service Compose 프로젝트의 DB 볼륨만 삭제합니다.

## Release manifests

Release Please 릴리스 PR 브랜치에서 merge 전에 매니페스트를 생성합니다.

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

매니페스트에는 `latest`를 사용하면 안 됩니다.

## GitHub Actions configuration

데모 배포는 GitHub environment `demo-production`을 사용합니다.

필수 secrets/vars:

- `DEMO_SSH_HOST`
- `DEMO_SSH_USER`
- `DEMO_SSH_KEY`
- `DEMO_PUBLIC_URL=https://smart-class.org`

Private GHCR fallback이 필요할 때만 사용하는 선택 값:

- `GHCR_READ_USER`
- `GHCR_READ_TOKEN`

`ssh Capstone-Service` 같은 로컬 운영자 SSH alias는 수동 작업용입니다. GitHub Actions에서는 명시적인 host/user/key secret을 사용합니다.
