---
name: controlphone
description: Control a real iPhone from the Mac over USB — launch apps, read device info/app list, and (with WebDriverAgent up) tap/type/swipe/screenshot. Use when the user says "control my phone", "open <app> on my phone", "tap/type/screenshot my phone", "drive my iPhone from the terminal", or references controlphone / iphonectl / TapKit-style control.
---

# /controlphone — control a real iPhone from the Mac

Open-source, TapKit-inspired. Repo: `~/projects/iphonectl`. One entrypoint
(`bin/controlphone`) that routes each verb to the transport that actually works for it,
plus a full Path B (WebDriverAgent CLI+MCP) and Path A (native Swift) underneath.

Real device on this Mac: iPhone 17 Pro, UDID `00000000-0000000000000000`, iOS 27.0.
Scope: the user's own device, for interoperability (DMCA §1201(f)).

## The one command (start here)

```bash
~/projects/iphonectl/bin/controlphone <verb>
```

| Verb | What it does | Transport | Needs |
|---|---|---|---|
| `list` | connected physical devices | `xcrun devicectl` | Xcode CLT |
| `info` | name / model / iOS / build / UDID | go-ios lockdownd | USB + Trust |
| `apps [filter]` | installed apps → bundle ids | go-ios lockdownd | USB + Trust |
| `open <name\|bundle>` | **launch an app on the phone** | `xcrun devicectl` (self-mounts DDI) | USB + Trust, unlocked |
| `screenshot [out.png]` | capture the screen | Path B (WDA) | `iphonectl-setup up` |
| `tap <x> <y>` | tap at coordinates | Path B (WDA) | `iphonectl-setup up` |
| `type <text>` | type into focused field | Path B (WDA) | `iphonectl-setup up` |

`list` / `info` / `apps` / `open` work over USB with **no tunnel** — this is the reliable
path and what to reach for first. `open` resolves an app *name* to its bundle id against the
phone's own installed-apps list, then launches via Apple's first-party `devicectl` (which
mounts the Developer Image itself on iOS 17+, so no go-ios tunnel is required).

Verified live 2026-09-28: `controlphone open Muse` → HatchApp running (PID confirmed);
`controlphone info` → iPhone18,1 / iOS 27.0.

## Build

```bash
cd ~/projects/iphonectl
make            # builds Path B (Go CLI+MCP) + Path A (native Swift, release)
make install    # symlinks controlphone + binaries into ~/.local/bin
make verify     # build, then `controlphone list` + `info` as a live smoke test
```

## Path B — WebDriverAgent (full tap/type/swipe/screenshot)

`open`/`info`/`apps`/`list` do not need this; `tap`/`type`/`screenshot` do.

```bash
cd ~/projects/iphonectl
./bin/iphonectl-setup tunnel     # terminal 1 — stays running, sudo (iOS 17+)
./bin/iphonectl-setup install    # first run only: sign + install WDA on the phone
./bin/iphonectl-setup up         # run WDA, forward :8100, create a session -> ~/.config/iphonectl/session-id
```

Then `controlphone tap/type/screenshot` route through the generated CLI
`~/projects/iphonectl/wda/iphonectl-pp-cli` (build: `make wda`). Every generated command has
`--json`, `--select`, `--dry-run`. MCP server (every command as an MCP tool):
`~/projects/iphonectl/wda/build/iphonectl-pp-mcp-darwin-arm64.mcpb`.

## Path A — native, nothing installed on the phone

Swift package at `~/projects/iphonectl/native` (`make native`; binary
`.build/release/iphonectl-native`): `devices`, `screenshot out.png`, `hid-descriptor`,
`tap`, `type`. Builds spec-correct USB-HID reports (keyboard + absolute pointer) and the
CoreMediaIO capture code.

**Current wall (honest):** on iOS 27 the phone does not publish a CoreMediaIO
screen-capture device to an unsigned CLI (raw CMIO enumeration shows only Mac/virtual
cameras), and live HID injection needs the private CoreBluetooth L2CAP transport. So Path A
prints HID wire bytes via a DryRun transport rather than injecting. For live control today,
use `open` (devicectl) or Path B (WDA). Details: `native/Sources/iphonectl-native/BluetoothHID.swift`.

## Routing

- "open <app> on my phone" / "launch X" → `controlphone open <X>` (works now, no tunnel).
- "what's on my phone" / "device info" → `controlphone apps` / `controlphone info`.
- "tap / type / swipe / screenshot" → Path B: `iphonectl-setup up`, then `controlphone tap/type/screenshot`.
- "control it with nothing installed" → Path A (screen-capture + HID walls noted above).

## Ground truth / setup

- go-ios: `~/go/bin/go-ios` (`info`, `apps`, `devicename`, `tunnel start`, `ui install wda`, `runwda`, `forward`).
- `xcrun devicectl` (Xcode CLT) — first-party device control; `list devices`, `device process launch`, `device info processes`.
- Apple signing (for Path B WDA): team `2KJ8W6N44B` (ESBE), ASC key `~/.appstoreconnect/private_keys/AuthKey_R7RQM8U3QY.p8`.
- Repo not yet published to GitHub (local only) as of 2026-09-28.
