#!/bin/zsh
# install.sh – complete setup for Apple Silicon Macs, without Homebrew and without Xcode:
#   1) prerequisites (Apple Silicon, macOS 15+, Rosetta)
#   2) Whisky (frankea's fork) from the signed DMG into /Applications
#   3) GPTK-capable runtime + Apple's D3DMetal                (setup/install-engine.sh)
#   4) bottle "Steam", Steam installed                        (setup/make-steam-bottle.sh)
# Downloads go to $STEAMROLLER_DATA (default: this folder).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
export STEAMROLLER_DATA="${STEAMROLLER_DATA:-$HERE}"
WHISKY_DMG_URL="https://github.com/frankea/Whisky/releases/download/app-v3.7.0/Whisky-3.7.0.dmg"
WHISKY_DMG_SHA="8232b3b96be09b56e8f4e6b091c34a89c74b27c63ccfce92aa8ffe6ce3fbfee2"
log(){ printf '\n\033[1m==> %s\033[0m\n' "$*"; }
die(){ printf '\033[31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

log "Prerequisites"
[ "$(uname -m)" = "arm64" ] || die "Apple Silicon Macs only (M1 or newer)."
MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
[ "$MAJOR" -ge 15 ] || die "macOS 15 (Sequoia) or newer required, found $(sw_vers -productVersion)"
if ! /usr/bin/pgrep -q oahd; then
  log "Installing Rosetta (macOS may ask for your password)"
  softwareupdate --install-rosetta --agree-to-license \
    || sudo softwareupdate --install-rosetta --agree-to-license \
    || die "Rosetta could not be installed"
fi
echo "Apple Silicon, macOS $(sw_vers -productVersion), Rosetta: OK"

log "Whisky"
WHISKY_APP=""
for c in "/Applications/Whisky.app" "$HOME/Applications/Whisky.app"; do
  if [ -d "$c" ] && /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$c/Contents/Info.plist" 2>/dev/null | grep -q com.franke.Whisky; then
    WHISKY_APP="$c"; break
  fi
done
if [ -n "$WHISKY_APP" ]; then
  echo "Whisky $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$WHISKY_APP/Contents/Info.plist") is installed ($WHISKY_APP)"
else
  DMG="$STEAMROLLER_DATA/downloads/whisky/Whisky-3.7.0.dmg"
  if [ ! -f "$DMG" ]; then
    mkdir -p "$(dirname "$DMG")"; echo "Downloading Whisky ($WHISKY_DMG_URL)"
    curl -fL --progress-bar -o "$DMG.part" "$WHISKY_DMG_URL" && mv "$DMG.part" "$DMG" || die "Whisky download failed"
  fi
  [ "$(shasum -a 256 "$DMG" | cut -d' ' -f1)" = "$WHISKY_DMG_SHA" ] || die "SHA-256 mismatch for the Whisky DMG; delete it: $DMG"
  echo "Checksum OK"
  MNT="$(mktemp -d)"
  # no "yes |" here: with pipefail its SIGPIPE exit would count as a failure although hdiutil succeeded
  printf 'Y\n' | hdiutil attach -nobrowse -readonly -quiet -mountpoint "$MNT" "$DMG" || die "Could not open the DMG"
  DEST="/Applications"; [ -w /Applications ] || { DEST="$HOME/Applications"; mkdir -p "$DEST"; }
  rm -rf "$DEST/Whisky.app"
  ditto "$MNT/Whisky.app" "$DEST/Whisky.app" || { hdiutil detach "$MNT" -quiet; die "Copying to $DEST failed"; }
  hdiutil detach "$MNT" -quiet || true
  xattr -dr com.apple.quarantine "$DEST/Whisky.app" 2>/dev/null || true
  WHISKY_APP="$DEST/Whisky.app"; echo "Whisky installed to $WHISKY_APP"
fi

"$HERE/setup/install-engine.sh"
"$HERE/setup/make-steam-bottle.sh"

printf '\n\033[32mAll set.\033[0m\n'
