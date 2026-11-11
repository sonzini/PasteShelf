#!/bin/zsh
# Re-renders the app icon from scripts/make-icon.swift into the asset catalog and docs/.
set -euo pipefail
cd "$(dirname "$0")/.."
SET="PasteShelf/Resources/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$SET" docs
swift scripts/make-icon.swift docs/icon.png
for s in 16 32 128 256 512; do
  sips -z $s $s docs/icon.png --out "$SET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) docs/icon.png --out "$SET/icon_${s}x${s}@2x.png" >/dev/null
done
echo "Icon updated."
