#!/bin/bash
# Startet Steam in der Whisky-Bottle "Steam".
# Läuft Steam dort bereits, wird nur sein Fenster nach vorn geholt (sonst passiert beim Doppelklick scheinbar nichts).
HERE="$(cd "$(dirname "$0")" && pwd)"
WHISKY_CMD="/Applications/Whisky.app/Contents/Resources/WhiskyCmd"
if [ ! -x "$WHISKY_CMD" ]; then
    WHISKY_APP="$(mdfind "kMDItemCFBundleIdentifier == 'com.franke.Whisky'" 2>/dev/null | head -n 1)"
    WHISKY_CMD="$WHISKY_APP/Contents/Resources/WhiskyCmd"
fi
if [ ! -x "$WHISKY_CMD" ]; then
    osascript -e 'display alert "Whisky nicht gefunden" message "Whisky installieren: brew install --cask frankea/whisky/whisky"'
    exit 1
fi
RUNNING="$(pgrep -f 'steamwebhelper.exe -nocrashdialog'; pgrep -f '^C:.*[Ss]team\.exe')"
if [ -n "$RUNNING" ]; then
    if [ -x "$HERE/front" ]; then
        "$HERE/front" $RUNNING
    else
        osascript -e 'display notification "Steam läuft bereits in der Bottle – Fenster „Sign in to Steam“ bzw. Steam suchen." with title "Steam (Whisky)"'
    fi
    exit 0
fi
exec "$WHISKY_CMD" run 'Steam' 'C:\Program Files (x86)\Steam\Steam.exe'
