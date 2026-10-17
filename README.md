# Steamroller – Windows Steam games on Apple Silicon Macs

**Quick start, one app:**

1. **[⬇ Download Steamroller.zip](https://github.com/Pere-D/Steamroller/releases/latest/download/Steamroller.zip)**
2. Unzip it, drag `Steamroller` into your Applications folder, double-click it.
3. The first time, macOS says it cannot verify the app: open System Settings → Privacy & Security and click **Open Anyway**.
4. Click **Install**, wait 5 to 10 minutes, sign in to Steam, install RuneScape: Dragonwilds, play.

Requirements: a Mac with Apple Silicon (M1 or newer), macOS 15 or newer, a Steam account that owns the game.
No Homebrew, no Xcode, no Terminal commands.

---

Steamroller is a free stand-in for CrossOver, assembled from the same parts CrossOver uses internally:
Wine with CrossOver patches, Apple's D3DMetal (DirectX 11/12 → Metal) and a macOS front end. It was built to
play **RuneScape: Dragonwilds** (Windows-only, needs DirectX 12) through Steam; other Windows Steam games
run the same way.

| Part | What it is | Where it comes from |
|---|---|---|
| **Whisky 3.7.0** | Front end and bottle management (actively maintained fork by frankea) | notarized DMG from GitHub, SHA-256 verified |
| **Runtime 4.6.4-beta.1** | Wine 11.16 with CrossOver 26.3 patches, marked "GPTK-capable" | GitHub release of frankea/Whisky, SHA-256 verified |
| **D3DMetal 3.0** | Apple's DirectX 12 translator from the Game Porting Toolkit 3 | Gcenx package `game-porting-toolkit-3.0-3`, Apple signature verified |
| **DXMT 0.80 / DXVK 1.10.3** | DirectX 11 fallbacks shipped with the runtime | included in the runtime |
| **Bottle "Steam"** | Windows 10 prefix with Steam, launcher compatibility mode on | created by `setup/make-steam-bottle.sh` |

Why the beta runtime? Whisky's stable runtime (3.1.1) is not "GPTK-capable", so Whisky never deploys
D3DMetal on it. Only the 4.x line (CrossOver patches) can execute D3DMetal, and its release notes list Steam
and DirectX 12 titles over D3DMetal as tested.

## What happens on first launch

The app is not notarized by Apple (that needs a paid developer account), so macOS blocks it the first time:
click "Done", then **System Settings → Privacy & Security**, scroll down, **Open Anyway**, confirm with your
password or Touch ID. This happens once.

Then the app asks "Install?" and shows the progress in a Terminal window: Rosetta (if needed), Whisky from
the signed DMG, the Wine engine with Apple's D3DMetal, Steam. About 1 GB of downloads. When it is done,
Steam starts by itself. The app seeds the Dragonwilds settings (frame generation off, graphics "High",
60 fps). From then on `Steamroller` is simply your Steam button: double-click starts Steam in the bottle,
or brings it to the front if it is already running.

**If you like the Terminal**, the same setup is available as scripts:

```bash
git clone https://github.com/Pere-D/Steamroller.git ~/Steamroller && ~/Steamroller/install.sh
```

This route additionally creates `~/Steamroller/Steam (Whisky).app` as a launcher. Everything else is below.

## Folder layout

```
Steamroller/
├── dist/Steamroller.app      ← the one-app installer (built by setup/build-app.sh), shipped as a ZIP in Releases
├── Steam (Whisky).app        ← launcher created on the script route (install.sh)
├── README.md                 ← this file
├── LICENSE                   ← MIT
├── install.sh                ← complete setup by script: Whisky (DMG) + engine + bottle + Steam
├── setup/
│   ├── install-engine.sh     ← download, verify, install and deploy runtime + D3DMetal (idempotent)
│   ├── make-steam-bottle.sh  ← create and configure the bottle, install Steam, build the launcher
│   ├── fix-dragonwilds.sh    ← turn FSR frame generation off (crash after ~30 s)
│   ├── launch.sh             ← launcher script of "Steam (Whisky).app"
│   ├── app-launch.sh         ← main script of "Steamroller.app" (setup on first launch, Steam afterwards)
│   ├── launcher.swift        ← Mach-O shell of the app (calls app-launch.sh; keeps the signature intact in ZIPs)
│   ├── front.swift           ← small helper that brings windows to the front
│   ├── build-app.sh          ← builds dist/Steamroller.app + Steamroller.zip
│   └── icon/                 ← icon renderer (Swift) and the generated AppIcon.icns
├── downloads/                ← (script route) runtime and GPTK archives, downloaded on demand
└── installer/SteamSetup.exe  ← (script route) Valve's official Steam installer, downloaded on demand
```

Where the data lives:

- App downloads (runtime, D3DMetal, Steam installer): `~/Library/Application Support/Steamroller/`
- Runtime: `~/Library/Application Support/com.franke.Whisky/Libraries/`
- D3DMetal store: `~/Library/Application Support/com.franke.Whisky/D3DMetal/` (survives runtime updates)
- Bottles: `~/Library/Containers/com.franke.Whisky/Bottles/<UUID>/` (Steam lives in `drive_c/Program Files (x86)/Steam`)

## Playing Dragonwilds

1. **Start Steam:** double-click `Steamroller` (or `Steam (Whisky).app` on the script route).
2. **Sign in** (Steam Guard on your phone as usual). Staying signed in to the native Mac Steam in parallel is
   fine, but the game has to be installed in *this* Steam; the Mac Steam greys out "Install" for Windows-only games.
3. **Install RuneScape: Dragonwilds** (about 25 GB) and start it. Steam installs the game's Visual C++
   runtime on first start.
4. **Play.** The game runs on D3DMetal (DirectX 12). Whisky switches automatically: Steam itself draws with
   DXVK, the game gets the bottle backend "Recommended" = D3DMetal.

The app seeds the game settings and refreshes them on every Steam start: **frame generation off** (the game
takes D3DMetal for an AMD card and would otherwise enable FSR 3 with frame generation, which silently kills
it after about 30 seconds in the main menu), FSR upscaling "Quality", graphics "High", 60 fps. If the game
still disappears half a minute after its very first start, it overwrote the seed: open `Steamroller` again
(that turns frame generation off) and start the game again. Do not re-enable frame generation in the game.

About power and fans: the game runs under Rosetta (x86 emulation) plus DirectX translation, which costs more
than native. With "High" and a 60 fps cap an M4 Pro stays much quieter than with the maximum settings the
game picks on its own because of the spoofed high-end GPU. Turn things up in the game if you want more.

## Troubleshooting

| Symptom | What to do |
|---|---|
| `Steamroller` cannot be opened ("not verified" / "damaged") | Not notarized; allow it once: System Settings → Privacy & Security → "Open Anyway". If macOS says "damaged", the ZIP was unpacked badly; download again and unpack with macOS Archive Utility. |
| Double-click on the app and nothing happens | Steam is already running in the bottle; the app only brings its window to the front. Look for Steam in the Dock or via Cmd-Tab. |
| Steam: "steamwebhelper is not responding" | The locale must be `en_US.UTF-8`. Check Whisky → bottle "Steam" → Config → Launcher Compatibility; if needed delete the Steam folder and run `setup/make-steam-bottle.sh` again. |
| Steam starts but **no window** appears (processes are running) | `logs/cef_log.txt` shows `eglCreateWindowSurface … EGL_BAD_ALLOC`. Apple's `dxgi` does not pair with DXVK's `d3d11`, which draws Steam's UI. Run `setup/make-steam-bottle.sh` again (installs Wine's original `dxgi.dll` as a native file in `system32`). Whisky ships the same fix in its next release (upstream #251/#295). |
| Steam window stays black | Known beta quirk under load. Start once with `WINEMSYNC=0`: Whisky → bottle → Config → Wine → Enhanced Sync "None", start Steam, switch back to "msync" afterwards. |
| Dragonwilds vanishes about 30 s after start, no error | FSR frame generation is on (auto-detected "AMD"). Run `setup/fix-dragonwilds.sh`, then restart. Do not re-enable frame generation in the game. |
| Game does not start / crashes while loading | In Steam: right-click → Properties → launch options `-dx11` (uses D3DMetal's DX11 path). Alternatively set the game executable's backend to DXMT in Whisky (only together with `-dx11`). |
| Pink screen / instant crash | That is DXVK/DXMT with DX12. The backend must be "Recommended" or "D3DMetal". Whisky → Settings → Game Porting Toolkit must show "D3DMetal 3.0" imported and deployed. |
| "GPU drivers are out of date" | Some engines reject D3DMetal's driver version. Try the Steam launch option `-dx11`; Whisky enables the runtime's driver-version interposer only for D3DMetal 4. |
| Missing VC++ runtime (`VCRUNTIME140` / `MSVCP140` errors) | Whisky → bottle "Steam" → Config → "Install Visual C++ Runtime". |
| Controller does not work | Whisky → bottle → Config → Controller & Input → "Controller Compatibility Mode". |

Logs: Whisky → bottle → "Diagnostics"; Steam logs under `drive_c/Program Files (x86)/Steam/logs/`.

## Sharing it

Send the link to the ZIP (see the top) or the ZIP itself via AirDrop or a messenger; it is tiny. The app
downloads everything else from GitHub (Whisky, the runtime, Apple's D3DMetal from the Game Porting Toolkit)
and from Valve (Steam) and verifies the SHA-256 digests. Nothing proprietary is redistributed.

What the other person needs: an Apple Silicon Mac, macOS 15 or newer, a Steam account with the game, about
5 GB for engine and Steam plus space for the game. The only hurdle is the one-time Gatekeeper click
("Open Anyway"), because the app is built without an Apple developer certificate.

## Updates

- **Steamroller app:** just replace it with the new version; downloads, engine and bottle stay.
- **Whisky app:** drag a newer DMG from https://github.com/frankea/Whisky/releases into /Applications
  (or `brew upgrade --cask frankea/whisky/whisky` if you installed it with Homebrew). Bottles and runtime stay.
- **Runtime:** Whisky reports no update while the local runtime (4.6.4) is newer than the stable one (3.1.1).
  For a newer beta runtime, put the file into `downloads/whisky-runtime/` and run
  `WANT_RUNTIME=4.x.y setup/install-engine.sh downloads/whisky-runtime/<file>.tar.gz`. The script backs up the
  old runtime, extracts the new one and deploys D3DMetal again (a runtime swap replaces the `Libraries/` folder
  including the deployed DLLs; the D3DMetal store stays).
- **D3DMetal 4 (for macOS 27 / Whisky's interposers):** download Apple's Game Porting Toolkit with your Apple
  ID from developer.apple.com, then Whisky → Settings → Game Porting Toolkit → import the DMG. Whisky verifies
  Apple's signature and replaces the store.

## Rolling back / removing

- **Back to the stable runtime (without D3DMetal):** quit Whisky,
  `rm -rf ~/Library/Application\ Support/com.franke.Whisky/Libraries`, start Whisky; it downloads 3.1.1 itself.
  Or rename the `Libraries-backup-*` folder next to it back.
- **Only D3DMetal:** Whisky → Settings → Game Porting Toolkit → Remove. Wine's original DLLs are kept in the
  store under `originals/` and restored.
- **Everything:** move `Whisky.app` and `Steamroller.app` to the Trash, then delete the folders listed under
  "Where the data lives".

## What the scripts do

`Steamroller.app` is a thin shell: a small compiled launcher runs `app-launch.sh`. If everything is there
(Whisky, runtime, bottle "Steam" with Steam.exe), it starts Steam or brings it to the front and keeps the
Dragonwilds settings fresh. If something is missing, it asks and runs `install.sh` in a Terminal window.
`install.sh` installs Whisky straight from the notarized DMG (SHA-256 verified) and then calls the two
scripts below.

`setup/install-engine.sh` mirrors Whisky's own import code (`GPTKImporter`) in shell: extract the runtime →
check `gptkCapable=true` → take `external/` (libd3dshared.dylib + D3DMetal.framework), the four forwarder
DLLs (d3d10/d3d11/d3d12/dxgi) plus nvapi64 and nvngx-on-metalfx from the GPTK archive → verify Apple's
signature with `codesign -R 'identifier … and anchor apple'` → write the store `D3DMetal/lib` +
`D3DMetalVersion.plist` → deploy into the runtime (Wine originals to `originals/`, unix bridges
`*.so → libd3dshared.dylib`, MetalFX bridge as `nvngx.dll`, Apple's NVAPI). Whisky recognizes the result as
its own deployment (byte-identical to the store) and keeps maintaining it. Finally it refreshes the native
`dxgi.dll` in all bottles.

`setup/make-steam-bottle.sh` creates the bottle with `WhiskyCmd create`, sets launcher compatibility,
`en_US.UTF-8`, a 90 s timeout and GPU spoofing (NVIDIA) in `Metadata.plist`, installs Steam silently
(`SteamSetup.exe /S`), puts Wine's original `dxgi.dll` without the builtin marker into `system32` (needed so
Steam's DXVK-drawn UI gets a window next to D3DMetal; Whisky 3.7.0 still lacks this step), seeds the
Dragonwilds settings and builds the `.app` launcher with `WhiskyCmd shortcut`.

## Legal, briefly

Steamroller's own scripts are MIT licensed. Whisky, Wine, DXMT and DXVK are open source. D3DMetal is
Apple-proprietary; every user downloads it themselves from Gcenx's Game Porting Toolkit package and uses it
under Apple's GPTK license (included in that package). Steam and the game are bought as usual.
Steamroller is not affiliated with Valve, Jagex, Apple or CodeWeavers.
