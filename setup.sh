#!/usr/bin/env bash
# First-time setup of the local Mattermost: the demo team, one room per site, the study people and the bot.
#   ./setup.sh                          the team in bot.yaml (huma-demo)
#   ./setup.sh acme "Acme demo"         another team, one per customer, so no customer sees another's demo;
#                                       the same people and the same bot are in each
# Safe to run again: anything that already exists is left as it is.
# Rooms follow Eliot's rules: one room per site (CRA, site staff and sponsor), no all-hands room, no one in a room
# without a study role. The bot's token goes into .env as MM_BOT_TOKEN.
set -euo pipefail
cd "$(dirname "$0")"
set -a; . ./.env; set +a

curl -fsS http://localhost:8065/api/v4/system/ping >/dev/null 2>&1 || { echo "Mattermost is not up: run ./up.sh first" >&2; exit 1; }
TEAM=${1:-huma-demo}
TEAM_NAME=${2:-${1:-Huma demo}}
[[ "$TEAM" =~ ^[a-z0-9][a-z0-9-]{1,63}$ ]] || { echo "team name: lowercase letters, digits and -, like acme-demo" >&2; exit 1; }
mm() { podman exec cormon-chat-app mmctl --local "$@"; }
quiet() { "$@" >/dev/null 2>&1 || true; }

quiet mm team create --name "$TEAM" --display-name "$TEAM_NAME" --private
# "is typing" shows for 1 second after each signal (not 5), so it goes away as soon as the bot has answered
quiet mm config set ServiceSettings.TimeBetweenUserTypingUpdatesMilliseconds 1000

# username | first name | last name | study role (for the bot's people list)
# The study roles have no names: made-up names confused people, so they go by their sign-in name (crc, pi, ...)
PEOPLE="
admin|Demo|Admin|admin
crc|||crc
pi|||pi
cra|||cra
sponsor|||clinops_lead
medmonitor|||medical_monitor
eliot|Eliot|Levitt|tester
peter|Peter|Brown|tester
john|John|Rohit|tester
"
# The team in bot.yaml uses the plain names. Every other team has its own people (crc-acme, cra-acme, ...):
# Mattermost shows a person's 1-on-1 chats in every team they are in, so shared people would let one customer
# see another's chats. Usernames are at most 22 letters, so the customer part is cut to 11 (as the bot does).
DEFAULT=$(sed -n 's/^team: *//p' bot.yaml)
TAG=""
if [ "$TEAM" != "$DEFAULT" ]; then S=${TEAM%-demo}; S=${S:0:11}; TAG="-${S%-}"; fi
STAFF=""
while IFS='|' read -r user first last role; do
  [ -z "$user" ] && continue
  if [ "$role" = admin ]; then   # one admin for the whole server
    quiet mm user create --username "$user" --email "$user@demo.local" --password "$DEMO_PASSWORD" \
      --firstname "$first" --lastname "$last" --system-admin
    quiet mm team users add "$TEAM" "$user"
    continue
  fi
  [ -n "$TAG" ] && { quiet mm team users remove "$TEAM" "$user"; [ -n "$first" ] && last="$last ($TEAM_NAME)"; }
  quiet mm user create --username "$user$TAG" --email "$user$TAG@demo.local" --password "$DEMO_PASSWORD" \
    --firstname "$first" --lastname "$last"
  quiet mm user verify "$user$TAG"
  quiet mm team users add "$TEAM" "$user$TAG"
  STAFF="$STAFF $user$TAG"
done <<< "$PEOPLE"

# site-01: the CRA, the site staff and the sponsor; the medical monitor joins for safety
quiet mm channel create --team "$TEAM" --name site-01-mgh --display-name "Site 01 (MGH)" --private
mm channel users add "$TEAM:site-01-mgh" $STAFF >/dev/null 2>&1 || true

# mmctl cannot make a bot in local mode, so the bot starts as a user and is converted
# (servers set up before the rename: the bot "cormon" is renamed, keeping its token and chats)
quiet mm bot update cormon --username huma-bot --display-name "Huma Bot"
BOT=huma-bot
quiet mm user create --username "$BOT" --email huma-bot@demo.local --password "$DEMO_PASSWORD" --firstname Huma --lastname Bot
quiet mm user convert "$BOT" --bot
quiet mm bot update "$BOT" --display-name "Huma Bot"
quiet mm team users add "$TEAM" "$BOT"
quiet mm channel users add "$TEAM:site-01-mgh" "$BOT"
# Mattermost puts every team member in Town Square and Off-Topic: that is an all-hands room, so the bot leaves
# them and Off-Topic is archived
quiet mm channel users remove "$TEAM:town-square" "$BOT"
quiet mm channel users remove "$TEAM:off-topic" "$BOT"
quiet mm channel archive "$TEAM:off-topic"

if ! grep -q '^MM_BOT_TOKEN=' .env; then
  token=$(mm token generate "$BOT" "huma bot" --json | sed -n 's/.*"token": *"\([^"]*\)".*/\1/p')
  [ -n "$token" ] || { echo "could not make the bot token" >&2; exit 1; }
  echo "MM_BOT_TOKEN=$token" >> .env
  echo "MM_URL=http://localhost:8065" >> .env
fi

set -a; . ./.env; set +a
./welcome.sh "$TEAM" || echo "Could not pin the welcome guide; run ./welcome.sh $TEAM later" >&2

echo "Done: team $TEAM. Open http://localhost:8065 and sign in as any of:$STAFF (or admin)"
echo "Run the bot on this team with: cormon chat-demo --team $TEAM"
echo "The password for all of them is DEMO_PASSWORD in .env. The bot's token is MM_BOT_TOKEN in .env."
