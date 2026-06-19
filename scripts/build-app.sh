#!/bin/bash
# Build NoteNest in release mode, wrap it in a .app bundle, ad-hoc codesign, and open it.
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1

swift build -c release
BIN_PATH="$(swift build -c release --show-bin-path)"
APP="./NoteNest.app"

mkdir -p "$APP/Contents/MacOS"
cp "$BIN_PATH/NoteNest" "$APP/Contents/MacOS/NoteNest"

# --- Build the app icon (AppIcon.icns) ---
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
BASE_PNG="$(mktemp -d)/icon-1024.png"
swift scripts/make-icon.swift "$BASE_PNG"
# Generate the required iconset sizes from the 1024 master.
for SZ in 16 32 64 128 256 512 1024; do
  sips -z "$SZ" "$SZ" "$BASE_PNG" --out "$ICONSET/icon_${SZ}x${SZ}.png" >/dev/null
done
# Retina (@2x) variants expected by iconutil.
cp "$ICONSET/icon_32x32.png"   "$ICONSET/icon_16x16@2x.png"
cp "$ICONSET/icon_64x64.png"   "$ICONSET/icon_32x32@2x.png"
cp "$ICONSET/icon_256x256.png" "$ICONSET/icon_128x128@2x.png"
cp "$ICONSET/icon_512x512.png" "$ICONSET/icon_256x256@2x.png"
cp "$ICONSET/icon_1024x1024.png" "$ICONSET/icon_512x512@2x.png"
mkdir -p "$APP/Contents/Resources"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>NoteNest</string>
  <key>CFBundleIdentifier</key><string>com.bbarzola.notenest</string>
  <key>CFBundleName</key><string>NoteNest</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "Built $APP"
open "$APP"
