#!/usr/bin/env bash
# Stops the local Mattermost. --wipe also deletes its users, rooms and messages (the Podman volumes).
set -euo pipefail
cd "$(dirname "$0")"
[ -f .env ] && { set -a; . ./.env; set +a; }
POD=cormon-chat
if [ "${1:-}" = "--wipe" ]; then
  podman pod rm -f "$POD" >/dev/null 2>&1 || true
  podman volume rm -f cormon-chat-db cormon-chat-data cormon-chat-config >/dev/null 2>&1 || true
  [ -f .env ] && { grep -v '^MM_BOT_TOKEN=\|^MM_URL=' .env > .env.new || true; mv .env.new .env; chmod 600 .env; }
  echo "removed the pod and its data"
else
  podman pod stop "$POD" >/dev/null && echo "stopped (data kept; ./up.sh starts it again)"
fi
