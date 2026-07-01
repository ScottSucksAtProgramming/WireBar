# Plan: Phase 6 — LemonSqueezy Licensing

> Source: PRD.md user stories 59-63, .taskpaper Phase 6, LemonSqueezy API research (2026-07-01)

## Architectural decisions

Durable decisions that apply across all phases:

- **API base URL**: `https://api.lemonsqueezy.com/v1/licenses/` — three endpoints: `/activate`, `/validate`, `/deactivate`
- **Content format**: `application/x-www-form-urlencoded` (form-encoded POST, not JSON)
- **Auth**: No API key needed — license key string is the only credential
- **Persistence**: Keychain for license key, instance_id, and cached validation response. No disk logging (core trust promise).
- **Protocol seam**: `LicenseValidating` protocol for DI/testing — matches existing codebase pattern (`WiFiScanning`, `VPNConfigurationProviding`, `NotificationDispatching`)
- **Config constants**: Store ID and checkout URL in a single `LicenseConfig` struct
- **State model**: `LicenseStatus` enum (`free`, `activated`, `gracePeriod`, `validationPending`) — `isPaid` is computed as true for `activated` and `gracePeriod`
- **Instance name**: Hardware UUID (`IOPlatformUUID`) to identify this device for activation
- **Rate limit**: 60 req/min (LemonSqueezy enforced) — not a concern for single-user desktop app

---

## Phase 1: Online Activation (Happy Path)

**User stories**: 59 (free features without paying), 60 (purchase + activate from within app)

### What to build

A complete online activation flow: user enters a license key in Settings, the app calls LemonSqueezy's activate endpoint, persists the instance_id and license key in Keychain, and flips `isPaid` to true. On next launch, the app calls the validate endpoint to confirm the license is still valid. Deactivation is not in scope yet — just the happy path from free → paid.

The API layer is behind a `LicenseValidating` protocol so tests can mock it. The real implementation is a thin URLSession wrapper (~50 lines) that form-encodes POST requests. Responses are JSON — parse only the fields we need (status, instance_id, license_key object).

The existing `LicenseSettingsView` stub is updated to show activation progress, success/error states, and the masked license key after activation. The "Get a License" link points to the LemonSqueezy checkout URL (placeholder until KYC clears).

### Acceptance criteria

- [ ] `LicenseValidating` protocol defined with `activate`, `validate`, `deactivate` signatures
- [ ] Real implementation calls LemonSqueezy API with form-encoded POST over HTTPS
- [ ] On successful activation, instance_id and license key stored in Keychain
- [ ] `isPaid` returns true after successful activation and persists across app relaunch
- [ ] On launch, validate is called — `isPaid` stays true if valid, flips to false if invalid/revoked
- [ ] `LicenseSettingsView` shows activation progress spinner, success state, error state
- [ ] Config constants (checkout URL, store slug) in a single `LicenseConfig` struct
- [ ] Unit tests: activation success/failure, validation success/failure/revoked, protocol mock works
- [ ] All new UI strings use `String(localized:)`
- [ ] VoiceOver labels on all new/modified UI elements

---

## Phase 2: Offline Caching + Grace Period

**User stories**: 63 (app keeps working forever at last installed version)

### What to build

Offline resilience so paid features don't lock out when the network is down — critical for a network utility that users need most during connectivity issues.

Cache the last successful validation response (status + timestamp) alongside the existing Keychain data. On launch: try online validation first; if it fails (network error, not revocation), fall back to the cache. If the cache is within the 7-day grace window, `isPaid` stays true with status `gracePeriod`. If the cache is older than 7 days, status becomes `validationPending` — paid features still degrade gracefully (visible but with a subtle "re-validate" banner), not hard-locked.

Clock-tampering detection: if the current system time is earlier than the last validation timestamp, treat the cache as invalid (prevents users from rolling back the clock to extend the grace period).

Re-validate automatically when connectivity returns (observe `NWPathMonitor` for path changes, same as `NetworkMonitor` already does).

### Acceptance criteria

- [ ] Last successful validation timestamp cached in Keychain
- [ ] Network errors during validation fall back to cache (HTTP errors like 404/revoked do NOT fall back)
- [ ] Cache within 7 days: `isPaid` true, status `gracePeriod`
- [ ] Cache older than 7 days: status `validationPending`, UI shows re-validation prompt
- [ ] Clock tampering detected (system time < last validation): cache treated as invalid
- [ ] Automatic re-validation when network path changes to satisfied
- [ ] Unit tests: grace period boundaries (day 1, day 6, day 7, day 8), clock tampering, network recovery re-validation
- [ ] Free features always work regardless of validation state

---

## Phase 3: Deactivate + Device Transfer

**User stories**: (device transfer — taskpaper requirement, no numbered PRD story)

### What to build

Complete the license lifecycle with deactivation. User can deactivate their license from Settings (calls LemonSqueezy's deactivate endpoint with the stored instance_id), which clears all Keychain data and returns to free tier. This enables device transfer: deactivate on old Mac, enter the same key on the new Mac.

The UI adds a confirmation dialog before deactivation (prevent accidental clicks) and shows the device transfer workflow inline — brief text explaining "Deactivate here, then activate on your new device with the same key."

### Acceptance criteria

- [ ] Deactivate calls LemonSqueezy API and clears Keychain data on success
- [ ] `isPaid` returns false after deactivation
- [ ] Confirmation dialog before deactivation ("Are you sure?")
- [ ] Deactivation error handling (network failure shows error, data NOT cleared)
- [ ] Device transfer guidance visible in LicenseSettingsView when license is active
- [ ] Unit tests: deactivation success, deactivation failure (network), state cleanup
- [ ] VoiceOver labels on confirmation dialog and transfer guidance

---

## Phase 4: Upgrade Prompt + Gating Audit + Polish

**User stories**: 60 (frictionless upgrade), 65 (VoiceOver)

### What to build

Final polish pass. Add a subtle upgrade prompt for free-tier users — visible in the popover (small banner or link) and in Settings tabs that show locked features. The prompt links to the LemonSqueezy checkout page.

Audit all ~15 existing `isPaid` gates to verify they work correctly: free users see free features only, paid users see everything, grace-period users see paid features with a subtle indicator. Verify no paid feature leaks in the free tier and no free feature is accidentally gated.

Final accessibility and localization sweep across all Phase 6 UI.

### Acceptance criteria

- [ ] Upgrade prompt visible to free users in popover and relevant Settings tabs
- [ ] Upgrade link opens LemonSqueezy checkout URL in default browser
- [ ] All `isPaid` gates verified: free tier shows only free features, paid tier shows all
- [ ] Grace period state shows paid features with subtle "offline — re-validate" indicator
- [ ] No paid features leak in free tier
- [ ] All Phase 6 UI strings use `String(localized:)`
- [ ] All Phase 6 UI elements have VoiceOver accessibility labels
- [ ] Manual test: full activation → relaunch → validate → deactivate → reactivate cycle
