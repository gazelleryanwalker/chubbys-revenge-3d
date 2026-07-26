extends Node3D
## Intro cinematic: the night she died, the funeral, the grave that couldn't keep her.
## Fully procedural diorama offset at x=+100, driven by a phase timer in _process.
## Any key skips straight to the finish (hands off to main.start_run()).

const Gore = preload("res://scripts/gore.gd")
const Models = preload("res://scripts/model_loader.gd")

const OX := 100.0            # diorama offset from the play area
const SKATE_FROM := -24.0    # girl road path (z)
const SKATE_TO := -9.0

var main
var t := 0.0
var finished := false
var finish_t := 0.0
var _done := false

var cam: Camera3D
var girl: Node3D
var board: Node3D
var girl_head: Node3D
var horse: Node3D
var brows: Array = []
var eyes: Array = []
var nostrils: Array = []
var bikes: Array = []
var grave: Node3D
var hand: MeshInstance3D
var mound: MeshInstance3D

var did_impact := false
var did_funeral := false
var did_rise := false
var did_rose := false
var did_closeup := false
var did_mercy := false
var did_title := false

func _mat(c: Color, rough := 0.7, metal := 0.0, emis := Color.BLACK, e := 0.0) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = c; m.roughness = rough; m.metalness = metal
	m.emission_enabled = e > 0; m.emission_energy_multiplier = e
	return m

func _ready() -> void:
	_build_road()
	_build_girl()
	_build_board()
	_build_bikes()
	_build_graveyard()
	_build_horse()
	# cinematic camera takes over; player cam is restored on finish
	cam = Camera3D.new()
	cam.fov = 58
	add_child(cam)
	cam.current = true
	main.hud.caption("11:47 PM. She was just skating home.")

func _build_road() -> void:
	var road = MeshInstance3D.new()
	var pm = PlaneMesh.new(); pm.size = Vector2(7, 50)
	road.mesh = pm
	road.material_override = _mat(Color(0.09, 0.09, 0.11), 0.6, 0.15)
	road.position = Vector3(OX, 0.02, -12)
	add_child(road)
	var line = MeshInstance3D.new()
	var lm = PlaneMesh.new(); lm.size = Vector2(0.12, 50)
	line.mesh = lm
	line.material_override = _mat(Color(0.4, 0.35, 0.1), 0.5, 0.0, Color(0.8, 0.7, 0.2), 0.4)
	line.position = Vector3(OX, 0.03, -12)
	add_child(line)
	# cold street light over the road
	var lamp = OmniLight3D.new()
	lamp.light_color = Color(0.7, 0.8, 1.0); lamp.light_energy = 2.2; lamp.omni_range = 22
	lamp.position = Vector3(OX + 3, 6, -14)
	add_child(lamp)

