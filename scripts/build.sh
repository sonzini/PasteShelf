#!/bin/zsh
# Builds a Release copy of PasteShelf.
#   ./scripts/build.sh            → build/PasteShelf.app
#   ./scripts/build.sh --install  → also copies it to /Applications and launches it
#   ./scripts/build.sh --zip      → also creates build/PasteShelf-<version>.zip for a GitHub release
set -euo pipefail
cd "$(dirname "$0")/.."

APP=PasteShelf
INSTALL=false; ZIP=false
for arg in "$@"; do
  case "$arg" in
    --install) INSTALL=true ;;
    --zip) ZIP=true ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done

xcodebuild -project "$APP.xcodeproj" -scheme "$APP" -configuration Release \
  -derivedDataPath build/DerivedData build -quiet

rm -rf "build/$APP.app"
cp -R "build/DerivedData/Build/Products/Release/$APP.app" build/
VERSION=$(defaults read "$PWD/build/$APP.app/Contents/Info" CFBundleShortVersionString)
echo "Built build/$APP.app (v$VERSION)"

if $ZIP; then
  rm -f "build/$APP-$VERSION.zip"
  ditto -c -k --keepParent "build/$APP.app" "build/$APP-$VERSION.zip"
  echo "Created build/$APP-$VERSION.zip"
fi

if $INSTALL; then
  pkill -x "$APP" 2>/dev/null || true
  sleep 0.5
  rm -rf "/Applications/$APP.app"
  cp -R "build/$APP.app" /Applications/
  open "/Applications/$APP.app"
  echo "Installed to /Applications/$APP.app"
fi
