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
var outfit := 0
var drops: Array = []
var knock_cd := 0.0
var turn_offer = null        # null or {"name": String, "t": float}
var next_turn_in := randf_range(22.0, 40.0)
var _hint_mode := ""

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

func _ready() -> void:
	_setup_input()
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
	else:
		# intro cinematic first; it calls start_run() itself at the end
		state = S.INTRO
		intro = Node3D.new()
		intro.set_script(IntroScript)
		intro.name = "Intro"
		intro.main = self
		add_child(intro)
		if "--introtest" in args:
			_introtest = true

func _setup_input() -> void:
	var binds := {
		"shoot": [MOUSE_BUTTON_LEFT], "brawl": [KEY_F], "jump": [KEY_SPACE],
		"slide": [KEY_SHIFT], "cam": [KEY_C], "transport": [KEY_H],
		"foot": [KEY_V], "knock": [KEY_E], "autolock": [KEY_X], "nvg": [KEY_N],
		"outfit": [KEY_O],
		"dodge_left": [KEY_A], "dodge_right": [KEY_D],
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
	turn_offer = null
	next_turn_in = randf_range(22.0, 40.0)
	_hint_mode = ""
	for g in world.slots:
		if g.has_meta("knocked"):
			g.remove_meta("knocked")
	world.apply_zone(0)
	state = S.RIDE
	player.on_run_start()
	hud.show_game()
	hud.floater("GOD MODE — SHE CANNOT DIE" if god_mode else "SHE RIDES", Color.GOLD)
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
			hud.floater("NEW OUTFIT: " + o["n"], Color.GOLD, 26)
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

func _set_hint(mode: String, text := "") -> void:
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
	_spawn_resident(g)
	# staggered dialogue, then the reward
	var line = RESIDENTS[randi() % RESIDENTS.size()]
	get_tree().create_timer(0.3).timeout.connect(
		func(): hud.floater("\"" + line + "\"", Color(0.9, 0.9, 1.0), 18))
	var rw = randi() % 3
	get_tree().create_timer(1.8).timeout.connect(func(): _knock_reward(rw))

func _knock_reward(rw: int) -> void:
	match rw:
		0:
			hud.floater("+1 INTEL", Color(0.6, 0.9, 1.0), 22)
		1:
			city_love = min(100.0, city_love + 20)
			hud.floater("+20 CITY LOVE", Color(1.0, 0.85, 0.4), 22)
		_:
			city_love = min(100.0, city_love + 10)   # "+2 STARS" folded into city love
			hud.floater("+2 STARS", Color.GOLD, 22)
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
	cfg.set_value("meta", "outfit", outfit)
	cfg.set_value("meta", "god_mode", god_mode)
	cfg.save("user://save.cfg")

func load_game() -> void:
	var cfg = ConfigFile.new()
	if cfg.load("user://save.cfg") == OK:
		lifetime_kills = int(cfg.get_value("meta", "lifetime_kills", 0))
		outfit = int(cfg.get_value("meta", "outfit", 0))
		god_mode = bool(cfg.get_value("meta", "god_mode", true))
	outfit = clampi(outfit, 0, Outfits.OUTFITS.size() - 1)
	if int(Outfits.OUTFITS[outfit]["kills"]) > lifetime_kills:
		outfit = 0   # saved outfit not actually unlocked

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()

func on_player_rammed(dmg: float) -> void:
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
		hud.show_pause()
	elif state == S.PAUSED:
		state = S.RIDE
		get_tree().paused = false
		hud.hide_pause()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_P or event.physical_keycode == KEY_ESCAPE:
			toggle_pause()
		elif event.physical_keycode == KEY_R and state == S.DEAD:
			get_tree().paused = false
			start_run()

func _process(delta: float) -> void:
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
	# door knocks: suburb + on foot + slot in reach
	knock_cd = maxf(0.0, knock_cd - delta)
	if turn_offer == null:
		if _knock_target() != null:
			_set_hint("knock", "E — KNOCK ON THE DOOR")
		else:
			_set_hint("")
	# side streets: intersection offer every 22-40s
	if turn_offer != null:
		turn_offer["t"] -= delta
		if turn_offer["t"] <= 0.0:
			turn_offer = null
			_set_hint("")
			next_turn_in = randf_range(22.0, 40.0)
	else:
		next_turn_in -= delta
		if next_turn_in <= 0.0:
			var nm = TURN_NAMES[randi() % TURN_NAMES.size()]
			world.spawn_intersection(nm)
			turn_offer = {"name": nm, "t": 4.0}
			_set_hint("turn", "◀ A TURN LEFT · D TURN RIGHT ▶")
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
