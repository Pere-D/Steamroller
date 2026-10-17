# WinGaming – Steam-Spiele auf dem Mac (Apple Silicon)

**Schnellstart, ein Programm:**

1. **[⬇ Steam-auf-Mac.zip herunterladen](https://github.com/Pere-D/WinGaming/releases/latest/download/Steam-auf-Mac.zip)**
2. Entpacken, `Steam auf Mac` in den Ordner „Programme“ ziehen, doppelklicken.
3. Beim ersten Mal sagt macOS „nicht überprüft“: Systemeinstellungen → Datenschutz & Sicherheit → **„Trotzdem öffnen“**.
4. „Installieren“ klicken, 5 bis 10 Minuten warten, in Steam einloggen, RuneScape: Dragonwilds installieren, spielen.

Voraussetzungen: Mac mit Apple Silicon (M1 oder neuer), macOS 15 oder neuer, ein Steam-Konto mit dem Spiel.

---

Freier Ersatz für CrossOver, zusammengebaut aus denselben Bausteinen, die CrossOver intern nutzt:
Wine mit CrossOver-Patches, Apples D3DMetal (DirectX 11/12 → Metal) und eine macOS-Oberfläche.
Ziel: **RuneScape: Dragonwilds** (Windows-only, braucht DirectX 12) über Steam spielen.

| Baustein | Was es ist | Herkunft |
|---|---|---|
| **Whisky 3.7.0** (`/Applications/Whisky.app`) | Oberfläche + Bottle-Verwaltung (aktiv gepflegter Fork von frankea) | `brew install --cask frankea/whisky/whisky` |
| **Runtime 4.6.4-beta.1** | Wine 11.16 mit CrossOver-26.3-Patches, als „GPTk-fähig“ markiert | GitHub-Release `frankea/Whisky v4.6.4-beta.1` (SHA-256 geprüft) |
| **D3DMetal 3.0** | Apples DirectX-12-Übersetzer aus dem Game Porting Toolkit 3 | Gcenx-Paket `game-porting-toolkit-3.0-3` (Apple-Signatur geprüft) |
| **DXMT 0.80 / DXVK 1.10.3** | DirectX-11-Fallbacks, kommen mit der Runtime | in der Runtime enthalten |
| **Bottle „Steam“** | Windows-10-Prefix mit Steam, Launcher-Kompatibilitätsmodus an | per `setup/make-steam-bottle.sh` |

Warum die Beta-Runtime? Die stabile Whisky-Runtime (3.1.1) ist nicht „GPTk-fähig“, Whisky deployt D3DMetal
darauf gar nicht. Erst die 4.x-Linie (CrossOver-Patches) kann D3DMetal ausführen. Laut Release-Notes wurde
sie mit Steam und DX12-Spielen über D3DMetal getestet.

## Was beim ersten Start passiert

Die App ist nicht bei Apple notarisiert (das bräuchte ein kostenpflichtiges Entwicklerkonto), darum blockt
macOS sie beim allerersten Öffnen: „Fertig“ klicken, dann **Systemeinstellungen → Datenschutz & Sicherheit**,
ganz unten **„Trotzdem öffnen“**, mit Passwort oder Touch ID bestätigen. Das passiert nur einmal.

Danach fragt die App „Installieren?“ und zeigt den Fortschritt in einem Terminal-Fenster: Rosetta (falls
nötig), Whisky aus der signierten DMG, Wine-Engine mit Apples D3DMetal, Steam. Rund 1 GB Download. Am Ende
startet Steam von selbst. Die App legt die Dragonwilds-Einstellungen passend vor (Frame Generation aus,
Grafik „Hoch“, 60 fps). Ab dann ist `Steam auf Mac` einfach der Steam-Startknopf: Doppelklick startet Steam
in der Bottle oder holt es nach vorn, wenn es schon läuft.

**Für Leute mit Terminal-Erfahrung** geht es auch ohne App:

```bash
git clone https://github.com/Pere-D/WinGaming.git ~/WinGaming && ~/WinGaming/install.sh
```

Das legt zusätzlich `~/WinGaming/Steam (Whisky).app` als Starter an. Alles Weitere unten.

## Ordner

```
WinGaming/
├── dist/Steam auf Mac.app    ← die Ein-Programm-App (gebaut von setup/build-app.sh), als ZIP im Release
├── Steam (Whisky).app        ← Starter aus dem Skript-Weg (install.sh)
├── README.md                 ← diese Datei
├── install.sh                ← Komplettinstallation per Skript: Whisky (DMG) + Engine + Bottle + Steam
├── setup/
│   ├── install-engine.sh     ← Runtime + D3DMetal laden, prüfen, installieren, deployen (idempotent)
│   ├── make-steam-bottle.sh  ← Bottle anlegen, konfigurieren, Steam installieren, Starter bauen
│   ├── fix-dragonwilds.sh    ← schaltet FSR Frame Generation ab (Absturz nach ~30 s)
│   ├── launch.sh             ← Startskript von „Steam (Whisky).app“
│   ├── app-launch.sh         ← Startskript von „Steam auf Mac.app“ (Setup beim ersten Start, sonst Steam)
│   ├── launcher.swift        ← Mach-O-Hülle der App (ruft app-launch.sh; damit die Signatur ZIPs übersteht)
│   ├── front.swift           ← kleiner Helfer, der Fenster nach vorn holt
│   └── build-app.sh          ← baut dist/Steam auf Mac.app + Steam-auf-Mac.zip
├── downloads/
│   ├── whisky-runtime/Libraries-4.6.4-beta.1.tar.gz   (481 MB, GPTk-fähig)
│   ├── whisky-runtime/Libraries-3.1.1-stock.tar.gz    (332 MB, Whiskys Standard, zum Zurückrollen)
│   └── gptk/game-porting-toolkit-3.0-3.tar.xz         (239 MB, enthält D3DMetal 3.0)
└── installer/SteamSetup.exe  ← offizieller Steam-Installer von Valve
```

Wo die Daten liegen:

- Downloads der App (Runtime, D3DMetal, Steam-Installer): `~/Library/Application Support/WinGaming/`

- Runtime: `~/Library/Application Support/com.franke.Whisky/Libraries/`
- D3DMetal-Store: `~/Library/Application Support/com.franke.Whisky/D3DMetal/` (überlebt Runtime-Updates)
- Bottles: `~/Library/Containers/com.franke.Whisky/Bottles/<UUID>/` (Steam liegt in `drive_c/Program Files (x86)/Steam`)

## Dragonwilds spielen

1. **Steam starten:** Doppelklick auf `Steam auf Mac` (oder `Steam (Whisky).app` beim Skript-Weg).
2. **Einloggen** (Steam Guard ganz normal am Handy bestätigen). Parallel im Mac-Steam eingeloggt zu bleiben
   ist erlaubt; installieren muss man das Spiel aber in diesem Steam, das Mac-Steam graut „Install“ aus.
3. **RuneScape: Dragonwilds installieren** (ca. 25 GB) und starten. Steam richtet beim ersten Start die
   Visual-C++-Laufzeit des Spiels ein.
4. **Spielen.** Das Spiel läuft über D3DMetal (DirectX 12). Whisky schaltet dafür automatisch um:
   Steam selbst zeichnet über DXVK, das Spiel bekommt den Bottle-Backend „Recommended“ = D3DMetal.

Die App legt die Spiel-Einstellungen vor und frischt sie bei jedem Steam-Start auf: **Frame Generation aus**
(das Spiel hält D3DMetal für eine AMD-Karte und würde sonst FSR 3 mit Frame Generation einschalten, was es
nach rund 30 Sekunden im Hauptmenü still beendet), FSR-Upscaling „Quality“, Grafik „Hoch“, 60 fps. Falls
das Spiel beim allerersten Start trotzdem nach einer halben Minute verschwindet, hat es die Vorbelegung
überschrieben: `Steam auf Mac` erneut öffnen (das setzt Frame Generation wieder aus) und das Spiel neu
starten. Im Spiel Frame Generation nicht wieder aktivieren.

Zu Strom und Lüftern: Das Spiel läuft unter Rosetta (x86-Emulation) plus DirectX-Übersetzung, das kostet
mehr als nativ. Mit „Hoch“ und 60 fps bleibt der M4 Pro deutlich ruhiger als mit dem Maximum ohne Limit,
das das Spiel wegen der vorgetäuschten High-End-GPU von selbst wählt. Wer mehr will, dreht im Spiel hoch.

## Wenn etwas hakt

| Symptom | Was tun |
|---|---|
| Steam: „steamwebhelper reagiert nicht“ | Locale ist auf `en_US.UTF-8` gesetzt (Pflicht). Whisky → Bottle „Steam“ → Config → Launcher Compatibility prüfen; notfalls Steam-Ordner löschen und `setup/make-steam-bottle.sh` neu laufen lassen. |
| „Steam auf Mac“ lässt sich nicht öffnen („nicht überprüft“ / „beschädigt“) | Nicht notarisiert, einmalig freigeben: Systemeinstellungen → Datenschutz & Sicherheit → „Trotzdem öffnen“. Meldet macOS „beschädigt“, wurde das ZIP unsauber entpackt; erneut laden und mit dem Archivierungsprogramm von macOS entpacken. |
| Doppelklick auf die App und nichts passiert | Steam läuft schon in der Bottle; die App holt nur dessen Fenster nach vorn. Steam im Dock oder per Cmd-Tab suchen. |
| Steam startet, aber **kein Fenster** erscheint (Prozesse laufen) | Kennzeichen: `logs/cef_log.txt` meldet `eglCreateWindowSurface … EGL_BAD_ALLOC`. Ursache: Apples `dxgi` passt nicht zu DXVKs `d3d11`, mit dem Steam seine UI zeichnet. Fix: `setup/make-steam-bottle.sh` erneut laufen lassen (setzt Wines Original-`dxgi.dll` als native Datei in `system32`). Whisky bringt denselben Fix in der nächsten Version (upstream #251/#295). |
| Steam-Fenster bleibt schwarz | Bekannte Beta-Eigenart unter Last. Einmal mit `WINEMSYNC=0` starten: Whisky → Bottle → Config → Wine → Enhanced Sync auf „None“, Steam starten, danach wieder auf „msync“. |
| Dragonwilds stürzt ca. 30 s nach dem Start im Menü ab, ohne Fehlermeldung | FSR Frame Generation ist an (Auto-Erkennung „AMD“). `setup/fix-dragonwilds.sh` ausführen, dann neu starten. Im Spiel Frame Generation nicht wieder aktivieren. |
| Spiel startet nicht / stürzt beim Laden ab | In Steam: Rechtsklick → Eigenschaften → Startoptionen `-dx11` eintragen (nutzt D3DMetals DX11-Pfad). Alternativ in Whisky bei der Spiel-EXE den Backend auf DXMT setzen (nur mit `-dx11`). |
| Pinker Bildschirm / sofortiger Absturz | Das passiert mit DXVK/DXMT bei DX12. Backend muss „Recommended“ oder „D3DMetal“ sein. Whisky → Settings → Game Porting Toolkit: dort muss „D3DMetal 3.0“ als importiert und deployt stehen. |
| „GPU drivers are out of date“ | Kommt bei manchen Engines von D3DMetals Treiberversion. Steam-Startoption `-dx11` probieren; der Treiber-Interposer der Runtime wird von Whisky erst für D3DMetal 4 aktiviert. |
| Spiel fehlt die VC++-Laufzeit (Fehler über `VCRUNTIME140`/`MSVCP140`) | Whisky → Bottle „Steam“ → Config → „Install Visual C++ Runtime“. |
| Controller geht nicht | Whisky → Bottle → Config → Controller & Input → „Controller Compatibility Mode“. |

Logs: Whisky → Bottle → „Diagnostics“; Steam-Logs unter `drive_c/Program Files (x86)/Steam/logs/`.

## Für Freunde weitergeben

Link zur ZIP schicken (siehe oben) oder die ZIP direkt per AirDrop/Messenger, sie ist winzig. Die App lädt
alles Weitere selbst von GitHub (Whisky, Runtime, Apples D3DMetal aus dem Game Porting Toolkit) und von
Valve (Steam) und prüft die SHA-256-Prüfsummen. Nichts Proprietäres wird weitergegeben.

Was die Freunde brauchen: Apple-Silicon-Mac, macOS 15 oder neuer, Steam-Konto mit dem Spiel, rund 5 GB
für Engine und Steam plus Platz für das Spiel. Die einzige Hürde ist der einmalige Gatekeeper-Klick
(„Trotzdem öffnen“), weil die App ohne Apple-Entwicklerzertifikat gebaut ist.

## Updates

- **„Steam auf Mac“-App:** einfach durch die neue Version ersetzen; Downloads, Engine und Bottle bleiben.
- **Whisky-App:** neue DMG von https://github.com/frankea/Whisky/releases nach /Applications ziehen (oder
  `brew upgrade --cask frankea/whisky/whisky`, falls per Homebrew installiert). Bottles und Runtime bleiben.
- **Runtime:** Whisky meldet kein Update, solange die lokale Runtime (4.6.4) neuer ist als die stabile
  (3.1.1). Für eine neue Beta-Runtime: Datei nach `downloads/whisky-runtime/` legen und
  `WANT_RUNTIME=4.x.y setup/install-engine.sh downloads/whisky-runtime/<datei>.tar.gz` ausführen.
  Das Skript sichert die alte Runtime, entpackt die neue und deployt D3DMetal erneut (ein Runtime-Wechsel
  ersetzt den `Libraries/`-Ordner samt deployter DLLs, der D3DMetal-Store bleibt).
- **D3DMetal 4 (für macOS 27 / Whiskys Interposer):** Apples Game Porting Toolkit mit Apple-ID bei
  developer.apple.com laden, dann Whisky → Settings → Game Porting Toolkit → DMG importieren. Whisky
  prüft Apples Signatur und ersetzt den Store.

## Zurückrollen / Entfernen

- **Stabile Runtime zurück (ohne D3DMetal):** Whisky beenden,
  `rm -rf ~/Library/Application\ Support/com.franke.Whisky/Libraries`, Whisky starten; es lädt 3.1.1 selbst.
  Oder die Sicherung `Libraries-backup-*` im selben Ordner zurückbenennen.
- **Nur D3DMetal raus:** Whisky → Settings → Game Porting Toolkit → Remove. Wines Original-DLLs liegen im
  Store unter `originals/` und werden zurückgespielt.
- **Alles weg:** `Whisky.app` und `Steam auf Mac.app` in den Papierkorb, dann die Ordner unter „Wo die Daten liegen“ löschen.

## Was die Skripte genau tun

`Steam auf Mac.app` ist eine dünne Hülle: Ein kleines kompiliertes Startprogramm ruft `app-launch.sh`.
Ist alles da (Whisky, Runtime, Bottle „Steam“ mit Steam.exe), startet es Steam bzw. holt es nach vorn und
pflegt nebenbei die Dragonwilds-Einstellungen. Fehlt etwas, fragt es nach und lässt `install.sh` in einem
Terminal-Fenster laufen. `install.sh` installiert Whisky direkt aus der notarisierten DMG (SHA-256 geprüft)
und ruft dann die beiden folgenden Skripte.


`setup/install-engine.sh` spiegelt Whiskys eigenen Import-Code (`GPTKImporter`) in Shell:
Runtime entpacken → `gptkCapable=true` prüfen → aus dem GPTk-Archiv `external/` (libd3dshared.dylib +
D3DMetal.framework) und die vier Forwarder-DLLs (d3d10/d3d11/d3d12/dxgi) sowie nvapi64 und
nvngx-on-metalfx holen → Apple-Signatur mit `codesign -R 'identifier … and anchor apple'` prüfen →
Store `D3DMetal/lib` + `D3DMetalVersion.plist` schreiben → in die Runtime deployen (Wine-Originale nach
`originals/`, Unix-Brücken `*.so → libd3dshared.dylib`, MetalFX-Brücke als `nvngx.dll`, Apples NVAPI).
Whisky erkennt das Ergebnis als „eigene“ Deployment (byteidentisch mit dem Store) und pflegt es weiter.
Zum Schluss frischt es in allen Bottles die native `dxgi.dll` (siehe unten) auf.

`setup/make-steam-bottle.sh` legt die Bottle per `WhiskyCmd create` an, setzt in `Metadata.plist`
Launcher-Kompatibilität, `en_US.UTF-8`, 90 s Timeout, GPU-Spoofing (NVIDIA), installiert Steam still
(`SteamSetup.exe /S`), legt Wines Original-`dxgi.dll` ohne Builtin-Marker nach `system32` (nötig, damit Steams
DXVK-UI neben D3DMetal ein Fenster bekommt; Whisky 3.7.0 fehlt dieser Schritt noch) und baut den `.app`-Starter
per `WhiskyCmd shortcut`.

## Rechtliches, kurz

Whisky, Wine, DXMT, DXVK: Open Source. D3DMetal ist Apple-proprietär; die Nutzung richtet sich nach
Apples Game-Porting-Toolkit-Lizenz (liegt dem Gcenx-Paket bei). Steam und das Spiel kauft man wie gewohnt.
