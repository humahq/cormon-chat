#!/usr/bin/env bash
# Double-click to start a demo: Podman, then one pod with Mattermost, patient memory and the bot, and the demo page.
# Close this window to stop the bot.
# Run ./install.sh once first. The bot's folder is BOT_DIR in .env (install.sh sets it).
cd "$(dirname "$0")" || exit 1
CHAT=$PWD
[ -f .env ] && { set -a; . ./.env; set +a; }
# the bot sits next to this folder (<root>/OpenBook/correspondence-monitor); .env remembers where, but if the
# folders were moved since, look next to this one and fix .env
if [ ! -d "${BOT_DIR:-}" ] && [ -d "$CHAT/../correspondence-monitor" ]; then
  BOT_DIR=$(cd "$CHAT/../correspondence-monitor" && pwd)
  if [ -f .env ]; then
    { grep -v '^BOT_DIR=' .env || true; echo "BOT_DIR=$BOT_DIR"; } > .env.new && mv .env.new .env && chmod 600 .env
  fi
fi
BOT_DIR=${BOT_DIR:-"$CHAT/../correspondence-monitor"}
[ -x "$BOT_DIR/.venv/bin/cormon" ] || { echo "The bot is not set up yet: run ./install.sh in $CHAT first"; read -r; exit 1; }

if [ "$(uname -s)" = Darwin ] && [ -n "${PODMAN_MACHINE:-}" ]; then
  # a Mac runs one Podman machine at a time
  OTHER=$(podman machine list --format '{{.Name}}|{{.Running}}' | tr -d '*' |
          awk -F'|' -v m="$PODMAN_MACHINE" '$2 == "true" && $1 != m {print $1}')
  if [ -n "$OTHER" ]; then
    read -r -p "Another Podman machine, $OTHER, is running; the demo needs its own. Stop $OTHER now (its data is kept)? [Y/n] " a
    [[ "$a" =~ ^[Nn] ]] && exit 1
    podman machine stop "$OTHER" >/dev/null
  fi
fi
if [ "$(uname -s)" = Darwin ]; then
  M=(${PODMAN_MACHINE:+"$PODMAN_MACHINE"})   # none: Podman's default machine
  state() { podman machine inspect "${M[@]}" --format '{{.State}}' 2>/dev/null; }
  # the first start after the laptop shut down without stopping it can fail; the second works
  for _ in 1 2; do
    [ "$(state)" = running ] && break
    podman machine start "${M[@]}" >/dev/null 2>&1 || sleep 3
  done
  [ "$(state)" = running ] ||
    { echo "Podman's machine did not start. Run: podman machine start ${PODMAN_MACHINE:-}"
      echo "and send John what it says. Press Return to close."; read -r; exit 1; }
fi
./up.sh || { echo "Mattermost did not start. Press Return to close."; read -r; exit 1; }
grep -q '^MM_BOT_TOKEN=' .env || ./setup.sh
./brand.sh || echo "The OpenBook look was not put on; the demo works without it."

# patient memory (Hindsight) in Podman, made the first time by the bot's deploy/hindsight.sh
memory_up() { curl -sf http://127.0.0.1:8888/health >/dev/null; }
if ! memory_up; then
  podman start hindsight >/dev/null 2>&1 && for _ in $(seq 24); do memory_up && break; sleep 5; done
  memory_up || (cd "$BOT_DIR" && CONTAINER=podman POD=cormon-chat ./deploy/hindsight.sh) ||
    echo "Patient memory did not start; the demo runs without it."
fi

cat <<EOF

  Sign in at http://localhost:8065 as crc, pi, cra, sponsor, medmonitor, eliot, peter or john
  Password:  ${DEMO_PASSWORD:-}
  Admin pages: http://localhost:8091/admin   (users operator, peter or eliot; one password, ADMIN_PASSWORD in $CHAT/.env)
  Demo teams: http://localhost:8090      Keep this window open; closing it stops the bot.

EOF
OPEN=$(command -v open || command -v xdg-open || echo true)
(sleep 15; "$OPEN" http://localhost:8090; "$OPEN" http://localhost:8065) >/dev/null 2>&1 &
# the bot itself runs in the pod (CORMON_LOCAL_POD); this window runs the demo page and shows the bot's log.
# OPENBOOK_BOT=host runs the bot as a plain process on the laptop instead.
export CORMON_LOCAL_POD=1
cd "$BOT_DIR" && exec .venv/bin/cormon chat-demo --chat "$CHAT"
