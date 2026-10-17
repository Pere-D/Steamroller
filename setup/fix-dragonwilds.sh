#!/bin/zsh
# fix-dragonwilds.sh
# RuneScape: Dragonwilds hält D3DMetal für eine AMD-Karte und schaltet FSR 3 MIT Frame Generation ein.
# Die Frame-Interpolation beendet das Spiel unter D3DMetal nach ca. 30 s still. FSR-Upscaling selbst ist ok.
# Dieses Skript schaltet Frame Generation ab, setzt die Engine-Variable und (nur wenn noch keine
# Spieleinstellungen existieren) ein moderates Grafik-Profil mit 60-fps-Limit. Idempotent.
set -euo pipefail
setopt null_glob   # leere Globs (z. B. noch keine Bottle) sind kein Fehler
NAME="${1:-Steam}"
BOTTLES="$HOME/Library/Containers/com.franke.Whisky/Bottles"
log(){ printf '\n\033[1m==> %s\033[0m\n' "$*"; }
die(){ printf '\033[31mFEHLER: %s\033[0m\n' "$*" >&2; exit 1; }
B=""; for d in "$BOTTLES"/*/; do
  n="$(/usr/libexec/PlistBuddy -c 'Print :info:name' "$d/Metadata.plist" 2>/dev/null || true)"
  [ "$n" = "$NAME" ] && { B="${d%/}"; break; }; done
[ -n "$B" ] || die "Bottle \"$NAME\" nicht gefunden"
pgrep -f 'RSDragonwilds' >/dev/null && die "Dragonwilds läuft gerade; erst beenden."

C="$B/drive_c/users/crossover/AppData/Local/RSDragonwilds/Saved/Config/Windows"
mkdir -p "$C"
GUS="$C/GameUserSettings.ini"
if [ -f "$GUS" ]; then
  log "Frame Generation in GameUserSettings.ini abschalten"
  n="$(grep -c -E '^FrameGenerationMode\[[0-9]+\]=[1-9]' "$GUS" || true)"
  sed -i '' -E 's/^(FrameGenerationMode\[[0-9]+\])=[0-9]+/\1=0/' "$GUS"
  [ "${n:-0}" -gt 0 ] && echo "$n Modus-Einträge auf 0 gesetzt" || echo "war bereits aus"
else
  log "Spieleinstellungen vorbelegen (Frame Generation aus, Grafik Hoch, 60 fps)"
  {
    printf '[/Script/Dominion.DominionUserSettings]\n'
    for i in 0 1 2 3 4 5 6 7 8; do printf 'FrameGenerationMode[%d]=0\n' "$i"; done
    printf 'FrontendFrameRateLimit=60.000000\nGameFrameRateLimit=60.000000\n'
    for k in RenderingQuality AntialiasingQuality GlobalIlluminationQuality ReflectionsQuality ShadowsQuality FoliageQuality ModelsQuality PostProcessQuality EffectsQuality ViewDistanceQuality TextureQuality; do printf '%s=3\n' "$k"; done
    printf '\n[ScalabilityGroups]\n'
    for k in sg.ViewDistanceQuality sg.AntiAliasingQuality sg.ShadowQuality sg.GlobalIlluminationQuality sg.ReflectionQuality sg.PostProcessQuality sg.TextureQuality sg.EffectsQuality sg.FoliageQuality sg.ShadingQuality sg.LandscapeQuality; do printf '%s=3\n' "$k"; done
  } > "$GUS"
  echo "GameUserSettings.ini angelegt"
fi
log "Engine-Variable r.FidelityFX.FI.Enabled=0"
if [ -f "$C/Engine.ini" ] && grep -q 'r.FidelityFX.FI.Enabled' "$C/Engine.ini"; then
  echo "bereits gesetzt"
else
  printf '\n[SystemSettings]\nr.FidelityFX.FI.Enabled=0\n' >> "$C/Engine.ini"; echo "ergänzt"
fi
printf '\n\033[32mDragonwilds: Frame Generation aus, FSR-Upscaling bleibt an.\033[0m\n'
