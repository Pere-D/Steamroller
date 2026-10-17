#!/bin/zsh
# Main program of Steamroller.app:
#  - everything installed -> start Steam in the bottle (or bring it to the front), keep the Dragonwilds fix fresh
#  - nothing there yet    -> run the first-time setup in a Terminal window, then start Steam
setopt null_glob
APP="$(cd "$(dirname "$0")/../.." && pwd)"
RES="$APP/Contents/Resources"
export STEAMROLLER_DATA="$HOME/Library/Application Support/Steamroller"
export STEAMROLLER_NO_SHORTCUT=1
export STEAMROLLER_FRONT="$APP/Contents/MacOS/front"

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
  # exec rather than a background start: apps launched by LaunchServices take their children down with them
  # when the app process exits. Steamroller stays in the Dock while Steam runs, like Whisky's own launchers.
  exec "$CMD" run Steam "$STEAM_EXE"
fi

# ---- first-time setup ----
ANSWER="$(osascript -e 'display dialog "Steamroller sets everything up on first launch: Rosetta, Whisky, the Wine engine with Apple'"'"'s D3DMetal, and Steam.\n\nTakes 5 to 10 minutes and about 1 GB of downloads. Progress is shown in a Terminal window; Steam starts when it is done.\n\nRequires a Mac with Apple Silicon and macOS 15 or newer." buttons {"Cancel", "Install"} default button "Install" with title "Steamroller" with icon note' 2>/dev/null || echo cancel)"
case "$ANSWER" in *Install*) ;; *) exit 0 ;; esac
mkdir -p "$STEAMROLLER_DATA"
RUNNER="$STEAMROLLER_DATA/first-time-setup.command"
cat > "$RUNNER" <<EOS
#!/bin/zsh
export STEAMROLLER_DATA="$STEAMROLLER_DATA" STEAMROLLER_NO_SHORTCUT=1 STEAMROLLER_FRONT="$STEAMROLLER_FRONT"
clear; echo "Steamroller – first-time setup"; echo
if "$RES/install.sh"; then
  echo; echo "Done. Steam is starting; you can close this window."
  open "$APP"
else
  echo; echo "Setup failed – please read the message above. Press any key to close."; read -k 1
fi
EOS
chmod +x "$RUNNER"
open -a Terminal "$RUNNER"
