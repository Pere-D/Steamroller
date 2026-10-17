#!/bin/zsh
# install-engine.sh
# Assembles the engine Steamroller runs Steam on:
#   1) Whisky runtime 4.6.4 (Wine 11.16 with CrossOver 26.3 patches, the only line marked GPTK-capable)
#   2) Apple's D3DMetal (from the Game Porting Toolkit) imported into Whisky's D3DMetal store
#   3) D3DMetal deployed into the runtime, mirroring Whisky's own GPTKImporter.deploy
#   4) the native dxgi.dll refreshed in existing bottles (needed by Steam's DXVK-drawn UI)
# Idempotent: safe to run again, for example after a runtime update.
#
# Usage: setup/install-engine.sh [Runtime.tar.gz] [game-porting-toolkit.tar.xz]
# Without arguments both archives are downloaded into downloads/ when missing and verified by SHA-256.
set -euo pipefail
setopt null_glob   # an empty glob (no bottle yet) is not an error

HERE="$(cd "$(dirname "$0")/.." && pwd)"
DATA="${STEAMROLLER_DATA:-$HERE}"          # where downloads go (the app uses ~/Library/Application Support/Steamroller)
RUNTIME_TAR="${1:-$DATA/downloads/whisky-runtime/Libraries-4.6.4-beta.1.tar.gz}"
GPTK_TAR="${2:-$DATA/downloads/gptk/game-porting-toolkit-3.0-3.tar.xz}"
WANT_RUNTIME="${WANT_RUNTIME:-4.6.4}"
APP_SUPPORT="$HOME/Library/Application Support/com.franke.Whisky"
LIB="$APP_SUPPORT/Libraries"
STORE="$APP_SUPPORT/D3DMetal"
BRIDGE_TARGET="../../external/libd3dshared.dylib"

