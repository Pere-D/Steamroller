#!/bin/zsh
# install-engine.sh
# Baut die "CrossOver-Engine" für Whisky zusammen:
#   1) Whisky-Runtime 4.6.4 (Wine 11.16 + CrossOver-26.3-Patches, GPTk-fähig) installieren
#   2) Apples D3DMetal aus dem Game Porting Toolkit in Whiskys D3DMetal-Store importieren
#   3) D3DMetal in die Runtime deployen (gleiche Schritte wie Whiskys GPTKImporter.deploy)
# Idempotent: kann jederzeit erneut laufen, z. B. nach einem Runtime-Update.
#
# Aufruf: setup/install-engine.sh [Runtime.tar.gz] [game-porting-toolkit.tar.xz]
# Ohne Argumente werden beide Archive bei Bedarf nach downloads/ geladen und per SHA-256 geprüft.
set -euo pipefail
setopt null_glob   # leere Globs (z. B. noch keine Bottle) sind kein Fehler

HERE="$(cd "$(dirname "$0")/.." && pwd)"
DATA="${WINGAMING_DATA:-$HERE}"            # wohin Downloads kommen (App: ~/Library/Application Support/WinGaming)
RUNTIME_TAR="${1:-$DATA/downloads/whisky-runtime/Libraries-4.6.4-beta.1.tar.gz}"
GPTK_TAR="${2:-$DATA/downloads/gptk/game-porting-toolkit-3.0-3.tar.xz}"
WANT_RUNTIME="${WANT_RUNTIME:-4.6.4}"
APP_SUPPORT="$HOME/Library/Application Support/com.franke.Whisky"
LIB="$APP_SUPPORT/Libraries"
STORE="$APP_SUPPORT/D3DMetal"
BRIDGE_TARGET="../../external/libd3dshared.dylib"

log(){ printf '\n\033[1m==> %s\033[0m\n' "$*"; }
die(){ printf '\033[31mFEHLER: %s\033[0m\n' "$*" >&2; exit 1; }
plist_version(){ local p="$1"; [ -f "$p" ] || return 1
  printf '%s.%s.%s' "$(/usr/libexec/PlistBuddy -c 'Print :version:major' "$p")" \
                    "$(/usr/libexec/PlistBuddy -c 'Print :version:minor' "$p")" \
                    "$(/usr/libexec/PlistBuddy -c 'Print :version:patch' "$p")"; }

# Bekannte Quellen + SHA-256 (veröffentlicht in den jeweiligen GitHub-Releases)
RUNTIME_URL="https://github.com/frankea/Whisky/releases/download/v4.6.4-beta.1/Libraries.tar.gz"
RUNTIME_SHA="c8e6a10dfeb54fc16d3dd3382ee2e9d2cec3eb1f5641613cad8b07903818cb12"
GPTK_URL="https://github.com/Gcenx/game-porting-toolkit/releases/download/Game-Porting-Toolkit-3.0-3/game-porting-toolkit-3.0-3.tar.xz"
GPTK_SHA="d377683937340f914823dbb2e1252b329cbf834ff58907d0293db8cebf0e392e"

fetch(){ # fetch <ziel> <url> <sha256>: lädt, wenn die Datei fehlt, und prüft die Prüfsumme
  local dst="$1" url="$2" sha="$3"
  if [ ! -f "$dst" ]; then
    log "Lade $(basename "$dst") ($url)"
    mkdir -p "$(dirname "$dst")"
    curl -fL --progress-bar -o "$dst.part" "$url" && mv "$dst.part" "$dst" || die "Download fehlgeschlagen: $url"
  fi
  local got; got="$(shasum -a 256 "$dst" | cut -d' ' -f1)"
  [ "$got" = "$sha" ] || die "Prüfsumme von $(basename "$dst") stimmt nicht (erwartet $sha, erhalten $got). Datei löschen und erneut versuchen."
  echo "Prüfsumme OK: $(basename "$dst")"
}
[ "$#" -ge 1 ] || fetch "$RUNTIME_TAR" "$RUNTIME_URL" "$RUNTIME_SHA"
[ "$#" -ge 2 ] || fetch "$GPTK_TAR" "$GPTK_URL" "$GPTK_SHA"
[ -f "$RUNTIME_TAR" ] || die "Runtime-Archiv fehlt: $RUNTIME_TAR"
[ -f "$GPTK_TAR" ]    || die "GPTk-Archiv fehlt: $GPTK_TAR"
WHISKY_APP=""; for c in "/Applications/Whisky.app" "$HOME/Applications/Whisky.app"; do
  [ -d "$c" ] && /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$c/Contents/Info.plist" 2>/dev/null | grep -q com.franke.Whisky && { WHISKY_APP="$c"; break; }; done
[ -n "$WHISKY_APP" ] || die "Whisky.app (frankea-Fork) fehlt; install.sh ausführen"
/usr/bin/pgrep -q oahd || die "Rosetta fehlt: softwareupdate --install-rosetta"

