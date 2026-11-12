#!/usr/bin/env bash
# The one file a new person needs on a Mac. It installs the tools, downloads the demo into <root>/OpenBook, runs
# install.sh and starts the demo. Safe to run again: what is installed is skipped, and cormon-chat and the bot are
# brought up to date with git when you have no unsaved changes in them. It stops only for what no script can do:
# the Mac password (only if Homebrew is missing) and the OpenAI key.
#
# Where it goes: <root>/OpenBook, holding cormon-chat and correspondence-monitor side by side. The root is, in order:
#   1. the first argument:      ./"Install OpenBook.command" ~/Huma
#   2. $OPENBOOK_ROOT:          OPENBOOK_ROOT=~/Huma ./"Install OpenBook.command"
#   3. OPENBOOK_ROOT in the .env of the checkout this file is in (so a re-run stays where it is)
#   4. what you type when it asks (Return = your home folder)
# Also runs as a one-liner (the root then comes from $OPENBOOK_ROOT, or the question):
#   curl -fsSL https://raw.githubusercontent.com/humahq/cormon-chat/main/Install%20OpenBook.command | bash
#   curl -fsSL .../Install%20OpenBook.command | OPENBOOK_ROOT=~/Huma bash
set -euo pipefail

# Everything is in main, which runs on the last line: bash has read the whole file before anything runs, so
# updating this very file with git in the middle of the run cannot confuse it.
main() {
  say() { printf '\n\033[1m%s\033[0m\n' "$*"; }
  fail() { printf '\n\033[31m%s\033[0m\n' "$*" >&2; echo "Press Return to close."; read -r < /dev/tty || true; exit 1; }
  trap 'fail "The setup stopped. Run it again; if it stops at the same place, send John a screenshot."' ERR

  [ "$(uname -s)" = Darwin ] || fail "This is for a Mac. On Linux, follow the README in humahq/cormon-chat."

  # git-pull only when that cannot lose anything, and say why when it does not (same function as in install.sh)
  update_repo() {   # update_repo DIR NAME
    local d=$1 n=$2 br behind
    [ -d "$d/.git" ] || return 0
    if [ -n "$(git -C "$d" status --porcelain 2>/dev/null)" ]; then
      echo "Not updating $n: it has changes of yours that are not saved in git."; return 0; fi
    br=$(git -C "$d" symbolic-ref -q --short HEAD) || { echo "Not updating $n: it is not on a branch."; return 0; }
    git -C "$d" rev-parse -q --verify '@{u}' >/dev/null 2>&1 ||
      { echo "Not updating $n: branch $br does not follow a branch on GitHub."; return 0; }
    GIT_TERMINAL_PROMPT=0 git -C "$d" fetch -q 2>/dev/null ||
      { echo "Could not reach GitHub to update $n; using the one here."; return 0; }
    behind=$(git -C "$d" rev-list --count 'HEAD..@{u}')
    if [ "$behind" = 0 ]; then echo "$n is up to date."
    elif git -C "$d" merge -q --ff-only '@{u}' >/dev/null 2>&1; then echo "$n updated ($behind new changes)."
    else echo "Not updating $n: your branch $br and GitHub both have new work. Update it by hand."; fi
    return 0
  }

  # ---- where this file lives, if it is a real file in a checkout (not piped from curl)
  local HERE=""
  if [ -f "${BASH_SOURCE[0]:-}" ] && [ -f "$(dirname "${BASH_SOURCE[0]}")/install.sh" ]; then
    HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  fi

  # ---- the root folder
  expand() { case "$1" in "~") echo "$HOME";; "~/"*) echo "$HOME/${1#\~/}";; *) echo "$1";; esac; }
  local ROOT=${1:-${OPENBOOK_ROOT:-}}
  if [ -z "$ROOT" ] && [ -n "$HERE" ] && [ -f "$HERE/.env" ]; then
    ROOT=$(sed -n 's/^OPENBOOK_ROOT=//p' "$HERE/.env" | tail -1 | sed "s/^[\"']//; s/[\"']\$//")
  fi
  if [ -z "$ROOT" ] && [ -n "$HERE" ]; then
    ROOT=$(dirname "$(dirname "$HERE")")   # already in <root>/OpenBook/cormon-chat: keep it there
  fi
  if [ -z "$ROOT" ]; then
    if read -r -p "Install under which folder? OpenBook goes in a folder of its own inside it. [Return = $HOME] " ROOT < /dev/tty; then :; else ROOT=""; fi
    ROOT=${ROOT:-$HOME}
  fi
  ROOT=$(expand "$ROOT")
  mkdir -p "$ROOT" || fail "Could not make the folder $ROOT."
  ROOT=$(cd "$ROOT" && pwd)
  case "$ROOT" in
    "$HOME/Documents"*|"$HOME/Desktop"*)
      printf '\033[33mNote: %s often syncs to iCloud, which can slow or break the demo. A folder like ~/Huma is safer.\033[0m\n' "$ROOT";;
  esac

  # an existing checkout is used where it is; otherwise the demo goes in <root>/OpenBook
  local DIR CHAT
  if [ -n "$HERE" ] && [ -d "$HERE/.git" ]; then
    CHAT=$HERE
    DIR=$(dirname "$CHAT")
  else
    DIR="$ROOT/OpenBook"
    CHAT="$DIR/cormon-chat"
  fi

  say "Setting up OpenBook in $DIR (about 20 minutes the first time, a minute or two when it is already there). Keep this window open."

  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && eval "$("$b" shellenv)" && break; done
  if ! command -v brew >/dev/null; then
    say "Installing Homebrew. Type your Mac password when it asks (nothing shows as you type)."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && eval "$("$b" shellenv)" && break; done
    grep -q 'brew shellenv' "$HOME/.zprofile" 2>/dev/null || echo "eval \"\$($(command -v brew) shellenv)\"" >> "$HOME/.zprofile"
  fi

  mkdir -p "$DIR"
  if [ -d "$CHAT/.git" ]; then
    local before after
    before=$(git -C "$CHAT" rev-parse HEAD 2>/dev/null || true)
    update_repo "$CHAT" cormon-chat
    after=$(git -C "$CHAT" rev-parse HEAD 2>/dev/null || true)
    # the scripts themselves changed: start again from the top with the new ones (once)
    if [ "$before" != "$after" ] && [ -z "${OPENBOOK_REEXEC:-}" ] && [ -x "$CHAT/Install OpenBook.command" ]; then
      echo "Restarting with the new version of the setup."
      OPENBOOK_REEXEC=1 exec "$CHAT/Install OpenBook.command" "$@"
    fi
  else
    GIT_TERMINAL_PROMPT=0 git clone -q https://github.com/humahq/cormon-chat.git "$CHAT" ||
      fail "Could not download. Check that you can open https://github.com/humahq/cormon-chat, then run it again."
  fi

  # remember the root, so "Start demo" and later runs find everything without being told
  setenv() {
    local f=$1 k=$2 v=$3
    [[ "$v" =~ ^[A-Za-z0-9_./:@+-]*$ ]] || v="'$v'"
    (umask 077; touch "$f")
    { grep -v "^$k=" "$f" || true; printf '%s=%s\n' "$k" "$v"; } > "$f.new"
    mv "$f.new" "$f"; chmod 600 "$f"
  }
  setenv "$CHAT/.env" OPENBOOK_ROOT "$(dirname "$DIR")"

  trap - ERR
  OPENBOOK_AUTO=1 "$CHAT/install.sh" < /dev/tty || fail "The setup stopped. Run it again; if it stops at the same place, send John a screenshot."
  say "Starting the demo. Your browser opens in a minute. Keep this window open; closing it stops the bot."
  exec "$CHAT/Start demo.command" < /dev/tty
}
main "$@"; exit $?
