extends CharacterBody3D
## First-person controller: free-look, auto-lock, god-mode damage sink, dodge,
## dismount/on-foot, brawl combos (8 arts), jump/vault/slide/flip, camera presets.

const Gore = preload("res://scripts/gore.gd")
const Outfits = preload("res://scripts/outfits.gd")
const Models = preload("res://scripts/model_loader.gd")

var main

const WEAPONS = {
	"shotgun":   {"n":"SHOTGUN",        "rate":0.55, "dmg":1, "melee":false, "col":Color(0.25, 0.26, 0.30)},
	"revolvers": {"n":"DUAL REVOLVERS", "rate":0.22, "dmg":1, "melee":false, "col":Color(0.72, 0.73, 0.80)},
	"sawedoff":  {"n":"SAWED-OFF",      "rate":0.80, "dmg":3, "melee":false, "col":Color(0.45, 0.30, 0.15)},
	"nailbat":   {"n":"NAIL BAT",       "rate":0.50, "dmg":2, "melee":true,  "col":Color(0.50, 0.36, 0.20)},
}

const GUN_MODELS = {
	"shotgun":   {"path": "res://assets/weapons/shotgun.glb",  "len": 0.7},
	"revolvers": {"path": "res://assets/weapons/revolver.glb", "len": 0.45},
	"sawedoff":  {"path": "res://assets/weapons/sawedoff.glb", "len": 0.45},
	"nailbat":   {"path": "res://assets/weapons/bat.glb",      "len": 0.5},
}

const CAMS = [
	{"n":"CENTER", "x":0.0, "y":0.0}, {"n":"LEFT HIP", "x":-0.95, "y":-0.35},
	{"n":"RIGHT SHOULDER", "x":0.95, "y":0.25}, {"n":"HIGH SADDLE", "x":0.0, "y":0.9},
]
const MOVES = ["JAB CROSS","MUAY THAI KNEE","JUDO THROW — IPPON","GRECO-ROMAN SUPLEX",
	"KARATE SPIN BACKFIST","BJJ ARM BAR SNAP","WRESTLING DOUBLE-LEG SLAM","CQC THROAT STRIKE"]

var yaw := 0.0
var pitch := 0.0
var lane_x := 0.0
var lane_cur := 0.0
var cam_mode := 0
var auto_cam_t := 0.0
var on_foot := false
var auto_lock := true
var auto_fire_t := 0.0
var combo := 0
var combo_t := 0.0
var move_t := 0.0
var move_kind := ""
var gallop := 0.0
var shake := 0.0
var transport := "board"
var weapon := "shotgun"
var weapon_t := 0.0
var outfit_idx := 0
var swing_t := 0.0
var swing_dir := 0

var cam: Camera3D
var gun: Node3D
var board: Node3D
var horse_fp: Node3D
var gun_models: Dictionary = {}
var stock: MeshInstance3D
var hands: Array = []
var chest: MeshInstance3D
var tie: MeshInstance3D
var veil: MeshInstance3D
var muzzle_flash: OmniLight3D
var ray: RayCast3D

func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 72
	cam.current = true
	add_child(cam)
	cam.position = Vector3(0, 2.7, 0)
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -200)
	ray.collision_mask = 2
	ray.collide_with_areas = true
	ray.collide_with_bodies = false
	cam.add_child(ray)
	muzzle_flash = OmniLight3D.new()
	muzzle_flash.light_color = Color(1.0, 0.8, 0.4)
	muzzle_flash.light_energy = 0.0
	muzzle_flash.omni_range = 12
	cam.add_child(muzzle_flash)
	_build_gun()
	_build_board()
	_build_horse()
	_build_outfit()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _mat(color: Color, rough := 0.5, metal := 0.0, emis := Color.BLACK, e := 0.0) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metalness = metal
	m.emission_enabled = e > 0.0
	m.emission = emis
	m.emission_energy_multiplier = e
	return m