func _build_girl() -> void:
	girl = Node3D.new()
	girl.position = Vector3(OX, 0, SKATE_FROM)
	add_child(girl)
	var head_y := 1.45
	var model = Models.inst("res://assets/characters/girl.glb")
	if model != null:
		# REAL GIRL — rigged Kenney skater, skating home
		Models.fit_height(model, 1.55)
		girl.add_child(model)
		Models.play_anim(model, ["skate", "drive", "sprint", "run", "walk", "idle"])
		var ga = Models.combined_aabb(model)
		if ga.size.y > 0.01:
			head_y = ga.position.y + ga.size.y - 0.12
	else:
		# fallback silhouette — white dress, the one she was buried in
		var body = MeshInstance3D.new()
		body.mesh = CapsuleMesh.new(); body.mesh.radius = 0.22; body.mesh.height = 1.15
		body.material_override = _mat(Color(0.9, 0.88, 0.86), 0.85)
		body.position = Vector3(0, 0.9, 0)
		girl.add_child(body)
	# face anchor on her head (rig head node if exposed, else measured head height)
	var anchor = Node3D.new()
	var head_node = Models.find_named(model, "head") if model != null else null
	if head_node != null:
		head_node.add_child(anchor)
		var hs = head_node.global_transform.basis.get_scale()
		if hs.x > 0.001:
			anchor.scale = Vector3.ONE / hs
	else:
		girl.add_child(anchor)
		anchor.position = Vector3(0, head_y, 0)
	girl_head = anchor
	var skin = _mat(Color(0.85, 0.7, 0.6), 0.8)
	# face (faces +z): eyes, brows, nostrils — animated in the close-up
	for i in [-1, 1]:
		var eye = MeshInstance3D.new()
		eye.mesh = SphereMesh.new(); eye.mesh.radius = 0.026; eye.mesh.height = 0.052
		eye.material_override = _mat(Color(0.08, 0.08, 0.1), 0.4)
		eye.position = Vector3(i * 0.06, 0.03, 0.15)
		anchor.add_child(eye)
		eyes.append(eye)
		var brow = MeshInstance3D.new()
		brow.mesh = BoxMesh.new(); brow.mesh.size = Vector3(0.065, 0.016, 0.02)
		brow.material_override = _mat(Color(0.1, 0.07, 0.04), 0.9)
		brow.position = Vector3(i * 0.06, 0.085, 0.15)
		anchor.add_child(brow)
		brows.append(brow)
		var nos = MeshInstance3D.new()
		nos.mesh = SphereMesh.new(); nos.mesh.radius = 0.013; nos.mesh.height = 0.026
		nos.material_override = skin
		nos.position = Vector3(i * 0.024, -0.045, 0.16)
		anchor.add_child(nos)
		nostrils.append(nos)

func _build_board() -> void:
	board = Node3D.new()
	board.position = Vector3(OX, 0, SKATE_FROM)
	add_child(board)
	var deck = MeshInstance3D.new()
	deck.mesh = BoxMesh.new(); deck.mesh.size = Vector3(0.45, 0.04, 1.1)
	deck.material_override = _mat(Color(0.2, 0.12, 0.06), 0.7)
	deck.position = Vector3(0, 0.1, 0)
	board.add_child(deck)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var w = MeshInstance3D.new()
			w.mesh = CylinderMesh.new(); w.mesh.top_radius = 0.05; w.mesh.bottom_radius = 0.05
			w.mesh.height = 0.05; w.mesh.radial_segments = 10
			w.material_override = _mat(Color(0.75, 0.72, 0.6), 0.6)
			w.rotation_degrees.z = 90
			w.position = Vector3(sx * 0.18, 0.05, sz * 0.4)
			board.add_child(w)

func _build_bikes() -> void:
	for i in 2:
		var b = Node3D.new()
		b.position = Vector3(OX - 1.5 + i * 3.0, 0, -42)
		add_child(b)
		# REAL BIKES — two motorcycles with boy riders out of the dark
		var moto = Models.inst("res://assets/vehicles/motorcycle.glb")
		if moto != null:
			Models.fit_height(moto, 1.4)
			Models.align_long_axis_z(moto)
			b.add_child(moto)
		var br = Models.inst("res://assets/characters/boy.glb")
		if br != null:
			Models.fit_height(br, 1.25)
			br.position = Vector3(0, 0.5, -0.1)
			b.add_child(br)
			if not Models.play_anim(br, ["sit_chair_idle", "sit", "drive", "ride"]):
				Models.play_anim(br, ["idle"])
		# headlight stabbing through the dark
		var lamp = OmniLight3D.new()
		lamp.light_color = Color(1, 0.95, 0.7); lamp.light_energy = 1.6; lamp.omni_range = 9
		lamp.position = Vector3(0, 0.8, 0.8)
		b.add_child(lamp)
		b.rotation.y = PI   # they ride toward +z, at her
		bikes.append(b)

