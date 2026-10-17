#!/bin/zsh
# install.sh – Komplettinstallation für Apple-Silicon-Macs, ohne Homebrew und ohne Xcode:
#   1) Voraussetzungen (Apple Silicon, macOS 15+, Rosetta)
#   2) Whisky (Fork von frankea) aus der signierten DMG nach /Applications
#   3) GPTk-fähige Runtime + Apples D3DMetal                 (setup/install-engine.sh)
#   4) Bottle "Steam" anlegen, Steam installieren             (setup/make-steam-bottle.sh)
# Downloads landen in $WINGAMING_DATA (Standard: dieser Ordner).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
export WINGAMING_DATA="${WINGAMING_DATA:-$HERE}"
WHISKY_DMG_URL="https://github.com/frankea/Whisky/releases/download/app-v3.7.0/Whisky-3.7.0.dmg"
WHISKY_DMG_SHA="8232b3b96be09b56e8f4e6b091c34a89c74b27c63ccfce92aa8ffe6ce3fbfee2"
log(){ printf '\n\033[1m==> %s\033[0m\n' "$*"; }
die(){ printf '\033[31mFEHLER: %s\033[0m\n' "$*" >&2; exit 1; }

log "Voraussetzungen"
[ "$(uname -m)" = "arm64" ] || die "Nur für Apple-Silicon-Macs (M1 oder neuer)."
MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
[ "$MAJOR" -ge 15 ] || die "macOS 15 (Sequoia) oder neuer nötig, gefunden: $(sw_vers -productVersion)"
if ! /usr/bin/pgrep -q oahd; then
  log "Rosetta wird installiert (macOS fragt eventuell nach dem Passwort)"
  softwareupdate --install-rosetta --agree-to-license \
    || sudo softwareupdate --install-rosetta --agree-to-license \
    || die "Rosetta konnte nicht installiert werden"
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
  echo "Whisky $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$WHISKY_APP/Contents/Info.plist") ist installiert ($WHISKY_APP)"
else
  DMG="$WINGAMING_DATA/downloads/whisky/Whisky-3.7.0.dmg"
  if [ ! -f "$DMG" ]; then
    mkdir -p "$(dirname "$DMG")"; echo "Lade Whisky ($WHISKY_DMG_URL)"
    curl -fL --progress-bar -o "$DMG.part" "$WHISKY_DMG_URL" && mv "$DMG.part" "$DMG" || die "Download von Whisky fehlgeschlagen"
  fi
  [ "$(shasum -a 256 "$DMG" | cut -d' ' -f1)" = "$WHISKY_DMG_SHA" ] || die "Prüfsumme der Whisky-DMG stimmt nicht; Datei löschen: $DMG"
  echo "Prüfsumme OK"
  MNT="$(mktemp -d)"
  # kein "yes |": mit pipefail würde dessen SIGPIPE-Ende als Fehler zählen, obwohl hdiutil Erfolg hatte
  printf 'Y\n' | hdiutil attach -nobrowse -readonly -quiet -mountpoint "$MNT" "$DMG" || die "DMG liess sich nicht öffnen"
  DEST="/Applications"; [ -w /Applications ] || { DEST="$HOME/Applications"; mkdir -p "$DEST"; }
  rm -rf "$DEST/Whisky.app"
  ditto "$MNT/Whisky.app" "$DEST/Whisky.app" || { hdiutil detach "$MNT" -quiet; die "Kopieren nach $DEST fehlgeschlagen"; }
  hdiutil detach "$MNT" -quiet || true
  xattr -dr com.apple.quarantine "$DEST/Whisky.app" 2>/dev/null || true
  WHISKY_APP="$DEST/Whisky.app"; echo "Whisky installiert nach $WHISKY_APP"
fi

"$HERE/setup/install-engine.sh"
"$HERE/setup/make-steam-bottle.sh"

printf '\n\033[32mAlles bereit.\033[0m\n'
