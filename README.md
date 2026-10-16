# WinGaming – CrossOver-Nachbau für Steam auf dem Mac

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

## Ordner

```
WinGaming/
├── Steam (Whisky).app        ← Doppelklick startet Steam in der Bottle
├── README.md                 ← diese Datei
├── install.sh                ← Ein-Befehl-Installation (für Freunde): Whisky + Engine + Bottle + Steam
├── WinGaming-Setup.zip       ← weitergabefähiges Paket (nur Skripte + README)
├── setup/
│   ├── install-engine.sh     ← Runtime + D3DMetal laden, prüfen, installieren, deployen (idempotent)
│   ├── make-steam-bottle.sh  ← Bottle anlegen, konfigurieren, Steam installieren, Starter bauen
│   ├── launch.sh             ← Startskript der .app (holt laufendes Steam nach vorn)
│   └── front.swift           ← kleiner Helfer, der Fenster nach vorn holt
├── downloads/
│   ├── whisky-runtime/Libraries-4.6.4-beta.1.tar.gz   (481 MB, GPTk-fähig)
│   ├── whisky-runtime/Libraries-3.1.1-stock.tar.gz    (332 MB, Whiskys Standard, zum Zurückrollen)
│   └── gptk/game-porting-toolkit-3.0-3.tar.xz         (239 MB, enthält D3DMetal 3.0)
└── installer/SteamSetup.exe  ← offizieller Steam-Installer von Valve
```

Wo Whisky seine Daten ablegt:

- Runtime: `~/Library/Application Support/com.franke.Whisky/Libraries/`
- D3DMetal-Store: `~/Library/Application Support/com.franke.Whisky/D3DMetal/` (überlebt Runtime-Updates)
- Bottles: `~/Library/Containers/com.franke.Whisky/Bottles/<UUID>/` (Steam liegt in `drive_c/Program Files (x86)/Steam`)

## Dragonwilds spielen

1. **Steam starten:** Doppelklick auf `Steam (Whisky).app` (oder Whisky öffnen → Bottle „Steam“ → Steam.exe).
   Das Client-Update ist bereits eingespielt; Steam steht aktuell am Login-Fenster.
2. **Einloggen** (Steam Guard ganz normal am Handy bestätigen).
3. **RuneScape: Dragonwilds installieren** (ca. 25 GB). Steam richtet beim ersten Spielstart die
   Visual-C++-Laufzeit des Spiels ein; das darf ein paar Minuten dauern.
4. **Spielen.** Das Spiel läuft über D3DMetal (DirectX 12). Whisky schaltet dafür automatisch um:
   Steam selbst zeichnet über DXVK, das Spiel bekommt den Bottle-Backend „Recommended“ = D3DMetal.

Empfohlene Spiel-Einstellungen für den Anfang: DirectX 12 (Standard), Upscaling an (MetalFX wird über die
DLSS-Brücke angeboten), Frame Generation aus, Grafik „Mittel“ bis „Hoch“ in 1440p. Auf dem M4 Pro sollte
das flüssig sein; dann hochdrehen.

## Wenn etwas hakt

| Symptom | Was tun |
|---|---|
| Steam: „steamwebhelper reagiert nicht“ | Locale ist auf `en_US.UTF-8` gesetzt (Pflicht). Whisky → Bottle „Steam“ → Config → Launcher Compatibility prüfen; notfalls Steam-Ordner löschen und `setup/make-steam-bottle.sh` neu laufen lassen. |
| Steam startet, aber **kein Fenster** erscheint (Prozesse laufen) | Kennzeichen: `logs/cef_log.txt` meldet `eglCreateWindowSurface … EGL_BAD_ALLOC`. Ursache: Apples `dxgi` passt nicht zu DXVKs `d3d11`, mit dem Steam seine UI zeichnet. Fix: `setup/make-steam-bottle.sh` erneut laufen lassen (setzt Wines Original-`dxgi.dll` als native Datei in `system32`). Whisky bringt denselben Fix in der nächsten Version (upstream #251/#295). |
| Steam-Fenster bleibt schwarz | Bekannte Beta-Eigenart unter Last. Einmal mit `WINEMSYNC=0` starten: Whisky → Bottle → Config → Wine → Enhanced Sync auf „None“, Steam starten, danach wieder auf „msync“. |
| Spiel startet nicht / stürzt beim Laden ab | In Steam: Rechtsklick → Eigenschaften → Startoptionen `-dx11` eintragen (nutzt D3DMetals DX11-Pfad). Alternativ in Whisky bei der Spiel-EXE den Backend auf DXMT setzen (nur mit `-dx11`). |
| Pinker Bildschirm / sofortiger Absturz | Das passiert mit DXVK/DXMT bei DX12. Backend muss „Recommended“ oder „D3DMetal“ sein. Whisky → Settings → Game Porting Toolkit: dort muss „D3DMetal 3.0“ als importiert und deployt stehen. |
| „GPU drivers are out of date“ | Kommt bei manchen Engines von D3DMetals Treiberversion. Steam-Startoption `-dx11` probieren; der Treiber-Interposer der Runtime wird von Whisky erst für D3DMetal 4 aktiviert. |
| Spiel fehlt die VC++-Laufzeit (Fehler über `VCRUNTIME140`/`MSVCP140`) | Whisky → Bottle „Steam“ → Config → „Install Visual C++ Runtime“. |
| Controller geht nicht | Whisky → Bottle → Config → Controller & Input → „Controller Compatibility Mode“. |

Logs: Whisky → Bottle → „Diagnostics“; Steam-Logs unter `drive_c/Program Files (x86)/Steam/logs/`.

## Für Freunde weitergeben

Das Paket `WinGaming-Setup.zip` (im Ordner, ein paar Kilobyte) enthält nur Skripte und diese Anleitung.
Runtime, D3DMetal und den Steam-Installer laden die Skripte selbst von GitHub bzw. Valve und prüfen die
SHA-256-Prüfsummen. Nichts Proprietäres wird weitergegeben, jeder lädt Apples D3DMetal selbst.

Voraussetzungen beim Freund: Mac mit Apple Silicon (M1 oder neuer), macOS 15 Sequoia oder neuer, Homebrew
(https://brew.sh), ein Steam-Konto mit dem Spiel, ca. 5 GB für Engine und Steam plus Platz für das Spiel.

So geht es:

1. ZIP entpacken, z. B. nach `~/WinGaming`.
2. Terminal öffnen und starten:

```bash
~/WinGaming/install.sh
```

   Das Skript prüft Rosetta und Homebrew, installiert Whisky, richtet Engine und D3DMetal ein, legt die
   Bottle an, installiert Steam und baut `Steam (Whisky).app`. Dauer: 5 bis 10 Minuten, rund 1 GB Download.
3. Doppelklick auf `Steam (Whisky).app`, einloggen, Spiel installieren.

Hinweis: Beim ersten Start von `install.sh` fragt macOS eventuell nach dem Passwort für Rosetta. Wer das
Paket per GitHub teilen will, legt den Ordner (ohne `downloads/`, `installer/` und die `.app`) in ein Repo;
die Skripte funktionieren von überall, solange `setup/` neben `install.sh` liegt.

## Updates

- **Whisky-App:** `brew upgrade --cask frankea/whisky/whisky`. Bottles und Runtime bleiben erhalten.
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
- **Alles weg:** `brew uninstall --cask frankea/whisky/whisky`, dann die Ordner unter „Wo Whisky seine Daten ablegt“ löschen.

## Was die Skripte genau tun

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
