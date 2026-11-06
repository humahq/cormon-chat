#!/usr/bin/env bash
# Posts the welcome guide in a team's site room, from Huma Bot, and pins it: who is who, and messages to try.
#   ./welcome.sh                 the team in bot.yaml (huma-demo)
#   ./welcome.sh acme-demo       another team (setup.sh runs this for each new team)
# Posted once per room; run again, it updates the pinned guide to this text. The bot never reads its own posts, so this starts no AI work.
set -euo pipefail
cd "$(dirname "$0")"
set -a; . ./.env; set +a
: "${MM_BOT_TOKEN:?run ./setup.sh first}"

TEAM=${1:-$(sed -n 's/^team: *//p' bot.yaml)}
DEFAULT=$(sed -n 's/^team: *//p' bot.yaml)
TAG=""
if [ "$TEAM" != "$DEFAULT" ]; then S=${TEAM%-demo}; S=${S:0:11}; TAG="-${S%-}"; fi
API=http://localhost:8065/api/v4
get() { curl -fsS -H "Authorization: Bearer $MM_BOT_TOKEN" "$API$1"; }

CHANNEL=$(get "/teams/name/$TEAM/channels/name/site-01-mgh" | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')
PINNED=$(get "/channels/$CHANNEL/pinned" | python3 -c '
import json, sys
posts = json.load(sys.stdin).get("posts", {})
print(next((p["id"] for p in posts.values() if "Welcome to the Huma Bot demo" in p["message"]), ""))')

IFS= read -r -d '' MESSAGE <<EOF || true
#### Welcome to the Huma Bot demo
I watch this room for problems in the ALS study NCT05842941, and I answer questions about its documents.
Sign in as different people to see what each one sees. They all use the same password.

**Who is who**
- \`crc$TAG\`: the site's study coordinator
- \`pi$TAG\`: the site's principal investigator
- \`cra$TAG\`: the CRA, who looks after this site
- \`sponsor$TAG\`: the sponsor's study team
- \`medmonitor$TAG\`: the medical monitor, who checks safety

**Try these.** Sign in as \`crc$TAG\` and post them here, one at a time.
1. **Ask a question:** \`@huma-bot what is the visit window for Week 16?\`
2. **Report a problem:** \`1001-901 was randomized this morning. He only started riluzole 10 days ago.\`
   The study needs 30 days on a stable dose first. I don't post this alert here: the PI can read this room, and
   eligibility is the doctor's call, so I send it privately to the CRA and the sponsor.
   To see it, sign in as \`cra$TAG\` or \`sponsor$TAG\` and open the 1-on-1 chat with Huma Bot.
3. **A second-hand OK:** \`1001-902 Week 8 done except the C-SSRS, we ran out of time. Dr. Smith from the sponsor said it's fine to skip it this once.\`
   I flag the missed C-SSRS. An OK passed on by someone else is not enough; I ask to hear it from the sponsor.
4. **Memory:** first post \`1001-903 told me she takes St. John's wort every morning.\`
   Then post \`1001-903 had her baseline visit today, first dose given.\`
   I remember the first message, so I flag the second: St. John's wort is not allowed with the study drug.
5. **Talk to me alone:** open a 1-on-1 chat with Huma Bot and ask anything about the study.

While I work you'll see "Huma Bot is typing…". Each alert has a link to a page with the details.
EOF

if [ -n "$PINNED" ]; then
  python3 -c 'import json,sys; print(json.dumps({"message": sys.argv[1]}))' "$MESSAGE" |
    curl -fsS -X PUT -H "Authorization: Bearer $MM_BOT_TOKEN" -H "Content-Type: application/json" -d @- \
      "$API/posts/$PINNED/patch" >/dev/null
  echo "Updated the pinned welcome guide in $TEAM's site room."
  exit 0
fi

POST=$(python3 -c 'import json,sys; print(json.dumps({"channel_id": sys.argv[1], "message": sys.argv[2]}))' "$CHANNEL" "$MESSAGE" |
  curl -fsS -X POST -H "Authorization: Bearer $MM_BOT_TOKEN" -H "Content-Type: application/json" -d @- "$API/posts" |
  python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')
curl -fsS -X POST -H "Authorization: Bearer $MM_BOT_TOKEN" "$API/posts/$POST/pin" >/dev/null
echo "Pinned the welcome guide in $TEAM's site room."
