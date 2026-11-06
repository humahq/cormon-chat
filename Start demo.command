#!/usr/bin/env bash
# Double-click to start a demo: Podman, Mattermost, the bot and the demo page. Close this window to stop the bot.
# The bot's folder is BOT_DIR in .env (default: ~/Documents/clinical trial).
cd "$(dirname "$0")"
CHAT=$PWD
[ -f .env ] && { set -a; . ./.env; set +a; }
BOT_DIR=${BOT_DIR:-"$HOME/Documents/clinical trial"}
[ -x "$BOT_DIR/.venv/bin/cormon" ] || { echo "The bot is not in $BOT_DIR: set BOT_DIR in $CHAT/.env"; read -r; exit 1; }

podman machine start >/dev/null 2>&1 || true
./up.sh || { echo "Mattermost did not start. Press Return to close."; read -r; exit 1; }
grep -q '^MM_BOT_TOKEN=' .env || ./setup.sh
./brand.sh || echo "The OpenBook look was not put on; the demo works without it."

# patient memory (Hindsight) in Podman, made the first time by the bot's deploy/hindsight.sh
memory_up() { curl -sf http://127.0.0.1:8888/health >/dev/null; }
if ! memory_up; then
  podman start hindsight >/dev/null 2>&1 && for _ in $(seq 24); do memory_up && break; sleep 5; done
  memory_up || (cd "$BOT_DIR" && CONTAINER=podman ./deploy/hindsight.sh) ||
    echo "Patient memory did not start; the demo runs without it."
fi

(sleep 15; open http://localhost:8090; open http://localhost:8065) &
cd "$BOT_DIR" && exec .venv/bin/cormon chat-demo --chat "$CHAT"
