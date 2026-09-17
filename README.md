# vps-infra

Shared Docker network, Traefik reverse proxy with automatic HTTPS, and a
single Postgres 18 server for my VPS.

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

In the app's `docker-compose.yml`, join the shared network and opt in to
Traefik. Don't publish ports.

```yaml
services:
    app:
        networks: [vps]
        labels:
            - "traefik.enable=true"
            - "traefik.http.routers.app.rule=Host(`app.coji-dev.com`)"
            - "traefik.http.routers.app.entrypoints=websecure"
            - "traefik.http.routers.app.tls.certresolver=letsencrypt"

networks:
    vps:
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

## Notes

- **Firewall:** Docker published ports bypass ufw. `daemon.json` sets
  `"ip": "127.0.0.1"` so a publish without an explicit host address binds
  to localhost. Only Traefik publishes `0.0.0.0` and `[::]` on 80/443. Postgres
  has no `ports:`; reach it via `docker compose exec postgres psql` or an SSH
  tunnel. Dashboard and API are disabled.
- **Certificates:** Let's Encrypt, TLS-ALPN-01 on 443, auto-renewed. Stored in
  the `letsencrypt` volume; losing it just reissues.
- **Hardening:** Traefik talks to Docker through `docker-socket-proxy`
  (read-only, containers only, isolated network), runs read-only with all
  capabilities dropped except `NET_BIND_SERVICE`. `traefik/dynamic.yml`
  adds HSTS, nosniff and a referrer policy to every response.
