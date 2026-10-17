#!/bin/zsh
# make-steam-bottle.sh
# Creates the Whisky bottle "Steam" (Windows 10), enables launcher compatibility mode (UTF-8 locale against
# the steamwebhelper crash, GPU spoofing, 90 s network timeout), installs Steam silently, applies the dxgi fix
# Steam's UI needs next to D3DMetal, pre-seeds the Dragonwilds settings and (unless STEAMROLLER_NO_SHORTCUT=1)
# creates a double-click launcher "Steam (Whisky).app" in this folder.
# Idempotent: an existing bottle / an existing Steam are reused.
#
# Requires: setup/install-engine.sh has run.
# Usage: setup/make-steam-bottle.sh [bottle-name]
set -euo pipefail
setopt null_glob   # an empty glob (no bottle yet) is not an error

HERE="$(cd "$(dirname "$0")/.." && pwd)"
DATA="${STEAMROLLER_DATA:-$HERE}"
CMD=""; for c in "/Applications/Whisky.app" "$HOME/Applications/Whisky.app"; do
  [ -x "$c/Contents/Resources/WhiskyCmd" ] && { CMD="$c/Contents/Resources/WhiskyCmd"; break; }; done
NAME="${1:-Steam}"
INSTALLER="$DATA/installer/SteamSetup.exe"
BOTTLES="$HOME/Library/Containers/com.franke.Whisky/Bottles"

log(){ printf '\n\033[1m==> %s\033[0m\n' "$*"; }
die(){ printf '\033[31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }
find_bottle(){ local d n; for d in "$BOTTLES"/*/; do
  n="$(/usr/libexec/PlistBuddy -c 'Print :info:name' "$d/Metadata.plist" 2>/dev/null || true)"
  [ "$n" = "$NAME" ] && { printf '%s' "${d%/}"; return 0; }; done; return 1; }

[ -n "$CMD" ] && [ -x "$CMD" ] || die "Whisky.app (frankea fork) not found; run install.sh"
[ -f "$HOME/Library/Application Support/com.franke.Whisky/Libraries/WhiskyWineVersion.plist" ] \
  || die "No runtime installed: run setup/install-engine.sh first"

if [ ! -f "$INSTALLER" ]; then
  log "Downloading SteamSetup.exe from Valve"
  mkdir -p "$DATA/installer"
  curl -fL -o "$INSTALLER" "https://cdn.cloudflare.steamstatic.com/client/installer/SteamSetup.exe"
fi

if B="$(find_bottle)"; then
  log "Bottle \"$NAME\" already exists: $B"
else
  log "Creating bottle \"$NAME\""
  "$CMD" create "$NAME"
  B="$(find_bottle)" || die "Bottle not found after creation"
fi

log "Enabling launcher compatibility"
/usr/libexec/PlistBuddy \
  -c 'Set :launcherConfig:compatibilityMode true' \
  -c 'Set :launcherConfig:launcherLocale en_US.UTF-8' \
  -c 'Set :launcherConfig:networkTimeout 90000' \
  -c 'Set :launcherConfig:gpuSpoofing true' \
  -c 'Set :launcherConfig:gpuVendor NVIDIA' \
  -c 'Set :graphicsConfig:backend recommended' \
  -c 'Set :wineConfig:windowsVersion win10' \
  "$B/Metadata.plist"

STEAM_EXE="$B/drive_c/Program Files (x86)/Steam/Steam.exe"
if [ -f "$STEAM_EXE" ]; then
  log "Steam is already installed"
else
  log "Installing Steam silently (creates the Wine prefix on first run, about 1 minute)"
  "$CMD" run "$NAME" "$INSTALLER" /S --follow 2>&1 | grep -v '^\s*VK_\|mvk-info\|^\s*GPU Family\|Read-Write Texture' || true
  [ -f "$STEAM_EXE" ] || die "Steam.exe was not installed"
fi

# Whisky 3.7.0 lacks the fix from upstream main (#251/#295): with D3DMetal deployed, Wine's builtin dxgi.dll is
# Apple's forwarder, and DXVK's d3d11 (which Whisky uses for Steam's own processes) cannot create a swapchain
# on it -> Steam starts without a window (CEF: eglCreateWindowSurface EGL_BAD_ALLOC). Same fix as upstream:
# put Wine's original dxgi.dll from the D3DMetal store, with the builtin marker stripped, into system32 as a
# native DLL. Games without an override keep loading Apple's builtin (Wine's default: builtin before native).
log "Reconciling dxgi.dll for Steam's DXVK processes"
ORIG_DXGI="$HOME/Library/Application Support/com.franke.Whisky/D3DMetal/originals/dxgi.dll"
SYS_DXGI="$B/drive_c/windows/system32/dxgi.dll"
if [ -f "$ORIG_DXGI" ]; then
  if [ -f "$SYS_DXGI" ] && ! dd if="$SYS_DXGI" bs=1 skip=64 count=16 2>/dev/null | grep -q 'Wine builtin DLL' \
     && cmp -s <(tail -c +81 "$SYS_DXGI") <(tail -c +81 "$ORIG_DXGI"); then
    echo "native dxgi.dll is already current"
  else
    cp "$ORIG_DXGI" "$SYS_DXGI"
    printf '\x0e\x1f\xba\x0e\x00\xb4\x09\xcd\x21\xb8\x01\x4c\xcd\x21\x90\x90' | dd of="$SYS_DXGI" bs=1 seek=64 count=16 conv=notrunc 2>/dev/null
    echo "native dxgi.dll (Wine original without builtin marker) installed"
  fi
else
  echo "no D3DMetal store with originals found, nothing to do"
fi

if [ "${STEAMROLLER_NO_SHORTCUT:-0}" != "1" ]; then
  log "Creating the double-click launcher"
  "$CMD" shortcut "$NAME" "$STEAM_EXE" --name "Steam (Whisky)" --output "$HERE" --overwrite
  APP="$HERE/Steam (Whisky).app"
  cp "$HERE/setup/launch.sh" "$APP/Contents/MacOS/launch" && chmod +x "$APP/Contents/MacOS/launch"
  if [ -n "${STEAMROLLER_FRONT:-}" ] && [ -x "$STEAMROLLER_FRONT" ]; then
    cp "$STEAMROLLER_FRONT" "$APP/Contents/MacOS/front"
  elif /usr/bin/xcode-select -p >/dev/null 2>&1; then
    xcrun swiftc -O -o "$APP/Contents/MacOS/front" "$HERE/setup/front.swift" 2>/dev/null && echo "window helper (front) compiled"
  else
    echo "no window helper (no Xcode tools); the launcher reports a running Steam with a notification"
  fi
  codesign --force --deep -s - "$APP" >/dev/null 2>&1 || true
fi

# Pre-seed the Dragonwilds configuration (frame generation off); harmless when the game is not installed yet
"$HERE/setup/fix-dragonwilds.sh" "$NAME" 2>/dev/null || true

printf '\n\033[32mDone. Start Steam with:\n  %s run %s "%s"\033[0m\n' "$CMD" "$NAME" "$STEAM_EXE"