log(){ printf '\n\033[1m==> %s\033[0m\n' "$*"; }
die(){ printf '\033[31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }
plist_version(){ local p="$1"; [ -f "$p" ] || return 1
  printf '%s.%s.%s' "$(/usr/libexec/PlistBuddy -c 'Print :version:major' "$p")" \
                    "$(/usr/libexec/PlistBuddy -c 'Print :version:minor' "$p")" \
                    "$(/usr/libexec/PlistBuddy -c 'Print :version:patch' "$p")"; }

# Known sources and SHA-256 digests (published in the respective GitHub releases)
RUNTIME_URL="https://github.com/frankea/Whisky/releases/download/v4.6.4-beta.1/Libraries.tar.gz"
RUNTIME_SHA="c8e6a10dfeb54fc16d3dd3382ee2e9d2cec3eb1f5641613cad8b07903818cb12"
GPTK_URL="https://github.com/Gcenx/game-porting-toolkit/releases/download/Game-Porting-Toolkit-3.0-3/game-porting-toolkit-3.0-3.tar.xz"
GPTK_SHA="d377683937340f914823dbb2e1252b329cbf834ff58907d0293db8cebf0e392e"

fetch(){ # fetch <dest> <url> <sha256>: download when missing, then verify the digest
  local dst="$1" url="$2" sha="$3"
  if [ ! -f "$dst" ]; then
    log "Downloading $(basename "$dst") ($url)"
    mkdir -p "$(dirname "$dst")"
    curl -fL --progress-bar -o "$dst.part" "$url" && mv "$dst.part" "$dst" || die "Download failed: $url"
  fi
  local got; got="$(shasum -a 256 "$dst" | cut -d' ' -f1)"
  [ "$got" = "$sha" ] || die "SHA-256 mismatch for $(basename "$dst") (expected $sha, got $got). Delete the file and retry."
  echo "Checksum OK: $(basename "$dst")"
}
[ "$#" -ge 1 ] || fetch "$RUNTIME_TAR" "$RUNTIME_URL" "$RUNTIME_SHA"
[ "$#" -ge 2 ] || fetch "$GPTK_TAR" "$GPTK_URL" "$GPTK_SHA"
[ -f "$RUNTIME_TAR" ] || die "Runtime archive missing: $RUNTIME_TAR"
[ -f "$GPTK_TAR" ]    || die "GPTK archive missing: $GPTK_TAR"
WHISKY_APP=""; for c in "/Applications/Whisky.app" "$HOME/Applications/Whisky.app"; do
  [ -d "$c" ] && /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$c/Contents/Info.plist" 2>/dev/null | grep -q com.franke.Whisky && { WHISKY_APP="$c"; break; }; done
[ -n "$WHISKY_APP" ] || die "Whisky.app (frankea fork) not found; run install.sh"
/usr/bin/pgrep -q oahd || die "Rosetta is missing: softwareupdate --install-rosetta"

if pgrep -xq Whisky; then log "Quitting Whisky"; osascript -e 'quit app "Whisky"' >/dev/null 2>&1 || true; sleep 2; fi
if pgrep -f 'com.franke.Whisky/Libraries/Wine' >/dev/null 2>&1 && [ "${FORCE:-0}" != "1" ]; then
  die "Wine processes are still running in a bottle (Steam?). Quit them first, then retry (or set FORCE=1)."
fi

# ---------- 1) Runtime ----------
mkdir -p "$APP_SUPPORT"
CUR="$(plist_version "$LIB/WhiskyWineVersion.plist" 2>/dev/null || true)"
if [ "$CUR" = "$WANT_RUNTIME" ]; then
  log "Runtime $CUR is already installed"
else
  if [ -d "$LIB" ]; then
    BK="$APP_SUPPORT/Libraries-backup-$(date +%Y%m%d-%H%M%S)"
    log "Moving the existing runtime (${CUR:-unknown}) to $BK"; mv "$LIB" "$BK"
  fi
  log "Extracting the runtime (about 1.5 GB, please wait)"
  tar -xzf "$RUNTIME_TAR" -C "$APP_SUPPORT"
  CUR="$(plist_version "$LIB/WhiskyWineVersion.plist")"
  [ "$CUR" = "$WANT_RUNTIME" ] || die "Unexpected runtime version: $CUR"
fi
/usr/libexec/PlistBuddy -c 'Print :gptkCapable' "$LIB/WhiskyWineVersion.plist" 2>/dev/null | grep -q true \
  || die "This runtime is not GPTK-capable (no gptkCapable=true in its plist)"
log "Runtime $CUR is GPTK-capable"

WINE_LIB="$LIB/Wine/lib"; PE="$WINE_LIB/wine/x86_64-windows"; UNIX="$WINE_LIB/wine/x86_64-unix"
[ -d "$PE" ] && [ -d "$UNIX" ] || die "Wine tree incomplete under $WINE_LIB"

# ---------- 2) D3DMetal store (mirrors GPTKImporter.importPayload) ----------
TMP="$(mktemp -d)"; trap 'rm -rf "${TMP:?}"' EXIT
GP="Game Porting Toolkit.app/Contents/Resources/wine/lib"
log "Extracting D3DMetal from the Game Porting Toolkit"
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

log "Verifying authenticity (Apple code signature, Wine builtin marker)"
codesign --verify -R='identifier "com.apple.libd3dshared" and anchor apple' "$STAGE/external/libd3dshared.dylib" \
  || die "libd3dshared.dylib does not carry a valid Apple signature"
codesign --verify -R='identifier "com.apple.D3DMetal" and anchor apple' "$STAGE/external/D3DMetal.framework" \
  || die "D3DMetal.framework does not carry a valid Apple signature"
for n in d3d10 d3d11 d3d12 dxgi; do
  dd if="$STAGE/wine/x86_64-windows/$n.dll" bs=1 skip=64 count=16 2>/dev/null | grep -q 'Wine builtin DLL' \
    || die "$n.dll is not a Wine builtin forwarder"
done
GPTK_VER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$STAGE/external/D3DMetal.framework/Versions/A/Resources/Info.plist")"
log "D3DMetal $GPTK_VER is genuine"

mkdir -p "$STORE"; rm -rf "${STORE:?}/lib" "${STORE:?}/lib.staging"
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
log "Store created: $STORE"

# ---------- 3) Deploy into the runtime (mirrors GPTKImporter.deploy) ----------
ORIG="$STORE/originals"; STAMP="$(plist_version "$LIB/WhiskyWineVersion.plist")"
if [ -f "$ORIG/OriginalsVersion.plist" ] && \
   [ "$(/usr/libexec/PlistBuddy -c 'Print :runtimeVersion' "$ORIG/OriginalsVersion.plist" 2>/dev/null || true)" != "$STAMP" ]; then
  rm -rf "${ORIG:?}"   # backups from another engine do not belong to this tree
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
      mv "$PE/$n.dll" "$ORIG/$n.dll"      # back up Wine's original once
    else
      rm -f "$PE/$n.dll"
    fi
  fi
  cp "$SRC/$n.dll" "$PE/$n.dll"
  ln -sfn "$BRIDGE_TARGET" "$UNIX/$n.so"
done
rm -rf "${WINE_LIB:?}/external"; cp -R "$STORE/lib/external" "$WINE_LIB/external"
# MetalFX bridge: Apple's nvngx-on-metalfx.dll under its export name nvngx.dll
if ! cmp -s "$PE/nvngx.dll" "$SRC/nvngx-on-metalfx.dll" 2>/dev/null; then
  rm -f "$PE/nvngx.dll"; cp "$SRC/nvngx-on-metalfx.dll" "$PE/nvngx.dll"
fi
ln -sfn "$BRIDGE_TARGET" "$UNIX/nvngx.so"
# NVAPI bridge: keep Wine's placeholder, install Apple's nvapi64.dll
if ! cmp -s "$PE/nvapi64.dll" "$SRC/nvapi64.dll" 2>/dev/null; then
  if [ -f "$PE/nvapi64.dll" ]; then
    [ -f "$PE/nvapi64.dll.wine-placeholder" ] || cp "$PE/nvapi64.dll" "$PE/nvapi64.dll.wine-placeholder"
    rm -f "$PE/nvapi64.dll"
  fi
  cp "$SRC/nvapi64.dll" "$PE/nvapi64.dll"
fi
ln -sfn "$BRIDGE_TARGET" "$UNIX/nvapi64.so"

# ---------- 4) Refresh the native dxgi.dll in existing bottles ----------
# Bottles that carry Wine's original dxgi.dll as a native copy (for Steam's DXVK processes) get the copy from
# THIS runtime's originals; otherwise it no longer matches wined3d after a Wine update.
log "Refreshing the native dxgi.dll in bottles"
for bottle in "$HOME/Library/Containers/com.franke.Whisky/Bottles"/*/; do
  sys="$bottle/drive_c/windows/system32/dxgi.dll"; name="$(/usr/libexec/PlistBuddy -c 'Print :info:name' "$bottle/Metadata.plist" 2>/dev/null || echo '?')"
  [ -f "$sys" ] || continue
  if dd if="$sys" bs=1 skip=64 count=16 2>/dev/null | grep -q 'Wine builtin DLL'; then
    echo "$name: builtin placeholder, left alone"; continue
  fi
  cp "$ORIG/dxgi.dll" "$sys"
  printf '\x0e\x1f\xba\x0e\x00\xb4\x09\xcd\x21\xb8\x01\x4c\xcd\x21\x90\x90' | dd of="$sys" bs=1 seek=64 count=16 conv=notrunc 2>/dev/null
  echo "$name: native dxgi.dll from runtime $STAMP installed"
done

# ---------- Check ----------
log "Check"
codesign --verify -R='identifier "com.apple.D3DMetal" and anchor apple' "$WINE_LIB/external/D3DMetal.framework" && echo "D3DMetal.framework in runtime: Apple-signed, OK"
for n in d3d10 d3d11 d3d12 dxgi nvapi64; do cmp -s "$PE/$n.dll" "$SRC/$n.dll" && echo "$n.dll: Apple forwarder active"; done
cmp -s "$PE/nvngx.dll" "$SRC/nvngx-on-metalfx.dll" && echo "nvngx.dll: MetalFX bridge active"
for n in d3d10 d3d11 d3d12 dxgi nvngx nvapi64; do [ "$(readlink "$UNIX/$n.so")" = "$BRIDGE_TARGET" ] && echo "$n.so -> libd3dshared.dylib"; done
ls "$ORIG" | sed 's/^/Original backed up: /'
printf '\n\033[32mDone: runtime %s + D3DMetal %s are ready.\033[0m\n' "$STAMP" "$GPTK_VER"
