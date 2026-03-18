# GT Legends + Altbierbude on Linux

**Status: Fully working as of March 2026** — game runs well, online multiplayer
confirmed, all ABB community content supported.

GT Legends (SimBin, 2005) running on Linux via Wine + Lutris, with full
[Altbierbude (ABB)](https://www.altbierbude.de/) community integration — the
primary German GT Legends online community, providing ~28GB of additional cars,
tracks, and patches with active multiplayer servers.

---

## What Works

- Full game running via Wine + DXVK at 60-70fps
- Complete ABB content installation (~28GB cars, tracks, patches)
- Online multiplayer on ABB servers
- LowGuard anti-cheat (optional, required only for record times)
- ABB AutoUpdater for keeping content up to date
- XD live telemetry overlay
- ZeroTier gaming VPN for private races with friends
- CPU affinity tuning for better performance on multi-core systems

## Known Issues

| Issue | Impact | Workaround |
|---|---|---|
| Occasional key drops (keyboard users) | Minor — release and repress key | Under investigation; steering wheel users unaffected |
| Finchfields track (server-side P2P deadlock) | Minor — track rarely raced on ABB | Download manually from altbierbude.de |

---

## Documentation

| Document | What's in it |
|---|---|
| [INSTALL.md](INSTALL.md) | Step-by-step installation guide for all users |
| [TECHNICAL.md](TECHNICAL.md) | Root cause analyses, Wine internals, AutoUpdater reverse engineering |

---

## Requirements

- Linux (tested on Ubuntu / Linux Mint)
- GT Legends installation media (original DVD or ISO)
- Free Altbierbude account — register at [altbierbude.de](https://www.altbierbude.de/)
- Online Key (printed on the back of the GT Legends manual)
- ~80GB free disk space
- Lutris + Wine (setup covered in [INSTALL.md](INSTALL.md))

---

## Quick Start

See [INSTALL.md](INSTALL.md) for the full guide. The short version:

1. Install Lutris and two Wine runners from [Kron4ek/Wine-Builds](https://github.com/Kron4ek/Wine-Builds/releases)
2. Install GTL into a 32-bit Wine prefix via Lutris
3. Run the ABB AutoUpdater to download and install ~28GB of community content
4. Configure DXVK and launch via the provided launcher script

---

## Project Background

Getting GT Legends online on Linux involved solving several non-obvious problems:
an Intel GPU VRAM detection bug fixed via DXVK configuration, a Wine runner split
to work around a GDI crash in Wine 11.3, reverse engineering the AutoUpdater's
Python bytecode to diagnose a queue-blocking installer bug, and tracking down an
X11 keyboard grab issue causing input drops. All findings are documented in
[TECHNICAL.md](TECHNICAL.md).

---

## Contributing

Found a fix for the key drop bug? Know which background process is calling
`XGrabKeyboard`? Tested this on a different distro or hardware? Contributions
and reports are welcome.
