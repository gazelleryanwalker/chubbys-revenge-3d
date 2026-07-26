# Verifier index (append-only)

## v1 — 2026-07-26 — UE5 C++ project structural criteria (SUPERSEDED)
Location: verifier/v1/criteria.md (under /mnt/agents/output/chubbys-revenge-ue5)
Measured: file presence, .uproject JSON validity, class coverage, docs.
Superseded because: user switched engine target from Unreal to Godot 4
(Godot is the only engine installable/runnable in the build environment).
The UE5 source scaffold remains on disk but is no longer the deliverable.

## v2 — 2026-07-26 — Godot 4 build runtime criteria (ACTIVE)
Location: verifier/v2/criteria.md, verifier/v2/check.sh (runs on the VPS
against /srv/chubby/godot-project)
Measures: file presence, headless import, scripted runtime smoke test
(boot → spawn 3 enemies → auto-lock must score ≥1 kill with zero input →
TEST_PASS), absence of script errors, feature-coverage greps.
Runs logged under verifier/runs/.
Status: ALL_PASS (run 20260726_065458 — auto-lock killed 9, health 100).
Exported Linux build independently re-passed the same smoke test.

## v3 — 2026-07-26 — Wave-2 systems criteria (ACTIVE)
Location: verifier/v3/criteria.md, verifier/v3/check.sh
Differs from v2: adds greps for outfits/weapons/music/horse/intro systems
and a new --introtest smoke (boot to S.INTRO, scripted skip, must reach
RIDE and print INTRO_OK). v2 remains the baseline for the original systems.
