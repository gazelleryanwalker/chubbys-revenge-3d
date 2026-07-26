extends Node3D
## CHUBBY'S REVENGE 3D — game root. Builds world/player/HUD in code, runs state machine.

const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const WorldBuilder = preload("res://scripts/world_builder.gd")
const HudScript = preload("res://scripts/hud.gd")
const IntroScript = preload("res://scripts/intro.gd")
const MusicScript = preload("res://scripts/music.gd")
const Outfits = preload("res://scripts/outfits.gd")
const Models = preload("res://scripts/model_loader.gd")

enum S { MENU, INTRO, RIDE, DEAD, PAUSED }

const LEVELS = ["MAPLE STREET","POPLAR AVE","THE CUL-DE-SAC","COUNTY ROAD 9","THEIR GARAGE",
	"NIGHT SHIFT","THE OVERPASS","NO SLEEP TILL BROOKLYN","MAIN STREET","THEIR TURF"]
const LEVEL_ZONES = [0,0,1,1,2,0,1,2,2,2]
const TAUNTS = ["EAT ASPHALT, FREAK!","CAN'T CATCH US!","OUR STREET NOW, #@$%!","WATCH THIS, LOSER!",
	"SHE'S BACK? BIG DEAL!","CRY ABOUT IT!","NICE KNEE! HA!","WE OWN THIS TOWN!","TOO SLOW, $#@&!","COME GET SOME!"]
const RESIDENTS = ["You're the girl from the news. God help you.","They garage those bikes two streets over.",
	"My nephew rides with them. I'm sorry, kid.","Half this block keeps bats by the door now. Go get 'em.",
	"They laugh about it at the gas station. LAUGH.","Be careful, mija. They run in a pack."]
const TURN_NAMES = ["POPLAR AVE", "CUL-DE-SAC CT", "BARN RD", "MAPLE CT"]

var state: int = S.MENU
var wave := 0
var kills := 0
var city_love := 0.0
var health := 100.0
var god_mode := true
var enemies: Array = []
var between_waves := true
var wave_break := 2.0
var wave_spawned := 0
var wave_killed := 0
var spawn_timer := 0.0
var zone_idx := 0
var lifetime_kills := 0
var rider_name := "BROOKE"   # player identity — shown on the HUD + menu, persisted in save.cfg
var runs_played := 0         # total runs booted (first 3 get instruction cards)
var tp_default := false      # menu toggle: start runs in third person
var outfit := 0
var drops: Array = []
var knock_cd := 0.0
var touch_mode := false      # true on touchscreens (iPhone Safari web export) — HUD builds touch UI
var joy_vec := Vector2.ZERO  # virtual joystick output (-1..1), x = lane dodge target
var turn_offer = null        # null or {"name": String, "t": float} — armed when the intersection is ~3s out
var pending_turn = null      # null or {"name": String, "node": Node3D} — intersection en route, not yet in range
var next_turn_in := randf_range(22.0, 40.0)
var _hint_mode := ""
var _suburb_hint_shown := false  # one-time knock hint per run (first visit to the suburb zone)

var world
var player
var hud
var intro
var music

var _test := false
var _test_t := 0.0
var _test_phase := 0
var _introtest := false
var _introtest_t := 0.0
var _looktest := false
var _looktest_t := 0.0
var _looktest_phase := 0


func _ready() -> void:
	# PAUSE FIX: while get_tree().paused, only PROCESS_MODE_ALWAYS nodes get input —
	# main must stay live or P/ESC/R can never unpause (soft-lock)
	process_mode = PROCESS_MODE_ALWAYS
	_setup_input()
	# touch controls: real touchscreens, incl. the Web export on iPhone Safari
	touch_mode = DisplayServer.is_touchscreen_available() or (OS.has_feature("web") and DisplayServer.is_touchscreen_available())
	if OS.has_environment("CHUBBY_FORCE_TOUCH"):   # test hook: exercise the touch UI path
		touch_mode = OS.get_environment("CHUBBY_FORCE_TOUCH") == "1"
	world = Node3D.new()
	world.set_script(WorldBuilder)
	world.name = "World"
	add_child(world)
	player = CharacterBody3D.new()
	player.set_script(PlayerScript)
	player.name = "Player"
	player.main = self
	add_child(player)
	hud = CanvasLayer.new()
	hud.set_script(HudScript)
	hud.name = "HUD"
	hud.main = self
	add_child(hud)
	load_game()
	music = Node.new()
	music.set_script(MusicScript)
	music.name = "Music"
	add_child(music)
	var args = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if "--smoke" in args:
		_test = true
		print("TEST_MODE: boot ok, starting run")
		start_run()
	elif "--looktest" in args:
		# like --smoke, but verifies mouse-look: injects motion, reads yaw/pitch
		_looktest = true
		print("LOOKTEST: boot ok, starting run")
		start_run()
	elif "--introtest" in args:
		_introtest = true
		_start_intro()
	else:
		# START MENU — name, controls, toggles; RIDE plays the intro, then the run
		state = S.MENU
		hud.show_menu()

