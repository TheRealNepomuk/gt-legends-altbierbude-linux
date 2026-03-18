# GT Legends + Altbierbude (ABB) — Linux Installation Guide
**Version 1.0 — March 2026**

GT Legends is a 2005 DirectX 9 racing simulation. The Altbierbude (ABB) community
provides ~28GB of additional cars, tracks and patches, and maintains active multiplayer
servers. This guide gets you from a fresh Linux install to racing online.

**Status:** Fully working as of 2026 on Ubuntu/Linux Mint.
For technical deep-dives and known issue analysis see [TECHNICAL.md](TECHNICAL.md).

---

## Overview — What You'll Be Doing

Here's the full picture before we start. Don't worry, each step is explained in detail below.

1. **Install Lutris** — the Linux game manager that handles Wine and game settings for you
2. **Install Wine runners** — the Windows compatibility layers GTL runs inside (you need two specific versions)
3. **Create a Wine prefix** — a self-contained fake Windows environment for GTL
4. **Install GT Legends** — run the GTL installer inside the Wine prefix
5. **Install and run the ABB AutoUpdater** — downloads and installs ~28GB of extra cars, tracks and patches (takes many hours)
6. **Configure Lutris and graphics** — set DXVK options and resolution
7. **Set up the launcher script** — a menu that launches all GTL tools correctly
8. **First launch and online setup** — enter your Online Key, join ABB servers

---

## What You'll Need

Before you start, gather these:

- **GT Legends installation media** — original DVD or ISO image. You need to own a legitimate copy.
- **Official 1.1.0.0 patch** — `GTL_Update_1.1.0.0.exe` (available from fan sites). Many versions already include it — see Step 3.2.
- **ABB AutoUpdater** — download from altbierbude.de:
  [AutoUpdater download page](https://www.altbierbude.de/component/option,com_remository/Itemid,26/func,fileinfo/id,650/lang,de/)
  *(You need a free ABB account to download — register at [altbierbude.de](https://www.altbierbude.de/))*
- **LowGuard anti-cheat** — optional, only needed if you want your lap times to count as official records. Available from altbierbude.de after registering.
- **Altbierbude account** — free registration at [altbierbude.de](https://www.altbierbude.de/)
- **Online Key** — printed on the back of the GT Legends manual (different from the DVD serial key — there are two separate keys)
- **~80GB free disk space** — ~40GB for the installed game + ~34GB for the download archive cache
- **Time** — the ABB content download takes many hours (~28GB via P2P at ~200KB/s). Plan to leave it running overnight.

---

## Part 1: Environment Setup

### 1.1 Install Lutris and Dependencies

**Lutris** is a Linux game manager. It handles Wine (the Windows compatibility layer) and game
settings for you, so you don't need to configure Wine manually. We'll also install a few
supporting tools GTL needs.

Open a terminal (keyboard shortcut: **Ctrl+Alt+T**, or search for "Terminal" in your apps) and
copy-paste these commands. Press Enter after pasting, then type your password when prompted:

```bash
sudo apt update
sudo apt install lutris wine64 wine32 winetricks p7zip-full curl wmctrl
```

> **What each package does:**
> - `lutris` — the game manager
> - `wine64` / `wine32` — Windows compatibility layer (we'll replace this with specific versions below, but the packages pull in useful dependencies)
> - `winetricks` — helper tool for installing Windows components into Wine prefixes
> - `p7zip-full` — archive extractor (needed for ISO files and some game content)
> - `curl` — download tool used in some install steps
> - `wmctrl` — window manager tool used by the launcher script

**To verify Lutris installed correctly**, type (or copy-paste):

```bash
lutris --version
```

The result should say something like `lutris 0.5.17` (version number may vary). If you see a
version number, Lutris is installed.

### 1.2 Download Wine Runners

A **Wine runner** is the specific version of Wine used to run a Windows program. Different
versions have different compatibility characteristics, and GTL needs two:

| Runner | Used for | Why |
|---|---|---|
| `wine-11.3-staging-amd64` | Launching GTL.exe (via Lutris) | Newest version, best compatibility with the game itself |
| `wine-10.20-staging-amd64` | AutoUpdater, GTLConfig, LowGuard | Wine 11.3 has a bug that crashes these helper tools; 10.20 handles them correctly |

Both come from the [Kron4ek/Wine-Builds](https://github.com/Kron4ek/Wine-Builds/releases) project.
Go to that page and download the `.tar.xz` file for each version — search for `wine-11.3-staging-amd64`
and `wine-10.20-staging-amd64`.

> **Watch out for the `wow64` variants** (e.g. `wine-11.3-staging-wow64`). These are a different
> build type — download the plain `amd64` versions, not the `wow64` ones.

Once downloaded, you need to extract the files into the Lutris runners folder
(`~/.local/share/lutris/runners/wine/`) — this is where Lutris looks for Wine versions.
The `mkdir` command below creates it if it doesn't exist yet, and `tar -xJf` extracts each
`.tar.xz` archive directly into that folder:

```bash
mkdir -p ~/.local/share/lutris/runners/wine/

tar -xJf ~/Downloads/wine-11.3-staging-amd64.tar.xz \
    -C ~/.local/share/lutris/runners/wine/

tar -xJf ~/Downloads/wine-10.20-staging-amd64.tar.xz \
    -C ~/.local/share/lutris/runners/wine/
```

> **Note:** If you saved the files somewhere other than `~/Downloads/`, adjust the paths accordingly.
> Each `tar` command is a single command split across two lines with `\` for readability — paste
> both lines together.

**To verify:** run this command and confirm both folder names appear in the output:

```bash
ls ~/.local/share/lutris/runners/wine/
```

You should see (among other entries):
```
wine-10.20-staging-amd64
wine-11.3-staging-amd64
```

### 1.3 Create Directories

GTL needs a few folders to store different things. Here's what each one is for:

| Folder | Purpose |
|---|---|
| `~/Games/GTLegends-Prefix/` | The Wine prefix — your fake Windows environment. All game files, saves, and settings live here. |
| `~/Games/GTLegends-Archive/` | The ABB download cache — compressed archive files downloaded by the AutoUpdater. |
| `~/Games/GTLegends-Install/` | Temporary: holds the extracted ISO during initial installation. Can be deleted afterwards. |

Create them with:

```bash
mkdir -p ~/Games/GTLegends-Prefix
mkdir -p ~/Games/GTLegends-Archive
mkdir -p ~/Games/GTLegends-Install
```

> **Important:** These exact folder names are used throughout this guide. If you want to use
> different locations, take note — you'll need to substitute your paths everywhere they appear.
> Spelling matters: `GTLegends-Prefix` and `gtlegends-prefix` are different folders on Linux.

---

## Part 2: Wine Prefix Setup

A **Wine prefix** is a self-contained fake Windows environment — think of it as a small Windows
installation living inside a folder on your Linux system. GTL and all its ABB tools will be
installed inside this prefix.

1. Open Lutris (search for it in your apps, or type `lutris` in a terminal)
2. Click **+** (top-left) → **Add a new game**
3. **Game info tab:**
   - Name: `GT Legends`
   - Runner: `Wine (Runs Windows games)`
4. **Game options tab:**
   - Executable: leave blank for now (we'll set this after installation)
   - Wine prefix: `~/Games/GTLegends-Prefix`
   - Prefix architecture: **32-bit** ← this is important, GTL is a 32-bit game
5. **Runner options tab:**
   - Wine version: `wine-11.3-staging-amd64`
   - Enable DXVK: **ON** ← required (see Part 5 for why)
   - Enable DXVK-NVAPI: OFF
   - Enable Esync: **ON**
   - Enable Fsync: OFF
6. **System options tab:**
   - Disable desktop effects: **ON**
   - Disable screen saver: ON
   - Enable Feral GameMode: ON (if installed)
7. Click **Save**

---

## Part 3: Game Installation

### 3.1 Extract ISO and Install Base Game

If you have a DVD, insert it. If you have an ISO file, extract it first:

```bash
7z x "GT\ Legends.iso" -o~/Games/GTLegends-Install/
```

> Adjust the filename to match your actual ISO file name. If the name contains spaces, wrap it
> in quotes.

In Lutris: right-click **GT Legends** → **Run EXE inside Wine prefix** → navigate to your DVD
or `~/Games/GTLegends-Install/` and select `setup.exe`.

The GTL installer will open. During the installer:

- Set the install path to **`C:\GTL`** — this avoids folder names with spaces, which can cause
  problems. Do not use the default location.
- Skip start menu entries and desktop shortcuts (you won't use them on Linux)
- Skip the video accelerator configuration screen
- **At the end, do NOT tick "Launch GT Legends"** — the game must not run until after the
  AutoUpdater has applied its No-CD patch in a later step. If the game runs first, you may
  need to reinstall.

### 3.2 Apply Official 1.1.0.0 Patch

Some versions of GT Legends (including the Steam version and the CBS version) already include
patch 1.1.0.0. If you know you have one of these, you can skip this step.

**If you're unsure:** apply the patch anyway — if your copy is already at 1.1.0.0 the installer
will simply report it's up to date and you can close it. Do not launch the game to check the
version at this point — the No-CD patch hasn't been applied yet.

In Lutris: right-click GT Legends → **Run EXE inside Wine prefix** → select `GTL_Update_1.1.0.0.exe`.

**Do not launch the game itself yet** — wait until after the AutoUpdater is set up.

---

## Part 4: ABB AutoUpdater

The ABB AutoUpdater is the community tool that downloads and installs ~28GB of extra cars,
tracks and patches. It also applies the No-CD patch that lets GTL run without a disc.

### 4.1 Download the AutoUpdater

Download the installer from altbierbude.de (you need to be logged into your ABB account):

[AutoUpdater download page](https://www.altbierbude.de/component/option,com_remository/Itemid,26/func,fileinfo/id,650/lang,de/)

The installer is called `Bierbuden_Autoupdate_WebInst.exe`. It is a web installer — when you
run it, it downloads and installs the AutoUpdater itself along with all its dependencies
(including Python 2.7 and wxPython, which the AutoUpdater needs to run).

### 4.2 Install the AutoUpdater

In Lutris: right-click **GT Legends** → **Run EXE inside Wine prefix** →
select `Bierbuden_Autoupdate_WebInst.exe`.

A component selection window will appear. Set it up like this:

- ✅ **Altbierbude** — keep this ticked (this is the GTL community you want)
- ❌ Pilsbierbude, Bockbierbude, Weissbierbude — untick (these are for other games)
- ❌ rFactor2 autosync — untick
- ✅ **Python 2.7.6** — keep ticked (required runtime for the AutoUpdater)
- ✅ **wxPython 2.8.12.1 (py27)** — keep ticked (graphical interface for the AutoUpdater)

Accept the default destination folder and let the installation complete. The installer
downloads all components from the internet — make sure you're connected.

> **Note:** Python and wxPython are installed inside the Wine prefix, only for use by the
> AutoUpdater. This does not affect your Linux system's Python installation.

### 4.3 Set Up the Archive Folder

The AutoUpdater stores all its downloaded files in an archive folder. The tricky part: it runs
inside Wine, which only understands Windows paths like `C:\GTL_Archive`. Your archive folder
lives on Linux at `~/Games/GTLegends-Archive/`.

We solve this with a **symlink** — a shortcut that makes the Linux folder appear at a Windows
path inside the prefix. Copy-paste the following command (it is one single command, split across
two lines with `\` for readability — paste both lines together):

```bash
ln -s ~/Games/GTLegends-Archive \
    ~/Games/GTLegends-Prefix/drive_c/GTL_Archive
```

After running this, the AutoUpdater can use `C:\GTL_Archive` and it will actually read/write
to `~/Games/GTLegends-Archive/` on your Linux filesystem.

**To verify the symlink worked:**

```bash
ls ~/Games/GTLegends-Prefix/drive_c/GTL_Archive
```

If the symlink is correct this will either show nothing (empty folder, which is fine) or the
contents of your archive if you already have one.

### 4.4 Launch the AutoUpdater

> **Important:** The AutoUpdater must be launched via the **launcher script**, not directly
> through Lutris. Launching it through Lutris causes a blue fullscreen background that covers
> your entire desktop. The launcher script applies a fix before starting it.

**Before continuing, set up the launcher script now (Part 7).** Then come back here and
use the **AutoUpdater** option from the launcher menu to start it. The launcher opens a
small menu window — click "AutoUpdater" and the AutoUpdater application will open.

### 4.5 Configure the AutoUpdater

The first time you launch the AutoUpdater, a setup wizard appears. Fill in:

1. **Login:** your Altbierbude username and password
2. **GTL folder:** `C:\GTL`
3. **Archive folder:** `C:\GTL_Archive`
4. **Download Ticket:** a short code shown in the bottom-left corner of altbierbude.de when
   you're logged in. This changes periodically — if downloads fail, get a fresh one.
5. **P2P ports:** leave at the default (8435–8438)

### 4.6 If You Already Have an ABB Archive

If you have a pre-existing ABB archive from a previous install, a backup, or a friend, copy it
to `~/Games/GTLegends-Archive/` before running the update. The AutoUpdater scans this folder
at startup and installs from local files, skipping the P2P download for anything already
present. This can save many hours.

Expected folder structure inside `~/Games/GTLegends-Archive/`:
```
AddonTracks/    ← track .zip/.7z files and .p2p torrent files
StandaloneCars/ ← car .zip/.7z files
Patches/        ← patch files
```

### 4.7 Run the Update

Click **Update** to start. The AutoUpdater compares your files against what the server expects
and queues anything missing.

**Dialogs you'll see:**

- **"Game folder changed — reinstall?"** → always click **No**. This is a harmless false alarm
  caused by a Linux/Windows difference in how folder timestamps work. It does not affect what
  gets installed.
- **Transfer dialog** listing files to install → click **Yes** to start.
- **"ABB Classes patch"** dialog → accept it. This sets up the correct car class configurations
  for ABB online racing.

Content already in your archive installs immediately. Missing content downloads via P2P —
~28GB takes many hours. Leave it running overnight.

**Known issue — Finchfields track deadlock:**
The track `Finchfields_GTL_V1_01.zip` has a server-side problem (wrong hash in the database)
and 0 P2P seeders, which means the AutoUpdater can never download it. If it stalls:
1. Download it manually from the ABB website
2. Place it in `~/Games/GTLegends-Archive/AddonTracks/`
3. Restart the AutoUpdater — it will find the local file and install it

This track is rarely raced on ABB servers — skipping it does not prevent online play.

### 4.8 Apply the 4GB Patch

Once the content installation is complete:

AutoUpdater → **Commands** → **4GB Patch**

This does two things: removes the StarForce DRM disc check (so GTL runs without a DVD) and
allows GTL.exe to use more than 2GB of RAM, which improves stability with the full ABB content loaded.

---

## Part 5: Configure Lutris for GTL

### 5.1 Update the Executable

Now that GTL is installed, tell Lutris where to find it.

In Lutris: right-click **GT Legends** → **Configure** → **Game options**:
- Executable: `~/Games/GTLegends-Prefix/drive_c/GTL/GTL.exe`
- Working directory: `~/Games/GTLegends-Prefix/drive_c/GTL`

### 5.2 Add the DXVK DLL Override

**DXVK** is an open-source library that translates DirectX 9 (what GTL uses) into Vulkan (the
modern Linux graphics API). It replaces Wine's built-in DirectX support and delivers better
performance and compatibility. For GTL specifically it also fixes a hardware detection bug that
otherwise causes the game to run at minimum texture quality regardless of your GPU.

You already enabled DXVK in Lutris (Part 2). One additional setting ensures Wine always uses
the DXVK version of `d3d9.dll` rather than its own. Open your Lutris config file:

```bash
ls ~/.config/lutris/games/gt-legends-*.yml
```

Open that file with a text editor (e.g. `gedit ~/.config/lutris/games/gt-legends-*.yml`) and
make sure this line is present under `system → env`:

```yaml
system:
  env:
    WINEDLLOVERRIDES: "d3d9=n,b"
```

If it's already there, nothing to do. If it's missing, add it. If DXVK is still not loading
after launch, see the troubleshooting section.

### 5.3 Create dxvk.conf

Create a file called `dxvk.conf` inside the GTL folder. This file lets you tune DXVK's behaviour.
Copy-paste this command into the terminal — it creates the file with the correct settings:

```bash
cat > ~/Games/GTLegends-Prefix/drive_c/GTL/dxvk.conf << 'EOF'
d3d9.maxAvailableMemory = 2048
d3d9.maxFrameLatency = 1
d3d9.samplerAnisotropy = 8
EOF
```

> **What these settings do:**
> - `maxAvailableMemory = 2048` — tells GTL it has 2GB of VRAM. Without this, GTL misdetects
>   your GPU's memory and forces minimum texture quality. Required on integrated GPUs;
>   also helps on dedicated GPUs with less than 2GB reported.
> - `maxFrameLatency = 1` — tightens the CPU-GPU pipeline, reduces frame pacing issues
> - `samplerAnisotropy = 8` — fixes blurry/broken track line markings when looking down long straights

DXVK reads this file before the game starts. GTL cannot overwrite it.

---

## Part 6: Graphics Configuration

GTLConfig.exe lets you set resolution, window mode and colour depth.

> **Why can't I just edit the config file?** GTL rewrites `Config.ini` on every single launch.
> Any manual edits get overwritten. You must use GTLConfig.exe to change settings — it writes
> them in the format GTL expects.

> **Why does directory matter?** GTLConfig.exe writes `Config.ini` into whichever folder it is
> *launched from*, not necessarily the GTL folder. If it's launched from the wrong place the
> settings file ends up somewhere GTL never looks, and your changes have no effect. Always
> launch GTLConfig via the launcher script — it `cd`s to the GTL folder first automatically.

Use the **GTLConfig** option in `scripts/launch-gtl.sh`.

**Recommended settings:**
- **Windowed mode** — prevents GTL from taking over all your monitors
- Resolution: your native screen resolution, or one step below if performance is poor (e.g. 1600×900)
- 32-bit colour
- VSync: personal preference

### Optional: XD Telemetry Overlay

XD is a live in-game overlay showing tyre temperatures, wear, fuel load and lap timing. It works
as a `d3d9.dll` wrapper in the GTL folder that chains through to DXVK — both work together
without conflict. Download it from [vitumo.de](http://www.vitumo.de/).

**Install:**
```bash
cp XD.v2.1.16/d3d9.dll ~/Games/GTLegends-Prefix/drive_c/GTL/d3d9.dll
```

XD creates an `XD.ini` file in the GTL folder on first launch. Two settings you'll likely want to adjust:

```ini
ToggleKey=220   ; German keyboard (^). For English keyboard use 192 (`)
Scale=100       ; XD was designed for 1024×768 — try 150–200 for 1080p displays
```

**To remove XD:** `rm ~/Games/GTLegends-Prefix/drive_c/GTL/d3d9.dll`

---

## Part 7: Launcher Script

`scripts/launch-gtl.sh` provides a single menu for all GTL tools. Rather than remembering
which Wine runner to use for which program, or how to work around the blue background bug,
you just run the script and pick what you want.

| Option | What it does |
|---|---|
| GT Legends | Launches via Lutris with automatic CPU affinity applied |
| AutoUpdater | Launches with the blue-background fix applied automatically |
| GTLConfig | Launches from the correct working directory so settings are saved in the right place |
| LowGuard | Launches the anti-cheat client |
| ZeroTier: Connect / Disconnect | Starts/stops the ZeroTier VPN on demand |

**Setup:** Edit `scripts/launch-gtl.sh` and fill in your paths at the top of the file
(prefix path, runners path). The script has comments explaining each variable.

**Desktop shortcut:**

Edit `scripts/GTL-Launcher.desktop` and replace `/path/to/GTLegends+ABB.Linux` with the
actual path where you cloned the repo (e.g. `~/Desktop/Coding/GTLegends+ABB.Linux`). Then:

```bash
cp scripts/GTL-Launcher.desktop ~/Desktop/
chmod +x ~/Desktop/GTL-Launcher.desktop
```

---

## Part 8: First Launch

1. Click **Play** in Lutris (or use the **GT Legends** option in the launcher script)
2. **Enter your Online Key** when prompted — this is the key printed on the back of the
   GTL manual. It is *not* the same as the DVD serial key. There are two separate keys;
   you need the one labelled "Online Key" or "Multiplayer Key".
3. Run a test race (single player → quick race) to confirm everything is working before
   going online

---

## Part 9: Online Play

### 9.1 Install LowGuard Anti-Cheat (Optional)

LowGuard is **not required** to join ABB servers or race online. The game works without it.
However, any lap records you set while not running LowGuard will not be accepted for the
official records board.

If you want your times to count, install LowGuard:

**Step 1 — Install Wine Mono (.NET runtime):**

LowGuard is a .NET application. Wine Mono provides the .NET runtime inside the Wine prefix.
Download and install it with these commands (copy-paste the whole block):

```bash
curl -L -o /tmp/wine-mono-9.4.0-x86.msi \
    https://dl.winehq.org/wine/wine-mono/9.4.0/wine-mono-9.4.0-x86.msi

WINEPREFIX=~/Games/GTLegends-Prefix \
~/.local/share/lutris/runners/wine/wine-10.20-staging-amd64/bin/wine \
    msiexec /i /tmp/wine-mono-9.4.0-x86.msi
```

A Wine installer window will open — follow it through to completion.

**Step 2 — Copy LowGuard files into the GTL folder:**

```bash
cp lowGuard.exe lowGuard.Base.dll lowGuard.Client.dll \
   lowGuard.exe.config log4net.dll \
   ~/Games/GTLegends-Prefix/drive_c/GTL/
```

Adjust the source path to wherever you downloaded the LowGuard files.

**Step 3 — Launch LowGuard:**

Use the **LowGuard** option in the launcher script. On first launch, go to LowGuard settings
and set the GTL path to `C:\GTL`. LowGuard will then launch GTL when you connect to a server.

> **Note:** Do not add `WINEDLLOVERRIDES="mscoree=d"` to any LowGuard launch configuration —
> this disables the .NET runtime LowGuard depends on.

### 9.2 Open Firewall Ports

If you have a firewall active, open the ports the AutoUpdater uses for P2P content downloads:

```bash
sudo ufw allow 8435:8439/tcp
```

### 9.3 ZeroTier — Private Races with Friends (Optional)

ZeroTier creates a virtual private network (like a LAN) that lets you race with friends without
needing to set up port forwarding on your router. It works on Linux, Windows and macOS.

**Install ZeroTier:**

```bash
curl -s https://install.zerotier.com | sudo bash
sudo systemctl disable zerotier-one   # don't start automatically — we'll start it manually when needed
```

**Set up a private race network:**

1. Go to [my.zerotier.com](https://my.zerotier.com) → create a free account → create a new Network
2. Share the **Network ID** (a 16-character code) with your friends
3. Each person joins with: `sudo zerotier-cli join [Network ID]`
4. Back on the website, go to your network's **Members** list and click the tick next to each
   person to authorize them
5. Everyone now has a ZeroTier IP address — use these to connect to each other's game servers

> **Note:** GTL's built-in server browser uses UDP broadcast, which ZeroTier doesn't carry.
> Connect to friends directly using their ZeroTier IP address instead of the server browser.

---

## Part 10: Backup & Archive

### Where Everything Lives

| Location | Contents |
|---|---|
| `~/Games/GTLegends-Prefix/` | Your complete Wine prefix — installed game, all ABB content, saves, configs |
| `~/Games/GTLegends-Archive/` | Compressed archive cache — the original `.zip`/`.7z` files downloaded by the AutoUpdater |

These are independent. The prefix is what you play from. The archive is the download cache —
not needed to run the game, but invaluable for reinstalls (skips all the P2P downloading).

### Save Files Location

Your personal save files (career progress, setup files, replays) are here:

```
~/Games/GTLegends-Prefix/drive_c/users/[your-username]/My Documents/GT Legends/
```

### Backing Up Your Installation

**Method 1 — Full prefix backup (recommended):**

```bash
tar -czf GTL_backup_$(date +%Y%m%d).tar.gz ~/Games/GTLegends-Prefix/
```

This creates a single compressed file named e.g. `GTL_backup_20260318.tar.gz`. Size: ~20–25GB.

To restore on any machine (replaces any existing prefix):
```bash
rm -rf ~/Games/GTLegends-Prefix
tar -xzf GTL_backup_YYYYMMDD.tar.gz -C ~/Games/
```

**Method 2 — Lutris export:**

In Lutris: right-click GT Legends → **Export game** → save the `.lutris` file. This exports
the game configuration. To restore: Lutris → **+** → **Import game** → select the file.

### Housekeeping

Once the game is confirmed working, `~/Games/GTLegends-Install/` (the extracted ISO, ~4.4GB)
can be safely deleted — the game is fully installed into the prefix and the original ISO is
still intact wherever you keep it:

```bash
rm -rf ~/Games/GTLegends-Install/
```

---

## Troubleshooting

### Game crashes immediately / won't start

Run GTL from the terminal to see the error output directly:

```bash
WINEPREFIX=~/Games/GTLegends-Prefix \
~/.local/share/lutris/runners/wine/wine-11.3-staging-amd64/bin/wine \
    ~/Games/GTLegends-Prefix/drive_c/GTL/GTL.exe
```

Copy any error messages and search for them — or post them in the ABB forums.

### DXVK not loading

After launching GTL, check whether `dxvk.log` has appeared:

```bash
ls ~/Games/GTLegends-Prefix/drive_c/GTL/dxvk.log
```

If the file doesn't exist, DXVK is not loading. Open the Lutris YAML file
(`gedit ~/.config/lutris/games/gt-legends-*.yml`) and check that it contains the following,
with correct indentation — **indentation matters in YAML**:

```yaml
wine:
  dxvk: true                  # must be indented under wine:, not at column 0
  esync: true
  version: wine-11.3-staging-amd64
system:
  env:
    WINEDLLOVERRIDES: "d3d9=n,b"
```

### AutoUpdater shows blue fullscreen background

Always launch the AutoUpdater via the launcher script (`scripts/launch-gtl.sh`), not directly
through Lutris. The script applies a fix before launching.

### AutoUpdater won't recognize archive / shows everything as needing download

- Check the archive path in AutoUpdater settings is set to `C:\GTL_Archive`
- Verify the symlink: `ls ~/Games/GTLegends-Prefix/drive_c/GTL_Archive/` should show your archive contents
- `.p2p` torrent files must stay alongside their matching `.zip`/`.7z` files — don't move them separately
- Fix permissions if needed: `chmod -R u+r ~/Games/GTLegends-Archive/`
- Try **Commands → Reinstallation** to force a full rescan

### AutoUpdater shows red (!) icon

The red icon means the AutoUpdater can't accept incoming P2P connections. Check:
- Ports 8435–8438 are allowed in your firewall (see Part 9.2)
- If you're behind a router, those ports need to be forwarded to your machine

### Kicked from ABB server immediately after joining

Most likely cause: missing or incomplete car/track content. Run AutoUpdater →
**Commands → Reinstallation**, let it complete, then try joining again.

### Screen stays dark after GTL crash

GTL sets display brightness/gamma when it starts and doesn't restore it when it crashes.
Fix it instantly with:

```bash
xgamma -gamma 1.0
```

> **Note:** `xrandr --gamma` does NOT fix this — it uses a different API. Use `xgamma`.

### Wrong car preview image / crash on car selection screen

An incomplete livery folder exists (has a `.CAR` file but is missing textures and other files).
Find any orphaned livery folders with:

```bash
find ~/Games/GTLegends-Prefix/drive_c/GTL/GameData/Teams \
    -mindepth 2 -maxdepth 2 -type d | while read dir; do
    count=$(ls "$dir" | wc -l)
    [ "$count" -eq 1 ] && echo "Orphaned livery: $dir"
done
```

Delete any directories listed in the output.

### LowGuard won't start

Wine Mono (the .NET runtime) may not be installed correctly. Re-run the installation command
from Part 9.1 — if Mono is already installed it will say so; if not it will install it.

> Reminder: do not use `WINEDLLOVERRIDES="mscoree=d"` when running LowGuard.

### Occasional key drops (keyboard users)

An arrow key occasionally stops responding mid-race. Press and release the key once to recover.
This is a known Linux/Wine/X11 issue currently under investigation.
See [TECHNICAL.md](TECHNICAL.md) for full analysis and the diagnostic tool in `debug/`.

---

## Known Issues

| Issue | Status | Workaround |
|---|---|---|
| Occasional key drops (keyboard users) | Under investigation | Release and repress key — steering wheel users unaffected |
| Finchfields track (P2P deadlock) | Server-side issue | Download manually from altbierbude.de and place in archive folder |
| AutoUpdater HTTP downloads stall | P2P is primary; FTP works if your ABB account includes access | Download content manually from altbierbude.de and place in archive folder |

---

## Resources

### Altbierbude
- [altbierbude.de](https://www.altbierbude.de/) — community home, forums, downloads
- [ABB Installation Wiki (English)](http://wiki.bierbuden.de/GTLInstallation/en)
- [AutoUpdater Guide (English)](http://wiki.bierbuden.de/Der_Gruene_Autoupdater/en)

### Wine / Linux Gaming
- [WineHQ AppDB — GT Legends](https://appdb.winehq.org/objectManager.php?sClass=application&iId=3588)
- [ProtonDB — GT Legends](https://www.protondb.com/app/44690)
- [r/linux_gaming](https://www.reddit.com/r/linux_gaming/)
- [Lutris documentation](https://lutris.net/documentation)
- [Kron4ek/Wine-Builds](https://github.com/Kron4ek/Wine-Builds/releases) — the Wine runner builds used in this guide
