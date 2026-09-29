---
name: controlphone
description: Control a real iPhone from the Mac over USB — launch apps, read device info/app list, and (with WebDriverAgent up) tap/type/swipe/screenshot. Use when the user says "control my phone", "open <app> on my phone", "tap/type/screenshot my phone", "drive my iPhone from the terminal", or references controlphone / iphonectl / TapKit-style control.
---

# /controlphone — control a real iPhone from the Mac

Open-source, TapKit-inspired. Repo: `~/projects/iphonectl`. One entrypoint
(`bin/controlphone`) that routes each verb to the transport that actually works for it,
plus a full Path B (WebDriverAgent CLI+MCP) and Path A (native Swift) underneath.

Reference device: iPhone 17 Pro, iOS 27.0. The UDID is resolved dynamically at
runtime (`xcrun devicectl list devices`) — nothing is hardcoded; override with `UDID=<udid>`.
Scope: your own device, for interoperability (DMCA §1201(f)).

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
| `screenshot [out.png]` | capture the screen | go-ios screenshotr (WDA fallback) | tunnel running |
| `tap <x> <y>` | tap at coordinates (points) | Path B (WDA REST) | `iphonectl-setup wda` |
| `swipe <x1> <y1> <x2> <y2>` | drag/scroll (points) | Path B (WDA REST) | `iphonectl-setup wda` |
| `type <text>` | type into focused field | Path B (WDA REST) | `iphonectl-setup wda` |

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

## Path B — WebDriverAgent (full tap/swipe/type)

**Working bring-up (verified live 2026-09-28, iPhone 17 Pro / iOS 27.0 — drove a full camera e2e):**

```bash
cd ~/projects/iphonectl
sudo -n ~/go/bin/go-ios tunnel start --udid=<UDID> &   # iOS 17+ tunnel (sudo is passwordless here)
./bin/iphonectl-setup wda     # clones appium/WebDriverAgent -> vendor/, xcodebuild test with
                              # ASC-key auto-provisioning (team 2KJ8W6N44B, key R7RQM8U3QY),
                              # waits for ServerURLHere, forwards device:8100 -> first free
                              # local port (writes ~/.config/iphonectl/port), creates session
./bin/controlphone tap 271 82 # points = screenshot pixels / 3
```

Why this path and not `install`/`up`: `go-ios ui install wda` needs a `.p12` + a *development*
profile covering the WDA bundle id. The only dev profile on this Mac is app-specific
(`com.improvebayarea.app`), and exporting the dev identity to a p12 triggers a keychain-export
password prompt. xcodebuild signs in place with the keychain identity and mints the WDA profile
itself. This go-ios build has **no `sign` subcommand** (older docs suggesting
`go-ios sign provision appstoreconnect` are wrong for it).

Traps found live:
- `:8100` and `:8101` are held by the **mobilecli daemon** (mobile-mcp). Forwarding to them fails
  with `bind: address already in use` and curl reports `Connection reset by peer`. `wda` picks a
  free port; tap/swipe/type read it from `~/.config/iphonectl/port`.
- **mobile-mcp screenshot/tap ETIMEDOUT on iOS 27** even with a fresh tunnel and healthy
  installationproxy (`controlphone apps` works) — its DeviceKit capture path is what is broken.
  Use controlphone, not mobile-mcp, for the physical phone.
- A stale go-ios tunnel makes installationproxy look dead ("context canceled"). Restart the phone
  tunnel first; do not conclude pairing is broken off one hang.
- WDA also listens on the phone's Wi-Fi IP (`ServerURLHere->http://10.0.0.62:8100` in the log) —
  a usable fallback if the USB forward misbehaves.

Legacy (still present): `iphonectl-setup install` (p12+profile via go-ios) and `up` (runwda +
forward on 8100). Generated REST CLI `wda/iphonectl-pp-cli` + MCP bundle remain available.

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
- "screenshot" → `controlphone screenshot` (go-ios screenshotr; no WDA needed).
- "tap / type / swipe" → Path B: `iphonectl-setup wda`, then `controlphone tap/swipe/type`.
- "control it with nothing installed" → Path A (screen-capture + HID walls noted above).

## Ground truth / setup

- go-ios: `~/go/bin/go-ios` (`info`, `apps`, `devicename`, `tunnel start`, `ui install wda`, `runwda`, `forward`).
- `xcrun devicectl` (Xcode CLT) — first-party device control; `list devices`, `device process launch`, `device info processes`.
- Apple signing (for Path B WDA): team `2KJ8W6N44B` (ESBE), ASC key `~/.appstoreconnect/private_keys/AuthKey_R7RQM8U3QY.p8`.
- Repo not yet published to GitHub (local only) as of 2026-09-28.