func _start_intro() -> void:
	# intro cinematic; it calls start_run() itself at the end
	state = S.INTRO
	intro = Node3D.new()
	intro.set_script(IntroScript)
	intro.name = "Intro"
	intro.main = self
	add_child(intro)
	hud.show_intro()   # hide gameplay chrome over the cinematic + skip prompt

func menu_done() -> void:
	# RIDE pressed on the start menu — save the rider name, play the intro
	if state != S.MENU:
		return
	hud.hide_menu()
	save_game()
	_start_intro()

func toggle_god_mode() -> void:
	god_mode = not god_mode
	save_game()
	hud.sync_menu()

func toggle_tp_default() -> void:
	tp_default = not tp_default
	save_game()   # persist the default next to lifetime_kills/outfit
	hud.sync_menu()

func _setup_input() -> void:
	var binds := {
		"shoot": [MOUSE_BUTTON_LEFT], "brawl": [KEY_F], "jump": [KEY_SPACE],
		"slide": [KEY_SHIFT], "cam": [KEY_C], "transport": [KEY_H],
		"foot": [KEY_V], "knock": [KEY_E], "autolock": [KEY_X], "nvg": [KEY_N],
		"outfit": [KEY_O], "tpview": [KEY_T],
		"dodge_left": [KEY_A], "dodge_right": [KEY_D],
		# dedicated side-street turn keys: Q left / E right (E = knock when no offer is up)
		"turn_left": [KEY_Q],
		# arrow-key aim fallback (trackpads / no mouse): handled in player physics
		"aim_left": [KEY_LEFT], "aim_right": [KEY_RIGHT],
		"aim_up": [KEY_UP], "aim_down": [KEY_DOWN],
	}
	for action in binds:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for b in binds[action]:
			var ev
			if b is int and b < 32:
				ev = InputEventMouseButton.new(); ev.button_index = b
			else:
				ev = InputEventKey.new(); ev.physical_keycode = b
			InputMap.action_add_event(action, ev)

func start_run() -> void:
	wave = 0; kills = 0; city_love = 0; health = 100
	for e in enemies: e.queue_free()
	enemies.clear()
	for d in drops: d.queue_free()
	drops.clear()
	between_waves = true; wave_break = 1.5
	wave_spawned = 0; wave_killed = 0
	zone_idx = 0
	knock_cd = 0.0
	Engine.time_scale = 1.0   # safety: killcam slow-mo never survives a restart
	joy_vec = Vector2.ZERO
	turn_offer = null
	pending_turn = null
	next_turn_in = randf_range(22.0, 40.0)
	_hint_mode = ""
	_suburb_hint_shown = false
	for g in world.slots:
		if g.has_meta("knocked"):
			g.remove_meta("knocked")
	world.apply_zone(0)
	state = S.RIDE
	player.on_run_start()
	hud.hide_menu()
	hud.show_game()
	runs_played += 1
	save_game()
	hud.floater("GOD MODE — SHE CANNOT DIE" if god_mode else "SHE RIDES", Color.GOLD)
	hud.run_instructions(runs_played)
	print("RUN_STARTED")

func start_wave() -> void:
	wave += 1
	wave_spawned = 0; wave_killed = 0
	between_waves = false
	music.set_level(wave)
	zone_idx = LEVEL_ZONES[(wave - 1) % 10] if wave <= 10 else (wave % 3)
	world.apply_zone(zone_idx)
	var label = "LEVEL %d/10 — %s" % [wave, LEVELS[wave-1]] if wave <= 10 else "ENDLESS — WAVE %d" % wave
	hud.floater(label, Color(0.85, 0.9, 1.0), 26)
	print("WAVE_STARTED:", label)
	# boss_spawn: one boss on waves 5 and 10, then every 5th endless wave
	if wave == 5 or wave == 10 or (wave > 10 and wave % 5 == 0):
		spawn_enemy(true)
		hud.floater("⚠ KILLER RIDES THIS LEVEL ⚠", Color(1.0, 0.15, 0.1), 26)
		print("BOSS_SPAWN: wave ", wave)

