# SignalDrop - Design Decision Log

Record of all decisions made during the initial product design session (2026-06-22).

---

## Q1: Technology Stack

**Decision:** Swift + SwiftUI

**Why:** Native macOS choice. Direct access to CoreWLAN (Wi-Fi APIs), NetworkExtension (VPN APIs), and system-level integrations without bridging layers. Lightweight — important for an always-running menu bar app. Alternatives like Electron or Tauri would add unnecessary bloat.

---

## Q2: App Store vs. Direct Distribution

**Decision:** Direct distribution (Developer ID signed + notarized)

**Why:** Several core features are impossible or severely restricted under App Store sandboxing:
- Switching Wi-Fi networks (CoreWLAN restricted in sandbox)
- Toggling VPNs (NetworkExtension requires Apple approval + limited to Apple VPN frameworks)
- Reading Wi-Fi details (gated entitlements)

Features are more important than App Store presence. Many successful Mac utilities (Bartender, iStat Menus, Little Snitch) use direct distribution for the same reasons. App Store version with reduced features is a future roadmap item.

---

## Q3: Menu Bar Icon

**Decision:** Configurable display. User chooses what to show from: Wi-Fi signal strength icon, network name, VPN status indicators, IP address.

**Default:** Wi-Fi icon + network name.

**Why:** Scott wants to see network name by default, but also sometimes wants VPN status or IP visible. Making it configurable satisfies all use cases without cluttering the menu bar.

---

## Q4: VPN Protocols/Clients

**Decision:** Support WireGuard, Tailscale, and Private Internet Access as primary. Curated library of popular VPNs. Custom VPN support for power users.

**Scott's setup:** Uses WireGuard and Tailscale regularly. PIA installed but used rarely.

---

## Q5: VPN Toggle Behavior

**Decision:** Simple on/off toggles for all VPNs via CLI commands.
- WireGuard: `wg-quick up/down` or app CLI
- Tailscale: `tailscale up/down`
- PIA: `piactl connect/disconnect`

**Why:** Scott uses the apps to toggle today but is comfortable with CLI. Simple toggle is the v1 need. Exit node selection (Tailscale) and server selection (PIA) deferred to v2.

---

## Q6: Wi-Fi Network Switching

**Decision:** Full list of available networks sorted by signal strength. Known/saved networks pinned to the top. Signal quality indicator and security type shown. Saved networks visually distinguished. Unknown networks prompt a password dialog.

---

## Q7: Dropdown Layout

**Decision:** SwiftUI popover (not NSMenu) with sections:
1. Current connection info (network name, signal strength, IPs)
2. VPN section (name, status, toggle per VPN)
3. Wi-Fi networks (known first, then available)
4. Quick actions (disconnect, settings)

**Why:** Popover allows proper toggle switches, signal strength bars, and rich UI. Traditional NSMenu is too limiting for VPN toggles and detailed info.

---

## Q8: IP Address Display

**Decision:** Both local and external IP. External IP fetched via lightweight HTTPS API (privacy-respecting, no personal data collection).

**Refresh modes (user configurable):**
- Timed interval (configurable)
- On-demand only (manual refresh button)

Auto-refresh on VPN state change regardless of mode. 30-second cache to avoid API spam. "Unavailable" with retry on failure.

**Why:** External IP is especially useful with VPNs — confirms traffic is actually routing through the VPN.

---

## Q9: Settings Scope

**Decision:** Extensive settings including:
- Menu bar display configuration
- IP refresh mode and interval
- VPN list management
- Launch at login (on by default)
- Granular notification toggles per event type
- Network detail display configuration
- Hotkey configuration
- Opt-in diagnostics

**Appearance:** Follows system dark/light mode. No manual override needed.

---

## Q10: Network Details

**Decision:** All network details built in and configurable by user:
- SSID, signal strength (bars + percentage), band/frequency, channel, link speed, BSSID, DNS servers, gateway IP, subnet mask

**Default display:** Network name + signal strength only. User configures what else to show.

**Why:** Power users want deep info, general users want simplicity. Configurable defaults solve both.

---

## Q11: Wi-Fi On/Off Control

**Decision:** Include Wi-Fi on/off toggle. When off, menu bar icon changes to disabled state, popover shows minimal UI with toggle to re-enable. VPN section still visible (relevant for Ethernet).

---

## Q12: Ethernet Awareness

**Decision:** Full Ethernet support. Auto-detect wired connections, show connection info, indicate wired connection on menu bar icon. VPN and IP features work regardless of connection type.

**Why:** Low implementation effort since we're already reading network interfaces. Would be weird if the app went blank on Ethernet.

---

## Q13: Multiple Active Connections

**Decision:** Handle Wi-Fi + Ethernet simultaneously. Show all active connections with clear labels. Indicate primary route. Soft warning when multiple VPNs active (dismissable, can be disabled in settings).

**Why:** Users running Tailscale + WireGuard simultaneously usually know what they're doing. Warn but don't block.

---

## Q14: Keyboard Shortcuts

**Decision:** Extensive configurable hotkeys:
- Global hotkey to open/close popover
- Toggle each VPN
- Toggle Wi-Fi
- Copy local/external IP to clipboard
- Refresh external IP
- Navigate between popover sections

**Why:** Scott specifically said extensive hotkeys are important.

---

## Q15: Data Persistence and First Run

**Decision:**
- Settings stored in UserDefaults (standard macOS approach)
- Auto-detect installed VPNs on first launch, user confirms
- User can add VPNs not detected (from curated list or custom)
- First-run setup wizard walks through Location Services permission and privileged helper installation

