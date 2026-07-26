extends Node3D
## World: night street, three rotating zones (SUBURB / RURAL / DOWNTOWN),
## recycled roadside slots, lamps, moon, embers, volumetric fog, glow, SDFGI.
## SUBURB slots use the 12 real Kenney house GLBs; side-street intersections
## spawn ahead and scroll with the world.

const Models = preload("res://scripts/model_loader.gd")

const ZONES = [
	{"n":"MAPLE STREET — THE SUBURBS", "fog":Color(0.05,0.04,0.08), "walk":Color(0.24,0.24,0.28)},
	{"n":"COUNTY ROAD 9 — FARMLAND",   "fog":Color(0.03,0.04,0.07), "walk":Color(0.13,0.19,0.11)},
	{"n":"MAIN STREET — DOWNTOWN",     "fog":Color(0.04,0.04,0.1),  "walk":Color(0.24,0.24,0.28)},
]
const SEG := 24.0
const NSEG := 12

var zone_idx := 0
var zone_t := 0.0
var slots: Array = []
var intersections: Array = []
var world_speed := 11.0
var walk_mats: Array = []

func _mat(c: Color, rough := 0.7, metal := 0.0, emis := Color.BLACK, e := 0.0) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = c; m.roughness = rough; m.metalness = metal
	m.emission_enabled = e > 0; m.emission = emis; m.emission_energy_multiplier = e
	return m

func _ready() -> void:
	_build_environment()
	_build_road()
	_build_slots()
	apply_zone(0)

func _build_environment() -> void:
	var env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.02, 0.06)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.25, 0.28, 0.45)
	e.ambient_light_energy = 0.6
	e.fog_enabled = true
	e.fog_light_color = Color(0.04, 0.04, 0.1)
	e.fog_density = 0.012
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.02
	e.glow_enabled = true
	e.glow_intensity = 0.8
	e.glow_bloom = 0.1
	e.ssao_enabled = true
	e.ssil_enabled = true
	e.sdfgi_enabled = true
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.1
	env.environment = e
	add_child(env)
	var moon = DirectionalLight3D.new()
	moon.light_color = Color(0.6, 0.65, 0.9)
	moon.light_energy = 1.1
	moon.rotation_degrees = Vector3(-50, -30, 0)
	add_child(moon)

func _build_road() -> void:
	var road = MeshInstance3D.new()
	var pm = PlaneMesh.new(); pm.size = Vector2(20, 600)
	road.mesh = pm
	road.material_override = _mat(Color(0.09, 0.09, 0.11), 0.6, 0.15)
	road.position = Vector3(0, 0, -150)
	add_child(road)
	# center line glow
	var line = MeshInstance3D.new()
	var lm = PlaneMesh.new(); lm.size = Vector2(0.15, 600)
	line.mesh = lm
	line.material_override = _mat(Color(0.4, 0.35, 0.1), 0.5, 0.0, Color(0.8, 0.7, 0.2), 0.5)
	line.position = Vector3(0, 0.01, -150)
	add_child(line)
	for s in [-1, 1]:
		var wm = _mat(Color(0.24, 0.24, 0.28), 0.9)
		walk_mats.append(wm)
		var walk = MeshInstance3D.new()
		var wp = PlaneMesh.new(); wp.size = Vector2(4, 600)
		walk.mesh = wp
		walk.material_override = wm
		walk.position = Vector3(s * 11.5, 0.02, -150)
		add_child(walk)
	# street lamps
	for i in range(10):
		for s in [-1, 1]:
			var pole = MeshInstance3D.new()
			var cyl = CylinderMesh.new(); cyl.top_radius = 0.07; cyl.bottom_radius = 0.09; cyl.height = 5.2
			pole.mesh = cyl
			pole.material_override = _mat(Color(0.1, 0.1, 0.12), 0.5, 0.8)
			pole.position = Vector3(s * 10.5, 2.6, -14 - i * 30)
			add_child(pole)
			var lamp = OmniLight3D.new()
			lamp.light_color = Color(1, 0.85, 0.6)
			lamp.light_energy = 1.5
			lamp.omni_range = 14
			lamp.position = Vector3(s * 9.5, 5.1, -14 - i * 30)
			add_child(lamp)