func spawn_enemy(boss := false) -> void:
	var e = Node3D.new()
	e.set_script(EnemyScript)
	e.main = self
	add_child(e)
	e.setup(boss, wave)
	e.position = Vector3(randf_range(-5.2, 5.2), 0, -150 - randf() * 20)
	enemies.append(e)

func on_enemy_killed(e) -> void:
	kills += 1
	wave_killed += 1
	enemies.erase(e)
	city_love = min(100.0, city_love + (25 if e.boss else 2))
	lifetime_kills += 1
	for o in Outfits.OUTFITS:
		if int(o["kills"]) == lifetime_kills:
			hud.floater("NEW OUTFIT: " + o["n"] + " — PRESS O TO WEAR", Color.GOLD, 26)
			music.sfx("unlock")
	save_game()
	if randf() < 0.12:
		spawn_drop(e.position)
	hud.refresh()

func spawn_drop(pos: Vector3) -> void:
	var ids = ["revolvers", "sawedoff", "nailbat"]
	var id = ids[randi() % ids.size()]
	var d = Node3D.new()
	d.set_meta("weapon", id)
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new(); bm.size = Vector3(0.5, 0.35, 0.5)
	mi.mesh = bm
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(0.1, 0.1, 0.12)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.7, 0.2)
	m.emission_energy_multiplier = 2.5
	mi.material_override = m
	d.add_child(mi)
	var glow = OmniLight3D.new()
	glow.light_color = Color(1.0, 0.7, 0.2); glow.light_energy = 1.2; glow.omni_range = 5
	d.add_child(glow)
	add_child(d)
	d.position = Vector3(pos.x, 1.1, pos.z)
	drops.append(d)

func killcam(boss_pos: Vector3) -> void:
	# BOSS KILL-CAM — slow motion + orbital camera on the death spot
	if state != S.RIDE:
		return
	Engine.time_scale = 0.25
	player.killcam(boss_pos)
	# restore in REAL time (ignore_time_scale=true), restart also resets in start_run
	get_tree().create_timer(1.2, true, false, true).timeout.connect(
		func(): Engine.time_scale = 1.0)

func _set_hint(mode: String, text := "") -> void:
	if mode == _hint_mode:
		return   # don't churn the label every frame (keeps "CLICK TO AIM" stable)
	_hint_mode = mode
	if mode == "":
		hud.clear_hint()
	else:
		hud.hint(text)

func _knock_target():
	# nearest suburb slot group in reach, not yet knocked this run
	if zone_idx != 0 or not player.on_foot or knock_cd > 0.0:
		return null
	var best = null
	var best_d := 999.0
	for g in world.slots:
		if g.has_meta("knocked"):
			continue
		var d = absf(g.position.z)
		if d < 6.0 and d < best_d:
			best_d = d
			best = g
	return best

func try_knock() -> void:
	var g = _knock_target()
	if g == null:
		return
	g.set_meta("knocked", true)
	knock_cd = 12.0
	_set_hint("")
	music.sfx("knock")
	_spawn_resident(g)
	# staggered dialogue, then the reward
	var line = RESIDENTS[randi() % RESIDENTS.size()]
	get_tree().create_timer(0.3).timeout.connect(
		func(): hud.floater("\"" + line + "\"", Color(0.9, 0.9, 1.0), 18))
	var rw = randi() % 3
	get_tree().create_timer(1.8).timeout.connect(func(): _knock_reward(rw))

func _knock_reward(rw: int) -> void:
	# rewards reference REAL stats only (city love / health) — no fake intel/stars
	match rw:
		0:
			city_love = min(100.0, city_love + 10)
			hud.floater("+10 CITY LOVE", Color(1.0, 0.85, 0.4), 22)
		1:
			city_love = min(100.0, city_love + 20)
			hud.floater("+20 CITY LOVE", Color(1.0, 0.85, 0.4), 22)
		_:
			health = minf(100.0, health + 15.0)
			hud.floater("+15 HEALTH", Color(0.5, 1.0, 0.5), 22)
	hud.refresh()

