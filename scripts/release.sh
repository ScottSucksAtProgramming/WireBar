#!/bin/zsh
# Builds a signed WireBar release .dmg.
# Usage: scripts/release.sh <version>      e.g. scripts/release.sh 0.2.0-beta
# Plan and decisions: plans/phase8-release-pipeline.md, DESIGN_DECISIONS.md Q44.
set -euo pipefail

SIGN_IDENTITY="Developer ID Application: Scott Kostolni (5N69HV7X7S)"
TEAM_ID="5N69HV7X7S"

fail() { print -u2 "\n✗ $1"; exit 1; }
step() { print "\n▸ $1"; }

VERSION="${1:-}"
[[ -n "$VERSION" ]] || fail "Usage: scripts/release.sh <version>   (e.g. 0.2.0-beta)"
[[ "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+(-[a-z0-9.]+)?$' ]] || fail "Version '$VERSION' should look like 0.2.0 or 0.2.0-beta"

ROOT="${0:A:h:h}"
cd "$ROOT"

BUILD_DIR="$ROOT/build/release"
DERIVED="$ROOT/build/DerivedData"
OUT_DIR="$ROOT/dist/$VERSION"
DMG="$OUT_DIR/WireBar-$VERSION.dmg"

# --- Preflight ---------------------------------------------------------------
step "Checking the repo"
[[ -z "$(git status --porcelain)" ]] || fail "There are uncommitted changes. Commit or stash them first."
[[ ! -e "$OUT_DIR" ]] || fail "$OUT_DIR already exists. Move it aside to rebuild this version."
security find-identity -v -p codesigning | grep -q "$SIGN_IDENTITY" || fail "Signing certificate not found: $SIGN_IDENTITY"
command -v xcodegen >/dev/null || fail "xcodegen is not installed (brew install xcodegen)"

CURRENT_VERSION=$(sed -n 's/^ *MARKETING_VERSION: "\(.*\)"/\1/p' project.yml)
CURRENT_BUILD=$(sed -n 's/^ *CURRENT_PROJECT_VERSION: "\(.*\)"/\1/p' project.yml)
[[ "$CURRENT_BUILD" =~ '^[0-9]+$' ]] || fail "Couldn't read CURRENT_PROJECT_VERSION from project.yml"
NEW_BUILD=$((CURRENT_BUILD + 1))
print "  $CURRENT_VERSION (build $CURRENT_BUILD) → $VERSION (build $NEW_BUILD)"

# --- Tests -------------------------------------------------------------------
step "Running tests"
EXPECTED_TESTS=$(grep -rho 'func test[A-Za-z0-9_]*' WireBarTests | wc -l | tr -d ' ')
TEST_LOG="$BUILD_DIR/test.log"
mkdir -p "$BUILD_DIR"
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

# --- Version bump --------------------------------------------------------------
step "Setting version"
# If anything below fails, put the version back so a failed run leaves the repo clean.
FINISHED=0
trap '[[ $FINISHED == 1 ]] || git checkout -- project.yml WireBar.xcodeproj' EXIT
sed -i '' "s/^\( *MARKETING_VERSION: \)\".*\"/\1\"$VERSION\"/" project.yml
sed -i '' "s/^\( *CURRENT_PROJECT_VERSION: \)\".*\"/\1\"$NEW_BUILD\"/" project.yml
xcodegen generate --quiet

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

# --- DMG -----------------------------------------------------------------------
step "Making the .dmg"
STAGE="$BUILD_DIR/dmg"
rm -rf "$STAGE"
mkdir -p "$STAGE" "$OUT_DIR"
ditto "$APP" "$STAGE/WireBar.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "WireBar" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
codesign --sign "$SIGN_IDENTITY" --timestamp "$DMG"
codesign --verify "$DMG" || fail "Signature check failed on $DMG"

FINISHED=1
print "\n✓ Built $DMG"
print "  Version $VERSION (build $NEW_BUILD). project.yml and WireBar.xcodeproj now carry the new version (uncommitted)."