func _build_slots() -> void:
	for i in NSEG:
		for s in [-1, 1]:
			var g = Node3D.new()
			g.set_meta("side", s)
			g.position = Vector3(0, 0, -i * SEG - 20)
			add_child(g)
			slots.append(g)

func _clear(g: Node) -> void:
	for c in g.get_children():
		c.queue_free()

func _style_slot(g: Node3D, zone: int, s: int) -> void:
	_clear(g)
	var rnd = randf()
	if zone == 2:  # DOWNTOWN — lit towers
		var bh = 12 + rnd * 26
		var b = MeshInstance3D.new()
		var bm = BoxMesh.new(); bm.size = Vector3(10 + rnd * 6, bh, 10)
		b.mesh = bm
		b.material_override = _mat(Color(0.1, 0.1, 0.14), 0.9, 0.1, Color(0.5, 0.5, 0.35), 0.35)
		b.position = Vector3(s * (19 + rnd * 4), bh / 2.0, 0)
		g.add_child(b)
	elif zone == 0:  # SUBURB — real houses, warm windows, trees, fences
		var hx = s * (19 + rnd * 3)
		g.set_meta("house_x", hx)   # remembered for door-knock residents
		var house = Models.inst(Models.HOUSES[randi() % Models.HOUSES.size()])
		if house != null:
			Models.fit_height(house, 7.0)
			house.position = Vector3(hx, 0, 0)
			house.rotation.y = -PI / 2.0 if s > 0 else PI / 2.0   # front faces the road
			g.add_child(house)
		else:
			var wall = _mat(Color(0.45, 0.4, 0.33) if rnd < 0.5 else Color(0.35, 0.4, 0.45), 0.9)
			var h = MeshInstance3D.new()
			var hm = BoxMesh.new(); hm.size = Vector3(7, 4.2, 7)
			h.mesh = hm; h.material_override = wall
			h.position = Vector3(hx, 2.1, 0)
			g.add_child(h)
		# warm window glow facing the road
		var win = MeshInstance3D.new()
		var wm2 = BoxMesh.new(); wm2.size = Vector3(0.1, 1.0, 1.0)
		win.mesh = wm2
		win.material_override = _mat(Color.BLACK, 0.5, 0, Color(1, 0.75, 0.4), 1.6)
		win.position = Vector3(hx - s * 4.4, 2.2, 0)
		g.add_child(win)
		# procedural picket fence along the sidewalk
		var fmat = _mat(Color(0.78, 0.76, 0.7), 0.9)
		var rail = MeshInstance3D.new()
		var rm3 = BoxMesh.new(); rm3.size = Vector3(0.06, 0.07, 7.0)
		rail.mesh = rm3; rail.material_override = fmat
		rail.position = Vector3(s * 14.2, 0.55, 0)
		g.add_child(rail)
		for fi in 5:
			var post = MeshInstance3D.new()
			var pm3 = BoxMesh.new(); pm3.size = Vector3(0.09, 0.85, 0.09)
			post.mesh = pm3; post.material_override = fmat
			post.position = Vector3(s * 14.2, 0.42, -2.8 + fi * 1.4)
			g.add_child(post)
		if rnd < 0.7:
			_add_tree(g, s * 13.5, 2 + rnd * 4, 1.0)
	else:  # RURAL — barns, silos, corn, big trees, gaps
		if rnd < 0.35:
			var barn = MeshInstance3D.new()
			var bm2 = BoxMesh.new(); bm2.size = Vector3(8, 5.5, 9)
			barn.mesh = bm2
			barn.material_override = _mat(Color(0.4, 0.08, 0.07), 0.85)
			barn.position = Vector3(s * (20 + rnd * 3), 2.75, 0)
			g.add_child(barn)
			var silo = MeshInstance3D.new()
			var sm = CylinderMesh.new(); sm.top_radius = 1.6; sm.bottom_radius = 1.6; sm.height = 9
			silo.mesh = sm
			silo.material_override = _mat(Color(0.6, 0.62, 0.66), 0.4, 0.7)
			silo.position = Vector3(s * 26, 4.5, 3)
			g.add_child(silo)
		elif rnd < 0.7:
			for c in 8:
				var corn = MeshInstance3D.new()
				var cm = CylinderMesh.new(); cm.top_radius = 0.05; cm.bottom_radius = 0.3; cm.height = 2.0
				corn.mesh = cm
				corn.material_override = _mat(Color(0.2, 0.28, 0.1), 1.0)
				corn.position = Vector3(s * (13 + randf() * 10), 1.0, -8 + c * 2.2)
				g.add_child(corn)
		elif rnd < 0.9:
			_add_tree(g, s * (15 + rnd * 4), 0, 2.0)

