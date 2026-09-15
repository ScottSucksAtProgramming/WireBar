#!/bin/zsh
# Builds a signed, notarized WireBar release: .dmg, release notes, and Sparkle appcast.
# Usage: scripts/release.sh <version>      e.g. scripts/release.sh 0.2.0-beta
# Plan and decisions: plans/phase8-release-pipeline.md, DESIGN_DECISIONS.md Q44.
set -euo pipefail

SIGN_IDENTITY="Developer ID Application: Scott Kostolni (5N69HV7X7S)"
TEAM_ID="5N69HV7X7S"
# Created by Scott with `xcrun notarytool store-credentials wirebar-notary`; the password stays in his keychain.
NOTARY_PROFILE="wirebar-notary"
REPO_URL="https://github.com/ScottSucksAtProgramming/WireBar"

fail() { print -u2 "\n✗ $1"; exit 1; }
step() { print "\n▸ $1"; }

VERSION="${1:-}"
[[ -n "$VERSION" ]] || fail "Usage: scripts/release.sh <version>   (e.g. 0.2.0-beta)"
[[ "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+(-[a-z0-9.]+)?$' ]] || fail "Version '$VERSION' should look like 0.2.0 or 0.2.0-beta"

ROOT="${0:A:h:h}"
cd "$ROOT"

BUILD_DIR="$ROOT/build/release"
DERIVED="$ROOT/build/DerivedData"
SPARKLE_BIN="$DERIVED/SourcePackages/artifacts/sparkle/Sparkle/bin"
OUT_DIR="$ROOT/dist/$VERSION"
DMG="$OUT_DIR/WireBar-$VERSION.dmg"
NOTES_MD="$BUILD_DIR/notes.md"
NOTES_HTML="$OUT_DIR/WireBar-$VERSION.html"   # same basename as the .dmg, so generate_appcast embeds it
APPCAST="$OUT_DIR/appcast.xml"

# --- Preflight ---------------------------------------------------------------
step "Checking the repo"
[[ -z "$(git status --porcelain)" ]] || fail "There are uncommitted changes. Commit or stash them first."
[[ "$(git branch --show-current)" == "main" ]] || fail "Releases are made from main. Merge your branch and switch to main first."
git fetch --quiet origin main --tags || fail "Couldn't reach GitHub to check main is up to date"
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || fail "Local main doesn't match GitHub's main. Pull or push first."
! git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null || fail "Tag v$VERSION already exists. Pick a new version."
! gh release view "v$VERSION" >/dev/null 2>&1 || fail "A GitHub release v$VERSION already exists. Pick a new version."
[[ ! -e "$OUT_DIR" ]] || fail "$OUT_DIR already exists. Move it aside to rebuild this version."
security find-identity -v -p codesigning | grep -q "$SIGN_IDENTITY" || fail "Signing certificate not found: $SIGN_IDENTITY"
command -v xcodegen >/dev/null || fail "xcodegen is not installed (brew install xcodegen)"
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
  || fail "Notarization login '$NOTARY_PROFILE' isn't working. Run: xcrun notarytool store-credentials $NOTARY_PROFILE --apple-id <email> --team-id $TEAM_ID"

# Release notes are the changelog's Unreleased section (without its heading).
mkdir -p "$BUILD_DIR"
awk '/^## \[Unreleased\]/{found=1; next} found && /^## \[/{exit} found' CHANGELOG.md >"$NOTES_MD"
grep -q '^- ' "$NOTES_MD" || fail "CHANGELOG.md has nothing under ## [Unreleased]. Add release notes first."

CURRENT_VERSION=$(sed -n 's/^ *MARKETING_VERSION: "\(.*\)"/\1/p' project.yml)
CURRENT_BUILD=$(sed -n 's/^ *CURRENT_PROJECT_VERSION: "\(.*\)"/\1/p' project.yml)
[[ "$CURRENT_BUILD" =~ '^[0-9]+$' ]] || fail "Couldn't read CURRENT_PROJECT_VERSION from project.yml"
NEW_BUILD=$((CURRENT_BUILD + 1))
print "  $CURRENT_VERSION (build $CURRENT_BUILD) → $VERSION (build $NEW_BUILD)"

# --- Tests -------------------------------------------------------------------
step "Running tests"
EXPECTED_TESTS=$(grep -rho 'func test[A-Za-z0-9_]*' WireBarTests | wc -l | tr -d ' ')
TEST_LOG="$BUILD_DIR/test.log"
xcodebuild test -project WireBar.xcodeproj -scheme WireBar -derivedDataPath "$DERIVED" \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO DEVELOPMENT_TEAM="" \
  >"$TEST_LOG" 2>&1 || true
# The flaky LicenseManager test can crash the run and still print a banner, so count what actually ran.
SUMMARY=$(grep -E "Executed [0-9]+ tests?, with [0-9]+ failures?" "$TEST_LOG" | tail -1 || true)
EXECUTED=$(print -r -- "$SUMMARY" | sed -n 's/.*Executed \([0-9]*\) test.*/\1/p')
FAILURES=$(print -r -- "$SUMMARY" | sed -n 's/.*with \([0-9]*\) failure.*/\1/p')
[[ "$EXECUTED" == "$EXPECTED_TESTS" && "$FAILURES" == "0" ]] \
  || fail "Tests: ran ${EXECUTED:-0} of $EXPECTED_TESTS with ${FAILURES:-?} failures. Log: $TEST_LOG"
print "  $EXECUTED of $EXPECTED_TESTS tests passed"

[[ -x "$SPARKLE_BIN/generate_appcast" && -x "$SPARKLE_BIN/sign_update" ]] \
  || fail "Sparkle's tools weren't found in $SPARKLE_BIN"

# --- Version bump --------------------------------------------------------------
step "Setting version and dating the changelog"
# If anything below fails, put these files back so a failed run leaves the repo clean.
FINISHED=0
trap '[[ $FINISHED == 1 ]] || git checkout -- project.yml WireBar.xcodeproj CHANGELOG.md' EXIT
sed -i '' "s/^\( *MARKETING_VERSION: \)\".*\"/\1\"$VERSION\"/" project.yml
sed -i '' "s/^\( *CURRENT_PROJECT_VERSION: \)\".*\"/\1\"$NEW_BUILD\"/" project.yml
xcodegen generate --quiet
sed -i '' "s/^## \[Unreleased\]\$/## [Unreleased]\\
\\
## [$VERSION] - $(date +%Y-%m-%d)/" CHANGELOG.md

CONDITIONS=$(xcodebuild -project WireBar.xcodeproj -scheme WireBar -configuration Release -showBuildSettings 2>/dev/null \
  | sed -n 's/^ *SWIFT_ACTIVE_COMPILATION_CONDITIONS = //p' | head -1)
[[ "$CONDITIONS" != *BETA_UNLOCK_PAID* ]] || fail "Release build has BETA_UNLOCK_PAID turned on. Remove it from project.yml."

# --- Build and sign ------------------------------------------------------------
step "Building and signing (Release)"
ARCHIVE="$BUILD_DIR/WireBar.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
rm -rf "$ARCHIVE" "$EXPORT_DIR"
xcodebuild archive -project WireBar.xcodeproj -scheme WireBar -configuration Release \
  -derivedDataPath "$DERIVED" -archivePath "$ARCHIVE" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$SIGN_IDENTITY" DEVELOPMENT_TEAM="$TEAM_ID" \
  >"$BUILD_DIR/archive.log" 2>&1 || fail "Archive failed. Log: $BUILD_DIR/archive.log"

cat >"$BUILD_DIR/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>developer-id</string>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>Developer ID Application</string>
  <key>teamID</key><string>$TEAM_ID</string>
</dict>
</plist>
EOF
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
  >"$BUILD_DIR/export.log" 2>&1 || fail "Export failed. Log: $BUILD_DIR/export.log"

APP="$EXPORT_DIR/WireBar.app"
codesign --verify --deep --strict "$APP" || fail "Signature check failed on $APP"
SIGNATURE=$(codesign -dvv "$APP" 2>&1)
[[ "$SIGNATURE" == *"Authority=$SIGN_IDENTITY"* ]] || fail "App isn't signed by $SIGN_IDENTITY"
BUILT_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
BUILT_BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$APP/Contents/Info.plist")
[[ "$BUILT_VERSION" == "$VERSION" && "$BUILT_BUILD" == "$NEW_BUILD" ]] \
  || fail "Built app says $BUILT_VERSION ($BUILT_BUILD), expected $VERSION ($NEW_BUILD)"

# Updates signed with a key the app doesn't trust are silently refused, so compare before publishing anything.
APP_PUBLIC_KEY=$(/usr/libexec/PlistBuddy -c "Print SUPublicEDKey" "$APP/Contents/Info.plist")
KEYCHAIN_PUBLIC_KEY=$("$SPARKLE_BIN/generate_keys" -p 2>/dev/null) \
  || fail "Couldn't read Sparkle's signing key from the keychain (allow access if macOS asked)"
[[ "$APP_PUBLIC_KEY" == "$KEYCHAIN_PUBLIC_KEY" ]] \
  || fail "The app's SUPublicEDKey doesn't match the Sparkle signing key in the keychain"

# Notarize the app itself too, so a copy dragged out of the .dmg carries its own ticket.
notarize() {  # $1 = file to submit, $2 = what to staple
  local log="$BUILD_DIR/notarize-${1:t}.log"
  xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait >"$log" 2>&1 \
    || fail "Notarization submit failed. Log: $log"
  grep -q "status: Accepted" "$log" \
    || fail "Apple did not accept ${1:t}. Log: $log  (details: xcrun notarytool log <submission id> --keychain-profile $NOTARY_PROFILE)"
  xcrun stapler staple "$2" >>"$log" 2>&1 || fail "Stapling failed. Log: $log"
  xcrun stapler validate "$2" >/dev/null 2>&1 || fail "Stapled ticket didn't validate on $2"
}

step "Notarizing the app (usually a few minutes)"
APP_ZIP="$BUILD_DIR/WireBar.zip"
rm -f "$APP_ZIP"
ditto -c -k --keepParent "$APP" "$APP_ZIP"
notarize "$APP_ZIP" "$APP"
spctl --assess --type execute "$APP" 2>/dev/null || fail "Gatekeeper rejects the notarized app"

# --- DMG -----------------------------------------------------------------------
step "Making the .dmg"
STAGE="$BUILD_DIR/dmg"
rm -rf "$STAGE"
mkdir -p "$STAGE" "$OUT_DIR"
ditto "$APP" "$STAGE/WireBar.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "WireBar" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null 2>&1
codesign --sign "$SIGN_IDENTITY" --timestamp "$DMG"
codesign --verify "$DMG" || fail "Signature check failed on $DMG"

step "Notarizing the .dmg"
notarize "$DMG" "$DMG"
spctl --assess --type open --context context:primary-signature "$DMG" 2>/dev/null || fail "Gatekeeper rejects the .dmg"

# --- Release notes and appcast ---------------------------------------------------
step "Writing release notes and the update feed"
# Minimal Markdown → HTML for the changelog's "### Heading" and "- item" lines.
awk '
  function esc(s) { gsub(/&/, "\\&amp;", s); gsub(/</, "\\&lt;", s); gsub(/>/, "\\&gt;", s); return s }
  /^### / { if (inList) { print "</ul>"; inList = 0 }; print "<h3>" esc(substr($0, 5)) "</h3>"; next }
  /^- /   { if (!inList) { print "<ul>"; inList = 1 }; print "<li>" esc(substr($0, 3)) "</li>"; next }
  /^[[:space:]]*$/ { next }
  { if (inList) { print "</ul>"; inList = 0 }; print "<p>" esc($0) "</p>" }
  END { if (inList) print "</ul>" }
' "$NOTES_MD" >"$NOTES_HTML"

"$SPARKLE_BIN/generate_appcast" \
  --download-url-prefix "$REPO_URL/releases/download/v$VERSION/" \
  --embed-release-notes \
  -o "$APPCAST" "$OUT_DIR" >"$BUILD_DIR/appcast.log" 2>&1 \
  || fail "generate_appcast failed. Log: $BUILD_DIR/appcast.log"

ITEMS=$(grep -c "<item>" "$APPCAST" || true)
[[ "$ITEMS" == "1" ]] || fail "appcast.xml should list exactly 1 update, found $ITEMS"
grep -q "<sparkle:version>$NEW_BUILD</sparkle:version>" "$APPCAST" || fail "appcast.xml doesn't say build $NEW_BUILD"
grep -q "<sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>" "$APPCAST" || fail "appcast.xml doesn't say version $VERSION"
grep -q "url=\"$REPO_URL/releases/download/v$VERSION/WireBar-$VERSION.dmg\"" "$APPCAST" \
  || fail "appcast.xml download link isn't $REPO_URL/releases/download/v$VERSION/WireBar-$VERSION.dmg"
ED_SIGNATURE=$(sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p' "$APPCAST" | head -1)
[[ -n "$ED_SIGNATURE" ]] || fail "appcast.xml has no update signature"
"$SPARKLE_BIN/sign_update" --verify "$DMG" "$ED_SIGNATURE" >/dev/null 2>&1 \
  || fail "The update signature in appcast.xml doesn't match the .dmg"
grep -q "<li>" "$APPCAST" || fail "Release notes weren't embedded in appcast.xml"

# --- Confirm and publish ---------------------------------------------------------
print "\n✓ Built and checked WireBar $VERSION (build $NEW_BUILD)"
print "\n  Files:"
print "    $(du -h "$DMG" | cut -f1)  ${DMG:t}"
print "    $(du -h "$APPCAST" | cut -f1)  ${APPCAST:t}"
print "\n  Release notes:"
sed 's/^/    /' "$NOTES_MD"
print "\n  Publishing will commit the version bump, tag v$VERSION, push to GitHub, and create a"
print "  public release. Anyone running WireBar will be offered this update."
# Anything but "y" (including no terminal to answer) publishes nothing; the EXIT trap undoes the bump.
if ! read -q "REPLY?  Publish $VERSION to GitHub? (y/n) "; then
  print "\n\nNot published. Version changes were undone; the build stays in $OUT_DIR."
  exit 0
fi
print

step "Committing and tagging"
git add project.yml WireBar.xcodeproj CHANGELOG.md
git commit --quiet -m "release: $VERSION (build $NEW_BUILD)"
FINISHED=1   # committed now, so a later failure must not undo the version files
git tag -a "v$VERSION" -m "WireBar $VERSION (build $NEW_BUILD)"
git push --quiet origin main "v$VERSION" \
  || fail "Push failed. The release commit and tag exist locally; fix the problem, then: git push origin main v$VERSION"

step "Creating the GitHub release"
gh release create "v$VERSION" "$DMG" "$APPCAST" \
  --title "WireBar $VERSION" --notes-file "$NOTES_MD" --latest --verify-tag >/dev/null \
  || fail "gh release create failed. The tag is pushed; retry: gh release create v$VERSION \"$DMG\" \"$APPCAST\" --title \"WireBar $VERSION\" --notes-file \"$NOTES_MD\" --latest --verify-tag"
[[ "$(gh release view "v$VERSION" --json isDraft,isPrerelease --jq '"\(.isDraft) \(.isPrerelease)"')" == "false false" ]] \
  || fail "Release v$VERSION is a draft or pre-release, so the app's update check won't see it"

step "Checking the app's update feed"
FEED_URL="$REPO_URL/releases/latest/download/appcast.xml"
for attempt in {1..12}; do
  curl -sfL "$FEED_URL" | grep -q "<sparkle:version>$NEW_BUILD</sparkle:version>" && break
  (( attempt < 12 )) || fail "$FEED_URL doesn't show build $NEW_BUILD yet. Check the release page, then retry in a minute."
  sleep 10
done
print "  $FEED_URL → build $NEW_BUILD"

print "\n✓ Published WireBar $VERSION: $REPO_URL/releases/tag/v$VERSION"
