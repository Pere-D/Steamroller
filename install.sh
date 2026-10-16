#!/bin/zsh
# install.sh – Alles in einem: freier CrossOver-Ersatz für Steam-Spiele auf Apple-Silicon-Macs.
#   1) Voraussetzungen prüfen (Apple Silicon, macOS 15+, Rosetta, Homebrew)
#   2) Whisky (Fork von frankea) per Homebrew installieren
#   3) GPTk-fähige Runtime + Apples D3DMetal einrichten   (setup/install-engine.sh)
#   4) Bottle "Steam" anlegen und Steam installieren       (setup/make-steam-bottle.sh)
# Danach: Doppelklick auf "Steam (Whisky).app", einloggen, Spiel installieren.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
log(){ printf '\n\033[1m==> %s\033[0m\n' "$*"; }
die(){ printf '\033[31mFEHLER: %s\033[0m\n' "$*" >&2; exit 1; }

log "Voraussetzungen"
[ "$(uname -m)" = "arm64" ] || die "Nur für Apple-Silicon-Macs (M1 oder neuer)."
MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
[ "$MAJOR" -ge 15 ] || die "macOS 15 (Sequoia) oder neuer nötig, gefunden: $(sw_vers -productVersion)"
if ! /usr/bin/pgrep -q oahd; then
  log "Rosetta wird installiert"
  softwareupdate --install-rosetta --agree-to-license || die "Rosetta konnte nicht installiert werden"
fi
if ! command -v brew >/dev/null 2>&1; then
  [ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
fi
command -v brew >/dev/null 2>&1 || die 'Homebrew fehlt. Erst installieren: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"  – danach dieses Skript erneut starten.'
echo "Apple Silicon, macOS $(sw_vers -productVersion), Rosetta, Homebrew: OK"

log "Whisky (Fork) installieren"
if [ -d /Applications/Whisky.app ] && /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' /Applications/Whisky.app/Contents/Info.plist 2>/dev/null | grep -q 'com.franke.Whisky'; then
  echo "Whisky $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' /Applications/Whisky.app/Contents/Info.plist) ist installiert"
else
  brew install --cask frankea/whisky/whisky
fi

"$HERE/setup/install-engine.sh"
"$HERE/setup/make-steam-bottle.sh"

printf '\n\033[32mAlles bereit. Doppelklick auf "%s/Steam (Whisky).app", einloggen, Spiel installieren.\033[0m\n' "$HERE"
