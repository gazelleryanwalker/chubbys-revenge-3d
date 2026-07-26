# Verifier v3 — Godot build acceptance criteria (adds Wave-2 systems)

Same as v2 plus coverage for the new systems and an intro smoke test.

## Checks (all must PASS)
1-5. All v2 checks unchanged (files, import, --smoke auto-lock kill test,
     no script errors).
6. Feature greps extended: OUTFITS, WEAPONS, set_level, horse_fp, caption,
   flash_red, lifetime_kills, S.INTRO, spawn_drop.
7. NEW intro smoke: `godot --headless --path . -- --introtest` boots into
   S.INTRO, programmatically skips at t=1.5s, must print INTRO_OK and exit 0
   (proves the cinematic builds without errors and transitions to RIDE).

## Method: verifier/v3/check.sh on VPS, logs to verifier/runs/<ts>.log.
