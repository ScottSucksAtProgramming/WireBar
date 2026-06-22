# SignalDrop - Roadmap

## v1.0 - Initial Release

Everything defined in [SPEC.md](SPEC.md). Core features:

- Menu bar icon with configurable display
- SwiftUI popover with connection info, VPN toggles, network list
- Wi-Fi network switching (known networks prioritized)
- VPN monitoring and toggling (WireGuard, Tailscale, PIA + curated list + custom)
- Local and external IP display with configurable refresh
- Ethernet detection and display
- Ping/latency indicator
- Configurable notifications
- Extensive configurable hotkeys
- Freemium licensing via LemonSqueezy
- Auto-updates via Sparkle + GitHub Releases
- First-run setup wizard
- Full accessibility support
- Localization-ready (English only)
- Privileged helper for elevated VPN commands
- Copy/export network info to clipboard
- Opt-in crash reporting via Sentry

---

## v1.x - Post-Launch Improvements

### VPN Library Expansion
- Add pre-configured CLI commands for popular VPN apps:
  - Mullvad
  - NordVPN
  - ExpressVPN
  - ProtonVPN
  - Surfshark
  - CyberGhost
  - OpenVPN (generic)
  - Cisco AnyConnect
  - GlobalProtect
- Community contributions welcome (open source curated list)

### Polish
- Bug fixes and performance improvements based on user feedback
- Refine first-run experience based on user friction points
- Expand notification options based on user requests

---

## v2.0 - Future Features

### Popover Enhancements
- **Section reordering** - drag and drop to rearrange popover sections
- **Tailscale exit node selection** - submenu to pick exit nodes
- **PIA server selection** - choose VPN server location

### Network Features
- **Speed test** - integrated upload/download speed test
- **Network history** - log of connected networks, VPN state changes, connection events
- **Personal Hotspot** - show and manage macOS Personal Hotspot sharing

### Visual
- **Menu bar icon customization** - choose your own icon or color scheme
- **macOS Widget** - desktop or Notification Center widget showing network status

### Distribution
- **Setapp integration** - second revenue channel via Setapp subscription platform
- **App Store version** - reduced feature set (no VPN toggling, no network switching) for App Store presence and discoverability

### Localization
- Community-sourced translations
- Priority languages based on user base geography

### Platform
- **Shortcuts/Automator integration** - expose actions for macOS Shortcuts app
- **AppleScript support** - scriptable VPN toggling and network info queries
