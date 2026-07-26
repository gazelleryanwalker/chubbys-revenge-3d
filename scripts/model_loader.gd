extends RefCounted
## ModelLoader: cached GLB loading + measure/fit/anim helpers for the real
## CC0/CC-BY assets (Kenney, KayKit, Quaternius, Corentin Fatus — ATTRIBUTION.md).

const KAYKIT = [
	"res://assets/characters/Barbarian.glb",
	"res://assets/characters/Knight.glb",
	"res://assets/characters/Rogue.glb",
]

const HOUSES = [
	"res://assets/houses/building-type-a.glb",
	"res://assets/houses/building-type-b.glb",
	"res://assets/houses/building-type-c.glb",
	"res://assets/houses/building-type-d.glb",
	"res://assets/houses/building-type-e.glb",
	"res://assets/houses/building-type-f.glb",
	"res://assets/houses/building-type-g.glb",
	"res://assets/houses/building-type-h.glb",
	"res://assets/houses/building-type-k.glb",
	"res://assets/houses/building-type-m.glb",
	"res://assets/houses/building-type-n.glb",
	"res://assets/houses/building-type-r.glb",
]

static var _scenes: Dictionary = {}

static func inst(path: String) -> Node3D:
	# cached PackedScene -> fresh instance (null if the asset failed to load)
	if not _scenes.has(path):
		_scenes[path] = load(path)
	var scn = _scenes.get(path)
	if scn == null:
		return null
	return scn.instantiate() as Node3D

static func _acc_aabb(node: Node, xf: Transform3D, acc: Array) -> void:
	var cur = xf
	if node is Node3D:
		cur = xf * node.transform
	if node is MeshInstance3D and node.mesh != null:
		var a = node.get_aabb()
		for i in 8:
			var corner = a.position + Vector3(
				a.size.x if (i & 1) != 0 else 0.0,
				a.size.y if (i & 2) != 0 else 0.0,
				a.size.z if (i & 4) != 0 else 0.0)
			var p = cur * corner
			if acc[0]:
				acc[1] = acc[1].expand(p)
			else:
				acc[0] = true
				acc[1] = AABB(p, Vector3.ZERO)
	for c in node.get_children():
		_acc_aabb(c, cur, acc)

static func combined_aabb(root: Node) -> AABB:
	# combined local-space AABB over every child MeshInstance3D
	var acc = [false, AABB()]
	_acc_aabb(root, Transform3D.IDENTITY, acc)
	return acc[1]

static func fit_height(node: Node3D, target_h: float) -> float:
	var a = combined_aabb(node)
	var s = 1.0
	if a.size.y > 0.001:
		s = target_h / a.size.y
	node.scale = Vector3.ONE * s
	return s

static func fit_length(node: Node3D, target: float) -> float:
	# scale so the LONGEST axis (gun barrel, board deck) == target
	var a = combined_aabb(node)
	var longest = maxf(a.size.x, maxf(a.size.y, a.size.z))
	var s = 1.0
	if longest > 0.001:
		s = target / longest
	node.scale = Vector3.ONE * s
	return s

static func align_long_axis_z(node: Node3D) -> void:
	# rotate y so the longest horizontal axis points along z (travel direction)
	var a = combined_aabb(node)
	if a.size.x > a.size.z:
		node.rotation.y = PI / 2.0

static func find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var r = find_anim_player(c)
		if r != null:
			return r
	return null

static func pick_anim(ap: AnimationPlayer, keys: Array) -> StringName:
	# keyword order = priority; exact (case-insensitive) match first, then contains()
	var list = ap.get_animation_list()
	for k in keys:
		var kl = String(k).to_lower()
		for a in list:
			if String(a).to_lower() == kl:
				return a
	for k in keys:
		var kl = String(k).to_lower()
		for a in list:
			if String(a).to_lower().contains(kl):
				return a
	return &""

static func play_anim(node: Node, keys: Array, loop := true) -> bool:
	var ap = find_anim_player(node)
	if ap == null:
		return false
	var a = pick_anim(ap, keys)
	if String(a).is_empty():
		return false
	var anim = ap.get_animation(a)
	if anim != null and loop:
		anim.loop_mode = Animation.LOOP_LINEAR
	ap.play(a)
	return true

static func find_named(node: Node, needle: String) -> Node:
	var n = needle.to_lower()
	if node != null and node.name.to_lower().contains(n):
		return node
	if node == null:
		return null
	for c in node.get_children():
		var r = find_named(c, needle)
		if r != null:
			return r
	return null

static func tint(node: Node, color: Color) -> void:
	# material overlay on every mesh (boss red)
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_apply_overlay(node, m)

static func _apply_overlay(node: Node, m: Material) -> void:
	if node is MeshInstance3D:
		node.material_overlay = m
	for c in node.get_children():
		_apply_overlay(c, m)
