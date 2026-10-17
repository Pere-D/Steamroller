#!/bin/zsh
# build-app.sh – builds dist/Steamroller.app (+ dist/Steamroller.zip) from the scripts in this repository.
# Only the build Mac needs the Xcode Command Line Tools (for the tiny Mach-O launcher and the window helper).
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$HERE/dist"; APP="$OUT/Steamroller.app"; VERSION="${1:-1.2}"
rm -rf "${APP:?}"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/setup"
xcrun swiftc -O -o "$APP/Contents/MacOS/launch" "$HERE/setup/launcher.swift"
xcrun swiftc -O -o "$APP/Contents/MacOS/front" "$HERE/setup/front.swift"
cp "$HERE/setup/app-launch.sh" "$APP/Contents/Resources/launch.sh"; chmod +x "$APP/Contents/Resources/launch.sh"
cp "$HERE/install.sh" "$APP/Contents/Resources/install.sh"
for f in install-engine.sh make-steam-bottle.sh fix-dragonwilds.sh; do cp "$HERE/setup/$f" "$APP/Contents/Resources/setup/$f"; done
cp "$HERE/README.md" "$APP/Contents/Resources/README.md"
cp "$HERE/setup/icon/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
chmod +x "$APP/Contents/Resources/install.sh" "$APP/Contents/Resources/setup/"*.sh
cat > "$APP/Contents/Info.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key><string>Steamroller</string>
	<key>CFBundleDisplayName</key><string>Steamroller</string>
	<key>CFBundleIdentifier</key><string>app.steamroller</string>
	<key>CFBundleExecutable</key><string>launch</string>
	<key>CFBundleIconFile</key><string>AppIcon</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>$VERSION</string>
	<key>CFBundleVersion</key><string>$VERSION</string>
	<key>LSMinimumSystemVersion</key><string>15.0</string>
	<key>LSArchitecturePriority</key><array><string>arm64</string></array>
	<key>NSHighResolutionCapable</key><true/>
	<key>NSHumanReadableCopyright</key><string>MIT License. Not affiliated with Valve, Jagex, Apple or CodeWeavers.</string>
</dict>
</plist>
PL
codesign --force --deep -s - "$APP"
codesign --verify --deep --strict "$APP" && echo "ad-hoc signature valid"
rm -f "$OUT/Steamroller.zip"
(cd "$OUT" && zip -qr -X "Steamroller.zip" "Steamroller.app")   # plain zip: the signature lives in the files
echo "Built: $APP"; echo "ZIP:   $OUT/Steamroller.zip ($(du -h "$OUT/Steamroller.zip" | cut -f1))"
