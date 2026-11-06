#!/usr/bin/env bash
# Sets up the OpenBook demo on a Mac or a Linux laptop, in one go:
#   git clone https://github.com/humahq/cormon-chat.git && cd cormon-chat && ./install.sh
# It installs the tools, gets the bot's code next to this folder, asks for the OpenAI key (and checks it), makes
# the passwords, and starts Mattermost, the demo people and the bot's look. Safe to run again: what is already
# there is kept, and it only asks what it does not know yet.
set -euo pipefail
cd "$(dirname "$0")"
CHAT=$PWD
OS=$(uname -s)

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }
fail() { printf '\n\033[31m%s\033[0m\n' "$*" >&2; exit 1; }
yes_no() { local a; read -r -p "$1 [Y/n] " a || true; [[ ! "$a" =~ ^[Nn] ]]; }
getenv() { [ -f "$2" ] && sed -n "s/^$1=//p" "$2" | tail -1 | sed "s/^[\"']//; s/[\"']\$//"; true; }
setenv() {   # setenv FILE KEY VALUE: one KEY= line in FILE, with this value
  local f=$1 k=$2 v=$3
  [[ "$v" =~ ^[A-Za-z0-9_./:@+-]*$ ]] || v="'$v'"   # .env files are read by the shell too; values have no '
  (umask 077; touch "$f")
  { grep -v "^$k=" "$f" || true; printf '%s=%s\n' "$k" "$v"; } > "$f.new"
  mv "$f.new" "$f"; chmod 600 "$f"
}

