# Plan: Phase 5 — Notifications, Hotkeys & UI Polish

> Source PRD: PRD.md — User stories 3, 6–7, 36–44, 50–52, 64

## Architectural decisions

Durable decisions that apply across all phases:

- **Notification dispatch**: `UNUserNotificationCenter` for all macOS notifications. NotificationService observes state changes from NetworkMonitor, VPNManager, and IPService via Combine. Each notification type individually toggleable via SettingsStore.
- **Hotkey registration**: `CGEvent` tap or `NSEvent.addGlobalMonitorForEvents` for global hotkeys. HotkeyManager owns registration/dispatch; actions routed back through AppDelegate. Hotkey mappings persisted in SettingsStore.
- **Feature gating**: All notification and hotkey features gated behind `LicenseManager.isPaid`. Collapsible sections and configurable menu bar also gated.
- **Settings persistence**: All new preferences (notification toggles, hotkey mappings, menu bar display options, section collapse state) stored in SettingsStore via UserDefaults, matching the existing pattern.
- **Menu bar rendering**: `NSStatusItem` with `NSStatusBarButton` — composing icon + optional text segments with a priority-based overflow/truncation strategy for notched displays.

---

## Phase 5a-1: NotificationService — VPN & Wi-Fi Alerts

**User stories**: 36, 38

### What to build

A NotificationService that observes VPNManager and NetworkMonitor state via Combine publishers. When a VPN connection drops (status transitions from `.connected` to `.disconnected`) or Wi-Fi disconnects, the service dispatches a macOS notification via `UNUserNotificationCenter`. The service requests notification authorization on first use. Gated behind `LicenseManager.isPaid`. AppDelegate creates and wires the service on launch. Add notification toggle settings to SettingsStore (defaults: all on). Unit tests with mock state publishers verify notifications fire on the correct transitions and respect the paid gate.

### Acceptance criteria

- [ ] VPN drop notification fires when a VPN transitions from connected → disconnected
- [ ] Wi-Fi disconnect notification fires when Wi-Fi connection is lost
- [ ] Notifications do not fire for free-tier users
- [ ] Notification authorization requested on first paid-feature use
- [ ] SettingsStore has per-type toggle properties for VPN drop and Wi-Fi disconnect notifications
- [ ] Unit tests cover: correct state transitions trigger notifications, paid gate blocks free users, disabled toggles suppress notifications
- [ ] VoiceOver: notification content is readable
- [ ] All user-facing strings use `String(localized:)`

---

## Phase 5a-2: NotificationService — IP Change + Settings Tab

**User stories**: 37, 39

### What to build

Extend NotificationService to observe IPService's external IP changes and dispatch a notification when the external IP address changes (not on initial fetch — only on subsequent changes). Add a per-type toggle for IP change notifications to SettingsStore. Build a Notifications settings tab in SettingsView with toggles for each notification type (VPN drop, Wi-Fi disconnect, IP change). The tab shows a "paid feature" message for free users. Unit tests for IP-change detection and the settings UI.

### Acceptance criteria

- [ ] IP change notification fires when external IP changes (not on first fetch)
- [ ] SettingsStore has IP change notification toggle
- [ ] Notifications settings tab in SettingsView with all three toggles
- [ ] Settings tab disabled/hidden for free users with upgrade prompt
- [ ] Toggling a notification type off suppresses that notification
- [ ] Unit tests cover: IP change detection, toggle suppression, no notification on initial fetch
- [ ] VoiceOver labels on all settings controls
- [ ] All user-facing strings use `String(localized:)`

---

## Phase 5a-3: HotkeyManager — Popover + Wi-Fi Hotkeys

**User stories**: 40, 43

### What to build

A HotkeyManager service that registers global keyboard shortcuts and dispatches actions. Start with two hotkeys: open/close popover (default: configurable, e.g. ⌥⇧W) and toggle Wi-Fi. A third hotkey for refresh external IP. The manager registers key combos via macOS global event monitoring, maps them to named actions, and calls back to AppDelegate to execute. Hotkey mappings stored in SettingsStore. Gated behind `LicenseManager.isPaid`. AppDelegate wires HotkeyManager on launch. Unit tests verify registration, dispatch, and paid gating.

### Acceptance criteria

- [ ] Global hotkey opens/closes the popover from any app
- [ ] Global hotkey toggles Wi-Fi on/off
- [ ] Global hotkey refreshes external IP
- [ ] Hotkeys only active for paid users
- [ ] Hotkey key combinations persisted in SettingsStore
- [ ] Unit tests cover: action dispatch, paid gate, enable/disable
- [ ] Accessibility: hotkeys do not conflict with system VoiceOver shortcuts
- [ ] All user-facing strings use `String(localized:)`

---

## Phase 5a-4: HotkeyManager — VPN + IP Hotkeys + Customization UI

**User stories**: 41, 42, 44

### What to build