func _build_graveyard() -> void:
	grave = Node3D.new()
	grave.position = Vector3(OX + 9, 0, -2)
	grave.visible = false
	add_child(grave)
	var dirt = _mat(Color(0.23, 0.16, 0.10), 1.0)
	var stone = _mat(Color(0.45, 0.46, 0.5), 0.85)
	# tombstone: box + rounded top
	var ts = MeshInstance3D.new()
	ts.mesh = BoxMesh.new(); ts.mesh.size = Vector3(0.9, 1.3, 0.22)
	ts.material_override = stone
	ts.position = Vector3(0, 0.65, 0)
	grave.add_child(ts)
	var top = MeshInstance3D.new()
	top.mesh = SphereMesh.new(); top.mesh.radius = 0.45; top.mesh.height = 0.9
	top.mesh.radial_segments = 16; top.mesh.rings = 8
	top.mesh.is_hemisphere = true
	top.material_override = stone
	top.position = Vector3(0, 1.3, 0)
	top.scale = Vector3(1, 0.8, 0.245)
	grave.add_child(top)
	# fresh dirt mound
	mound = MeshInstance3D.new()
	mound.mesh = SphereMesh.new(); mound.mesh.radius = 1.0; mound.mesh.height = 2.0
	mound.material_override = dirt
	mound.scale = Vector3(1.1, 0.3, 1.7)
	mound.position = Vector3(0, 0.05, 2.2)
	grave.add_child(mound)
	# the hand, waiting below
	hand = MeshInstance3D.new()
	hand.mesh = CapsuleMesh.new(); hand.mesh.radius = 0.07; hand.mesh.height = 0.5
	hand.material_override = _mat(Color(0.72, 0.6, 0.5), 0.9)
	hand.position = Vector3(0, -0.7, 2.2)
	grave.add_child(hand)
	# five mourners — real KayKit townsfolk, idle, heads bowed
	for i in 5:
		var mo = Models.inst(Models.KAYKIT[i % Models.KAYKIT.size()])
		if mo == null:
			continue
		Models.fit_height(mo, 1.6)
		mo.position = Vector3(-1.9 + (i % 3) * 1.9, 0, 3.4 + (i / 3) * 1.4)
		mo.rotation.y = PI          # facing the stone
		mo.rotation.x = 0.16        # bowed
		grave.add_child(mo)
		Models.play_anim(mo, ["idle", "stand"])
	# grave-side candle glow
	var gl = OmniLight3D.new()
	gl.light_color = Color(1, 0.7, 0.35); gl.light_energy = 1.4; gl.omni_range = 8
	gl.position = Vector3(0.8, 0.4, 1.2)
	grave.add_child(gl)

func _build_horse() -> void:
	# WHITE HORSE — walks in while she rises
	horse = Node3D.new()
	horse.position = Vector3(OX + 17, 0, 9)
	horse.rotation.y = -PI * 0.75   # angled in from the east, toward the grave
	horse.visible = false
	add_child(horse)
	var hm = Models.inst("res://assets/animals/horse.glb")
	if hm != null:
		Models.fit_height(hm, 1.9)
		horse.add_child(hm)

func _dirt_burst(at: Vector3) -> void:
	# gore.chunks, recolored to fresh grave dirt
	var before = get_child_count()
	Gore.chunks(self, at, 10)
	for i in range(before, get_child_count()):
		var rb = get_child(i)
		if rb is RigidBody3D:
			for c in rb.get_children():
				if c is MeshInstance3D:
					c.material_override = _mat(Color(0.23, 0.16, 0.10), 1.0)