# ---------------------------------------------------------------- 1. the tools
say "1/6  Checking the tools (Podman, uv, git, Python)"
if [ "$OS" = Darwin ]; then
  if ! command -v brew >/dev/null; then
    yes_no "Homebrew (the Mac's installer for tools) is missing. Install it now?" || fail "Homebrew is needed: https://brew.sh"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
  fi
  need=()
  for t in podman uv git python3; do command -v "$t" >/dev/null || need+=("$t"); done
  [ ${#need[@]} -eq 0 ] || brew install "${need[@]/python3/python}"
else
  need=()
  for t in podman git python3 curl; do command -v "$t" >/dev/null || need+=("$t"); done
  if [ ${#need[@]} -gt 0 ]; then
    echo "Missing: ${need[*]}. They need sudo (your laptop password)."
    if command -v apt-get >/dev/null; then sudo apt-get update -qq && sudo apt-get install -y "${need[@]}"
    elif command -v dnf >/dev/null; then sudo dnf install -y "${need[@]}"
    else fail "Please install ${need[*]} with your system's installer, then run ./install.sh again"; fi
  fi
  if ! command -v uv >/dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
  fi
fi
echo "ok"

# ---------------------------------------------------------------- 2. Podman's machine (Mac only)
# On a Mac, Podman runs Linux in a small machine of its own. The demo has its own, named openbook, so it does not
# mix with other Podman machines on the laptop. A laptop set up before this script keeps the machine it has.
if [ "$OS" = Darwin ]; then
  say "2/6  Podman's machine"
  MACHINE=$(getenv PODMAN_MACHINE .env)
  if [ -z "$MACHINE" ] && ! grep -q '^MM_BOT_TOKEN=' .env 2>/dev/null; then
    MACHINE=openbook
    setenv .env PODMAN_MACHINE "$MACHINE"
    setenv .env CONTAINER_CONNECTION "$MACHINE"
  fi
  if [ -n "$MACHINE" ]; then
    podman machine inspect "$MACHINE" >/dev/null 2>&1 ||
      podman machine init "$MACHINE" --cpus 4 --memory 6144 --disk-size 40
    podman machine start "$MACHINE" 2>&1 | grep -v -i "helper\|docker\|socket\|API forwarding" || true
    export CONTAINER_CONNECTION=$MACHINE
  else
    podman machine start >/dev/null 2>&1 || true
  fi
  echo "ok (machine: ${MACHINE:-default})"
else
  say "2/6  Podman (Linux needs no machine)"
  echo "ok"
fi

# ---------------------------------------------------------------- 3. the bot's code
say "3/6  The bot's code"
BOT_DIR=$(getenv BOT_DIR .env)
for d in "$BOT_DIR" "$CHAT/../correspondence-monitor" "$CHAT/../clinical trial" \
         "$HOME/Documents/correspondence-monitor" "$HOME/Documents/clinical trial"; do
  if [ -n "$d" ] && [ -f "$d/pyproject.toml" ] && [ -d "$d/cormon" ]; then BOT_DIR=$(cd "$d" && pwd); break; fi
  BOT_DIR=""
done
if [ -z "$BOT_DIR" ]; then
  BOT_DIR=$(cd "$CHAT/.." && pwd)/correspondence-monitor
  echo "Downloading it to $BOT_DIR"
  git clone https://github.com/humahq/correspondence-monitor.git "$BOT_DIR" ||
    fail "Could not download the bot. Ask John to give your GitHub account access to humahq/correspondence-monitor."
fi
setenv .env BOT_DIR "$BOT_DIR"
(cd "$BOT_DIR" && env -u VIRTUAL_ENV uv sync -q)
echo "ok ($BOT_DIR)"

# ---------------------------------------------------------------- 4. the OpenAI key
say "4/6  The OpenAI key"
key_works() {
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $1" https://api.openai.com/v1/models)
  [ "$code" = 200 ]
}
KEY=$(getenv OPENAI_API_KEY "$BOT_DIR/.env")
CHANGED=""
if [ -n "$KEY" ] && key_works "$KEY"; then
  echo "The key already saved works."
else
  [ -n "$KEY" ] && echo "The key saved in $BOT_DIR/.env does not work."
  for _ in 1 2 3; do
    read -r -s -p "Paste your OpenAI API key (it starts with sk-; nothing shows as you paste) and press Return: " KEY
    echo
    KEY=$(printf '%s' "$KEY" | tr -d '[:space:]')
    if key_works "$KEY"; then CHANGED=1; break; fi
    echo "OpenAI did not accept that key. Check you copied all of it, with no spaces."
    KEY=""
  done
  [ -n "$KEY" ] || fail "No working key. Make one at https://platform.openai.com/api-keys and run ./install.sh again."
  setenv "$BOT_DIR/.env" OPENAI_API_KEY "$KEY"
  echo "Saved (only in $BOT_DIR/.env, which is never put on GitHub)."
fi

# ---------------------------------------------------------------- 5. the passwords
say "5/6  The passwords"
grep -q '^DB_PASSWORD=.' .env 2>/dev/null || setenv .env DB_PASSWORD "$(openssl rand -hex 16)"
echo "The database password is made for you; you never need to type it."
DEMO=$(getenv DEMO_PASSWORD .env)
if [ -z "$DEMO" ]; then
  while true; do
    read -r -p "Pick a password for signing in to the demo (8 or more letters), or press Return for a random one: " DEMO
    [ -z "$DEMO" ] && DEMO="Demo-$(openssl rand -hex 6)!"
    if [ ${#DEMO} -lt 8 ]; then echo "That is shorter than 8 letters."
    elif [[ "$DEMO" == *[\"\'\ \\]* ]]; then echo "Please leave out quote marks, spaces and \\."
    else break; fi
  done
  setenv .env DEMO_PASSWORD "$DEMO"
fi
echo "The demo password is kept in $CHAT/.env."

# ---------------------------------------------------------------- 6. start it all once
say "6/6  Starting Mattermost and making the demo (the first time takes about 5 minutes)"
set -a; . ./.env; set +a
./up.sh
if grep -q '^MM_BOT_TOKEN=' .env; then
  ./brand.sh || echo "The OpenBook look was not put on; the demo works without it."
else
  ./setup.sh   # it puts on the OpenBook look too
fi
# patient memory (Hindsight) reads the key when it is made, so a new key means making it again (its data is kept)
if curl -sf http://127.0.0.1:8888/health >/dev/null && [ -z "$CHANGED" ]; then
  echo "Patient memory is running."
elif podman container exists hindsight 2>/dev/null && [ -z "$CHANGED" ]; then
  podman start hindsight >/dev/null && echo "Patient memory started."
elif curl -sf http://127.0.0.1:8888/health >/dev/null && ! podman container exists hindsight 2>/dev/null; then
  echo "Patient memory runs outside Podman here; if it uses an old OpenAI key, update it there."
else
  echo "Starting patient memory (the first time downloads about 2 GB)"
  (cd "$BOT_DIR" && CONTAINER=podman ./deploy/hindsight.sh >/dev/null) ||
    echo "Patient memory did not start; the demo runs without it. \"Start demo\" tries again."
fi

DEMO=$(getenv DEMO_PASSWORD .env)
cat <<EOF

All set.

  Start the demo:  double-click "Start demo.command" in $CHAT
                   (on Linux: ./"Start demo.command" in a terminal)
  Mattermost:      http://localhost:8065   sign in as crc, pi, cra, sponsor, medmonitor, eliot, peter or john
  Password:        $DEMO
  Demo teams:      http://localhost:8090   (while the demo runs)
EOF
