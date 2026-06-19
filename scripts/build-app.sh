#!/bin/bash
# Build NoteNest in release mode, wrap it in a .app bundle, ad-hoc codesign, and open it.
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1

swift build -c release
BIN_PATH="$(swift build -c release --show-bin-path)"
APP="./NoteNest.app"

mkdir -p "$APP/Contents/MacOS"
cp "$BIN_PATH/NoteNest" "$APP/Contents/MacOS/NoteNest"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>NoteNest</string>
  <key>CFBundleIdentifier</key><string>com.bbarzola.notenest</string>
  <key>CFBundleName</key><string>NoteNest</string>
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
