#!/usr/bin/env sh
# Create an app database + owner role with a random password.
# Usage: scripts/create-db.sh <name>
set -eu
cd "$(dirname "$0")/.."
set -a; . ./.env; set +a
NAME="$1"
PASS=$(openssl rand -base64 24 | tr -d '/+=')
docker compose exec -T postgres psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" >/dev/null <<SQL
CREATE ROLE "$NAME" LOGIN PASSWORD '$PASS';
CREATE DATABASE "$NAME" OWNER "$NAME";
REVOKE ALL ON DATABASE "$NAME" FROM PUBLIC;
SQL
echo "postgres://$NAME:$PASS@postgres:5432/$NAME"