func _build_gun() -> void:
	gun = Node3D.new()
	cam.add_child(gun)
	gun.position = Vector3(0.42, -0.42, -0.8)
	# REAL WEAPON MODELS — one per WEAPONS entry, swapped by _recolor_gun
	for id in GUN_MODELS:
		var info: Dictionary = GUN_MODELS[id]
		var m = Models.inst(info["path"])
		if m == null:
			continue
		Models.fit_length(m, info["len"])
		Models.align_long_axis_z(m)   # barrel along z (muzzle -z)
		if id == "nailbat":
			m.rotation.z = 0.6   # held angled
			m.rotation.x = -0.35
		m.visible = false
		gun.add_child(m)
		gun_models[id] = m
	stock = MeshInstance3D.new()
	stock.mesh = BoxMesh.new()
	stock.mesh.size = Vector3(0.07, 0.12, 0.18)
	stock.material_override = _mat(Color(0.35, 0.2, 0.1), 0.7)
	stock.position = Vector3(0, -0.08, 0.18)
	gun.add_child(stock)
	# her hands on the grip — outfit accent recolors these
	for i in [-1, 1]:
		var h = MeshInstance3D.new()
		h.mesh = BoxMesh.new()
		h.mesh.size = Vector3(0.085, 0.09, 0.11)
		h.material_override = _mat(Color(0.227, 0.29, 0.478), 0.8)
		h.position = Vector3(i * 0.05, -0.045, 0.08)
		gun.add_child(h)
		hands.append(h)

func _build_horse() -> void:
	# WHITE HORSE — real rigged model, first-person mount (head/neck fills the view)
	horse_fp = Node3D.new()
	cam.add_child(horse_fp)
	horse_fp.position = Vector3(0, -0.9, -0.9)
	horse_fp.visible = false
	var hm = Models.inst("res://assets/animals/horse.glb")
	if hm != null:
		Models.fit_height(hm, 1.9)
		hm.rotation.y = PI   # head forward, body under her
		hm.position = Vector3(0, -1.75, 1.1)
		horse_fp.add_child(hm)
		Models.play_anim(hm, ["gallop", "walk", "idle"])

func _build_outfit() -> void:
	# chest accent + wick tie + bride veil, all recolored/toggled by apply_outfit
	chest = MeshInstance3D.new()
	chest.mesh = BoxMesh.new(); chest.mesh.size = Vector3(0.46, 0.2, 0.22)
	chest.material_override = _mat(Color(0.227, 0.29, 0.478), 0.6, 0.1, Color(0.227, 0.29, 0.478), 0.3)
	chest.position = Vector3(0, -0.78, -0.5)
	chest.rotation_degrees.x = 12
	cam.add_child(chest)
	tie = MeshInstance3D.new()
	tie.mesh = BoxMesh.new(); tie.mesh.size = Vector3(0.07, 0.2, 0.03)
	tie.material_override = _mat(Color(0.5, 0.03, 0.05), 0.5, 0.2, Color(0.5, 0.03, 0.05), 0.5)
	tie.position = Vector3(0, -0.74, -0.62)
	tie.rotation_degrees.x = 12
	tie.visible = false
	cam.add_child(tie)
	veil = MeshInstance3D.new()
	veil.mesh = PlaneMesh.new(); veil.mesh.size = Vector2(0.75, 0.55)
	var vm = _mat(Color(0.95, 0.93, 0.9, 0.16), 0.9)
	vm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	veil.material_override = vm
	veil.position = Vector3(0, 0.2, -0.42)
	veil.rotation_degrees.x = -28
	veil.visible = false
	cam.add_child(veil)

func _build_board() -> void:
	# LED skateboard — real Kenney deck + her glowing LED strips
	board = Node3D.new()
	cam.add_child(board)
	board.position = Vector3(0, -1.05, -1.1)
	board.rotation_degrees.x = -8
	var deck = Models.inst("res://assets/props/skateboard.glb")
	if deck != null:
		Models.fit_length(deck, 0.8)
		Models.align_long_axis_z(deck)
		board.add_child(deck)
	for i in [-1, 1]:
		var strip = MeshInstance3D.new()
		var sm = BoxMesh.new(); sm.size = Vector3(0.03, 0.035, 0.78)
		strip.mesh = sm
		strip.material_override = _mat(Color.BLACK, 0.3, 0.5, Color(1.0, 0.15, 0.8), 3.0)
		strip.position = Vector3(i * 0.22, 0, 0)
		board.add_child(strip)
	var glow = OmniLight3D.new()
	glow.light_color = Color(0.5, 0.3, 1.0)
	glow.light_energy = 1.6
	glow.omni_range = 5
	glow.position = Vector3(0, -0.3, 0)
	board.add_child(glow)

func on_run_start() -> void:
	yaw = 0; pitch = 0; lane_x = 0; lane_cur = 0; combo = 0
	on_foot = false
	transport = "board"
	weapon = "shotgun"
	weapon_t = 0.0
	_recolor_gun()
	_update_transport_vis()
	apply_outfit(main.outfit)

func _update_transport_vis() -> void:
	board.visible = not on_foot and transport == "board"
	horse_fp.visible = not on_foot and transport == "horse"

