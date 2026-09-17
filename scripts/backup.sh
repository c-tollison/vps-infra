#!/usr/bin/env sh
# Dump all databases to backups/, keep last 3.
# Usage: scripts/backup.sh   (schedule with scripts/install-cron.sh)
set -eu
cd "$(dirname "$0")/.."
set -a; . ./.env; set +a
mkdir -p backups
docker compose exec -T postgres pg_dumpall -U "$POSTGRES_USER" | gzip > "backups/$(date +%F).sql.gz"
ls -t backups/*.sql.gz | tail -n +4 | xargs -r rm --
