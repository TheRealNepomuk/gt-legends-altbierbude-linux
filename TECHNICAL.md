# GT Legends + ABB — Technical Reference
**Version 1.0 — March 2026**

This document covers the internals, root cause analyses, and reverse engineering
findings behind the Linux setup. It assumes familiarity with Wine, Linux, and
basic programming concepts. For installation steps see [INSTALL.md](INSTALL.md).

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Wine Runner Split](#2-wine-runner-split)
3. [DXVK Configuration](#3-dxvk-configuration)
4. [ABB AutoUpdater Internals](#4-abb-autoupdater-internals)
5. [Blue Background Bug](#5-blue-background-bug)
6. [CPU Affinity](#6-cpu-affinity)
7. [Key Drop Bug — Investigation](#7-key-drop-bug--investigation)
8. [Config.ini Behavior](#8-configini-behavior)
9. [Online Kick Investigation](#9-online-kick-investigation)

---

## 1. Architecture Overview

### Technology Stack

| Component | Solution | Notes |
|---|---|---|
| Game runner | Wine 11.3-staging (Kron4ek) | GTL.exe only |
| Helper apps | Wine 10.20-staging (Kron4ek) | AutoUpdater, GTLConfig, LowGuard |
| Wine prefix | 32-bit (`win32`) | GTL is a 32-bit game |
| DirectX translation | DXVK 2.4.1 | DirectX 9 → Vulkan |
| ABB AutoUpdater | Python 2.7.6 + wxPython 2.8 | Runs inside Wine |
| Anti-cheat | LowGuard + Wine Mono 9.4.0 | .NET app, optional |
| Launcher | Lutris + custom shell script | GTL via Lutris, rest via script |

### Wine Prefix Structure

Everything lives inside the Wine prefix at `~/Games/GTLegends-Prefix/`:

```
drive_c/
├── GTL/                          ← game installation (39GB extracted)
│   ├── GTL.exe
│   ├── dxvk.conf                 ← DXVK settings (not touched by GTL)
│   ├── Config.ini                ← game config (rewritten by GTL on every launch)
│   ├── d3d9.dll                  ← XD telemetry wrapper (if installed)
│   ├── GameData/
│   │   ├── Locations/            ← tracks (20GB)
│   │   └── Teams/                ← cars (16GB)
│   └── UserData/                 ← profiles, saves, replays
├── GTL_Archive → ~/Games/GTLegends-Archive/  ← symlink to archive
├── Python27/                     ← Python 2.7.6 (for AutoUpdater)
└── users/[username]/
    ├── Documents/Bierbuden/      ← AutoUpdater scripts
    └── AppData/Local/lowspeed/   ← LowGuard user config
```

The archive at `~/Games/GTLegends-Archive/` stores the original compressed
packages (~34GB). It is the AutoUpdater's download cache and is separate from
the installed game. Both are needed for a self-sufficient installation; only the
prefix is needed to play.

---

## 2. Wine Runner Split

### The Problem

Wine 11.3-staging crashes when any GDI/Win32 app calls `NtUserChangeDisplaySettings`
on this hardware configuration (Intel integrated GPU + XRandR). The crash manifests
as `free(): invalid pointer` in two threads at the same offset in `libgcc_s.so.1`,
inside Wine's SEH→libgcc exception bridge.

Affected apps: AutoUpdater (wxPython GUI), GTLConfig.exe (MFC dialog),
LowGuard.exe (.NET WinForms).

**GTL.exe is not affected** because DXVK completely bypasses the GDI/Win32
display path — it initializes through Vulkan directly.

### The Solution

Two runners, one shared prefix:

| Runner | Used for | Why |
|---|---|---|
| `wine-11.3-staging-amd64` | GTL.exe (via Lutris) | Better game compatibility; DXVK bypasses GDI crash |
| `wine-10.20-staging-amd64` | AutoUpdater, GTLConfig, LowGuard | GDI/Win32 works correctly |

Both runners read from and write to the same prefix
(`~/Games/GTLegends-Prefix`). This works because the prefix is just a directory
tree — the runner is only the Wine binary executing against it.

### Why Not Use a Single Newer Runner?

The GDI crash in 11.3 is hardware-specific (Intel GPU + XRandR interaction).
Downgrading to 10.20 for everything would mean losing the game compatibility
improvements in 11.3. Upgrading the helper apps to 11.3 would mean they crash.
The split is the cleanest solution.

### Why Not wine-ge-custom?

wine-ge-custom (GloriousEggroll) was abandoned at Proton8 / wine-staging 8.0
in late 2022. wine-staging 8.0 has a critical SEH unwinding bug that crashes GTL
on launch (`ACCESS_VIOLATION` in `libgcc_s.so.1 + 0x1bcf6`). Kron4ek's
Wine-Builds provide maintained Wine-Staging builds in the same tarball format
Lutris expects.

---

## 3. DXVK Configuration

### What DXVK Does

DXVK is a Vulkan-based implementation of DirectX 9/10/11. It replaces Wine's
built-in `d3d9.dll` with a native Linux library that translates D3D9 API calls
into Vulkan. For GTL this has two effects:

1. **Performance:** Vulkan is more efficient than Wine's WGL/OpenGL path for D3D9
2. **Hardware detection fix:** GTL queries `IDirect3D9::GetAdapterIdentifier` at
   startup to set `VIDEORAM`, `TEXDETAIL`, and `SHADERLEVEL` in `Config.ini`.
   With Wine's built-in d3d9, Intel integrated GPUs return `-1023` (negative VRAM
   due to shared memory reporting). DXVK queries Vulkan's
   `VkPhysicalDeviceMemoryProperties` instead, returning a correct positive value.

### The YAML Indentation Bug

Lutris stores game config in YAML. A malformed config had `dxvk: true` at column 0
instead of indented under `wine:`:

```yaml
# BROKEN — dxvk: true is a top-level key, not under wine:
wine:
dxvk: true       ← column 0
  esync: true
  version: wine-11.3-staging-amd64
```

YAML interprets this as `dxvk` being a separate top-level key — Lutris ignores it,
never sets `WINEDLLOVERRIDES`, and Wine silently uses its own built-in d3d9.
`dxvk.log` not appearing in the GTL directory is the diagnostic indicator.

Correct config:
```yaml
wine:
  dxvk: true     ← indented 2 spaces under wine:
  esync: true
  version: wine-11.3-staging-amd64
system:
  env:
    WINEDLLOVERRIDES: "d3d9=n,b"
```

`WINEDLLOVERRIDES: "d3d9=n,b"` is a belt-and-suspenders measure — it forces Wine
to use the native d3d9.dll (DXVK) regardless of Lutris's internal DLL setup logic.

### dxvk.conf Settings Explained

```
d3d9.maxAvailableMemory = 2048
```
Tells DXVK to report 2048MB of available texture memory to the game. GTL uses this
value directly for `VIDEORAM` in `Config.ini`, which controls `TEXDETAIL` and
`SHADERLEVEL` auto-detection. Without this, Intel integrated GPUs get `-1023`.

```
d3d9.maxFrameLatency = 1
```
Limits the number of frames the CPU can prepare ahead of the GPU. Default is 3.
Setting to 1 tightens the CPU-GPU pipeline, reducing the frame pacing irregularity
("feels laggy even at 60fps") common with DXVK on older games.

```
d3d9.samplerAnisotropy = 8
```
Forces 8x anisotropic filtering at the DXVK level, overriding whatever the game
requests. Fixes broken/interrupted track line markings at shallow viewing angles —
a classic artifact of bilinear filtering at extreme perspective.

### XD Telemetry Overlay and DXVK

XD is a `d3d9.dll` wrapper placed in the GTL game folder. It intercepts D3D9 calls
to read telemetry data, then forwards them to the DXVK `d3d9.dll` in
`drive_c/windows/system32/`. The chain is:

```
GTL.exe → GTL/d3d9.dll (XD) → system32/d3d9.dll (DXVK) → Vulkan
```

This works because Wine's DLL search order checks the application directory
before system32. Both XD and DXVK are active simultaneously.

---

## 4. ABB AutoUpdater Internals

The AutoUpdater (`altbierbude_en.pyw`) is a Python 2.7 + wxPython 2.8 application
running inside Wine. Its `.pyo` bytecode files were decompiled using `uncompyle6`
to understand its behavior.

### Update Flow

The update logic is entirely **hash-based** — timestamps play no role:

1. Fetch package list from server (`func=listtracks`, `func=listcars`)
   — returns `id, filename, size, hash1:hash2` for every package
2. Compare against `installed.csv` (local record of installed packages + their hashes)
3. For each missing/mismatched package:
   - Scan archive folder using `FileExists(filename, hash)` — reads zip, computes
     `GtHash`, returns path if hash matches
   - Found locally → mark as "local" (yellow in Transfer dialog, no download)
   - Not found → queue for download (P2P or FTP)
4. Transfer dialog → user confirms → install begins
5. Each package is extracted to the correct subfolder, recorded in `installed.csv`

### GtHash Algorithm

The AutoUpdater uses a custom hash for package verification:

1. Compute SHA-1 digest of the file content
2. Encode 6 bits at a time using the custom charset:
   `0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz+-`
3. Result: 27-character string (e.g. `ZP0CqYyRh6gQ1e-5n9PC8-I62aC`)

### "Game Folder Changed" False Positive

Every time the AutoUpdater runs, it may show a dialog:
*"The game folder has changed since your last update — reinstall?"*

This is a Linux-specific false positive. The code:

```python
gpd = int(os.path.getctime(self.GetGamePath()))
```

- **Windows:** `os.path.getctime()` on a folder returns its **creation time** —
  stable, never changes
- **Linux:** `os.path.getctime()` returns the **inode change time** — updated
  whenever files are added or removed from the folder

Every AutoUpdater install modifies the GTL folder, changing its ctime. On next
launch the stored value doesn't match → dialog appears. Always click **No** —
the dialog is purely informational and has no effect on the hash-based file
comparison that follows.

### Installer Queue Clear Bug

`Installer._load()` contains a critical bug that wipes the entire install queue
on startup under certain conditions:

```python
def _load(self):
    # ... load all queue entries ...
    if not all_exists or not self.p2p and not all_ready:
        self.__clear()   # wipes and saves empty install_queue.csv
```

Python operator precedence parses this as:
```python
if (not all_exists) or ((not self.p2p) and (not all_ready)):
```

If any item has `ready=False` (e.g. a P2P-only file with no seeders), `all_ready`
is `False`. If `self.p2p` is `None` (P2P client failed to initialize), the entire
condition becomes `True` and the queue is cleared — including all the ready items
behind the broken one.

**Practical impact:** The Finchfields track (`peer2peer=True, ready=False`) caused
this condition to fire on every AutoUpdater restart, silently wiping 12 installable
tracks from the queue before they could be processed.

**Workaround:** Remove the blocking entry from `install_queue.csv` manually.

### Finchfields Hash Mismatch (Server-Side Issue)

`Finchfields_GTL_V1_01.zip` has a permanent inconsistency on the ABB server:

| Source | GtHash |
|---|---|
| `listtracks` database (expected) | `YHI99gJafTHD4DR4GzmDPQ9jEj1` |
| FTP file at `ftp.altbierbude.de` | `Y6BYFQOWGhMEuFpjXRnv5HlQeC6` |
| BitTorrent (tracker scrape, 2026-03-02) | 0 seeders, 1 completed |

The AutoUpdater downloads from FTP, computes the hash, gets a mismatch, and
concludes: *"FTP version is outdated — correct version must be on P2P."* It sets
`peer2peer=True, ready=False` and waits for a BitTorrent seeder that never comes.

The hash in the `listtracks` database corresponds to a version that was distributed
via torrent but never synced back to FTP. The single person who downloaded it is
no longer seeding.

**This affects any new installation today.** The fix is to download Finchfields
manually from the altbierbude.de website and place it in the archive.

---

## 5. Blue Background Bug

### Root Cause

When Lutris launches GTL, it writes the following key to the Wine prefix registry
(`user.reg`):

```
[Software\\Wine\\Explorer]
"Desktop"="WineDesktop"
```

This tells Wine's explorer to create a virtual desktop window — a fullscreen
`_NET_WM_WINDOW_TYPE_DESKTOP` X11 window that acts as a contained desktop
environment for all Wine applications. This key **persists in the registry** after
GTL exits.

When the AutoUpdater is launched next (even from a different script), Wine sees
the key, creates the desktop window, and the AutoUpdater appears inside a
fullscreen blue Wine desktop rather than as a normal window.

### Why Lutris Writes This Key

Lutris was configured with `Desktop: true` / `WineDesktop: 1280x800` to keep GTL
windowed. The virtual desktop wrapper was the mechanism. The side effect of it
persisting into subsequent Wine launches was not obvious.

### Fix

Two changes, both required:

1. **Remove `Desktop: true`/`WineDesktop` from Lutris config** — GTL no longer
   uses a virtual desktop wrapper and relies on its own `WINDOWEDMODE=1` setting
   instead. Lutris no longer writes the key.

2. **Launch script strips the key before starting AutoUpdater:**
   ```bash
   wineserver -k   # kill any running Wine processes first
   sleep 1
   sed -i '/^"Desktop"="WineDesktop"$/d' "${WINEPREFIX}/user.reg"
   ```
   This handles any residual key that may have been written before the Lutris
   config was fixed. It's a no-op once the config is corrected.

---

## 6. CPU Affinity

### Background

GT Legends was designed for single-core CPUs (2005). The main game loop is
single-threaded, but the overall process has background threads for audio, AI,
and file I/O. On modern multi-core systems, without affinity pinning, Linux
schedules the game onto CPU 0 — which also handles system IRQs — causing
interference and inconsistent frame times.

### Hyperthreading Topology (i5-8365U Reference)

| HT Pair | Physical Core | Recommendation |
|---|---|---|
| CPU 0 ↔ CPU 4 | Core 0 | Avoid — handles system IRQs |
| CPU 1 ↔ CPU 5 | Core 1 | Usable |
| CPU 2 ↔ CPU 6 | Core 2 | Preferred |
| CPU 3 ↔ CPU 7 | Core 3 | Preferred |

**Do not** assign both siblings of one HT pair (e.g. CPU 2 + CPU 6). They share
execution units, L1 and L2 cache — the game loop and background threads would
still contend on the same physical core.

**Recommended: CPU 2 + CPU 3.** Two independent physical cores. Main loop occupies
one, background threads use the other.

### Implementation

The AutoUpdater shows a CPU selection dialog when launching GTL from within it
(via `shortcut.ShowDialog()` → `kernel32.SetProcessAffinityMask`). This does not
appear when launching via Lutris directly.

The launcher script (`scripts/launch-gtl.sh`) replicates this using Linux's
`taskset`:

```bash
lutris lutris:rungameid/[ID] &
# wait for GTL.exe to appear in process list
while ! GTL_PID=$(pgrep -i "GTL.exe"); do sleep 1; done
taskset -cp 2,3 "$GTL_PID"
```

`taskset -cp 2,3 <pid>` is exactly equivalent to the Windows
`SetProcessAffinityMask` call the AutoUpdater makes, with the same core selection.

**Observed result:** CPU 0 drops from ~100% to 50-60% (Wine infrastructure);
game CPUs (2+3) at 40-50% each. FPS improves from ~38fps worst-case to 60-70+fps.

---

## 7. Key Drop Bug — Investigation

### Symptom

Arrow keys occasionally stop registering mid-race. The key appears "dead" until
physically released and repressed. Never occurs on Windows — Linux/Wine-specific.

A secondary failure mode also exists: if a key is physically held when the trigger
fires, Wine can latch it as pressed with no input → phantom steering. Pressing and
releasing that key once clears it.

### Confirmed Root Cause: X11 Keyboard Grabs

Confirmed via `xev -id <gtl-window>` monitoring (2026-03-12).

When volume or brightness keys are pressed, the GTL window receives:
```
FocusOut event, mode NotifyGrab, detail NotifyAncestor
```

`NotifyGrab` means an external application called `XGrabKeyboard` — which
redirects all keyboard input system-wide away from GTL's window. Wine's
`winex11.drv` handles `FocusOut NotifyGrab` by clearing all held key states
(synthesizing a phantom `KeyUp` for every held key). The game thinks the key
was released.

**Contrast:** Clicking another window produces `FocusOut mode NotifyNormal`.
Wine handles this correctly — key state is preserved.

### What Was Disproved

| Theory | Test | Result |
|---|---|---|
| CPU preemption | Stress test with 35 opponents (90-100% CPU) | No correlation with drop frequency |
| Keyboard matrix ghosting | `xev` test with all arrow keys simultaneously | Only affects 3+ simultaneous keys, not single drops |
| `UseTakeFocus=N` Wine registry setting | Applied and tested | No effect |
| Wine virtual desktop | Tested (WineHQ Bug #57423) | Makes it worse, not better |

### Wine Hardcoded Behavior

The key clear on `FocusOut NotifyGrab` is hardcoded in
`dlls/winex11.drv/event.c`. There is no Wine registry key, config option, or
wine-staging patch that changes this behavior.

### Confirmed Trigger

Volume and brightness OSD keys fire `XGrabKeyboard`. Confirmed via
`xev -id <gtl-window>` showing `FocusOut NotifyGrab` on every OSD key press.

### Unknown Trigger (Random Drops)

Drops also occur randomly during driving with no OSD key pressed. Some background
process is calling `XGrabKeyboard` occasionally. The `debug/monitor-grabs.sh`
tool watches for `FocusOut NotifyGrab` events and logs the timestamp and active
window — run it alongside GTL to identify the culprit.

### Next Pending Test

`debug/xset-repeat-test.sh` (accessible from the launcher menu as
"Key Repeat Test") tests an alternative hypothesis: Wine's auto-repeat filtering
race condition.

Wine peeks ahead in the X11 event queue to filter fake `KeyRelease` events
generated during key repeat. Under load this peek can misfire and swallow a real
keypress. Disabling X11 key repeat (`xset r off`) removes this filtering entirely.

- Drops stop → auto-repeat filtering confirmed as cause. Fix: wrap GTL launch
  with `xset r off` / `xset r on`.
- Drops continue → ruled out. Next step: full 4-layer pipeline monitor (kernel
  evdev → XI2 raw → X11 window delivery → Wine/DirectInput).

### Debug Tools

| Tool | Location | Purpose |
|---|---|---|
| `monitor-grabs.sh` | `debug/` | Logs all X11 grab events with timestamp + window info |
| `xset-repeat-test.sh` | `debug/` | Disables key repeat for a session to test that hypothesis |

---

## 8. Config.ini Behavior

### GTL Rewrites Config.ini on Every Launch

`Config.ini` is not a simple INI file — it is a binary container that GTL
rewrites from scratch on every launch based on live hardware detection. Manual
edits are overwritten immediately.

The only correct way to change GTL settings is via `GTLConfig.exe`, which feeds
values into GTL's internal configuration system before the game itself runs.

### GTLConfig Working Directory Requirement

`GTLConfig.exe` writes `Config.ini` into whatever directory it is executed from
(its working directory), not the GTL installation directory. If launched from
`~/` or any other location, the config file ends up there and GTL — which looks
for `Config.ini` in its own directory — never sees it.

The launcher script always `cd`s to the GTL directory before launching GTLConfig:
```bash
cd ~/Games/GTLegends-Prefix/drive_c/GTL
wine GTLConfig.exe
```

### DXVK Bypasses the VRAM Problem

GTL's hardware detection queries DirectX 9 for adapter memory. With Wine's
built-in d3d9, Intel integrated GPUs report negative VRAM (shared memory
reporting underflow → `-1023`). GTL uses this value directly for `VIDEORAM`,
which drives `TEXDETAIL` and `SHADERLEVEL` — resulting in minimum quality.

With DXVK active, the query goes to Vulkan (`VkPhysicalDeviceMemoryProperties`),
which reports correctly. Combined with `d3d9.maxAvailableMemory = 2048` in
`dxvk.conf`, GTL detects 2044MB and auto-sets `TEXDETAIL=3`.

`dxvk.conf` is read by DXVK before the game starts and is never touched by GTL.

---

## 9. Online Kick Investigation

### Symptom

After joining an ABB server lobby, the client was kicked after ~5 seconds with
no error message.

### Things Ruled Out

- UFW firewall (inactive)
- GTL version (confirmed 1.1.0.0)
- Network connectivity (game.altbierbude.de pingable, port 810 open)
- Online key (correct key confirmed in registry)
- LowGuard authentication
- `garage.gar` corruption (regenerated, still kicked)

### Root Cause

**Missing car files.** The TC-65, GTC-65, and GTC-TC-76 car packages were present
in the archive but not yet extracted into the game folder. The ABB server performs
a content check when a client joins — cars that exist on the server but not on the
client result in an immediate kick.

Once those three car classes were fully installed via the AutoUpdater, the client
joined successfully.

### LowGuard and Wine Mono

LowGuard is a .NET 4.x application. The `winetricks dotnet48` verb does not work
with the installed winetricks version. The correct approach is to install Wine
Mono 9.4.0 directly:

```bash
wine msiexec /i wine-mono-9.4.0-x86.msi
```

Wine Mono provides .NET compatibility inside the prefix without requiring the full
Windows .NET Framework. Do not use `WINEDLLOVERRIDES="mscoree=d"` alongside
LowGuard — that override disables the .NET runtime entirely.

LowGuard stores its GTL path setting in AppData (not `lowGuard.exe.config`):
```
drive_c/users/[username]/AppData/Local/lowspeed/
  lowGuard.exe_Url_.../1.0.0.0/user.config
```
The GTL path must be set via the LowGuard settings UI — editing `exe.config`
has no effect at runtime.