if pgrep -xq Whisky; then log "Whisky wird beendet"; osascript -e 'quit app "Whisky"' >/dev/null 2>&1 || true; sleep 2; fi
if pgrep -f 'com.franke.Whisky/Libraries/Wine' >/dev/null 2>&1 && [ "${FORCE:-0}" != "1" ]; then
  die "In einer Bottle laufen noch Wine-Prozesse (z. B. Steam). Erst beenden, dann erneut starten (oder FORCE=1 setzen)."
fi

# ---------- 1) Runtime ----------
mkdir -p "$APP_SUPPORT"
CUR="$(plist_version "$LIB/WhiskyWineVersion.plist" 2>/dev/null || true)"
if [ "$CUR" = "$WANT_RUNTIME" ]; then
  log "Runtime $CUR ist bereits installiert"
else
  if [ -d "$LIB" ]; then
    BK="$APP_SUPPORT/Libraries-backup-$(date +%Y%m%d-%H%M%S)"
    log "Vorhandene Runtime (${CUR:-unbekannt}) wird nach $BK verschoben"; mv "$LIB" "$BK"
  fi
  log "Runtime wird entpackt (ca. 1,5 GB, bitte warten)"
  tar -xzf "$RUNTIME_TAR" -C "$APP_SUPPORT"
  CUR="$(plist_version "$LIB/WhiskyWineVersion.plist")"
  [ "$CUR" = "$WANT_RUNTIME" ] || die "Unerwartete Runtime-Version: $CUR"
fi
/usr/libexec/PlistBuddy -c 'Print :gptkCapable' "$LIB/WhiskyWineVersion.plist" 2>/dev/null | grep -q true \
  || die "Diese Runtime ist nicht GPTk-fähig (kein gptkCapable=true im Plist)"
log "Runtime $CUR ist GPTk-fähig"

WINE_LIB="$LIB/Wine/lib"; PE="$WINE_LIB/wine/x86_64-windows"; UNIX="$WINE_LIB/wine/x86_64-unix"
[ -d "$PE" ] && [ -d "$UNIX" ] || die "Wine-Baum unvollständig unter $WINE_LIB"

# ---------- 2) D3DMetal-Store (entspricht GPTKImporter.importPayload) ----------
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
GP="Game Porting Toolkit.app/Contents/Resources/wine/lib"
log "D3DMetal wird aus dem Game Porting Toolkit extrahiert"
tar -xJf "$GPTK_TAR" -C "$TMP" "$GP/external" \
  "$GP/wine/x86_64-windows/d3d10.dll" "$GP/wine/x86_64-windows/d3d11.dll" \
  "$GP/wine/x86_64-windows/d3d12.dll" "$GP/wine/x86_64-windows/dxgi.dll" \
  "$GP/wine/x86_64-windows/nvapi64.dll" "$GP/wine/x86_64-windows/nvngx-on-metalfx.dll"
STAGE="$TMP/lib"
mkdir -p "$STAGE/wine/x86_64-windows" "$STAGE/wine/x86_64-unix"
cp -R "$TMP/$GP/external" "$STAGE/external"
cp "$TMP/$GP/wine/x86_64-windows/"*.dll "$STAGE/wine/x86_64-windows/"
for n in d3d10 d3d11 d3d12 dxgi; do ln -sfn "$BRIDGE_TARGET" "$STAGE/wine/x86_64-unix/$n.so"; done
xattr -cr "$STAGE" 2>/dev/null || true

log "Echtheit wird geprüft (Apple-Signatur, Wine-Builtin-Marker)"
codesign --verify -R='identifier "com.apple.libd3dshared" and anchor apple' "$STAGE/external/libd3dshared.dylib" \
  || die "libd3dshared.dylib trägt keine gültige Apple-Signatur"
codesign --verify -R='identifier "com.apple.D3DMetal" and anchor apple' "$STAGE/external/D3DMetal.framework" \
  || die "D3DMetal.framework trägt keine gültige Apple-Signatur"
for n in d3d10 d3d11 d3d12 dxgi; do
  dd if="$STAGE/wine/x86_64-windows/$n.dll" bs=1 skip=64 count=16 2>/dev/null | grep -q 'Wine builtin DLL' \
    || die "$n.dll ist kein Wine-Builtin-Forwarder"
done
GPTK_VER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$STAGE/external/D3DMetal.framework/Versions/A/Resources/Info.plist")"
log "D3DMetal $GPTK_VER ist echt"

mkdir -p "$STORE"; rm -rf "$STORE/lib" "$STORE/lib.staging"
cp -R "$STAGE" "$STORE/lib.staging" && mv "$STORE/lib.staging" "$STORE/lib"
cat > "$STORE/D3DMetalVersion.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>gptkVersion</key>
	<string>$GPTK_VER</string>
	<key>importedAt</key>
	<date>$(date -u +%Y-%m-%dT%H:%M:%SZ)</date>
</dict>
</plist>
PL
log "Store angelegt: $STORE"

