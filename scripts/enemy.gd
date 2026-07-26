extends Node3D
## WheeliePunk: real motorcycle + rigged KayKit rider doing a permanent wheelie.
## Approaches, taunts, brawls on foot, rams. Dies in gore (head split via gore.gd).

const Gore = preload("res://scripts/gore.gd")
const Models = preload("res://scripts/model_loader.gd")

var main
var boss := false
var hp := 1
var speed := 7.5
var weave_phase := 0.0
var weave_amp := 1.5
var base_x := 0.0
var taunted := false
var hitbox: Area3D
var head: Marker3D
var rider: Node3D
var bike: Node3D
var stache: MeshInstance3D
var alive := true

func setup(p_boss: bool, wave: int) -> void:
	boss = p_boss
	hp = 16 if boss else (2 if wave >= 3 else 1)
	speed = (6.0 if boss else 7.5 + randf() * 2.0) * (1.0 + wave * 0.05)
	base_x = position.x
	_build()
	rotation.x = -0.28   # wheelie

func _mat(c: Color, rough := 0.5, metal := 0.0, emis := Color.BLACK, e := 0.0) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = c; m.roughness = rough; m.metalness = metal
	m.emission_enabled = e > 0; m.emission_energy_multiplier = e
	return m

func _build() -> void:
	# REAL BIKE — static motorcycle model fitted to ~1.4m, long axis along +z travel
	bike = Node3D.new()
	add_child(bike)
	var moto = Models.inst("res://assets/vehicles/motorcycle.glb")
	if moto != null:
		Models.fit_height(moto, 1.4)
		Models.align_long_axis_z(moto)
		bike.add_child(moto)
		if boss:
			Models.tint(moto, Color(0.9, 0.1, 0.08, 0.35))
	# headlight
	var lamp = OmniLight3D.new()
	lamp.light_color = Color(1, 0.95, 0.7); lamp.light_energy = 1.2; lamp.omni_range = 8
	lamp.position = Vector3(0, 0.8, 0.7)
	bike.add_child(lamp)
	# REAL RIDER — rigged KayKit punk seated on the bike (bosses always Barbarian)
	rider = Node3D.new()
	rider.position = Vector3(0, 0.5, -0.1)
	bike.add_child(rider)
	var head_y := 1.3
	var cpath = Models.KAYKIT[0] if boss else Models.KAYKIT[randi() % Models.KAYKIT.size()]
	var rm = Models.inst(cpath)
	if rm != null:
		Models.fit_height(rm, 1.35)
		rider.add_child(rm)
		if not Models.play_anim(rm, ["sit_chair_idle", "sit", "drive", "ride"]):
			Models.play_anim(rm, ["idle"])   # fallback: positioned to read as riding
		var ra = Models.combined_aabb(rm)
		if ra.size.y > 0.01:
			head_y = ra.position.y + ra.size.y - 0.08
		if boss:
			Models.tint(rm, Color(1.0, 0.12, 0.1, 0.45))
	# head reference for head_split (~top of the rider model)
	head = Marker3D.new()
	head.position = Vector3(0, head_y, 0)
	rider.add_child(head)
	# mustache — every one of them
	stache = MeshInstance3D.new()
	stache.mesh = BoxMesh.new(); stache.mesh.size = Vector3(0.16, 0.03, 0.03)
	stache.material_override = _mat(Color(0.09, 0.06, 0.04), 0.9)
	stache.position = Vector3(0, head_y - 0.06, 0.16)
	rider.add_child(stache)
	# rim light so the black rider reads at night
	var rim = OmniLight3D.new()
	rim.light_color = Color(0.65, 0.75, 1); rim.light_energy = 1.4; rim.omni_range = 6
	rim.position = Vector3(0, 2.2, 0.8)
	add_child(rim)
	# hitbox on layer 2 for the player's ray
	hitbox = Area3D.new()
	hitbox.collision_layer = 2
	hitbox.collision_mask = 0
	var cs = CollisionShape3D.new()
	var box = BoxShape3D.new(); box.size = Vector3(1.1, 2.1, 2.0)
	cs.shape = box; cs.position = Vector3(0, 1.0, 0)
	hitbox.add_child(cs)
	hitbox.set_meta("enemy", self)
	add_child(hitbox)
	var sc = 1.45 if boss else 1.3
	scale = Vector3.ONE * sc

func take_damage(dmg: int, at: Vector3) -> void:
	if not alive: return
	hp -= dmg
	Gore.blood_burst(get_parent(), at, 30)
	if hp <= 0:
		die()

func die() -> void:
	if not alive: return
	alive = false
	var head_pos = head.global_position
	head.visible = false
	rider.visible = false
	Gore.blood_burst(get_parent(), head_pos, 90)
	Gore.head_split(get_parent(), head_pos)
	Gore.chunks(get_parent(), head_pos, 8)
	main.on_enemy_killed(self)
	if boss:
		main.hud.floater("KILLER IS DEAD", Color.RED, 40)
		main.killcam(head_pos)   # slow-mo kill-cam orbits the death spot
	elif randf() < 0.25:
		main.hud.floater("HEAD SPLIT!", Color(1, 0.4, 0.4), 20)
	queue_free()

func _taunt() -> void:
	taunted = true
	var l = Label3D.new()
	l.text = main.TAUNTS[randi() % main.TAUNTS.size()]
	l.font_size = 48
	l.modulate = Color(1, 0.6, 0.2)
	l.position = Vector3(0, 2.8, 0)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(l)
	get_tree().create_timer(2.2).timeout.connect(l.queue_free)
	get_tree().create_timer(8.0).timeout.connect(func(): taunted = false)

func _process(delta: float) -> void:
	if main.state != main.S.RIDE or not alive:
		return
	var wdt = delta
	var on_foot_brawl = main.player.on_foot and not boss
	if on_foot_brawl and position.z > -14:
		# circle her like a pack
		var ang = weave_phase * 0.5
		var ring = Vector3(sin(ang) * 6.5, 0, -cos(ang) * 6.5 - 2)
		position = position.lerp(ring, min(1.0, delta * 2))
		look_at(main.player.global_position * Vector3(1, 0, 1), Vector3.UP)
	else:
		position.z += (11.0 + speed) * wdt
		weave_phase += wdt * 2.4
		position.x = base_x + sin(weave_phase) * weave_amp
	if not taunted and not boss and position.z > -90 and position.z < -12 and randf() < wdt * 0.25:
		_taunt()
	if position.z > -1.5 and not on_foot_brawl:
		main.on_player_rammed(25 if boss else 11)
		main.enemies.erase(self)
		queue_free()
