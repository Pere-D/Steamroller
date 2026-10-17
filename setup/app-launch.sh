#!/bin/zsh
setopt null_glob
# Hauptprogramm von "Steam auf Mac.app":
#  - alles eingerichtet  -> Steam in der Bottle starten (oder nach vorn holen), Dragonwilds-Fix nebenbei pflegen
#  - noch nichts da      -> Erstinstallation in einem Terminal-Fenster starten, danach Steam starten
APP="$(cd "$(dirname "$0")/../.." && pwd)"
RES="$APP/Contents/Resources"
export WINGAMING_DATA="$HOME/Library/Application Support/WinGaming"
export WINGAMING_NO_SHORTCUT=1
export WINGAMING_FRONT="$APP/Contents/MacOS/front"

CMD=""; for c in "/Applications/Whisky.app" "$HOME/Applications/Whisky.app"; do
  [ -x "$c/Contents/Resources/WhiskyCmd" ] && { CMD="$c/Contents/Resources/WhiskyCmd"; break; }; done
STEAM_EXE=""
if [ -n "$CMD" ] && [ -f "$HOME/Library/Application Support/com.franke.Whisky/Libraries/WhiskyWineVersion.plist" ]; then
  for d in "$HOME/Library/Containers/com.franke.Whisky/Bottles"/*/; do
    n="$(/usr/libexec/PlistBuddy -c 'Print :info:name' "$d/Metadata.plist" 2>/dev/null || true)"
    [ "$n" = "Steam" ] && [ -f "$d/drive_c/Program Files (x86)/Steam/Steam.exe" ] && { STEAM_EXE="$d/drive_c/Program Files (x86)/Steam/Steam.exe"; break; }
  done
fi

if [ -n "$STEAM_EXE" ]; then
  "$RES/setup/fix-dragonwilds.sh" Steam >/dev/null 2>&1 || true
  RUNNING="$(pgrep -f 'steamwebhelper.exe -nocrashdialog'; pgrep -f '^C:.*[Ss]team\.exe')"
  if [ -n "$RUNNING" ]; then
    [ -x "$APP/Contents/MacOS/front" ] && "$APP/Contents/MacOS/front" $RUNNING
    exit 0
  fi
  # Steam losgelöst starten; die App selbst beendet sich sofort wieder
  ( "$CMD" run Steam "$STEAM_EXE" >/dev/null 2>&1 & )
  exit 0
fi

# ---- Erstinstallation ----
ANSWER="$(osascript -e 'display dialog "Steam auf Mac richtet beim ersten Start alles ein: Rosetta, Whisky, Wine-Engine mit Apples D3DMetal und Steam.\n\nDauer 5 bis 10 Minuten, rund 1 GB Download. Der Fortschritt erscheint in einem Terminal-Fenster. Danach startet Steam.\n\nVoraussetzung: Mac mit Apple Silicon, macOS 15 oder neuer." buttons {"Abbrechen", "Installieren"} default button "Installieren" with title "Steam auf Mac" with icon note' 2>/dev/null || echo cancel)"
case "$ANSWER" in *Installieren*) ;; *) exit 0 ;; esac
mkdir -p "$WINGAMING_DATA"
RUNNER="$WINGAMING_DATA/Erstinstallation.command"
cat > "$RUNNER" <<EOS
#!/bin/zsh
export WINGAMING_DATA="$WINGAMING_DATA" WINGAMING_NO_SHORTCUT=1 WINGAMING_FRONT="$WINGAMING_FRONT"
clear; echo "Steam auf Mac – Erstinstallation"; echo
if "$RES/install.sh"; then
  echo; echo "Fertig. Steam startet jetzt; dieses Fenster kann geschlossen werden."
  open "$APP"
else
  echo; echo "Installation fehlgeschlagen – bitte die Meldung oben lesen. Taste drücken zum Schliessen."; read -k 1
fi
EOS
chmod +x "$RUNNER"
open -a Terminal "$RUNNER"
