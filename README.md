# WireBar

**Your network, at a glance.**

<p align="center">
  <!-- TODO: Add screenshot of the popover -->
  <em>Screenshot coming soon</em>
</p>

## What is WireBar?

WireBar is a native macOS menu bar app that gives you instant access to your Wi-Fi status, VPN connections, and network details — all from a single click on your menu bar. It replaces the need to dig through System Settings, open separate VPN apps, or run terminal commands just to check your network.

It lives in your menu bar, stays out of your way, and shows you exactly what you need when you need it.

## Who is it for?

- **Remote workers** who switch between home, office, and coffee shop networks and need to keep VPNs connected
- **Developers and IT professionals** who need quick access to IP addresses, DNS servers, gateway info, and latency stats
- **Privacy-conscious users** who want to verify their VPN is active and their public IP is what they expect
- **Anyone tired of macOS burying network info** across System Settings, Wi-Fi menus, and third-party VPN apps

## The Problem

macOS splits network management across too many places. Want to check your Wi-Fi signal? Menu bar. Switch networks? System Settings. See if your VPN is connected? Open the VPN app. Check your IP address? Open Terminal. Check your public IP? Open a browser.

WireBar puts all of that in one popover, one click away, all the time.

## Features

### Free — forever

- **Wi-Fi status in your menu bar** — network name and signal strength, always visible
- **Available networks** — see and switch between Wi-Fi networks without opening System Settings
- **Known networks first** — saved networks pinned to the top, sorted by signal strength
- **One-click switching** — join saved networks instantly, enter passwords for new ones
- **Ethernet detection** — automatically shows wired connection info when plugged in
- **Local IP address** — displayed in the popover, click to copy
- **Wi-Fi toggle** — turn Wi-Fi on/off from the popover
- **Dark/light mode** — follows your system appearance

### Pro — $12.99 one-time

- **VPN monitoring & control** — see all your VPNs and toggle them on/off with a single click
- **Auto-discovers every VPN** — WireGuard, Tailscale, Mullvad, NordVPN, corporate VPNs — if macOS sees it, WireBar sees it
- **External IP address** — verify your public IP, auto-refreshes when VPNs connect/disconnect
- **Ping & latency** — live latency indicator to a configurable target
- **Advanced network details** — band, channel, link speed, BSSID, DNS, gateway, subnet
- **Notifications** — alerts when a VPN drops, your IP changes, or Wi-Fi disconnects
- **Global hotkeys** — configurable keyboard shortcuts for the popover, VPN toggles, and more
- **Configurable menu bar** — choose exactly what's shown: icon, SSID, VPN indicators, IP address

**Buy once, keep it forever.** No subscription. No renewal. Your license never expires and the app keeps working at the version you have.

## Download & Install

1. Download the latest `.dmg` from [Releases](../../releases)
2. Open the `.dmg` and drag WireBar to your Applications folder
3. Launch WireBar — it appears in your menu bar

WireBar is signed with an Apple Developer ID and notarized by Apple for your security. Updates are delivered automatically — you'll get a notification when a new version is available.

### Requirements

- macOS 13 (Ventura) or later
- Location Services permission (required by macOS to scan for Wi-Fi networks)

## Privacy & Trust

WireBar is built with a privacy-first philosophy:

- **No data leaves your Mac.** All network information stays in memory only — nothing is written to disk, logged, or transmitted.
- **No telemetry.** Crash reporting is opt-in only and ships disabled by default.
- **No account required.** License activation is a one-time key validation — no sign-up, no login.
- **HTTPS only.** The only external network calls the app makes are license validation and external IP lookup, both exclusively over HTTPS.
- **Open source.** The full source code is available in this repository so you can verify exactly what the app does.

## FAQ

**How does VPN discovery work?**
WireBar uses Apple's Network Extension framework to detect all VPN profiles registered with macOS. Any VPN app that creates a system VPN profile (which is nearly all of them) appears automatically — no manual configuration needed.

**Can WireBar toggle my VPN?**
Yes. WireBar connects and disconnects VPNs through the macOS Network Extension API — the same mechanism that System Settings uses.

**Does it work with Ethernet?**
Yes. WireBar detects wired connections automatically and shows Ethernet info alongside (or instead of) Wi-Fi details.

**What happens if I don't buy a license?**
All Wi-Fi features work forever for free. The Pro upgrade unlocks VPN management, external IP, notifications, hotkeys, and advanced network details.

**Is there a subscription?**
No. WireBar Pro is a one-time purchase. You pay once and the app is yours.

## Built With

- Swift & SwiftUI
- CoreWLAN & Network framework
- Network Extension framework
- Sparkle (automatic updates)

## Support

- [Report a bug](../../issues)
- [Request a feature](../../issues)
- [Discussions](../../discussions)

## License

[Business Source License 1.1](LICENSE.md) — converts to Apache 2.0 on July 1, 2029.

---

<p align="center">
  <a href="../../releases"><strong>Download WireBar</strong></a>
</p>