func _spawn_resident(g: Node3D) -> void:
	var side = int(g.get_meta("side"))
	var hx = float(g.get_meta("house_x", side * 20.0))
	var r = Node3D.new()
	add_child(r)
	var model = Models.inst(Models.KAYKIT[randi() % Models.KAYKIT.size()])
	if model == null:
		r.queue_free()
		return
	Models.fit_height(model, 1.65)
	r.add_child(model)
	r.position = Vector3(hx - side * 4.0, 0, g.position.z + 1.5)
	r.look_at(player.global_position * Vector3(1, 0, 1), Vector3.UP)
	Models.play_anim(model, ["idle", "stand"])
	get_tree().create_timer(8.0).timeout.connect(r.queue_free)

func take_turn(dir: int) -> void:
	if turn_offer == null:
		return
	hud.floater("TURNED ONTO " + turn_offer["name"], Color(0.6, 1.0, 0.6), 22)
	player.turn_swing(dir)
	world.apply_zone(randi() % world.ZONES.size())
	turn_offer = null
	_set_hint("")
	next_turn_in = randf_range(22.0, 40.0)

func save_game() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("meta", "lifetime_kills", lifetime_kills)
	cfg.set_value("meta", "rider_name", rider_name)
	cfg.set_value("meta", "runs_played", runs_played)
	cfg.set_value("meta", "outfit", outfit)
	cfg.set_value("meta", "god_mode", god_mode)
	cfg.set_value("meta", "tp_default", tp_default)
	cfg.save("user://save.cfg")

func load_game() -> void:
	var cfg = ConfigFile.new()
	if cfg.load("user://save.cfg") == OK:
		lifetime_kills = int(cfg.get_value("meta", "lifetime_kills", 0))
		rider_name = str(cfg.get_value("meta", "rider_name", "BROOKE"))
		runs_played = int(cfg.get_value("meta", "runs_played", 0))
		outfit = int(cfg.get_value("meta", "outfit", 0))
		god_mode = bool(cfg.get_value("meta", "god_mode", true))
		tp_default = bool(cfg.get_value("meta", "tp_default", false))
	outfit = clampi(outfit, 0, Outfits.OUTFITS.size() - 1)
	if int(Outfits.OUTFITS[outfit]["kills"]) > lifetime_kills:
		outfit = 0   # saved outfit not actually unlocked

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()

func on_player_rammed(dmg: float) -> void:
	# RAM FEEDBACK — red flash + heavy camera shake + thud on every hit
	hud.flash_red()
	player.shake = maxf(player.shake, 14.0)
	music.sfx("ram")
	if god_mode:
		hud.floater("UNBREAKABLE", Color.GOLD, 18)
	else:
		health -= dmg
		if health <= 0:
			state = S.DEAD
			hud.show_dead(kills, wave)
	hud.refresh()

func toggle_pause() -> void:
	if state == S.RIDE:
		state = S.PAUSED
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # release aim lock while paused
		hud.show_pause()
	elif state == S.PAUSED:
		state = S.RIDE
		get_tree().paused = false
		if not touch_mode:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		hud.hide_pause()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_P or event.physical_keycode == KEY_ESCAPE:
			toggle_pause()
		elif event.physical_keycode == KEY_R and (state == S.DEAD or state == S.PAUSED):
			# R — RESTART works from the death screen AND the pause menu
			get_tree().paused = false
			hud.hide_pause()
			start_run()
		elif event.physical_keycode == KEY_M and state == S.DEAD:
			# M — MENU: escape the death dead-end; per-run vars reset on next start_run
			state = S.MENU
			hud.show_menu()

