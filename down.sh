#!/usr/bin/env bash
# Stops the local Mattermost. --wipe also deletes its users, rooms and messages (the Podman volumes).
set -euo pipefail
POD=cormon-chat
if [ "${1:-}" = "--wipe" ]; then
  podman pod rm -f "$POD" >/dev/null 2>&1 || true
  podman volume rm -f cormon-chat-db cormon-chat-data cormon-chat-config >/dev/null 2>&1 || true
  sed -i '' '/^MM_BOT_TOKEN=/d;/^MM_URL=/d' "$(dirname "$0")/.env" 2>/dev/null || true
  echo "removed the pod and its data"
else
  podman pod stop "$POD" >/dev/null && echo "stopped (data kept; ./up.sh starts it again)"
fi
