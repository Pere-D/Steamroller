#!/bin/zsh
# fix-dragonwilds.sh
# RuneScape: Dragonwilds stürzt unter D3DMetal ca. 30 Sekunden nach dem Start im Hauptmenü ab, weil das Spiel
# D3DMetal für eine AMD-Karte hält und automatisch FSR 3 MIT Frame Generation (Frame Interpolation) wählt.
# Die FSR-Frame-Interpolation verträgt sich nicht mit D3DMetal. FSR-Upscaling selbst läuft problemlos.
# Dieses Skript schaltet Frame Generation in den Spieleinstellungen ab und setzt zusätzlich die Engine-Variable.
# Idempotent; jederzeit erneut ausführbar (das Spiel sollte dabei nicht laufen).
set -euo pipefail
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
log "Frame Generation in GameUserSettings.ini abschalten"
if [ -f "$C/GameUserSettings.ini" ]; then
  python3 -I - "$C/GameUserSettings.ini" <<'PY'
import re, sys
p=sys.argv[1]; t=open(p,encoding="utf-8-sig").read()
n=len(re.findall(r"^FrameGenerationMode\[\d+\]=[1-9]", t, flags=re.M))
t=re.sub(r"^(FrameGenerationMode\[\d+\])=\d+", r"\1=0", t, flags=re.M)
open(p,"w",encoding="utf-8-sig").write(t)
print(f"{n} Modus-Einträge auf 0 gesetzt" if n else "war bereits aus")
PY
else
  echo "GameUserSettings.ini gibt es noch nicht (Spiel noch nie gestartet); nach dem ersten Start erneut ausführen"
fi
log "Engine-Variable r.FidelityFX.FI.Enabled=0 setzen"
if [ -f "$C/Engine.ini" ] && grep -q 'r.FidelityFX.FI.Enabled' "$C/Engine.ini"; then
  echo "bereits gesetzt"
else
  printf '\n[SystemSettings]\nr.FidelityFX.FI.Enabled=0\n' >> "$C/Engine.ini"; echo "ergänzt"
fi
printf '\n\033[32mFertig. Dragonwilds jetzt über Steam starten; FSR-Upscaling bleibt an, Frame Generation ist aus.\033[0m\n'
