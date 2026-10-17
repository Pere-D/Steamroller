#!/bin/zsh
# build-app.sh – baut dist/"Steam auf Mac.app" (+ dist/Steam-auf-Mac.zip) aus den Skripten in diesem Repo.
# Braucht nur auf dem Build-Mac die Xcode Command Line Tools (für den kleinen Fenster-Helfer "front").
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$HERE/dist"; APP="$OUT/Steam auf Mac.app"; VERSION="${1:-1.1}"
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/setup"
xcrun swiftc -O -o "$APP/Contents/MacOS/launch" "$HERE/setup/launcher.swift"
xcrun swiftc -O -o "$APP/Contents/MacOS/front" "$HERE/setup/front.swift"
cp "$HERE/setup/app-launch.sh" "$APP/Contents/Resources/launch.sh"; chmod +x "$APP/Contents/Resources/launch.sh"
cp "$HERE/install.sh" "$APP/Contents/Resources/install.sh"
for f in install-engine.sh make-steam-bottle.sh fix-dragonwilds.sh; do cp "$HERE/setup/$f" "$APP/Contents/Resources/setup/$f"; done
cp "$HERE/README.md" "$APP/Contents/Resources/README.md"
chmod +x "$APP/Contents/Resources/install.sh" "$APP/Contents/Resources/setup/"*.sh
cat > "$APP/Contents/Info.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key><string>Steam auf Mac</string>
	<key>CFBundleDisplayName</key><string>Steam auf Mac</string>
	<key>CFBundleIdentifier</key><string>ch.pere-d.steam-auf-mac</string>
	<key>CFBundleExecutable</key><string>launch</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>$VERSION</string>
	<key>CFBundleVersion</key><string>$VERSION</string>
	<key>LSMinimumSystemVersion</key><string>15.0</string>
	<key>LSArchitecturePriority</key><array><string>arm64</string></array>
	<key>NSHighResolutionCapable</key><true/>
	<key>LSUIElement</key><false/>
</dict>
</plist>
PL
codesign --force --deep -s - "$APP"
codesign --verify --deep --strict "$APP" && echo "Signatur (ad hoc) gültig"
rm -f "$OUT/Steam-auf-Mac.zip"
(cd "$OUT" && zip -qr -X "Steam-auf-Mac.zip" "Steam auf Mac.app")   # ohne AppleDouble-Beiwerk, Signatur steckt in den Dateien
echo "Gebaut: $APP"; echo "ZIP:    $OUT/Steam-auf-Mac.zip ($(du -h "$OUT/Steam-auf-Mac.zip" | cut -f1))"
