#!/bin/bash
# verifier/v2 — run ON THE VPS against /srv/chubby/godot-project
set -u
P=/srv/chubby/godot-project
G=/srv/chubby/tools/Godot_v4.3-stable_linux.x86_64
TS=$(date +%Y%m%d_%H%M%S)
LOG=$P/verifier/runs/$TS.log
mkdir -p $P/verifier/runs
FAIL=0
note(){ echo "$@" | tee -a $LOG; }

note "=== verifier v5 run $TS ==="
# 1-2: files
for f in project.godot scenes/main.tscn scripts/main.gd scripts/player.gd scripts/enemy.gd scripts/world_builder.gd scripts/gore.gd scripts/hud.gd; do
  if [ -f "$P/$f" ]; then note "PASS file $f"; else note "FAIL file $f MISSING"; FAIL=1; fi
done
# 3: headless import
$G --headless --path $P --import > /tmp/import.log 2>&1
if [ $? -eq 0 ]; then note "PASS headless import"; else note "FAIL headless import"; cat /tmp/import.log | tail -20 | tee -a $LOG; FAIL=1; fi
# 4-5: runtime smoke
timeout 40 $G --headless --path $P -- --smoke > /tmp/run.log 2>&1
RC=$?
grep -q "RUN_STARTED" /tmp/run.log && note "PASS RUN_STARTED" || { note "FAIL no RUN_STARTED (rc=$RC)"; FAIL=1; }
grep -q "TEST_PASS" /tmp/run.log && note "PASS TEST_PASS" || { note "FAIL no TEST_PASS (rc=$RC)"; FAIL=1; }
if grep -qE "SCRIPT ERROR|Parse Error|Attempt to call" /tmp/run.log; then
  note "FAIL script errors found:"; grep -E "SCRIPT ERROR|Parse Error|Attempt to call" /tmp/run.log | head -10 | tee -a $LOG; FAIL=1
else
  note "PASS no script errors"
fi
# 6: feature greps
for term in "GOD MODE" "AUTO-LOCK" "MOVES" "head_split" "LEVELS" "FARMLAND" "DOWNTOWN" "stache" "TAUNTS" "board" "PAUSED" "OUTFITS" "WEAPONS" "set_level" "horse_fp" "caption" "flash_red" "lifetime_kills" "S.INTRO" "spawn_drop" "touch_mode" "view_mode" "killcam" "joy_vec" "try_knock" "show_menu" "rider_name" "looktest" "LOOK_OK" "CLICK TO AIM"; do
  if grep -rq "$term" $P/scripts/; then note "PASS grep $term"; else note "FAIL grep $term"; FAIL=1; fi
done
# 7: intro-skip smoke — boot without --smoke must enter INTRO then be skippable into RIDE
timeout 30 $G --headless --path $P -- --introtest > /tmp/intro.log 2>&1
if grep -q "INTRO_OK" /tmp/intro.log; then note "PASS intro smoke"; else note "FAIL intro smoke (see runs log)"; grep -E "SCRIPT ERROR|INTRO" /tmp/intro.log | head -5 | tee -a $LOG; FAIL=1; fi
note "=== RESULT: $([ $FAIL -eq 0 ] && echo ALL_PASS || echo FAILURES) ==="
exit $FAIL
# 8: look test — injected mouse motion must move yaw/pitch
timeout 40 $G --headless --path $P -- --looktest > /tmp/look.log 2>&1
if grep -q "LOOK_OK" /tmp/look.log; then note "PASS look test"; else note "FAIL look test"; grep -E "LOOK|SCRIPT ERROR" /tmp/look.log | head -4 | tee -a $LOG; FAIL=1; fi
