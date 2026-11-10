# cormon-chat

A chat server on your own laptop, for demos and tests of OpenBook and its bot, Mira Belle. It is Mattermost, in
OpenBook's look, running in Podman. Nothing
goes to the cloud except the bot's calls to OpenAI, and the demo people need no real email addresses.

The bot's code is in its own repo, [correspondence-monitor](https://github.com/humahq/correspondence-monitor).

## Set up a new laptop (once)

**On a Mac:** open **Terminal** (press Cmd+Space, type `Terminal`, press Return), paste this line and press Return:
```
curl -fsSL https://raw.githubusercontent.com/humahq/cormon-chat/main/Install%20OpenBook.command | bash
```
It does everything by itself: it installs the tools, downloads the demo into a folder named `OpenBook` in your
home folder, and starts it. It asks only for:
- your Mac password, if Homebrew is not installed yet (nothing shows as you type);
- your OpenAI key (from https://platform.openai.com/api-keys; nothing shows as you paste). It checks the key
  with OpenAI before saving it.

It takes about 20 minutes the first time, most of it downloading. At the end it prints "All set", the sign-in
names and the password, and your browser opens the demo. Keep the Terminal window open; closing it stops the bot.
You can run the same line again at any time; it keeps what is there.

You need a Mac (or Linux laptop) with 16 GB of memory and 20 GB of free disk.

**On Linux (Ubuntu or Fedora):**
```
sudo apt install git     # or: sudo dnf install git
mkdir -p ~/code && cd ~/code
git clone https://github.com/humahq/cormon-chat.git
cd cormon-chat
./install.sh
```
It asks for your OpenAI key, a demo password (press Return to get one made for you), and yes or no before it
installs a tool you don't have yet. Then start the demo as in [Run a demo](#run-a-demo) below.

What the installer does:
- installs Podman, uv and git if they are missing (Homebrew on a Mac, apt or dnf on Linux);
- on a Mac, makes a Podman machine of its own, named `openbook` (4 CPUs, 6 GB), so it doesn't touch any other
  Podman machine you have;
- downloads the bot's code next to this folder, as `correspondence-monitor`, unless it finds it already;
- writes both `.env` files (the bot's key, the passwords, and where the bot is), readable only by you;
- starts Mattermost and patient memory, and makes the team, the site room, the demo people and the bot.

If something goes wrong:
- Podman may print "the system helper service is not installed". That is fine; the demo doesn't need it.
- "Another Podman machine is running": a Mac runs one Podman machine at a time. The installer stops the other one;
  its containers and data are kept, and `podman machine start <its name>` starts it again later.
- "Could not download": check the internet connection, then run it again.
- "OpenAI did not accept that key": copy the whole key again, from `sk-` to the end.
- Anything else: run `./install.sh` again. If it stops at the same place, send John a screenshot.

## Run a demo

Double-click **Start demo.command** in the `cormon-chat` folder (on Linux, run `./"Start demo.command"` in a
terminal). If macOS says it can't open the file, right-click it and choose **Open**. It starts Podman, Mattermost,
patient memory and the bot, then opens:

- http://localhost:8065: **Mattermost**, the chat itself.
- http://localhost:8090: **Demo teams**, the list of customer demos.

Keep its window open during the demo. Closing it stops the bot.

**Sign in** as one of the study people:

| Name | Who it is |
|---|---|
| `crc` | the site's study coordinator |
| `pi` | the site's doctor in charge of the study |
| `cra` | the sponsor's monitor who visits the site |
| `sponsor` | the sponsor's study lead |
| `medmonitor` | the sponsor's medical monitor |
| `eliot`, `peter`, `john` | testers |

They all use the same password. It is made when you install, so it is different on each laptop, and it is shown
in the demo's window each time the demo starts (it is also `DEMO_PASSWORD` in `cormon-chat/.env`). `admin` is the
server's administrator.

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
