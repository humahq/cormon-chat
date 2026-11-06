#!/usr/bin/env bash
# The OpenBook look on the local Mattermost (openbook.phd): the site's name and sign-in page, OpenBook's colors for
# every person, the bot as Mira Belle (@mira) with its picture, and a small plugin that shows "OpenBook" where
# Mattermost shows its own logo. Safe to run again: Start demo runs it each time.
set -euo pipefail
cd "$(dirname "$0")"
set -a; . ./.env; set +a
mm() { podman exec cormon-chat-app mmctl --local "$@"; }
quiet() { "$@" >/dev/null 2>&1 || true; }
BOT=mira

# the bot: servers set up before the rename keep their bot, its token and its chats
quiet mm bot update huma-bot --username "$BOT"
quiet mm bot update cormon --username "$BOT"
quiet mm bot update "$BOT" --display-name "Mira Belle"

quiet mm config set TeamSettings.SiteName "OpenBook"
quiet mm config set TeamSettings.CustomDescriptionText "Study chat with Mira Belle"
quiet mm config set TeamSettings.EnableCustomBrand true
quiet mm config set TeamSettings.CustomBrandText "**OpenBook**: study chat with Mira Belle, powered by Huma.ai"

# the plugin has no server part, only a script for the web page; a newer copy replaces the old one
quiet mm config set PluginSettings.Enable true
quiet mm config set PluginSettings.EnableUploads true
PLUGIN=$(mktemp -t openbook-brand.XXXXXX)
COPYFILE_DISABLE=1 tar -czf "$PLUGIN" -C brand openbook-brand   # no macOS ._ files in it
podman cp "$PLUGIN" cormon-chat-app:/tmp/openbook-brand.tar.gz >/dev/null
rm -f "$PLUGIN"
mm plugin add --force /tmp/openbook-brand.tar.gz >/dev/null 2>&1 ||
  { quiet mm plugin delete openbook-brand; mm plugin add /tmp/openbook-brand.tar.gz >/dev/null; }
mm plugin enable openbook-brand >/dev/null

python3 brand/brand.py "$BOT"
