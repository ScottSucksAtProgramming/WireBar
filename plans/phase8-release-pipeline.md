# Plan: Phase 8 — Release Pipeline (In-App Updates via GitHub Releases)

> Source PRD: PRD.md, user stories 61–62
> Design decisions: Q17 (Sparkle from v1), Q38 (updates are public), Q39 (.dmg distribution), Q44 (release pipeline — decided 2026-09-15)
> Tasks: `.taskpaper` → Phase 8 → Release Infrastructure
> Branch: `phase/8-release-prep`

## Architectural decisions

Durable decisions that apply across all phases:

- **Where releases are built**: one local script on Scott's Mac (`scripts/`). No CI. Signing certificate, Sparkle EdDSA private key (login keychain), and notarization credentials never leave the Mac.
- **Human gate**: the script prints a summary and asks `Publish <version> to GitHub? (y/n)` before anything is uploaded or pushed. Nothing public happens before that answer.
- **Release type**: normal GitHub releases (never "Pre-release" or draft), tagged `v<version>` (e.g. `v0.2.0-beta`). Required because `SUFeedURL` uses `/releases/latest/download/appcast.xml`, which ignores pre-releases.
- **Versioning**: `MARKETING_VERSION` is chosen per release (script takes it as an argument); `CURRENT_PROJECT_VERSION` (what Sparkle compares) increments by exactly 1 every release, automatically. Bump is committed and tagged. First release: `0.2.0-beta` / build `2`.
- **Artifacts**: each release is built into its own clean folder `dist/<version>/` (gitignored contents: `.dmg`, notes HTML, `appcast.xml`). The appcast is generated from that folder only, with download URLs pointing at `https://github.com/ScottSucksAtProgramming/WireBar/releases/download/v<version>/`. A fresh `appcast.xml` is attached to every release. Old hand-made DMGs move to `dist/old/`.
- **DMG**: plain `hdiutil` image containing `WireBar.app` + an `/Applications` symlink. No styled background (can be added later).
- **Release notes**: `CHANGELOG.md` is the single source. The script renames `## [Unreleased]` to `## [<version>] - <date>`, refuses to continue if that section is empty, converts it to HTML next to the DMG (same basename) so Sparkle's update window shows it, and uses the same text for the GitHub release body.
- **Sparkle tools**: `generate_appcast` / `sign_update` are located under the newest `~/Library/Developer/Xcode/DerivedData/WireBar-*/SourcePackages/artifacts/sparkle/Sparkle/bin/`. If missing, the script stops with "build WireBar in Xcode first". Never hardcode a hash path.
- **Notarization**: a step in the script behind a switch, **off** until Scott's Apple Developer membership renewal clears. Keychain profile name: `wirebar-notary`. When on: notarize + staple the app, then the DMG; fail early if the profile is missing. The agent never handles Apple credentials.
- **Build config**: Release configuration only. `BETA_UNLOCK_PAID` must not be present (Debug-only per Q43).
- **Test gate**: the script runs the test suite before building and checks the **executed test count** (currently 153), not the pass/fail banner — `LicenseManagerTests` is flaky and can crash partway while still printing a banner.

---

## Phase 1: One command makes an installable .dmg

**User stories**: 61, 62 (foundation)

### What to build

A release script that takes a version (e.g. `0.2.0-beta`), runs the tests, bumps the marketing version and build number, builds the Release configuration, signs it with the Developer ID certificate, and packages it into `dist/<version>/WireBar-<version>.dmg`. Nothing is published, committed, or tagged in this phase — run it, inspect the output, throw it away. Move the three old DMGs in `dist/` to `dist/old/`.

### Acceptance criteria

- [x] Script stops with a clear message if the working tree is dirty, tests don't all run, or the version argument is missing (caught 8 keychain-dependent failures, then a 91-of-153 crash — both fixed)
- [x] Build number goes up by exactly 1 from the current value (1 → 2)
- [x] `codesign --verify --deep --strict` passes on the built app, signed by "Developer ID Application: Scott Kostolni (5N69HV7X7S)" with hardened runtime and a timestamp
- [x] Release binary is built without `BETA_UNLOCK_PAID` (script checks Release build settings)
- [x] DMG contains `WireBar.app` + `Applications` shortcut; app inside reports `0.2.0-beta` (build 2); DMG is signed
- [ ] Dragging to Applications and launching works after "Open Anyway" (Scott)
- [ ] About shows `0.2.0-beta` (Scott). License tab: Scott's Mac already holds his beta key, so it shows Beta, not Free. Free-before-a-key is covered by the build-settings check; confirm on a Mac without a key during beta.
- [x] No release artifacts show up in `git status`
- Noticed, not changed: `hdiutil` prints deprecation warnings (suggests `diskutil image`); still works on macOS 27.