func _impact() -> void:
	did_impact = true
	grave.visible = true
	main.hud.caption("Two dirt bikes. No plates.")
	main.hud.floater("THEY NEVER BRAKED", Color(0.9, 0.05, 0.05), 44)
	main.hud.flash_red()
	Models.play_anim(girl, ["die", "death", "fall", "hit"], false)
	# she is flung off the board
	var tw = create_tween()
	tw.tween_property(girl, "position:y", 2.4, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(girl, "position:y", 0.15, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var tw2 = create_tween()
	tw2.tween_property(girl, "rotation:x", -2.3, 0.7)

func _rise() -> void:
	did_rise = true
	main.hud.caption("But the grave would not keep her.")
	# the white horse walks in out of the night
	horse.visible = true
	Models.play_anim(horse, ["walk", "idle"])
	var htw = create_tween()
	htw.tween_property(horse, "position", Vector3(OX + 12, 0, 5.5), 4.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# a hand punches up through the fresh dirt
	var hp = hand.global_position + Vector3(0, 1.0, 0)
	var tw = create_tween()
	tw.tween_property(hand, "position:y", 0.35, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_dirt_burst(hp)

func _rose() -> void:
	did_rose = true
	main.hud.caption("SHE ROSE.")
	# she stands again on her own grave
	girl.rotation = Vector3.ZERO
	girl.position = grave.position + Vector3(0, -1.7, 2.2)
	girl.visible = true
	Models.play_anim(girl, ["idle", "stand"])
	var tw = create_tween()
	tw.tween_property(girl, "position:y", grave.position.y, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _title() -> void:
	did_title = true
	main.hud.caption("CHUBBY'S REVENGE")
	main.hud.fade_to(1.0, 1.2)
	finished = true
	finish_t = 1.6

func _skip() -> void:
	if finished:
		return
	finished = true
	finish_t = 0.05

func _do_finish() -> void:
	if _done:
		return
	_done = true
	main.hud.caption("")
	main.hud.fade_to(0.0, 0.8)
	main.player.cam.current = true
	main.start_run()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if finished:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_skip()
	elif event is InputEventScreenTouch and event.pressed:
		_skip()   # touch screens (no keyboard) skip with a tap

func _process(delta: float) -> void:
	if finished:
		finish_t -= delta
		if finish_t <= 0.0:
			_do_finish()
		return
	t += delta
	# timed beats
	if t >= 6.0 and not did_impact:
		_impact()
	if t >= 7.0 and not did_funeral:
		did_funeral = true
		girl.visible = false
		main.hud.caption("They buried her on a Tuesday. Nobody was charged.")
	if t >= 12.0 and not did_rise:
		_rise()
	if t >= 15.0 and not did_rose:
		_rose()
	if t >= 20.0 and not did_closeup:
		did_closeup = true
		main.hud.caption("")
	if t >= 24.0 and not did_mercy:
		did_mercy = true
		main.hud.caption("NO MERCY.")
	if t >= 25.0 and not did_title:
		_title()
	# bikes sweep through her after the impact cue
	if did_impact:
		var bp = clampf((t - 6.0) / 1.3, 0.0, 1.0)
		for i in bikes.size():
			bikes[i].position.z = lerp(-42.0, 14.0, bp)
	# camera work per phase
	if t < 6.0:
		# she skates home down the road strip
		girl.position.z = lerp(SKATE_FROM, SKATE_TO, t / 6.0)
		girl.position.y = 0.12 + absf(sin(t * 5.0)) * 0.04
		board.position.z = girl.position.z
		cam.position = Vector3(OX + 1.2, 2.0, girl.position.z + 5.5)
		cam.look_at(girl.position + Vector3(0, 1.2, 0), Vector3.UP)
	elif t < 7.0:
		cam.position = Vector3(OX + 2.5, 2.4, SKATE_TO + 6.5)
		cam.look_at(Vector3(OX, 1.0, SKATE_TO), Vector3.UP)
	elif t < 12.0:
		# funeral: mourners around the stone
		cam.position = Vector3(OX + 5.5, 2.6, 4.5)
		cam.look_at(grave.position + Vector3(0, 1.0, 0.5), Vector3.UP)
	elif t < 20.0:
		# the grave that would not keep her
		cam.position = Vector3(OX + 5.2, 2.1, 4.2)
		cam.look_at(grave.position + Vector3(0, 0.5, 2.0), Vector3.UP)
	else:
		# dolly into her face: 3m -> 0.85m
		var p = clampf((t - 20.0) / 5.0, 0.0, 1.0)
		var face = girl_head.global_position
		cam.position = face + Vector3(0.05, 0.03, lerp(3.0, 0.85, p))
		cam.look_at(face, Vector3.UP)
		# the anger settles in: brows down, eyes narrow, nostrils flare
		var f = clampf((t - 20.0) / 2.0, 0.0, 1.0)
		brows[0].rotation.z = lerp(0.0, -0.5, f)
		brows[1].rotation.z = lerp(0.0, 0.5, f)
		for e2 in eyes:
			e2.scale.y = lerp(1.0, 0.35, f)
		var flare = 1.0 + 0.8 * f * (0.5 + 0.5 * sin(t * 9.0))
		for n2 in nostrils:
			n2.scale = Vector3.ONE * flare
