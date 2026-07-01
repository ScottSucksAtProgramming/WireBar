# WireBar

**Your network, at a glance.**

WireBar is a macOS menu bar utility that puts Wi-Fi status, VPN management, and detailed network information in a single, always-accessible popover. No more juggling System Settings, separate VPN apps, and terminal commands — everything you need is one click away.

<p align="center">
  <!-- TODO: Add screenshot of the popover -->
  <em>Screenshot coming soon</em>
</p>

## Features

### Free

- **Wi-Fi status in your menu bar** — network name and signal strength, always visible
- **Available networks** — see and switch between Wi-Fi networks without opening System Settings
- **Known networks first** — saved networks pinned to the top, sorted by signal strength
- **One-click switching** — join saved networks instantly, enter passwords for new ones
- **Ethernet detection** — automatically shows wired connection info when plugged in
- **Local IP address** — displayed in the popover, click to copy
- **Wi-Fi toggle** — turn Wi-Fi on/off from the popover
- **Dark/light mode** — follows your system appearance

### Paid — $12.99 one-time

- **VPN monitoring & control** — see all your VPNs and toggle them on/off with a single click
- **Auto-discovers every VPN** — WireGuard, Tailscale, Mullvad, NordVPN, corporate VPNs — if macOS sees it, WireBar sees it
- **External IP address** — verify your public IP, auto-refreshes when VPNs connect/disconnect
- **Ping & latency** — live latency indicator to a configurable target
- **Advanced network details** — band, channel, link speed, BSSID, DNS, gateway, subnet
- **Notifications** — alerts when a VPN drops, your IP changes, or Wi-Fi disconnects
- **Global hotkeys** — configurable keyboard shortcuts for the popover, VPN toggles, and more
- **Configurable menu bar** — choose exactly what's shown: icon, SSID, VPN indicators, IP address

**Buy once, keep it forever.** Your license never expires and the app keeps working at the version you have.

## Requirements

- macOS 13 (Ventura) or later
- Location Services permission (required by macOS for Wi-Fi scanning)

## Installation

Download the latest `.dmg` from [Releases](../../releases), open it, and drag WireBar to your Applications folder. The app is Developer ID signed and notarized by Apple.

WireBar updates automatically via Sparkle — you'll get a notification when a new version is available.

## Privacy

- **No data leaves your Mac.** All network information stays in memory — nothing is written to disk or sent anywhere.
- **No telemetry.** Crash reporting is opt-in only and ships disabled.
- **No account required.** License activation is a one-time key validation.
- **HTTPS only.** The only external calls are license validation and external IP lookup, both over HTTPS.

## FAQ

**How does VPN discovery work?**
WireBar uses Apple's Network Extension framework to detect all VPN profiles registered with macOS. Any VPN app that creates a system VPN profile (which is most of them) will appear automatically — no configuration needed.

**Can WireBar toggle my VPN?**
Yes. WireBar connects and disconnects VPNs through the macOS Network Extension API. This is the same mechanism System Settings uses.

**Does it work with Ethernet?**
Yes. WireBar detects wired connections automatically and shows Ethernet info alongside (or instead of) Wi-Fi details.

**What happens if I don't buy a license?**
All Wi-Fi features work forever for free. The paid tier unlocks VPN management, external IP, notifications, hotkeys, and advanced network details.

## Built With

- Swift & SwiftUI
- CoreWLAN & Network framework
- Network Extension framework
- Sparkle (auto-updates)

## License

[Business Source License 1.1](LICENSE.md) — converts to Apache 2.0 after the change date specified in the license.

---

<p align="center">
  <a href="../../releases">Download</a>&ensp;·&ensp;<a href="../../issues">Report a Bug</a>&ensp;·&ensp;<a href="../../discussions">Discuss</a>
</p>