---

## Phase 2: Release notes and the signed update file

**User stories**: 61

### What to build

Extend the script so it turns the changelog's Unreleased section into this version's dated section, writes the notes as HTML beside the DMG, and runs `generate_appcast` on `dist/<version>/` to produce a signed `appcast.xml`. Add the beta license key line to the Unreleased section of `CHANGELOG.md` ("Beta testers can enter a personal beta key in Settings → License to unlock paid features until the key's end date").

### Acceptance criteria

- [ ] Script refuses to run if the Unreleased section is empty
- [ ] `appcast.xml` contains exactly one item: this version, with `sparkle:version` = the new build number and `sparkle:shortVersionString` = the version
- [ ] Enclosure URL is `https://github.com/ScottSucksAtProgramming/WireBar/releases/download/v<version>/WireBar-<version>.dmg`
- [ ] The EdDSA signature in the appcast verifies against the app's `SUPublicEDKey`
- [ ] Release notes (embedded or linked) match the changelog section
- [ ] Script stops with a clear message if Sparkle's tools can't be found

---

## Phase 3: Publish 0.2.0-beta with a confirm step

**User stories**: 61, 62

### What to build

After building, the script shows a summary (version, build number, notes, files) and asks for confirmation. On "y": commit the version bump + changelog, tag `v<version>`, push, and create a normal GitHub release with the DMG and `appcast.xml` attached and the notes as the body. On "n": leave nothing behind except the local build folder. Run it for real for `0.2.0-beta` (after the phase branch is merged to `main`). Scott installs from GitHub, replacing the old everything-unlocked `/Applications/WireBar.app`.

### Acceptance criteria

- [ ] Answering "n" publishes nothing and leaves no commit or tag
- [ ] Release `v0.2.0-beta` exists, is not marked Pre-release or draft, and has both assets
- [ ] `https://github.com/ScottSucksAtProgramming/WireBar/releases/latest/download/appcast.xml` returns the 0.2.0-beta appcast (HTTP 200)
- [ ] The DMG downloaded from GitHub installs and launches; About shows `0.2.0-beta`; License tab shows Free (Scott)

---

## Phase 4: Prove in-app updates work (0.2.1-beta)

**User stories**: 61, 62

### What to build

Publish a tiny same-day release `0.2.1-beta` (changelog: "Confirms in-app updates work") using the script unchanged. Scott triggers Check for Updates on the installed 0.2.0-beta.

### Acceptance criteria

- [ ] Feed URL now returns the 0.2.1-beta appcast
- [ ] Installed 0.2.0-beta offers 0.2.1-beta with the right release notes (Scott)
- [ ] Update downloads, installs, and relaunches without a Gatekeeper block (Scott)
- [ ] About shows `0.2.1-beta` afterwards; settings and saved data are intact (Scott)
- [ ] If anything fails, diagnose before publishing anything else — users on a broken updater can't be fixed by an update

---

## Phase 5: Turn notarization on and re-verify

**User stories**: 61, 62 — **blocked on Scott's Apple Developer membership renewal**

### What to build

Scott re-runs `xcrun notarytool store-credentials wirebar-notary …` once renewal clears. Switch the notarization step on (app notarized + stapled, DMG notarized + stapled) and repeat the Phase 3–4 install-then-update test with notarized releases. **No DMG goes to beta testers until this phase passes.**

### Acceptance criteria

- [ ] Script fails early with a clear message if the `wirebar-notary` profile is missing
- [ ] `xcrun stapler validate` passes on the app and the DMG
- [ ] `spctl --assess --type execute` accepts the app; `spctl --assess --type open --context context:primary-signature` accepts the DMG
- [ ] A fresh download from GitHub opens without "Open Anyway" (Scott)
- [ ] Updating from the previous notarized release to the next one works end to end (Scott)
