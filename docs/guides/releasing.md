# Guide: Releasing a New Version

One command builds, tests, notarizes, and publishes WireBar. Everyone running WireBar is then offered the update automatically.

How the pipeline was designed: `plans/phase8-release-pipeline.md` and `DESIGN_DECISIONS.md` Q44.

---

## Quick version

1. The changes are merged into `main` and pushed.
2. `CHANGELOG.md` has notes under `## [Unreleased]`, committed and pushed.
3. Run `scripts/release.sh <version>` in your own Terminal.
4. Read the summary and press **y**.
5. Click **Check for Updates** in your installed WireBar to confirm it offers the new version.

The details for each step are below.

---

## Step 1: Pick the version number

Versions look like `0.2.3-beta`. Choose the next one:

| Kind of release | Change | Example |
|---|---|---|
| Small fixes | last number | `0.2.2-beta` → `0.2.3-beta` |
| New features | middle number, last resets to 0 | `0.2.3-beta` → `0.3.0-beta` |
| Paid launch | drop `-beta` | `1.0.0` |

Check what was released last: https://github.com/ScottSucksAtProgramming/WireBar/releases

You don't choose the **build number**. The script raises it by 1 every release, and that's what tells the app an update is newer.

---

## Step 2: Write the release notes

Open `CHANGELOG.md` and add notes under `## [Unreleased]`. Testers see these in the update window and on the GitHub release page, so write them for users:

```markdown
## [Unreleased]

### Added
- Something new people can do

### Fixed
- Something that used to go wrong and now works
```

Use `### Added`, `### Changed`, or `### Fixed` headings and one `- ` line per change. Leave the version and date off; the script adds them.

Commit and push this to `main` before releasing.

---

## Step 3: Run the release

Releases must run in **your own Terminal**, because the script asks you to confirm before publishing.

```bash
cd ~/programming_projects/wifi-menubar && scripts/release.sh 0.2.3-beta
```

It takes about 15 minutes, mostly waiting on Apple's notarization. You'll see each stage:

```
▸ Checking the repo
▸ Running tests
▸ Setting version and dating the changelog
▸ Building and signing (Release)
▸ Notarizing the app (usually a few minutes)
▸ Making the .dmg
▸ Notarizing the .dmg
▸ Writing release notes and the update feed
```

If macOS asks whether `generate_keys` or `generate_appcast` can use the **sparkle-project.org** keychain item, click **Always Allow**.

---

## Step 4: Confirm

When everything passes, the script shows the version, the files, and the release notes, then asks:

```
Publish 0.2.3-beta to GitHub? (y/n)
```

- **y** publishes. The script commits the new version, tags it, pushes to GitHub, creates the release, and checks that the app's update feed shows the new version.
- **Anything else** stops. Nothing is published, and the version changes are undone. The built files stay in `dist/<version>/` if you want to look at them.

A successful release ends with:

```
✓ Published WireBar 0.2.3-beta: https://github.com/ScottSucksAtProgramming/WireBar/releases/tag/v0.2.3-beta
```

---

## Step 5: Check the update works

In your installed WireBar, open **Settings → About → Check for Updates**. It should offer the new version with your release notes. Install it and confirm **About** shows the new version number.

Testers get the update the same way, or automatically if **Automatically check for updates** is on.

---

## If the script stops

Every stop begins with **✗** and says what to do. Nothing is published unless you pressed **y**, and a stopped run undoes its version changes.

| Message starts with | What to do |
|---|---|
| "There are uncommitted changes" | Commit or stash your changes, then rerun. |
| "Releases are made from main" | Merge your branch, then `git checkout main`. |
| "Local main doesn't match GitHub's main" | Run `git pull` (or `git push` if you have unpushed commits). |
| "Tag … already exists" / "A GitHub release … already exists" | That version was already released. Pick the next number. |
| "dist/\<version\> already exists" | A build for that version is left over from a stopped run. Move the folder into `dist/old/`, then rerun. |
| "CHANGELOG.md has nothing under ## [Unreleased]" | Write release notes (Step 2), commit, push. |
| "Notarization login 'wirebar-notary' isn't working" | Your Apple login expired or changed. Rerun: `xcrun notarytool store-credentials wirebar-notary --apple-id <your Apple ID email> --team-id 5N69HV7X7S` and paste a new app-specific password from appleid.apple.com. |
| "HTTP status code: 403 … agreement" (in a notarize log) | Accept the updated agreement at developer.apple.com/account, or renew your membership. |
| "Tests: ran X of Y" | A test failed or crashed. Open the log it names, or ask Claude to diagnose. |
| "Signing certificate not found" | The Developer ID certificate is missing from your keychain. Check Keychain Access, or re-download it from developer.apple.com. |
| "Couldn't read Sparkle's signing key" | macOS blocked keychain access. Rerun and click **Always Allow**. |
| "Push failed" or "gh release create failed" | The release commit exists but isn't fully published. The message gives the exact command to finish it. |

---

## Things that must stay true

- **Never mark a release as "Pre-release" or "Draft" on GitHub.** The app only checks the newest normal release, so a pre-release is invisible to it.
- **Never delete an older release's files.** People on older versions still download from them.
- **Keep these safe; releases can't happen without them:**
  - the **Developer ID Application** certificate (Keychain Access)
  - the **sparkle-project.org** key in your login keychain, which signs updates. If it's lost, existing users can never be updated again.
  - the **wirebar-notary** saved login
- **Your Apple Developer membership must be active.** When it lapses, notarization fails with a 403 error.

---

## Where things are

| What | Where |
|---|---|
| Release script | `scripts/release.sh` |
| Built files for each release | `dist/<version>/` (not in git) |
| Old or trial builds | `dist/old/` |
| Logs from the last run | `build/release/` (test, archive, export, notarize, and appcast logs) |
| Published releases | https://github.com/ScottSucksAtProgramming/WireBar/releases |
| Feed the app checks | https://github.com/ScottSucksAtProgramming/WireBar/releases/latest/download/appcast.xml |