Extend HotkeyManager with hotkeys to toggle specific VPNs (one hotkey per monitored VPN) and copy local/external IP to clipboard. Build a Keyboard Shortcuts settings tab where users can view, change, and clear all hotkey bindings. The tab includes a key-capture field (press keys to record a combo), conflict detection (warns if a combo is already used), and a reset-to-defaults button. Manual test against PRD user stories 40–44. Regression test all Phase 1–4 user stories.

### Acceptance criteria

- [ ] Per-VPN toggle hotkeys work for each monitored VPN
- [ ] Copy local IP and copy external IP hotkeys work
- [ ] Keyboard Shortcuts settings tab with key-capture fields for all hotkeys
- [ ] Conflict detection warns when a hotkey combo is already assigned
- [ ] Users can clear individual hotkey bindings
- [ ] Reset to defaults restores original key combos
- [ ] All hotkey settings persisted in SettingsStore
- [ ] Unit tests cover: VPN toggle dispatch, IP copy, conflict detection
- [ ] VoiceOver labels on all settings controls
- [ ] All user-facing strings use `String(localized:)`
- [ ] Manual test: PRD user stories 36–44 pass
- [ ] Regression test: all Phase 1–4 user stories pass

---

## Phase 5b-1: Collapsible Sections + Copy All Network Info

**User stories**: 51, 64

### What to build

Add collapse/expand toggles to each popover section (Connection Info, IP & Ping, VPN, Network List). Collapsed state persisted per-section in SettingsStore. Section headers become tappable with a disclosure chevron. Collapsible sections gated behind `LicenseManager.isPaid` (free users see all sections expanded, no toggle). Add a "Copy All" button to the quick actions bar that copies a formatted summary of all visible network info (SSID, signal, IPs, VPN states, Ethernet info) to the clipboard — available to all users (free feature).

### Acceptance criteria

- [ ] Each popover section has a tappable header that collapses/expands the section
- [ ] Collapse state persisted in SettingsStore and restored on relaunch
- [ ] Collapsible sections only available for paid users
- [ ] "Copy All" button in quick actions copies formatted network summary to clipboard
- [ ] Copied text includes all visible info: SSID, signal, local IP, external IP, VPN states, Ethernet
- [ ] VoiceOver: section headers announce expanded/collapsed state; Copy All button labeled
- [ ] All user-facing strings use `String(localized:)`

---

## Phase 5b-2: Configurable Menu Bar Display + Overflow

**User stories**: 3, 6, 7

### What to build

Replace the current fixed menu bar icon with a configurable display. Users choose which elements to show: Wi-Fi icon (always on as base), network name, VPN status indicators, IP address. Choices stored in SettingsStore. The menu bar renders chosen elements left-to-right with a priority-based truncation strategy for notched MacBook displays (icon always visible, then name truncated with ellipsis, then remaining items dropped by priority). VPN indicators and IP address in menu bar gated behind `LicenseManager.isPaid`. Add a Menu Bar Display section to the General settings tab with toggles for each element and a live preview. Network name and VPN indicators are paid features.

### Acceptance criteria

- [ ] Menu bar displays user-chosen combination of icon, network name, VPN indicators, IP address
- [ ] Default display: Wi-Fi icon + network name (matching current behavior for free users)
- [ ] VPN indicators and IP address in menu bar gated behind paid tier
- [ ] Overflow: on notched displays, elements truncate/drop by priority order
- [ ] Settings UI with toggles for each menu bar element
- [ ] Menu bar updates in real-time as network state or settings change
- [ ] Unit tests: menu bar content reflects settings and paid gate
- [ ] VoiceOver: menu bar button accessibility label reflects all shown info
- [ ] All user-facing strings use `String(localized:)`

---

## Phase 5b-3: Popover Polish + Wi-Fi Off State

**User stories**: 50, 52

### What to build

Add max-height constraint to the popover with vertical scrolling when content exceeds it. Ensure popover closes when user clicks outside (already partially handled by `.transient` behavior — verify and fix edge cases). Polish the Wi-Fi off state: when Wi-Fi is powered off, show a minimal popover with a prominent "Wi-Fi is off" message, the Wi-Fi toggle to re-enable, and the VPN section still visible (VPNs work over Ethernet). Verify dark/light mode renders correctly across all sections. Manual test against PRD user stories 3, 6–7, 50–52, 64. Full regression test of all Phase 1–5a user stories.

### Acceptance criteria

- [ ] Popover scrolls when content exceeds max height
- [ ] Popover closes when clicking outside it
- [ ] Wi-Fi off state shows: "Wi-Fi is off" message, Wi-Fi toggle, VPN section, settings button
- [ ] Wi-Fi off state hides: connection info details, network list
- [ ] App renders correctly in both light and dark mode
- [ ] Manual test: PRD user stories 3, 6–7, 50–52, 64 pass
- [ ] Regression test: all Phase 1–5a user stories pass
- [ ] VoiceOver: Wi-Fi off state announces status clearly
- [ ] All user-facing strings use `String(localized:)`