func toggle_transport() -> void:
	transport = "horse" if transport == "board" else "board"
	_update_transport_vis()
	main.hud.floater("WHITE HORSE" if transport == "horse" else "LED DECK", Color(0.8, 0.85, 1.0), 20)

func apply_outfit(idx: int) -> void:
	outfit_idx = clampi(idx, 0, Outfits.OUTFITS.size() - 1)
	var o = Outfits.OUTFITS[outfit_idx]
	var ac: Color = o["accent"]
	stock.material_override = _mat(ac, 0.7)
	for h in hands:
		h.material_override = _mat(ac.lightened(0.15), 0.8)
	chest.material_override = _mat(ac, 0.6, 0.1, ac, 0.35)
	tie.visible = o["tie"]
	veil.visible = o["veil"]

func cycle_outfit() -> void:
	var list = Outfits.unlocked_list(main.lifetime_kills)
	if list.is_empty():
		return
	var pos = (list.find(outfit_idx) + 1) % list.size()
	var idx: int = list[pos]
	main.outfit = idx
	apply_outfit(idx)
	main.save_game()
	main.hud.floater("OUTFIT: " + Outfits.OUTFITS[idx]["n"], Color(1, 0.85, 0.5), 20)
	main.hud.refresh()

func _recolor_gun() -> void:
	# weapon switching = model swap (WEAPONS rates/melee logic unchanged)
	for id in gun_models:
		gun_models[id].visible = (id == weapon)

func set_weapon(id: String) -> void:
	weapon = id
	weapon_t = 25.0
	_recolor_gun()
	main.hud.floater(WEAPONS[id]["n"] + " PICKED UP", Color(1, 0.8, 0.3), 24)
	main.hud.refresh()

func _unhandled_input(event: InputEvent) -> void:
	if main.state != main.S.RIDE:
		return
	if event is InputEventMouseMotion:
		yaw = clampf(yaw - event.relative.x * 0.0026, -1.15, 1.15)
		pitch = clampf(pitch - event.relative.y * 0.0022, -0.45, 0.5)
	if event.is_action_pressed("shoot") and not on_foot:
		shoot()
	elif event.is_action_pressed("jump"):
		do_jump()
	elif event.is_action_pressed("slide"):
		do_slide()
	elif event.is_action_pressed("brawl"):
		brawl_strike()
	elif event.is_action_pressed("foot"):
		toggle_foot()
	elif event.is_action_pressed("transport"):
		toggle_transport()
	elif event.is_action_pressed("outfit"):
		cycle_outfit()
	elif event.is_action_pressed("cam"):
		cam_mode = (cam_mode + 1) % CAMS.size()
		auto_cam_t = 0.0
		main.hud.floater("CAM: " + CAMS[cam_mode]["n"], Color(0.6, 0.9, 1), 14)
	elif event.is_action_pressed("autolock"):
		auto_lock = not auto_lock
		main.hud.floater("AUTO-LOCK ON" if auto_lock else "AUTO-LOCK OFF", Color.GOLD, 16)
	elif event.is_action_pressed("knock"):
		main.try_knock()
	elif event.is_action_pressed("dodge_left"):
		if main.turn_offer != null:
			main.take_turn(-1)
		else:
			lane_x = clampf(lane_x - 2.4, -4.6, 4.6)
	elif event.is_action_pressed("dodge_right"):
		if main.turn_offer != null:
			main.take_turn(1)
		else:
			lane_x = clampf(lane_x + 2.4, -4.6, 4.6)

func shoot() -> void:
	muzzle_flash.light_energy = 6.0
	shake = max(shake, 5)
	var w = WEAPONS[weapon]
	if w["melee"]:
		# NAIL BAT — close-range swing, only connects up close (z > -25)
		var best = null
		var best_z := -999.0
		for e in main.enemies:
			if e.position.z > -25 and e.position.z > best_z:
				best_z = e.position.z
				best = e
		if best:
			main.hud.floater("CRACK", Color(1, 0.6, 0.3), 22)
			best.take_damage(w["dmg"], best.global_position + Vector3(0, 1.2, 0))
		return
	ray.force_raycast_update()
	if ray.is_colliding():
		var e = ray.get_collider().get_meta("enemy", null)
		if e:
			e.take_damage(w["dmg"], ray.get_collision_point())

func turn_swing(dir: int) -> void:
	# 0.8s camera yaw swing for side-street turns (offset eased out and back)
	swing_t = 0.8
	swing_dir = dir

func do_jump() -> void:
	if move_t > 0: return
	move_kind = "jump"; move_t = 0.55

