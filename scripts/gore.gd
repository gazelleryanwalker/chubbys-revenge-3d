extends RefCounted
## Gore: blood particles, head split halves, meat chunks. All GPU particles + rigid bodies.

static func _blood_mat() -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.02, 0.02)
	m.roughness = 0.35
	return m

static func blood_burst(parent: Node, at: Vector3, count := 40) -> void:
	var p = GPUParticles3D.new()
	p.amount = count
	p.lifetime = 1.2
	p.one_shot = true
	p.explosiveness = 0.95
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0.4)
	mat.spread = 65.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 8.0
	mat.gravity = Vector3(0, -12, 0)
	mat.scale_min = 0.06
	mat.scale_max = 0.16
	mat.color = Color(0.6, 0.03, 0.03)
	p.process_material = mat
	var quad = QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	var qm = StandardMaterial3D.new()
	qm.albedo_color = Color(0.55, 0.02, 0.02)
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = qm
	p.draw_pass_1 = quad
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	parent.get_tree().create_timer(2.0).timeout.connect(p.queue_free)

static func head_split(parent: Node, at: Vector3) -> void:
	# two hemispheres flying apart — every head splits in half
	for side in [-1, 1]:
		var rb = RigidBody3D.new()
		rb.gravity_scale = 1.0
		var mi = MeshInstance3D.new()
		var sph = SphereMesh.new()
		sph.radius = 0.15; sph.height = 0.3
		sph.radial_segments = 12; sph.rings = 6
		sph.is_hemisphere = true
		mi.mesh = sph
		mi.material_override = _blood_mat()
		rb.add_child(mi)
		var cs = CollisionShape3D.new()
		var shp = SphereShape3D.new(); shp.radius = 0.14
		cs.shape = shp
		rb.add_child(cs)
		parent.add_child(rb)
		rb.global_position = at
		rb.apply_central_impulse(Vector3(side * (2.0 + randf() * 2), 5.0 + randf() * 2, 1.5 + randf()))
		rb.angular_velocity = Vector3(randf() * 10, randf() * 10, side * 8)
		parent.get_tree().create_timer(4.0).timeout.connect(rb.queue_free)

static func chunks(parent: Node, at: Vector3, n := 6) -> void:
	for i in n:
		var rb = RigidBody3D.new()
		var mi = MeshInstance3D.new()
		var bx = BoxMesh.new(); bx.size = Vector3(0.09, 0.09, 0.09)
		mi.mesh = bx
		mi.material_override = _blood_mat()
		rb.add_child(mi)
		var cs = CollisionShape3D.new()
		var shp = BoxShape3D.new(); shp.size = Vector3(0.09, 0.09, 0.09)
		cs.shape = shp
		rb.add_child(cs)
		parent.add_child(rb)
		rb.global_position = at
		rb.apply_central_impulse(Vector3(randf_range(-2.5, 2.5), randf_range(2, 7), randf_range(0, 4)))
		parent.get_tree().create_timer(3.0).timeout.connect(rb.queue_free)
