# Chubby's Revenge 3D

A revenge FPS built in **Godot 4.3** — GDScript, with real CC0/CC-BY 3D assets (see [ATTRIBUTION.md](ATTRIBUTION.md)).

## Story

Brooke was out cruising the neighborhood on her skateboard when two kids on dirt bikes ran her down and left her for dead. But Brooke didn't stay down. She rose from the grave with one thing on her mind: revenge. Now she stalks the suburbs, the farmland, and downtown on her LED-lit skateboard (and occasionally a white horse), hunting the ones who wronged her. *A fictional revenge fantasy — for Brooke.*

## Features

- **Proper start menu** — rider name (persisted in the save), full controls list, god-mode & third-person toggles, and lifetime stats
- **In-game instruction cards** — staggered how-to cards on your first runs (touch gets its own wording)
- **Click-to-aim + arrow-key aim fallback** — click once to lock the pointer ("AIM LOCKED"); arrow keys aim on trackpads/no-mouse setups, with a "CLICK TO AIM" nudge while the pointer is free
- Auto-lock FPS combat
- God mode
- 8-arts brawl mode — **now dangerous**: punks circle and lunge at her while she's on foot (telegraphed with a "!" flash)
- Gore / head-split system
- **Bosses on levels 5 & 10** — "KILLER IS DEAD" slow-mo kill-cams orbit the death spot
- **Full SFX** — synthesized gunshots, gore/kill crunches, rams, pickups, outfit-unlock fanfares, door knocks, wave-clear arpeggios (headless-safe second audio generator)
- 10 levels across suburb, farmland, and downtown zones
- LED skateboard + white horse mounts
- 5 unlockable outfits
- Weapon drops
- Opening cinematic
- Procedural heavy-riff music
- **Knock on houses** in the suburbs while on foot (E) — residents answer with intel, city love, or health
- **Side-street turns on Q/E** — the turn offer arms as the intersection actually arrives (~3s out), so the keys match what you see; A/D stay dodge-only
- **Pause & death screens fixed** — pause works while the tree is paused (clickable RESUME, R restarts from pause or death, M returns to menu from the death screen)
- **Real GLB models** replace all primitives: characters, houses, weapons, bikes, the horse
- **Full touch controls** — virtual joystick, drag-to-look, and on-screen buttons; playable on iPhone Safari at http://2.25.205.134/play/
- **Third-person view of Brooke** (T key) — orbit camera behind her real rigged model; can be set as the default from the menu
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

Headless acceptance checks live in `verifier/`. To run the current suite (v6):

```sh
verifier/v6/check.sh
```

Requires a Linux box with the headless Godot 4.3 binary available. See `verifier/README.md` for details.
