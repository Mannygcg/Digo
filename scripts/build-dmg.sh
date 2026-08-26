#!/bin/bash
# Builds Digo.app and packages it into an installable, unsigned .dmg.
# Run from the repo root: ./scripts/build-dmg.sh [version]
set -euo pipefail

VERSION="${1:-0.1.0}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "==> Regenerating Xcode project with XcodeGen"
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "XcodeGen not found — installing via Homebrew..."
  brew install xcodegen
fi
xcodegen generate

echo "==> Archiving Digo (unsigned build, version $VERSION)"
rm -rf build
xcodebuild archive \
  -project Digo.xcodeproj \
  -scheme Digo \
  -configuration Release \
  -archivePath build/Digo.xcarchive \
  -destination "generic/platform=macOS" \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  MARKETING_VERSION="$VERSION"

echo "==> Exporting Digo.app and applying an ad-hoc signature"
mkdir -p build/export
cp -R "build/Digo.xcarchive/Products/Applications/Digo.app" build/export/
codesign --force --deep --sign - "build/export/Digo.app"

echo "==> Packaging build/Digo-$VERSION.dmg"
if ! command -v create-dmg >/dev/null 2>&1; then
  echo "create-dmg not found — installing via Homebrew..."
  brew install create-dmg
fi

rm -rf build/dmg-source
mkdir -p build/dmg-source
cp -R build/export/Digo.app build/dmg-source/
rm -f "build/Digo-$VERSION.dmg"

# create-dmg drives Finder via AppleScript to lay out the window, which
# occasionally exits non-zero even when it actually succeeds — so check
# for the real output file rather than trusting its exit code alone.
create-dmg \
  --volname "Digo" \
  --background "dmg-assets/background.png" \
  --window-size 660 400 \
  --icon-size 128 \
  --icon "Digo.app" 180 185 \
  --app-drop-link 480 185 \
  --hide-extension "Digo.app" \
  --no-internet-enable \
  "build/Digo-$VERSION.dmg" \
  "build/dmg-source" || true

if [ ! -f "build/Digo-$VERSION.dmg" ]; then
  echo "create-dmg didn't produce a file — falling back to a plain hdiutil dmg"
  hdiutil create -volname "Digo" \
    -srcfolder build/export/Digo.app \
    -ov -format UDZO \
    "build/Digo-$VERSION.dmg"
fi

echo ""
echo "Done: build/Digo-$VERSION.dmg"
echo "First launch needs a right-click > Open to get past Gatekeeper (it's unsigned)."
