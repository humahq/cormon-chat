# cormon-chat

A chat server on your own laptop, for demos and tests of OpenBook and its bot, Mira Belle. It is Mattermost, in
OpenBook's look, running in Podman. Nothing
goes to the cloud except the bot's calls to OpenAI, and the demo people need no real email addresses.

The bot's code is in its own repo, [correspondence-monitor](https://github.com/humahq/correspondence-monitor).

## Set up a new laptop (once)

You need:
- a Mac, or a Linux laptop with Ubuntu or Fedora, with 16 GB of memory and 20 GB of free disk;
- an OpenAI API key (from https://platform.openai.com/api-keys);
- a GitHub account.

Both repos are private. John adds your GitHub account to **humahq/cormon-chat** and
**humahq/correspondence-monitor**. GitHub emails you an invite for each. Open both emails and click **Accept**.

All the steps below are typed in **Terminal**. On a Mac, press Cmd+Space, type `Terminal` and press Return.
Paste each block, press Return, and wait for it to finish before the next one.

1. **Install Homebrew and the GitHub tool.**

   On a Mac:
   ```
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```
   It asks for your laptop password (nothing shows as you type) and to press Return. It takes a few minutes.
   Then:
   ```
   echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
   eval "$(/opt/homebrew/bin/brew shellenv)"
   brew install gh
   ```
   If you already have Homebrew, run only `brew install gh`. On an older Mac with an Intel chip, skip the two
   lines that start with `echo` and `eval`.

   On Linux: `sudo apt install git gh` (Ubuntu) or `sudo dnf install git gh` (Fedora).

2. **Sign in to GitHub.**
   ```
   gh auth login --hostname github.com --git-protocol https --web
   ```
   If it asks "Authenticate Git with your GitHub credentials?", answer **Yes**. It shows a short code, like
   `AB12-CD34`. Press Return, and your browser opens GitHub. Sign in, type the code and click **Authorize**.

3. **Download the demo and run the installer.**
   ```
   mkdir -p ~/code && cd ~/code
   gh repo clone humahq/cormon-chat
   cd cormon-chat
   ./install.sh
   ```
   This puts it in a folder named `code` in your home folder. Any folder works, but not one that syncs to
   iCloud, such as Documents or Desktop on many Macs.

4. **Answer the installer's questions.** It asks only for:
   - your OpenAI key (paste it; nothing shows as you paste). It checks the key with OpenAI before saving it;
   - a password for signing in to the demo, or press Return to get one made for you;
   - yes or no, before it installs a tool you don't have yet.

   It takes about 15 minutes the first time, most of it downloading. What it does:
   - installs Podman, uv and git if they are missing (Homebrew on a Mac, apt or dnf on Linux);
   - on a Mac, makes a Podman machine of its own, named `openbook` (4 CPUs, 6 GB), so it doesn't touch any other
     Podman machine you have;
   - downloads the bot's code next to this folder, as `correspondence-monitor`, unless it finds it already;
   - writes both `.env` files (the bot's key, the passwords, and where the bot is), readable only by you;
   - starts Mattermost and patient memory, and makes the team, the site room, the demo people and the bot.

   At the end it prints "All set", the sign-in names and the password. You can run it again at any time; it
   keeps what is there and only asks for what is missing or wrong.

5. **Start the demo** as in [Run a demo](#run-a-demo) below.

If something goes wrong:
- Podman may print "the system helper service is not installed". That is fine; the demo doesn't need it.
- "Another Podman machine is running": a Mac runs one Podman machine at a time. Answer yes to stop the other one;
  its containers and data are kept, and `podman machine start <its name>` starts it again later.
- "Could not download the bot": you have not accepted the invite to humahq/correspondence-monitor yet. Accept it,
  then run `./install.sh` again.
- "OpenAI did not accept that key": copy the whole key again, from `sk-` to the end.
- Anything else: run `./install.sh` again. If it stops at the same place, send John a screenshot.

## Run a demo

Double-click **Start demo.command** in the `cormon-chat` folder (on Linux, run `./"Start demo.command"` in a
terminal). If macOS says it can't open the file, right-click it and choose **Open**. It starts Podman, Mattermost,
patient memory and the bot, then opens:

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

The same from the command line: `./setup.sh acme-demo "Acme demo"` here, then in the bot's folder
`.venv/bin/cormon chat-demo --chat ~/code/cormon-chat --team acme-demo` (with the path to your cormon-chat).

## Rooms

There is one private room per site, `Site 01 (MGH)`. It holds the CRA, the site staff and the sponsor, with the
medical monitor for safety. There is no room with everyone in it. The bot, `@mira` (Mira Belle), is in the site
room. You can also talk to it alone in a 1-on-1 chat.

## Stop

```
./down.sh          # stops it, keeps the data
./down.sh --wipe   # stops it and deletes all users, rooms and messages
```

## The scripts

- `install.sh`: sets up a new laptop (see above). It is safe to run again.
- `up.sh`: starts Mattermost. It puts the passwords in `.env` if they are not there yet.
- `setup.sh`: makes a team, its site room, the demo people, the bot and its token. It is safe to run again.
- `brand.sh`: the OpenBook look: the name OpenBook, its colors for everyone, the bot as Mira Belle with its
  picture, and a small plugin (`brand/openbook-brand`) that shows OpenBook where Mattermost shows its logo. Start
  demo runs it each time. A few Mattermost words stay, such as in the About box.
- `welcome.sh`: pins the welcome guide in a team's site room, or updates it.
- `down.sh`: stops Mattermost.
- `bot.yaml`: which room each study uses, and which study person each demo person is.
