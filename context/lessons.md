---
title: "SignalDrop Lessons Learned"
summary: "Running log of corrections, preferences, and discoveries during SignalDrop development"
created: 2026-06-22
updated: 2026-06-22
---

# SignalDrop Lessons Learned

<!-- Append dated one-liners below. When 3+ related lessons accumulate on a topic, extract into a dedicated context file. -->

- 2026-06-22: DNS-based IP lookup (Cloudflare/OpenDNS) is faster, more private, and more reliable than HTTPS APIs for external IP detection.
- 2026-06-22: ICMP ping requires raw sockets and special entitlements on macOS — use TCP-based latency via NWConnection instead.
- 2026-06-22: SMAppService privileged helpers must verify caller code signatures via audit token, or any local process can invoke them.
- 2026-06-22: SMAppService daemons survive app deletion — always provide an uninstall flow.
- 2026-06-22: Location Services authorization is required in Phase 1, not just onboarding — CWInterface.ssid() returns nil without it.
- 2026-06-22: Most VPN CLIs (tailscale, piactl, mullvad) don't need sudo — only wg-quick does. Two-tier execution avoids unnecessary privileged helper usage.
- 2026-06-22: Sparkle EdDSA private key loss is catastrophic — existing installs will never accept updates again. Back up immediately upon generation.
