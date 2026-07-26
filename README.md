# Chubby's Revenge 3D

A revenge FPS built in **Godot 4.3** — GDScript, with real CC0/CC-BY 3D assets (see [ATTRIBUTION.md](ATTRIBUTION.md)).

## Story

Brooke was out cruising the neighborhood on her skateboard when two kids on dirt bikes ran her down and left her for dead. But Brooke didn't stay down. She rose from the grave with one thing on her mind: revenge. Now she stalks the suburbs, the farmland, and downtown on her LED-lit skateboard (and occasionally a white horse), hunting the ones who wronged her. *A fictional revenge fantasy — for Brooke.*

## Features

- Auto-lock FPS combat
- God mode
- 8-arts brawl mode
- Gore / head-split system
- 10 levels across suburb, farmland, and downtown zones
- LED skateboard + white horse mounts
- 5 unlockable outfits
- Weapon drops
- Opening cinematic
- Procedural heavy-riff music
- **Knock on houses** in the suburbs while on foot (E) — residents answer with intel, city love, or stars
- **Side-street turns** — intersections appear ahead with green street signs; A/D to turn onto a new street
- **Real GLB models** replace all primitives: characters, houses, weapons, bikes, the horse
- **Full touch controls** — virtual joystick, drag-to-look, and on-screen buttons; playable on iPhone Safari at http://2.25.205.134/play/
- **Third-person view of Brooke** (T key) — orbit camera behind her real rigged model
- **Boss kill-cams** — slow-mo orbit around the death spot when a boss goes down
- **macOS + Web builds now available** — see Prebuilt binaries below

## Real 3D assets

All character, vehicle, weapon, and building models are real GLBs loaded through `scripts/model_loader.gd` (cached load, measure/fit, animation picking):

- **Kenney — Mini Skate pack** (CC0): skate-girl and skate-boy characters, skateboard deck
- **Kenney — City Kit: Suburban** (CC0): 12 suburban house models lining Maple Street
- **KayKit — Adventurers Character Pack** (CC0, Kay Lousberg): rigged Barbarian/Knight/Rogue punks, door-knock residents, funeral mourners
- **Quaternius** (CC0): rigged/animated white horse, shotgun, sawed-off, revolver, barbed bat
- **Motorcycle** — Corentin Fatus, **CC-BY 4.0** (via poly.pizza): the punks' dirt bikes

Full credit list and links: [ATTRIBUTION.md](ATTRIBUTION.md).

> **Note:** the `assets/` folder (~16 MB of GLBs) is **not tracked in git**. Download the models separately using the links in ATTRIBUTION.md and place them under `assets/` (`characters/`, `houses/`, `weapons/`, `animals/`, `vehicles/`, `props/`), or grab a prebuilt binary release — binaries have the assets baked in.

## Build & Run

1. Install [Godot 4.3](https://godotengine.org/download).
2. Download the GLB assets per [ATTRIBUTION.md](ATTRIBUTION.md) into `assets/` (skip this for binary releases).
3. Open `project.godot` in the Godot editor.
4. Press **F5** to run.

Exports: presets are included in `export_presets.cfg` (Linux, Windows, macOS, Web) — use **Project > Export** in the editor.

### Prebuilt binaries

- Windows: http://2.25.205.134/builds/chubbys-revenge-windows.exe
- Linux: http://2.25.205.134/builds/chubbys-revenge-linux.x86_64
- macOS: http://2.25.205.134/builds/chubbys-revenge-mac.zip
- Web (play in browser, touch-friendly on iPhone Safari): http://2.25.205.134/play/

## Verifier

Headless acceptance checks live in `verifier/`. To run the current suite (v4):

```sh
verifier/v4/check.sh
```

Requires a Linux box with the headless Godot 4.3 binary available. See `verifier/README.md` for details.