func do_slide() -> void:
	if move_t > 0 or not on_foot: return
	move_kind = "slide"; move_t = 0.5
	main.hud.floater("SLIDE", Color(0.6, 0.9, 1), 16)

func toggle_foot() -> void:
	on_foot = not on_foot
	_update_transport_vis()   # on foot hides board AND horse; remount restores the active one
	main.hud.floater("ON FOOT — F FOR 8 ARTS" if on_foot else "BACK ON THE DECK", Color(1, 0.62, 0.77), 18)

func brawl_strike() -> void:
	if not on_foot:
		# mounted melee = same as a shot for v0.1
		shoot()
		return
	var best = null
	var best_z := -999.0
	for e in main.enemies:
		if e.position.z > best_z and e.position.z > -18:
			best_z = e.position.z
			best = e
	if not best:
		return
	var move = MOVES[combo % MOVES.size()]
	combo += 1
	combo_t = 2.2
	main.hud.floater(move + (" x%d" % combo if combo >= 2 else ""), Color(1, 0.82, 0.5), 22)
	shake = max(shake, 6)
	best.take_damage(2, best.global_position + Vector3(0, 1.2, 0))

func _physics_process(delta: float) -> void:
	if main.state != main.S.RIDE:
		return
	gallop += delta
	muzzle_flash.light_energy = max(0.0, muzzle_flash.light_energy - delta * 40)
	shake = max(0.0, shake - delta * 26)
	combo_t = max(0.0, combo_t - delta)
	if combo_t <= 0: combo = 0
	move_t = max(0.0, move_t - delta)
	# picked-up weapons expire back to the shotgun
	if weapon != "shotgun":
		weapon_t -= delta
		if weapon_t <= 0:
			weapon = "shotgun"
			_recolor_gun()
			main.hud.floater("BACK TO THE SHOTGUN", Color(0.8, 0.8, 0.9), 16)
			main.hud.refresh()
	# horse bob on top of the shared gallop feel
	if horse_fp.visible:
		horse_fp.position.y = -0.9 + sin(gallop * 9.0) * 0.05
	# auto-cam
	auto_cam_t += delta
	if auto_cam_t > 9.0:
		auto_cam_t = 0.0
		var n = cam_mode
		while n == cam_mode: n = randi() % CAMS.size()
		cam_mode = n
		main.hud.floater("CAM: " + CAMS[n]["n"], Color(0.6, 0.9, 1), 12)
	# auto-lock aim
	auto_fire_t = max(0.0, auto_fire_t - delta)
	if auto_lock and not main.enemies.is_empty():
		var tgt = null
		var tz := -999.0
		for e in main.enemies:
			if e.position.z < -2 and e.position.z > tz:
				tz = e.position.z; tgt = e
		if tgt:
			var tp = tgt.global_position + Vector3(0, 1.2, 0)
			var d = tp - cam.global_position
			var want_yaw = clampf(atan2(-d.x, -d.z), -1.15, 1.15)
			var want_pitch = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -0.45, 0.5)
			yaw += (want_yaw - yaw) * min(1.0, delta * 7)
			pitch += (want_pitch - pitch) * min(1.0, delta * 7)
			if abs(want_yaw - yaw) < 0.09 and abs(want_pitch - pitch) < 0.12 and auto_fire_t <= 0:
				shoot()
				auto_fire_t = WEAPONS[weapon]["rate"]
	# camera
	lane_cur += (lane_x - lane_cur) * min(1.0, delta * 9)
	var base_h = 1.62 if on_foot else 2.7
	var bob = sin(gallop * 6.2) * (0.03 if on_foot else 0.06)
	var co = CAMS[cam_mode]
	var cy = base_h + bob + co["y"]
	if move_kind == "jump" and move_t > 0:
		cy += sin((1.0 - move_t / 0.55) * PI) * 0.9
	elif move_kind == "slide" and move_t > 0:
		cy = lerp(cy, 0.8, sin((1.0 - move_t / 0.5) * PI))
	cam.position = Vector3(lane_cur + co["x"], cy, 0)
	if shake > 0:
		cam.position.x += randf_range(-1, 1) * shake * 0.02
		cam.position.y += randf_range(-1, 1) * shake * 0.02
	# side-street turn swing: temporary yaw offset, out and back over 0.8s
	swing_t = maxf(0.0, swing_t - delta)
	var swing_off := 0.0
	if swing_t > 0.0:
		swing_off = sin((1.0 - swing_t / 0.8) * PI) * 1.2 * float(swing_dir)
	cam.rotation = Vector3(pitch + sin(gallop * 3.1) * 0.01, yaw + swing_off, 0)
