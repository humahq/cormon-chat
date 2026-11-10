#!/usr/bin/env bash
# The one file a new person needs on a Mac. It installs the tools, signs in to GitHub, downloads the demo into
# ~/OpenBook, runs install.sh and starts the demo. Safe to run again. It stops only for what no script can do:
# the Mac password (only if Homebrew is missing), Authorize on GitHub's web page, and the OpenAI key.
set -euo pipefail
DIR="$HOME/OpenBook"   # not in Documents or Desktop, which often sync to iCloud

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }
fail() { printf '\n\033[31m%s\033[0m\n' "$*" >&2; echo "Press Return to close."; read -r || true; exit 1; }
trap 'fail "The setup stopped. Run it again; if it stops at the same place, send John a screenshot."' ERR

[ "$(uname -s)" = Darwin ] || fail "This is for a Mac. On Linux, follow the README in humahq/cormon-chat."
say "Setting up OpenBook (about 20 minutes the first time). Keep this window open."

for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && eval "$("$b" shellenv)" && break; done
if ! command -v brew >/dev/null; then
  say "Installing Homebrew. Type your Mac password when it asks (nothing shows as you type)."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && eval "$("$b" shellenv)" && break; done
  grep -q 'brew shellenv' "$HOME/.zprofile" 2>/dev/null || echo "eval \"\$($(command -v brew) shellenv)\"" >> "$HOME/.zprofile"
fi

command -v gh >/dev/null || brew install -q gh
if ! gh auth status --hostname github.com >/dev/null 2>&1; then
  say "Signing in to GitHub: your browser opens. Sign in, paste the code (it is already copied: Cmd+V), click Authorize."
  gh auth login --hostname github.com --git-protocol https --web --skip-ssh-key --clipboard < /dev/null ||
    gh auth login --hostname github.com --git-protocol https --web --skip-ssh-key --clipboard
fi
gh auth setup-git --hostname github.com

mkdir -p "$DIR"
if [ -d "$DIR/cormon-chat/.git" ]; then
  git -C "$DIR/cormon-chat" pull -q --ff-only || echo "Could not get the newest version; using the one here."
else
  gh repo clone humahq/cormon-chat "$DIR/cormon-chat" -- -q ||
    fail "Could not download. Check that you can open https://github.com/humahq/cormon-chat, then run it again."
fi

trap - ERR
OPENBOOK_AUTO=1 "$DIR/cormon-chat/install.sh" || fail "The setup stopped. Run it again; if it stops at the same place, send John a screenshot."
say "Starting the demo. Your browser opens in a minute. Keep this window open; closing it stops the bot."
exec "$DIR/cormon-chat/Start demo.command"