---

## Q16: Custom VPN Support

**Decision:** Two approaches:
1. Curated list of popular VPN apps with pre-configured CLI commands (checkbox to enable)
2. Advanced/custom option: user provides name + shell commands for status check, connect, disconnect

**Why:** Approachable for most users, extensible for power users. Curated list grows over time.

---

## Q17: Auto-Updates

**Decision:** Sparkle framework integrated from v1. Releases hosted on GitHub Releases. `generate_appcast` builds update feed XML from releases.

**Why:** Direct distribution means no App Store auto-updates. Sparkle is free (MIT), safe, and used by thousands of Mac apps (Firefox, VLC, Sketch).

---

## Q18: App Name

**Decision:** SignalDrop

---

## Q19: Minimum macOS Version

**Decision:** macOS 13 (Ventura) through macOS 27 (Golden Gate, currently in beta). Must work on Tahoe (macOS 26) as well.

**Why:** macOS 13 covers the vast majority of active Macs and provides modern SwiftUI + full CoreWLAN access. Scott is running Golden Gate beta.

---

## Q20: Security and Privacy

**Decision:**
- Privileged helper via `SMAppService` (user authorizes once during setup)
- No data logging — all network info in-memory only, never written to disk
- External IP fetch via HTTPS only
- Opt-in diagnostic logging for error reports (off by default, user must enable)

**Why:** Trust is paramount for a networking utility. "I want this app to be trusted." — Scott

---

## Q21: Error Handling

**Decision:**
- Missing VPN CLI: grayed out entry with warning icon and tooltip
- Network state: real-time via `NWPathMonitor` (no polling)
- IP fetch failure: "Unavailable" with retry button
- Helper failure: "Reinstall Helper" option in settings
- Principle: never silently fail, always give clear path to fix

---

## Q22: Speed Test

**Decision:** Skip full speed test for v1. Future roadmap item.

---

## Q23: Ping/Latency Indicator

**Decision:** Include lightweight ping indicator. Configurable target (default `1.1.1.1`). User can toggle on/off.

---

## Q24: Popover Interaction

**Decision:**
- Left-click menu bar icon to open popover
- Close on click outside
- Sections collapsible
- Section reordering deferred to v2
- Max height with scrolling, dynamic resize up to max

---

## Q25: Accessibility

**Decision:** Full accessibility from day one:
- VoiceOver support (all elements labeled)
- Keyboard navigation (tab through all elements)
- Respect system settings (reduced motion, high contrast, increased contrast)

**Why:** Much harder to bolt on later. Nearly free with SwiftUI if built from the start.

---

## Q26: Open Source / License

**Decision:** BSL (Business Source License), converts to Apache 2.0 after 3-4 years.

**Why:** Scott wants to sell the app but also wants code transparency for trust. BSL allows full source visibility, personal/non-commercial use for free, but protects commercial rights. Conversion to Apache 2.0 ensures older versions eventually become fully open source.

---

## Q27: Licensing and Payment

**Decision:** Freemium model with LemonSqueezy as storefront.
- Free tier: core Wi-Fi features
- Paid tier: $12.99 one-time (1 year updates included)
- Renewal: $6.99/year for continued updates
- App works at last installed version if not renewed

LemonSqueezy chosen for: simplest onboarding experience, merchant of record (handles global sales tax), Swift SDK for license validation, 5% + $0.50 per transaction.

**Why:** Scott has never sold an app before — LemonSqueezy is the easiest path. Freemium builds adoption, paid tier converts power users, renewal generates recurring revenue without subscription stigma.

---

## Q28: Free vs. Paid Feature Split

**Decision:**

Free: Wi-Fi status/name in menu bar, signal strength, network list + switching, Wi-Fi on/off, Ethernet detection, local IP.

Paid: VPN monitoring/toggles, external IP, custom VPNs, configurable menu bar display, configurable hotkeys, advanced network details, ping indicator, notifications, collapsible sections.

**Why:** Free tier is genuinely useful (not crippled). VPN management is the clear premium value.

---

## Q29: Pricing Research

**Decision:** $12.99 + $6.99 renewal based on competitive analysis.

**Market context:** Consumer Mac networking utilities cluster $9-$30 one-time. One-time purchase dominates (subscriptions deeply unpopular). Comparable apps: Radio Silence ($9), iStat Menus ($11.99), WiFi Explorer ($19.99). SignalDrop is unique in combining Wi-Fi + VPN + network info.

---

## Q30: Analytics/Telemetry

**Decision:** Opt-in only. Sentry for crash reporting, off by default. No behavioral analytics in v1. LemonSqueezy provides basic business metrics via license activations.

**Why:** "I want this app to be trusted." — Scott

---

## Q31: Localization

**Decision:** Localization-ready but English-only at launch. All strings use `String(localized:)` from the start. Translations added later without refactoring.

---

## Q32: Setapp Distribution

**Decision:** Not for v1. Architect licensing to support Setapp SDK integration later. Good future growth channel once app is stable.

---

## Q33: Additional Features Triage

**Deferred to v2+:**
- Personal Hotspot management
- Network connection history/log
- Menu bar icon customization
- macOS Widget (desktop/Notification Center)
- Section reordering in popover
- Tailscale exit node selection
- PIA server selection
- Speed test
- Setapp integration
- App Store reduced-feature version
- Shortcuts/Automator integration
- AppleScript support

**Included in v1:**
- Copy/export all network info to clipboard (useful for tech support)
