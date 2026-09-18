# vps-infra

Shared Docker networks, Traefik reverse proxy with automatic HTTPS, a single
Postgres 18 server, and the deploy script GitHub Actions calls, for my VPS.

## Setup

Requires Docker installed and ensure ssh user is apart of the docker group.
DNS: `A` and `AAAA` records for `*.coji-dev.com` point at the VPS.

```sh
git clone https://github.com/c-tollison/vps-infra.git && cd vps-infra
sudo scripts/install-daemon.sh
sudo ufw allow 80/tcp && sudo ufw allow 443/tcp
cp .env.example .env                  # set ACME_EMAIL
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

In the app's `docker-compose.yml`, join `vps` for anything Traefik routes to
and `db` for anything that talks to Postgres. A static web container joins
`vps` only, so it cannot reach the database. Don't publish ports.

```yaml
services:
    api:
        networks: [vps, db]
        labels:
            - "traefik.enable=true"
            - "traefik.http.routers.app.rule=Host(`app.coji-dev.com`)"
            - "traefik.http.routers.app.entrypoints=websecure"
            - "traefik.http.routers.app.tls.certresolver=letsencrypt"

networks:
    vps:
        external: true
    db:
        external: true
```

Start this stack first. Router names must be unique across apps. For a UI
and API on one host, give the API router
`` Host(`app.coji-dev.com`) && PathPrefix(`/api`) ``; the longer rule wins.
Redirect, TLS and HSTS are global. CSP and Permissions-Policy are per app:
`traefik.http.middlewares.<name>.headers.customresponseheaders.<Header>=...`
plus `traefik.http.routers.<router>.middlewares=<name>`.

To verify, run `traefik/whoami` with the labels above on a test subdomain,
`curl -I http://…` should 308 and `curl https://…` should return a valid cert,
then remove it.

## Deploys

Each app's GitHub workflow builds images, pushes them to GHCR, then runs
`ssh vps sha-<commit>`. The ssh key it uses is locked to `scripts/deploy.sh`
in `~/.ssh/authorized_keys`:

```
restrict,command="/home/<user>/vps-infra/scripts/deploy.sh <app>" ssh-ed25519 AAAA... github-actions-<app>
```

`command=` makes ssh run the script instead of whatever the workflow asked
for; the request lands in `SSH_ORIGINAL_COMMAND`. `deploy.sh` accepts only a
`sha-<hex>` tag, then in `~/<app>/` pulls that tag, writes it to `.env` as
`IMAGE_TAG`, and runs `docker compose up -d`. A stolen key can deploy a tag
of its own app and nothing else.

Per app: one key, one `authorized_keys` line with the app's name, one
`~/<app>/` holding its `docker-compose.yml` and `.env`. The app's compose
file reads `${IMAGE_TAG}` for its images. To roll back, set `IMAGE_TAG` to
an older tag and `docker compose up -d`.

## Notes

- **Networks:** `vps` is Traefik and the containers it routes to. `db` is
  Postgres and the containers that need it; it is `internal`, so nothing on
  it alone can reach the internet. `socket` is Traefik and the socket proxy.
- **Firewall:** Docker published ports bypass ufw. `daemon.json` sets
  `"ip": "127.0.0.1"` so a publish without an explicit host address binds
  to localhost. Only Traefik publishes `0.0.0.0` and `[::]` on 80/443. Postgres
  has no `ports:` and is only on `db`; reach it via
  `docker compose exec postgres psql`. Dashboard and API are disabled.
- **Certificates:** Let's Encrypt, TLS-ALPN-01 on 443, auto-renewed. Stored in
  the `letsencrypt` volume; losing it just reissues.
- **Hardening:** Traefik talks to Docker through `docker-socket-proxy`
  (read-only, containers only, isolated network), runs read-only with all
  capabilities dropped except `NET_BIND_SERVICE`. `traefik/dynamic.yml`
  adds HSTS, nosniff and a referrer policy to every response. Every service
  has `no-new-privileges` and a memory limit.
- **Backups:** `scripts/backup.sh` dumps every database with `pg_dumpall`
  and keeps the last 3 in `backups/`.
