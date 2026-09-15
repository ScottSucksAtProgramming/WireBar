# Changelog

## [Unreleased]

## [0.2.2-beta] - 2026-09-15

### Added
- WireBar has its own app icon, shown in Finder, the update window, and a larger version in Settings → About

## [0.2.1-beta] - 2026-09-15

### Changed
- Confirms in-app updates work: this release is delivered through WireBar's built-in updater

## [0.2.0-beta] - 2026-09-15

### Added
- Saved Networks settings tab: WireBar can remember the Wi-Fi passwords you type, stored in your Mac's keychain and never sent anywhere
- Add, change, and forget saved passwords, or forget them all at once
- Support for work and school (WPA2-Enterprise) networks, which sign in with a username and password
- Progress indicator while WireBar joins a network
- Beta testers can enter a personal beta key in Settings → License to unlock paid features until the key's end date

### Fixed
- Launch at Login now actually adds WireBar to your Login Items
- The network list no longer shows the same network several times
- Switching networks from WireBar works again, and a failed join no longer leaves you disconnected. WireBar now asks for the password instead
- Network name, VPN indicator, and IP address appear in the menu bar as soon as WireBar launches, instead of showing up late

## [0.1.1-beta] - 2026-07-06

### Added
- Dynamic signal strength icon in the menu bar that reflects real-time Wi-Fi signal quality
- Personal hotspot detection with dedicated menu bar icon when connected to a hotspot
- Location Services permission check with popover banner and launch alert to ensure Wi-Fi name visibility
- Quit WireBar button in the popover for easy app exit

### Fixed
- Hotspot detection now uses gateway subnet (172.20.10.x) in addition to SSID matching, reliably detecting iPhone/iPad hotspots regardless of device name

## [0.1.0-beta] - 2026-07-01

Initial beta release with core functionality:
- Wi-Fi status monitoring and network name display
- Signal strength, noise level, and channel info
- Network scanning and switching
- VPN status monitoring with multi-VPN support
- Local and external IP display
- Ping latency monitoring
- Ethernet connection support
- Keyboard shortcuts
- Notification system for network changes
- Settings panel with customizable menu bar display
- Sparkle auto-update integration
- Freemium licensing via LemonSqueezy
