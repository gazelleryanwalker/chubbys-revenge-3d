# Verifier v2 — Godot 4 build acceptance criteria

Deliverable: /mnt/agents/output/chubby-godot/ must boot and play under Godot
4.3 headless on the build VPS.

## Checks
1. project.godot exists, declares run/main_scene=res://scenes/main.tscn.
2. scenes/main.tscn exists; scripts/: main.gd, player.gd, enemy.gd,
   world_builder.gd, gore.gd, hud.gd exist.
3. Headless import: `godot --headless --path . --import` exits 0.
4. Runtime smoke test: `godot --headless --path . -- --test` prints
   "RUN_STARTED", "TEST_PASS: auto-lock killed" and exits 0 within 30s
   (auto-lock must score ≥1 kill with no input).
5. No SCRIPT ERROR / Parse Error lines in output.
6. Feature greps (in scripts/): GOD MODE, AUTO-LOCK, MOVES (8 arts),
   HEAD SPLIT, LEVELS(10), SUBURB/FARMLAND/DOWNTOWN, mustache, taunts,
   LED board, pause, zones.

## Method
verifier/v2/check.sh runs on the VPS against /srv/chubby/godot-project,
logs to verifier/runs/<ts>.log, exit 0 = PASS.
