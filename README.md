# vps-infra

Shared Docker network and a single Postgres 18 server for my VPS.

## Setup

Requires Docker installed and ensure ssh user is apart of the docker group

```sh
git clone https://github.com/c-tollison/vps-infra.git && cd vps-infra
sudo scripts/install-daemon.sh
cp .env.example .env
mkdir -p secrets
openssl rand -base64 32 > secrets/postgres_password
chmod 600 secrets/postgres_password
docker compose up -d
scripts/backup.sh                     # first backup for sanity check
scripts/install-cron.sh               # then weekly, Sunday 00:00
```

## Adding an app

One role + one database per app. The superuser in `.env` is for admin

```sh
scripts/create-db.sh myapp
```

In the app's `docker-compose.yml`:

```yaml
services:
    app:
        networks: [vps]

networks:
    vps:
        external: true
```

Start this stack first so the network exists.

## Notes

- **Firewall:** Docker published ports bypass ufw. `daemon.json` sets
  `"ip": "127.0.0.1"` so a publish without an explicit host address binds
  to localhost instead of `0.0.0.0`. Only a reverse proxy should publish
  `0.0.0.0:80/443`, and it must say so explicitly. Postgres has
  no `ports:` at all; reach it via `docker compose exec postgres psql` or an
  SSH tunnel.