func _add_tree(g: Node3D, x: float, z: float, sc: float) -> void:
	var trunk = MeshInstance3D.new()
	var tm = CylinderMesh.new(); tm.top_radius = 0.2; tm.bottom_radius = 0.3; tm.height = 2.2
	trunk.mesh = tm
	trunk.material_override = _mat(Color(0.16, 0.11, 0.07), 1.0)
	trunk.position = Vector3(x, 1.1 * sc, z)
	trunk.scale = Vector3.ONE * sc
	g.add_child(trunk)
	var leaf = MeshInstance3D.new()
	var lm = SphereMesh.new(); lm.radius = 1.9; lm.height = 3.8
	leaf.mesh = lm
	leaf.material_override = _mat(Color(0.09, 0.18, 0.08), 1.0)
	leaf.position = Vector3(x, (3.4 if sc < 1.5 else 6.5) * min(sc, 1.8), z)
	leaf.scale = Vector3.ONE * sc
	g.add_child(leaf)

func spawn_intersection(street_name: String) -> Node3D:
	# SIDE STREET — cross-road + green street sign, scrolls with the world
	var g = Node3D.new()
	g.position = Vector3(0, 0, -130)
	add_child(g)
	var cr = MeshInstance3D.new()
	var pm = PlaneMesh.new(); pm.size = Vector2(140, 10)
	cr.mesh = pm
	cr.material_override = _mat(Color(0.09, 0.09, 0.11), 0.6, 0.15)
	cr.position = Vector3(0, 0.015, 0)
	g.add_child(cr)
	# green street sign on a box pole at the corner
	var pole = MeshInstance3D.new()
	var bm = BoxMesh.new(); bm.size = Vector3(0.09, 3.0, 0.09)
	pole.mesh = bm
	pole.material_override = _mat(Color(0.15, 0.16, 0.18), 0.5, 0.7)
	pole.position = Vector3(11.0, 1.5, 0)
	g.add_child(pole)
	var sign = MeshInstance3D.new()
	var sb = BoxMesh.new(); sb.size = Vector3(2.2, 0.6, 0.06)
	sign.mesh = sb
	sign.material_override = _mat(Color(0.02, 0.25, 0.1), 0.6, 0.1, Color(0.02, 0.4, 0.15), 0.6)
	sign.position = Vector3(11.0, 2.9, 0)
	g.add_child(sign)
	var lab = Label3D.new()
	lab.text = street_name
	lab.font_size = 64
	lab.modulate = Color(1, 1, 1)
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.position = Vector3(11.0, 2.95, 0.1)
	g.add_child(lab)
	intersections.append(g)
	return g

func apply_zone(z: int) -> void:
	zone_idx = z
	for g in slots:
		_style_slot(g, z, g.get_meta("side"))
	for wm in walk_mats:
		wm.albedo_color = ZONES[z]["walk"]
	var hud = get_parent().get_node_or_null("HUD")
	if hud and hud.has_method("floater"):
		hud.floater(ZONES[z]["n"], Color(0.8, 0.9, 1), 20)

func _process(delta: float) -> void:
	var main = get_parent()
	if main.state != main.S.RIDE:
		return
	var wdt = delta
	for g in slots:
		g.position.z += world_speed * wdt
		if g.position.z > 40:
			g.position.z -= NSEG * SEG
	for i in range(intersections.size() - 1, -1, -1):
		var g2 = intersections[i]
		g2.position.z += world_speed * wdt
		if g2.position.z > 40:
			intersections.remove_at(i)
			g2.queue_free()
	zone_t += wdt
	if zone_t > 35:
		zone_t = 0
		apply_zone((zone_idx + 1) % ZONES.size())