func _process(delta: float) -> void:
	if _looktest:
		_looktest_t += delta
		if _looktest_phase == 0 and _looktest_t > 0.3:
			# inject two right-and-up mouse motions, as if the player dragged the mouse
			for i in 2:
				var ev = InputEventMouseMotion.new()
				ev.relative = Vector2(200, -50)
				Input.parse_input_event(ev)
			_looktest_phase = 1
		elif _looktest_phase == 1 and _looktest_t > 0.8:
			# code subtracts relative*dSens: mouse right -> yaw drops; up -> pitch rises
			var y = player.yaw
			var p = player.pitch
			if y < -0.15 and p > 0.05:
				print("LOOK_OK: yaw=%.3f pitch=%.3f" % [y, p])
				get_tree().quit(0)
			else:
				print("LOOK_FAIL: yaw=%.3f pitch=%.3f" % [y, p])
				get_tree().quit(1)
		return
	if _introtest:
		_introtest_t += delta
		if _introtest_t > 1.5 and state == S.INTRO and is_instance_valid(intro):
			intro._skip()
			_introtest_t = -99.0   # skip requested; await result below
		elif state == S.RIDE:
			print("INTRO_OK: skip transitioned to RIDE")
			get_tree().quit(0)
		elif _introtest_t > 10:
			print("INTRO_FAIL: never reached RIDE (state=%d)" % state)
			get_tree().quit(1)
		return
	if state != S.RIDE:
		return
	# ZONE SYNC — world owns the zone (auto-rotates, take_turn randomizes it);
	# main.zone_idx is a mirror, refreshed every frame for knock gating + HUD
	zone_idx = world.zone_idx
	# one-time knock discovery hint, first suburb visit of the run
	if not _suburb_hint_shown and world.zone_idx == 0:
		_suburb_hint_shown = true
		hud.floater("DISMOUNT TO KNOCK ON DOORS" if touch_mode else "V — DISMOUNT TO KNOCK ON DOORS",
			Color(0.75, 0.95, 0.75), 18, 3.0)
	if between_waves:
		wave_break -= delta
		if wave_break <= 0:
			start_wave()
	else:
		var count = 5 + wave * 2
		spawn_timer -= delta
		if wave_spawned < count and enemies.size() < 7 and spawn_timer <= 0:
			wave_spawned += 1
			spawn_timer = 0.7 + randf() * 1.0
			spawn_enemy(false)
		if wave_spawned >= count and enemies.is_empty():
			between_waves = true
			wave_break = 3.5
			hud.floater("WAVE CLEARED", Color(0.4, 1, 0.4), 24)
			music.sfx("waveclear")
	# weapon pickups drift toward her; collected as they reach the bike
	for i in range(drops.size() - 1, -1, -1):
		var d = drops[i]
		d.position.z += world.world_speed * delta
		d.rotation.y += delta * 2.0
		d.position.y = 1.1 + sin(Time.get_ticks_msec() * 0.004 + i * 1.7) * 0.15
		if d.position.z > -6:
			player.set_weapon(d.get_meta("weapon"))
			d.queue_free()
			drops.remove_at(i)
	# door knocks: suburb + on foot + slot in reach (touch-aware hint)
	knock_cd = maxf(0.0, knock_cd - delta)
	if turn_offer == null:
		if _knock_target() != null:
			_set_hint("knock", "KNOCK BUTTON — KNOCK ON THE DOOR" if touch_mode else "E — KNOCK ON THE DOOR")
		else:
			_set_hint("")
	# side streets: intersection spawns on a 22-40s timer ~12s out; the TURN OFFER
	# arms from the intersection's own position (z > -45, ~3s out) so keys match visuals
	if turn_offer != null:
		turn_offer["t"] -= delta
		if turn_offer["t"] <= 0.0:
			turn_offer = null
			_set_hint("")
			next_turn_in = randf_range(22.0, 40.0)
	elif pending_turn != null:
		if not is_instance_valid(pending_turn["node"]):
			pending_turn = null
			next_turn_in = randf_range(22.0, 40.0)
		elif pending_turn["node"].position.z > -45.0:
			turn_offer = {"name": pending_turn["name"], "t": 4.0}
			pending_turn = null
			_set_hint("turn", "◀ FLICK JOYSTICK TO TURN ▶" if touch_mode else "◀ Q TURN LEFT · E TURN RIGHT ▶")
	else:
		next_turn_in -= delta
		if next_turn_in <= 0.0:
			var nm = TURN_NAMES[randi() % TURN_NAMES.size()]
			var g = world.spawn_intersection(nm)
			pending_turn = {"name": nm, "node": g}
	if _test:
		_run_test(delta)

func _run_test(delta: float) -> void:
	_test_t += delta
	if _test_phase == 0 and _test_t > 0.5:
		# force-spawn three enemies close, then verify auto-lock kills them
		for i in 3:
			spawn_enemy(false)
			enemies[-1].position = Vector3(-2 + i * 2, 0, -30 - i * 10)
		_test_phase = 1
		print("TEST: spawned 3 enemies")
	elif _test_phase == 1 and _test_t > 8.0:
		var k = kills
		if k >= 1:
			print("TEST_PASS: auto-lock killed %d enemies, state=%d, wave=%d, health=%s" % [k, state, wave, health])
			get_tree().quit(0)
		else:
			print("TEST_FAIL: no kills after 8s (kills=%d, enemies=%d)" % [k, enemies.size()])
			get_tree().quit(1)
