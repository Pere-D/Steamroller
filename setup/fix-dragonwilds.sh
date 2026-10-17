#!/bin/zsh
# fix-dragonwilds.sh
# RuneScape: Dragonwilds takes D3DMetal for an AMD GPU and switches on FSR 3 WITH frame generation.
# Frame interpolation silently kills the game under D3DMetal after about 30 seconds; FSR upscaling itself is fine.
# This script turns frame generation off, sets the engine variable and (only when no game settings exist yet)
# seeds a moderate graphics profile with a 60 fps cap. Idempotent.
set -euo pipefail
setopt null_glob
NAME="${1:-Steam}"
BOTTLES="$HOME/Library/Containers/com.franke.Whisky/Bottles"
log(){ printf '\n\033[1m==> %s\033[0m\n' "$*"; }
die(){ printf '\033[31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }
B=""; for d in "$BOTTLES"/*/; do
  n="$(/usr/libexec/PlistBuddy -c 'Print :info:name' "$d/Metadata.plist" 2>/dev/null || true)"
  [ "$n" = "$NAME" ] && { B="${d%/}"; break; }; done
[ -n "$B" ] || die "Bottle \"$NAME\" not found"
pgrep -f 'RSDragonwilds' >/dev/null && die "Dragonwilds is running; quit it first."

C="$B/drive_c/users/crossover/AppData/Local/RSDragonwilds/Saved/Config/Windows"
mkdir -p "$C"
GUS="$C/GameUserSettings.ini"
if [ -f "$GUS" ]; then
  log "Turning frame generation off in GameUserSettings.ini"
  n="$(grep -c -E '^FrameGenerationMode\[[0-9]+\]=[1-9]' "$GUS" || true)"
  sed -i '' -E 's/^(FrameGenerationMode\[[0-9]+\])=[0-9]+/\1=0/' "$GUS"
  [ "${n:-0}" -gt 0 ] && echo "$n mode entries set to 0" || echo "already off"
else
  log "Seeding game settings (frame generation off, graphics High, 60 fps)"
  {
    printf '[/Script/Dominion.DominionUserSettings]\n'
    for i in 0 1 2 3 4 5 6 7 8; do printf 'FrameGenerationMode[%d]=0\n' "$i"; done
    printf 'FrontendFrameRateLimit=60.000000\nGameFrameRateLimit=60.000000\n'
    for k in RenderingQuality AntialiasingQuality GlobalIlluminationQuality ReflectionsQuality ShadowsQuality FoliageQuality ModelsQuality PostProcessQuality EffectsQuality ViewDistanceQuality TextureQuality; do printf '%s=3\n' "$k"; done
    printf '\n[ScalabilityGroups]\n'
    for k in sg.ViewDistanceQuality sg.AntiAliasingQuality sg.ShadowQuality sg.GlobalIlluminationQuality sg.ReflectionQuality sg.PostProcessQuality sg.TextureQuality sg.EffectsQuality sg.FoliageQuality sg.ShadingQuality sg.LandscapeQuality; do printf '%s=3\n' "$k"; done
  } > "$GUS"
  echo "GameUserSettings.ini created"
fi
log "Engine variable r.FidelityFX.FI.Enabled=0"
if [ -f "$C/Engine.ini" ] && grep -q 'r.FidelityFX.FI.Enabled' "$C/Engine.ini"; then
  echo "already set"
else
  printf '\n[SystemSettings]\nr.FidelityFX.FI.Enabled=0\n' >> "$C/Engine.ini"; echo "added"
fi
printf '\n\033[32mDragonwilds: frame generation off, FSR upscaling stays on.\033[0m\n'
