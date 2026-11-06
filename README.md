# cormon-chat

A chat server on your own laptop, for demos and tests of Huma Bot. It is Mattermost, running in Podman. Nothing
goes to the cloud except the bot's calls to OpenAI, and the demo people need no real email addresses.

The bot's code is in its own repo, [correspondence-monitor](https://github.com/humahq/correspondence-monitor).

## Set up a new laptop (once)

You need a Mac, about 4 GB of free memory and an OpenAI API key.

1. **Install the tools.** Install [Homebrew](https://brew.sh) if you don't have it. Then, in Terminal:
   ```
   brew install podman uv git
   podman machine init
   podman machine start
   ```
2. **Download the bot and this chat server** into your Documents folder:
   ```
   cd ~/Documents
   git clone https://github.com/humahq/correspondence-monitor.git "clinical trial"
   git clone https://github.com/humahq/cormon-chat.git
   ```
3. **Set up the bot:**
   ```
   cd ~/Documents/"clinical trial"
   uv sync
   echo "OPENAI_API_KEY=your-key-here" > .env
   ```
   Put your own OpenAI key in place of `your-key-here`.
4. **Start it.** In Finder, open `Documents/cormon-chat` and double-click **Start demo.command**. The first time it
   takes about 5 minutes. It downloads Mattermost and the memory server, then makes the team, the site room, the
   demo people and the bot. If macOS says it can't open the file, right-click it and choose **Open**.

If you put the bot somewhere other than `~/Documents/clinical trial`, add `BOT_DIR=/path/to/the/bot` to
`cormon-chat/.env`.

## Run a demo

Double-click **Start demo.command**. It starts Podman, Mattermost, patient memory and the bot, then opens:

- http://localhost:8065: **Mattermost**, the chat itself.
- http://localhost:8090: **Demo teams**, the list of customer demos.

Keep its window open during the demo. Closing it stops the bot.

**Sign in** as `crc`, `pi`, `cra`, `sponsor` or `medmonitor`. They all use the same password, `DEMO_PASSWORD` in
`cormon-chat/.env`. `admin` is the server's administrator.

**The welcome guide** is pinned in the site room. It says who is who, and gives messages to try: a question, a
problem the bot catches, a second-hand OK it doesn't accept, and a fact it remembers. To see it, open
**Site 01 (MGH)** and click the pin icon at the top.

## One team per customer

Each customer demo gets its own team and its own people, so no customer sees another's messages. Huma demo has
`crc`, `cra` and so on. Acme Pharma has `crc-acme-pharma`, `cra-acme-pharma` and so on, all with the same password.
The bot is in every team.

On the **Demo teams** page:

- **Create**: type the customer's name, for example `Acme Pharma`. It makes the team `acme-pharma-demo`, its site
  room with the welcome guide, and the demo people. Then it adds the bot and moves the bot there. It takes about a
  minute.
- **Use this one**: moves the bot to another customer's team.

Each team has its own bot database and memory, so alerts and facts from one demo never show in another. The bot
works in one team at a time.

The same from the command line: `./setup.sh acme-demo "Acme demo"`, then `cormon chat-demo --team acme-demo` in the
bot's folder.

## Rooms

There is one private room per site, `Site 01 (MGH)`. It holds the CRA, the site staff and the sponsor, with the
medical monitor for safety. There is no room with everyone in it. The bot, `@huma-bot` (Huma Bot), is in the site
room. You can also talk to it alone in a 1-on-1 chat.

## Stop

```
./down.sh          # stops it, keeps the data
./down.sh --wipe   # stops it and deletes all users, rooms and messages
```

## The scripts

- `up.sh`: starts Mattermost. The first time, it makes `.env` with the passwords.
- `setup.sh`: makes a team, its site room, the demo people, the bot and its token. It is safe to run again.
- `welcome.sh`: pins the welcome guide in a team's site room, once.
- `down.sh`: stops Mattermost.
- `bot.yaml`: which room each study uses, and which study person each demo person is.
