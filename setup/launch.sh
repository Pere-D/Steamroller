#!/bin/bash
# Starts Steam in the Whisky bottle "Steam" (launcher created by make-steam-bottle.sh).
# If Steam is already running there, only its window is brought to the front.
HERE="$(cd "$(dirname "$0")" && pwd)"
WHISKY_CMD="/Applications/Whisky.app/Contents/Resources/WhiskyCmd"
if [ ! -x "$WHISKY_CMD" ]; then
    WHISKY_APP="$(mdfind "kMDItemCFBundleIdentifier == 'com.franke.Whisky'" 2>/dev/null | head -n 1)"
    WHISKY_CMD="$WHISKY_APP/Contents/Resources/WhiskyCmd"
fi
if [ ! -x "$WHISKY_CMD" ]; then
    osascript -e 'display alert "Whisky not found" message "Install Whisky (frankea fork) first, e.g. by running install.sh."'
    exit 1
fi
RUNNING="$(pgrep -f 'steamwebhelper.exe -nocrashdialog'; pgrep -f '^C:.*[Ss]team\.exe')"
if [ -n "$RUNNING" ]; then
    if [ -x "$HERE/front" ]; then
        "$HERE/front" $RUNNING
    else
        osascript -e 'display notification "Steam is already running in the bottle – look for its window." with title "Steam (Whisky)"'
    fi
    exit 0
fi
exec "$WHISKY_CMD" run 'Steam' 'C:\Program Files (x86)\Steam\Steam.exe'
