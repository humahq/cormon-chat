#!/usr/bin/env bash
# Starts a local Mattermost (and its Postgres) in one Podman pod at http://localhost:8065.
# Data is kept in Podman volumes, so a restart keeps users and messages; ./down.sh --wipe removes them.
set -euo pipefail
cd "$(dirname "$0")"

# Mattermost only publishes amd64 images; on an M-series Mac Podman runs them through Rosetta
MM_IMAGE="${MM_IMAGE:-docker.io/mattermost/mattermost-team-edition:12.1}"
PG_IMAGE="${PG_IMAGE:-docker.io/library/postgres:16-alpine}"
POD=cormon-chat

# The passwords are added to .env if they are missing, also when .env was made first by hand (for BOT_DIR)
umask 077
touch .env
[ -z "$(tail -c1 .env)" ] || echo >> .env
grep -q '^DB_PASSWORD=.' .env || { echo "DB_PASSWORD=$(openssl rand -hex 16)" >> .env; echo "added the database password to .env"; }
grep -q '^DEMO_PASSWORD=.' .env ||
  { echo "DEMO_PASSWORD=Demo-$(openssl rand -hex 6)!" >> .env; echo "added the demo users' password to .env (never commit it)"; }
set -a; . ./.env; set +a

podman pod exists "$POD" || podman pod create --name "$POD" -p 127.0.0.1:8065:8065 >/dev/null
if ! podman container exists cormon-chat-db; then
  podman run -d --pod "$POD" --name cormon-chat-db --restart unless-stopped \
    -e POSTGRES_USER=mmuser -e POSTGRES_PASSWORD="$DB_PASSWORD" -e POSTGRES_DB=mattermost \
    -v cormon-chat-db:/var/lib/postgresql/data "$PG_IMAGE" >/dev/null
fi
if ! podman container exists cormon-chat-app; then
  podman run -d --pod "$POD" --name cormon-chat-app --restart unless-stopped --platform linux/amd64 \
    -e MM_SQLSETTINGS_DRIVERNAME=postgres \
    -e "MM_SQLSETTINGS_DATASOURCE=postgres://mmuser:${DB_PASSWORD}@localhost:5432/mattermost?sslmode=disable&connect_timeout=10" \
    -e MM_SERVICESETTINGS_SITEURL=http://localhost:8065 \
    -e MM_SERVICESETTINGS_ENABLELOCALMODE=true \
    -e MM_SERVICESETTINGS_ENABLEBOTACCOUNTCREATION=true \
    -e MM_SERVICESETTINGS_ENABLEUSERACCESSTOKENS=true \
    -e MM_TEAMSETTINGS_ENABLEOPENSERVER=false \
    -e MM_EMAILSETTINGS_SENDEMAILNOTIFICATIONS=false \
    -e MM_LOGSETTINGS_CONSOLELEVEL=WARN \
    -v cormon-chat-data:/mattermost/data -v cormon-chat-config:/mattermost/config \
    "$MM_IMAGE" >/dev/null
fi
podman pod start "$POD" >/dev/null

printf "waiting for Mattermost"
for _ in $(seq 1 90); do
  if curl -fsS http://localhost:8065/api/v4/system/ping >/dev/null 2>&1; then
    echo; echo "Mattermost is up: http://localhost:8065 (first time: run ./setup.sh)"
    exit 0
  fi
  printf "."; sleep 2
done
echo; echo "Mattermost did not answer in 3 minutes; see: podman logs cormon-chat-app" >&2
exit 1
