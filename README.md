# Chubby's Revenge 3D

A revenge FPS built in **Godot 4.3** — GDScript, fully procedural (no external assets).

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

## Build & Run

1. Install [Godot 4.3](https://godotengine.org/download).
2. Open `project.godot` in the Godot editor.
3. Press **F5** to run.

Exports: presets are included in `export_presets.cfg` — use **Project > Export** in the editor.

### Prebuilt binaries

- Windows: http://2.25.205.134/builds/chubbys-revenge-windows.exe
- Linux: http://2.25.205.134/builds/chubbys-revenge-linux.x86_64

## Verifier

Headless acceptance checks live in `verifier/`. To run the current suite (v3):

```sh
verifier/v3/check.sh
```

Requires a Linux box with the headless Godot 4.3 binary available. See `verifier/README.md` for details.