# ---------- 3) Deploy in die Runtime (entspricht GPTKImporter.deploy) ----------
ORIG="$STORE/originals"; STAMP="$(plist_version "$LIB/WhiskyWineVersion.plist")"
if [ -f "$ORIG/OriginalsVersion.plist" ] && \
   [ "$(/usr/libexec/PlistBuddy -c 'Print :runtimeVersion' "$ORIG/OriginalsVersion.plist" 2>/dev/null || true)" != "$STAMP" ]; then
  rm -rf "$ORIG"   # Backups einer anderen Engine passen nicht zu diesem Baum
fi
mkdir -p "$ORIG"
cat > "$ORIG/OriginalsVersion.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>runtimeVersion</key>
	<string>$STAMP</string>
</dict>
</plist>
PL
SRC="$STORE/lib/wine/x86_64-windows"
for n in d3d10 d3d11 d3d12 dxgi; do
  if [ -f "$PE/$n.dll" ]; then
    if [ ! -f "$ORIG/$n.dll" ] && ! cmp -s "$PE/$n.dll" "$SRC/$n.dll"; then
      mv "$PE/$n.dll" "$ORIG/$n.dll"      # Wine-Original einmalig sichern
    else
      rm -f "$PE/$n.dll"
    fi
  fi
  cp "$SRC/$n.dll" "$PE/$n.dll"
  ln -sfn "$BRIDGE_TARGET" "$UNIX/$n.so"
done
rm -rf "$WINE_LIB/external"; cp -R "$STORE/lib/external" "$WINE_LIB/external"
# MetalFX-Bridge: Apples nvngx-on-metalfx.dll unter ihrem Exportnamen nvngx.dll
if ! cmp -s "$PE/nvngx.dll" "$SRC/nvngx-on-metalfx.dll" 2>/dev/null; then
  rm -f "$PE/nvngx.dll"; cp "$SRC/nvngx-on-metalfx.dll" "$PE/nvngx.dll"
fi
ln -sfn "$BRIDGE_TARGET" "$UNIX/nvngx.so"
# NVAPI-Bridge: Wines Platzhalter sichern, Apples nvapi64.dll einsetzen
if ! cmp -s "$PE/nvapi64.dll" "$SRC/nvapi64.dll" 2>/dev/null; then
  if [ -f "$PE/nvapi64.dll" ]; then
    [ -f "$PE/nvapi64.dll.wine-placeholder" ] || cp "$PE/nvapi64.dll" "$PE/nvapi64.dll.wine-placeholder"
    rm -f "$PE/nvapi64.dll"
  fi
  cp "$SRC/nvapi64.dll" "$PE/nvapi64.dll"
fi
ln -sfn "$BRIDGE_TARGET" "$UNIX/nvapi64.so"

# ---------- 4) Native dxgi.dll in bestehenden Bottles auffrischen ----------
# Bottles, die (für Steams DXVK-Prozesse) Wines Original-dxgi.dll als native Kopie tragen, bekommen die
# Kopie aus den Originalen DIESER Runtime, sonst passt sie nach einem Wine-Update nicht mehr zu wined3d.
log "Native dxgi.dll in Bottles auffrischen"
for bottle in "$HOME/Library/Containers/com.franke.Whisky/Bottles"/*/; do
  sys="$bottle/drive_c/windows/system32/dxgi.dll"; name="$(/usr/libexec/PlistBuddy -c 'Print :info:name' "$bottle/Metadata.plist" 2>/dev/null || echo '?')"
  [ -f "$sys" ] || continue
  if dd if="$sys" bs=1 skip=64 count=16 2>/dev/null | grep -q 'Wine builtin DLL'; then
    echo "$name: Builtin-Platzhalter, bleibt"; continue
  fi
  cp "$ORIG/dxgi.dll" "$sys"
  printf '\x0e\x1f\xba\x0e\x00\xb4\x09\xcd\x21\xb8\x01\x4c\xcd\x21\x90\x90' | dd of="$sys" bs=1 seek=64 count=16 conv=notrunc 2>/dev/null
  echo "$name: native dxgi.dll aus Runtime $STAMP eingesetzt"
done

# ---------- Kontrolle ----------
log "Kontrolle"
codesign --verify -R='identifier "com.apple.D3DMetal" and anchor apple' "$WINE_LIB/external/D3DMetal.framework" && echo "D3DMetal.framework in Runtime: Apple-signiert, OK"
for n in d3d10 d3d11 d3d12 dxgi nvapi64; do cmp -s "$PE/$n.dll" "$SRC/$n.dll" && echo "$n.dll: Apple-Forwarder aktiv"; done
cmp -s "$PE/nvngx.dll" "$SRC/nvngx-on-metalfx.dll" && echo "nvngx.dll: MetalFX-Bridge aktiv"
for n in d3d10 d3d11 d3d12 dxgi nvngx nvapi64; do [ "$(readlink "$UNIX/$n.so")" = "$BRIDGE_TARGET" ] && echo "$n.so -> libd3dshared.dylib"; done
ls "$ORIG" | sed 's/^/Original gesichert: /'
printf '\n\033[32mFertig: Runtime %s + D3DMetal %s sind einsatzbereit.\033[0m\n' "$STAMP" "$GPTK_VER"
