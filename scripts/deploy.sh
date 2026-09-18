#!/usr/bin/env bash
# Deploys one app. Bound to that app's ssh key in ~/.ssh/authorized_keys via
# `restrict,command="deploy.sh <app>"`, so the workflow can only pass a tag.
set -euo pipefail

fail() { echo "deploy: $*" >&2; exit 1; }

APP="${1:-}"
TAG="${SSH_ORIGINAL_COMMAND:-}"

[[ "$APP" =~ ^[a-z][a-z0-9-]{0,31}$ ]] || fail "bad app name '$APP'"
[[ "$TAG" =~ ^sha-[0-9a-f]{7,40}$ ]] || fail "expected an image tag like sha-abc1234, got '$TAG'"

cd "$HOME/$APP" || fail "no ~/$APP"
[[ -f docker-compose.yml && -f .env ]] || fail "~/$APP needs docker-compose.yml and .env"

# Pull first so a bad tag leaves the running version and .env untouched.
IMAGE_TAG="$TAG" docker compose pull --quiet

{ grep -v '^IMAGE_TAG=' .env || true; printf 'IMAGE_TAG=%s\n' "$TAG"; } > .env.tmp
chmod 600 .env.tmp
mv .env.tmp .env

docker compose up -d --remove-orphans
docker image prune -af --filter "until=168h" >/dev/null
docker compose ps
