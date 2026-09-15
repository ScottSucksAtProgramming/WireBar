# Plan: Phase 7a — Quit Button, Location Services Check, Signal Strength

> Source: Grilling session 2026-07-01, PRD user stories 55-56 (Location Services), 3/6-7 (menu bar display)

## Architectural decisions

Durable decisions that apply across all phases:

- **Location Services monitoring**: CLLocationManager authorization status observed continuously (not just on launch). Status is published so both the popover and the launch alert can react independently.
- **Menu bar icon model**: A single icon slot managed by AppDelegate. Icon selection follows a priority chain: Wi-Fi off → disabled icon, Ethernet only → cable icon, hotspot detected (paid) → hotspot icon, signal strength enabled → dynamic bars, default → static brand icon.
- **Signal strength display formats**: An enum with cases for bars (free), percentage (paid), and dBm (paid). SettingsStore persists the user's choice. The menu bar updater reads the format and renders accordingly.
- **Feature gating pattern**: Consistent with existing codebase — `licenseManager.isPaid` guards paid options in Settings UI and in the menu bar update logic. Free features never check the license.
- **Settings persistence**: New settings use the existing `@AppStorage` pattern in SettingsStore with string-literal keys.

---

## Phase 1: Quit Button

**User stories**: N/A (quality-of-life, no PRD story — LSUIElement app has no other quit mechanism)

### What to build

A "Quit WireBar" button at the bottom of the popover, below the existing Wi-Fi toggle and Settings gear. Tapping it immediately terminates the app via `NSApplication.shared.terminate(nil)`. No confirmation dialog. The button should be visually distinct from the other controls (e.g., secondary/destructive style, separated by a divider) so it's not accidentally tapped but is easy to find.

### Acceptance criteria

- [ ] "Quit WireBar" button visible at the bottom of the popover
- [ ] Tapping it immediately quits the app (no confirmation)
- [ ] Button has a VoiceOver accessibility label
- [ ] Button label uses `String(localized:)`
- [ ] Button is visually separated from the Wi-Fi toggle / Settings gear row

---

## Phase 2: Location Services — Popover Warning

**User stories**: PRD 55-56 (first-run Location Services explanation)

### What to build

Ongoing monitoring of CLLocationManager authorization status. When the status is denied or not yet determined, a styled inline banner appears at the top of the popover explaining that SSID display requires Location Services. The banner is visually distinct — colored background (e.g., system yellow/orange warning style) so it stands out from normal content. Clicking the banner opens System Settings to the correct pane (Privacy & Security > Location Services). The banner disappears automatically when Location Services is granted.

### Acceptance criteria

- [ ] CLLocationManager authorization status is monitored continuously (not just checked once on launch)
- [ ] When Location Services is denied or undetermined, a colored banner appears at the top of the popover
- [ ] Banner text explains why Location Services is needed (SSID display)
- [ ] Clicking the banner opens System Settings > Privacy & Security > Location Services
- [ ] Banner disappears when Location Services is granted (no app restart required)
- [ ] Banner has VoiceOver accessibility label and action description
- [ ] All strings use `String(localized:)`
- [ ] Banner does not interfere with popover scrolling or layout

---

## Phase 3: Location Services — Launch Alert + Dismissal

**User stories**: PRD 55-56 (first-run Location Services explanation)

### What to build

A one-time NSAlert shown on app launch when Location Services is not granted. The alert explains why WireBar needs Location Services and offers a button to open the correct System Settings pane. A "Don't Remind Me Again" checkbox suppresses future alerts — this preference is persisted in SettingsStore. The Phase 2 popover banner remains visible regardless of whether the user dismisses the alert. The alert only fires after a short delay (app is fully loaded, popover is not yet shown) to avoid feeling jarring on startup.

### Acceptance criteria

- [ ] Alert appears on launch when Location Services is denied or undetermined
- [ ] Alert explains the SSID/Location Services dependency in plain language
- [ ] Primary button opens System Settings > Location Services
- [ ] "Don't Remind Me Again" checkbox suppresses future alerts when checked
- [ ] Dismissal preference persisted via SettingsStore
- [ ] Alert does NOT appear if the user previously checked "Don't Remind Me Again"
- [ ] Alert does NOT appear if Location Services is already granted
- [ ] Phase 2 popover banner still appears regardless of alert dismissal
- [ ] Alert text uses `String(localized:)`

---

## Phase 4: Signal Strength + Hotspot Icon

**User stories**: PRD 3, 6-7 (configurable menu bar display)

### What to build

Replace the static menu bar icon with a dynamic signal strength indicator when the user enables it. Three display formats: signal bars (free), percentage text (paid), and dBm text (paid). A format picker in Settings lets paid users choose their preferred display. The default for free users is bars; toggling the feature on swaps the static brand icon for dynamic bars.

Additionally, detect personal hotspot connections and automatically swap the menu bar icon to a hotspot-specific icon (paid feature, on by default). A toggle in Settings lets paid users disable hotspot detection and keep the normal icon. Hotspot detection uses CWInterface network characteristics (SSID patterns, BSS type) to identify tethered connections.

A small warning note in the menu bar display Settings section informs users that showing many items may cause some to be hidden on smaller screens.

### Acceptance criteria

- [ ] New "Show Signal Strength" toggle in Settings (free, no license gate)
- [ ] When enabled, menu bar icon changes from static brand icon to dynamic Wi-Fi signal bars reflecting actual signal level
- [ ] Signal bars update in real-time as signal strength changes
- [ ] Paid users see a format picker in Settings: Bars, Percentage, dBm
- [ ] Percentage format shows signal as text (e.g., "72%") next to or replacing the icon
- [ ] dBm format shows raw value (e.g., "-67 dBm") next to or replacing the icon
- [ ] Free users see only the Bars option; other options show upgrade prompt or are disabled
- [ ] Hotspot detection: icon automatically swaps to hotspot icon when tethered to a personal hotspot (paid)
- [ ] Hotspot detection on by default for paid users, with a Settings toggle to disable
- [ ] Free users do not see hotspot detection toggle (or see it with upgrade prompt)
- [ ] Icon state priority chain works correctly: Wi-Fi off → Ethernet → hotspot → signal bars → static icon
- [ ] Warning text in Settings about menu bar space on smaller/notched screens
- [ ] All new Settings controls have VoiceOver accessibility labels
- [ ] All new strings use `String(localized:)`
- [ ] Existing menu bar display features (SSID text, VPN dots, IP) continue working alongside new icon modes
