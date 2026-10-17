#!/bin/zsh
# make-steam-bottle.sh
# Legt die Whisky-Bottle "Steam" an (Windows 10), schaltet den Launcher-Kompatibilitätsmodus ein
# (UTF-8-Locale gegen den steamwebhelper-Absturz, GPU-Spoofing, 90 s Netzwerk-Timeout),
# installiert Steam still und legt einen Doppelklick-Starter "Steam (Whisky).app" in diesen Ordner.
# Idempotent: vorhandene Bottle / vorhandenes Steam werden wiederverwendet.
#
# Voraussetzung: setup/install-engine.sh ist gelaufen.
# Aufruf: setup/make-steam-bottle.sh [Bottle-Name]
set -euo pipefail
setopt null_glob   # leere Globs (z. B. noch keine Bottle) sind kein Fehler

HERE="$(cd "$(dirname "$0")/.." && pwd)"
DATA="${WINGAMING_DATA:-$HERE}"
CMD=""; for c in "/Applications/Whisky.app" "$HOME/Applications/Whisky.app"; do
  [ -x "$c/Contents/Resources/WhiskyCmd" ] && { CMD="$c/Contents/Resources/WhiskyCmd"; break; }; done
NAME="${1:-Steam}"
INSTALLER="$DATA/installer/SteamSetup.exe"
BOTTLES="$HOME/Library/Containers/com.franke.Whisky/Bottles"

log(){ printf '\n\033[1m==> %s\033[0m\n' "$*"; }
die(){ printf '\033[31mFEHLER: %s\033[0m\n' "$*" >&2; exit 1; }
find_bottle(){ local d n; for d in "$BOTTLES"/*/; do
  n="$(/usr/libexec/PlistBuddy -c 'Print :info:name' "$d/Metadata.plist" 2>/dev/null || true)"
  [ "$n" = "$NAME" ] && { printf '%s' "${d%/}"; return 0; }; done; return 1; }

[ -n "$CMD" ] && [ -x "$CMD" ] || die "Whisky.app (frankea-Fork) fehlt; install.sh ausführen"
[ -f "$HOME/Library/Application Support/com.franke.Whisky/Libraries/WhiskyWineVersion.plist" ] \
  || die "Keine Runtime installiert: erst setup/install-engine.sh ausführen"

if [ ! -f "$INSTALLER" ]; then
  log "SteamSetup.exe wird von Valve geladen"
  mkdir -p "$DATA/installer"
  curl -fL -o "$INSTALLER" "https://cdn.cloudflare.steamstatic.com/client/installer/SteamSetup.exe"
fi

if B="$(find_bottle)"; then
  log "Bottle \"$NAME\" existiert bereits: $B"
else
  log "Bottle \"$NAME\" wird angelegt"
  "$CMD" create "$NAME"
  B="$(find_bottle)" || die "Bottle wurde nicht gefunden"
fi

log "Launcher-Kompatibilität wird eingeschaltet"
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
  log "Steam ist bereits installiert"
else
  log "Steam wird still installiert (legt beim ersten Mal das Wine-Prefix an, ca. 1 Minute)"
  "$CMD" run "$NAME" "$INSTALLER" /S --follow 2>&1 | grep -v '^\s*VK_\|mvk-info\|^\s*GPU Family\|Read-Write Texture' || true
  [ -f "$STEAM_EXE" ] || die "Steam.exe wurde nicht installiert"
fi

# Whisky 3.7.0 kennt den Fix aus upstream-main (#251/#295) noch nicht: Mit deployter D3DMetal ist Wines
# eingebaute dxgi.dll Apples Forwarder, und DXVKs d3d11 (das Whisky für Steams eigene Prozesse nutzt)
# kann darüber kein Swapchain anlegen -> Steam startet ohne Fenster (CEF: eglCreateWindowSurface EGL_BAD_ALLOC).
# Lösung wie upstream: Wines Original-dxgi.dll aus dem D3DMetal-Store ohne Builtin-Marker als native Datei
# in system32 legen. Spiele ohne Override laden weiter Apples Builtin (Wines Standard: builtin vor native).
log "dxgi.dll für Steams DXVK-Prozesse abgleichen"
ORIG_DXGI="$HOME/Library/Application Support/com.franke.Whisky/D3DMetal/originals/dxgi.dll"
SYS_DXGI="$B/drive_c/windows/system32/dxgi.dll"
if [ -f "$ORIG_DXGI" ]; then
  if [ -f "$SYS_DXGI" ] && ! dd if="$SYS_DXGI" bs=1 skip=64 count=16 2>/dev/null | grep -q 'Wine builtin DLL' \
     && cmp -s <(tail -c +81 "$SYS_DXGI") <(tail -c +81 "$ORIG_DXGI"); then
    echo "native dxgi.dll ist bereits aktuell"
  else
    cp "$ORIG_DXGI" "$SYS_DXGI"
    printf '\x0e\x1f\xba\x0e\x00\xb4\x09\xcd\x21\xb8\x01\x4c\xcd\x21\x90\x90' | dd of="$SYS_DXGI" bs=1 seek=64 count=16 conv=notrunc 2>/dev/null
    echo "native dxgi.dll (Wine-Original ohne Builtin-Marker) eingesetzt"
  fi
else
  echo "kein D3DMetal-Store mit Originalen gefunden, nichts zu tun"
fi

if [ "${WINGAMING_NO_SHORTCUT:-0}" != "1" ]; then
  log "Doppelklick-Starter wird angelegt"
  "$CMD" shortcut "$NAME" "$STEAM_EXE" --name "Steam (Whisky)" --output "$HERE" --overwrite
  APP="$HERE/Steam (Whisky).app"
  cp "$HERE/setup/launch.sh" "$APP/Contents/MacOS/launch" && chmod +x "$APP/Contents/MacOS/launch"
  if [ -n "${WINGAMING_FRONT:-}" ] && [ -x "$WINGAMING_FRONT" ]; then
    cp "$WINGAMING_FRONT" "$APP/Contents/MacOS/front"
  elif /usr/bin/xcode-select -p >/dev/null 2>&1; then
    xcrun swiftc -O -o "$APP/Contents/MacOS/front" "$HERE/setup/front.swift" 2>/dev/null && echo "Fenster-Helfer (front) kompiliert"
  else
    echo "Kein Fenster-Helfer (keine Xcode-Tools); Starter meldet ein laufendes Steam per Mitteilung"
  fi
  codesign --force --deep -s - "$APP" >/dev/null 2>&1 || true
fi

# Dragonwilds-Konfiguration vorbereiten (Frame Generation aus); harmlos, wenn das Spiel noch fehlt
"$HERE/setup/fix-dragonwilds.sh" "$NAME" 2>/dev/null || true

printf '\n\033[32mFertig. Steam starten:\n  %s run %s "%s"\033[0m\n' "$CMD" "$NAME" "$STEAM_EXE"
