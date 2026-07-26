extends CanvasLayer
## HUD: health bar, level line, floaters, crosshair, pause menu, death screen,
## plus the full touch-control layer (virtual joystick + buttons) for touch_mode.

class Joystick:
	## Virtual thumbstick (bottom-left). Drag inside the ring -> main.joy_vec (-1..1).
	extends Control
	var main
	var knob := Vector2.ZERO
	var dragging := false
	const R_OUT := 70.0
	const R_IN := 28.0

	func _init() -> void:
		custom_minimum_size = Vector2(190, 190)
		size = Vector2(190, 190)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		var c = size / 2.0
		draw_circle(c, R_OUT, Color(1, 1, 1, 0.07))
		draw_arc(c, R_OUT, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
		if dragging:
			var kc = c + knob * (R_OUT - R_IN)
			draw_circle(kc, R_IN, Color(1, 1, 1, 0.32))
			draw_arc(kc, R_IN, 0.0, TAU, 32, Color(1, 1, 1, 0.6), 2.0)
		else:
			draw_circle(c, R_IN, Color(1, 1, 1, 0.16))

	func _stick(p: Vector2) -> void:
		var v = (p - size / 2.0) / (R_OUT - R_IN)
		if v.length() > 1.0:
			v = v.normalized()
		knob = v
		main.joy_vec = v   # x: lane dodge target; y: unused
		queue_redraw()

	func _release() -> void:
		dragging = false
		knob = Vector2.ZERO
		main.joy_vec = Vector2.ZERO
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			if event.pressed:
				dragging = true
				_stick(event.position)
			else:
				_release()
			accept_event()
		elif event is InputEventScreenDrag:
			dragging = true
			_stick(event.position)
			accept_event()

	func _input(event: InputEvent) -> void:
		# keep tracking even if the drag wanders outside the ring zone
		if not dragging:
			return
		if event is InputEventScreenTouch and not event.pressed:
			_release()
		elif event is InputEventScreenDrag:
			_stick(get_global_transform_with_canvas().affine_inverse() * event.position)

var main
var touch_layer: Control = null
var pause_btn: Button = null
var joy = null

var hp_bar: ColorRect
var level_label: Label
var kills_label: Label
var weapon_label: Label
var outfit_label: Label
var caption_label: Label
var hint_label: Label
var credits_label: Label
var flash_rect: ColorRect
var fade_rect: ColorRect
var crosshair: Label
var floaters: VBoxContainer
var pause_panel: Control
var dead_panel: Control

func _ready() -> void:
	# crosshair
	crosshair = Label.new()
	crosshair.text = "┼"
	crosshair.add_theme_font_size_override("font_size", 28)
	crosshair.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	add_child(crosshair)
	# health bar
	var hp_bg = ColorRect.new()
	hp_bg.color = Color(0, 0, 0, 0.5)
	hp_bg.position = Vector2(20, 20)
	hp_bg.size = Vector2(220, 18)
	add_child(hp_bg)
	hp_bar = ColorRect.new()
	hp_bar.color = Color(1, 0.84, 0)
	hp_bar.position = Vector2(22, 22)
	hp_bar.size = Vector2(216, 14)
	add_child(hp_bar)
	level_label = Label.new()
	level_label.position = Vector2(20, 46)
	level_label.add_theme_font_size_override("font_size", 15)
	add_child(level_label)
	kills_label = Label.new()
	kills_label.position = Vector2(20, 68)
	kills_label.add_theme_font_size_override("font_size", 15)
	add_child(kills_label)
	weapon_label = Label.new()
	weapon_label.position = Vector2(20, 90)
	weapon_label.add_theme_font_size_override("font_size", 15)
	add_child(weapon_label)
	outfit_label = Label.new()
	outfit_label.position = Vector2(20, 112)
	outfit_label.add_theme_font_size_override("font_size", 15)
	add_child(outfit_label)
	# full-screen overlays: impact flash + cinematic fade (under the caption)
	flash_rect = ColorRect.new()
	flash_rect.color = Color(0.85, 0.02, 0.02)
	flash_rect.modulate.a = 0.0
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(flash_rect)
	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.modulate.a = 0.0
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fade_rect)
	# persistent bottom caption (intro cinematic) — renders above the fade
	caption_label = Label.new()
	caption_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	caption_label.position = Vector2(-400, -70)
	caption_label.custom_minimum_size = Vector2(800, 40)
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.add_theme_font_size_override("font_size", 24)
	caption_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	add_child(caption_label)
	# persistent bottom-center hint (door knocks, side-street offers)
	hint_label = Label.new()
	hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.position = Vector2(-400, -130)
	hint_label.custom_minimum_size = Vector2(800, 30)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 16)
	hint_label.add_theme_color_override("font_color", Color(0.75, 0.95, 0.75))
	hint_label.visible = false
	add_child(hint_label)
	# asset attribution, always on
	credits_label = Label.new()
	credits_label.text = "Assets: Kenney/KayKit/Quaternius (CC0), Corentin Fatus (CC-BY)"
	credits_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	credits_label.position = Vector2(-420, -20)
	credits_label.custom_minimum_size = Vector2(400, 16)
	credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	credits_label.add_theme_font_size_override("font_size", 10)
	credits_label.modulate.a = 0.5
	add_child(credits_label)
	# floaters center
	floaters = VBoxContainer.new()
	floaters.set_anchors_preset(Control.PRESET_CENTER_TOP)
	floaters.position = Vector2(-400, 100)
	floaters.custom_minimum_size = Vector2(800, 0)
	floaters.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(floaters)
	# labels never eat screen touches (drag-to-look must work everywhere else)
	for c in [crosshair, hp_bg, hp_bar, level_label, kills_label, weapon_label,
			outfit_label, caption_label, hint_label, credits_label, floaters]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_pause()
	_build_dead()
	if main.touch_mode:
		_build_touch()
	refresh()

func _build_pause() -> void:
	pause_panel = Control.new()
	pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(bg)
	var t = Label.new()
	t.text = "PAUSED\n\nTAP II TO RESUME" if main.touch_mode else "PAUSED\n\nP / ESC — RESUME\nR — RESTART"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 32)
	t.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.add_child(t)
	pause_panel.visible = false
	add_child(pause_panel)

func _build_dead() -> void:
	dead_panel = Control.new()
	dead_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg = ColorRect.new()
	bg.color = Color(0.3, 0, 0, 0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dead_panel.add_child(bg)
	var t = Label.new()
	t.name = "DeadText"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 36)
	t.set_anchors_preset(Control.PRESET_CENTER)
	dead_panel.add_child(t)
	dead_panel.visible = false
	add_child(dead_panel)
	if main.touch_mode:
		# no keyboard on a phone — big restart button on the death screen
		var rb = _touch_btn("RIDE AGAIN", func(): main.start_run(), false)
		rb.process_mode = Node.PROCESS_MODE_ALWAYS
		rb.custom_minimum_size = Vector2(220, 64)
		rb.set_anchors_preset(Control.PRESET_CENTER)
		rb.position = Vector2(-110, 120)
		dead_panel.add_child(rb)

func _touch_btn(text: String, cb: Callable, in_ride := true) -> Button:
	# semi-transparent dark action button; in_ride buttons only fire while riding
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(64, 64)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	for s in ["normal", "hover", "pressed", "focus"]:
		var st = StyleBoxFlat.new()
		st.bg_color = Color(0.9, 0.8, 0.2, 0.55) if s == "pressed" else Color(0.02, 0.02, 0.05, 0.5)
		st.set_corner_radius_all(14)
		b.add_theme_stylebox_override(s, st)
	b.pressed.connect(func():
		if not in_ride or main.state == main.S.RIDE:
			cb.call())
	return b

func _build_touch() -> void:
	# full touch-control layer for touch_mode (iPhone Safari web export)
	touch_layer = Control.new()
	touch_layer.name = "TouchUI"
	touch_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE   # empty areas = drag-to-look
	add_child(touch_layer)
	# a) virtual joystick, bottom-left
	joy = Joystick.new()
	joy.main = main
	joy.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joy.position = Vector2(24, -214)
	touch_layer.add_child(joy)
	# c) buttons, right side: utility column + combat column
	var row = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.position = Vector2(-20, -20)
	row.add_theme_constant_override("separation", 12)
	touch_layer.add_child(row)
	var col_a = VBoxContainer.new()
	var col_b = VBoxContainer.new()
	for c in [col_a, col_b]:
		c.add_theme_constant_override("separation", 8)
	row.add_child(col_a)
	row.add_child(col_b)
	col_a.add_child(_touch_btn("KNOCK", func(): main.try_knock()))
	col_a.add_child(_touch_btn("AUTO", func(): main.player.toggle_autolock()))
	col_a.add_child(_touch_btn("TP", func(): main.player.toggle_view()))
	col_a.add_child(_touch_btn("CAM", func(): main.player.cycle_cam()))
	col_a.add_child(_touch_btn("FOOT", func(): main.player.toggle_foot()))
	col_b.add_child(_touch_btn("SLIDE", func(): main.player.do_slide()))
	col_b.add_child(_touch_btn("JUMP", func(): main.player.do_jump()))
	col_b.add_child(_touch_btn("BRAWL", func(): main.player.brawl_strike()))
	var fire = _touch_btn("FIRE", func(): main.player.shoot())
	fire.custom_minimum_size = Vector2(88, 88)
	fire.add_theme_font_size_override("font_size", 22)
	col_b.add_child(fire)
	# d) pause, top-center — must respond while the tree is paused
	pause_btn = _touch_btn("II", func(): main.toggle_pause(), false)
	pause_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_btn.custom_minimum_size = Vector2(72, 40)
	pause_btn.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pause_btn.position = Vector2(-36, 14)
	touch_layer.add_child(pause_btn)
	touch_layer.visible = false   # shown by show_game() once the run starts

func floater(text: String, color := Color.WHITE, size := 22) -> void:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	floaters.add_child(l)
	var tw = create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)

func caption(text: String) -> void:
	caption_label.text = text

func hint(text: String) -> void:
	hint_label.text = text
	hint_label.visible = true

func clear_hint() -> void:
	hint_label.visible = false

func flash_red() -> void:
	flash_rect.modulate.a = 0.7
	var tw = create_tween()
	tw.tween_property(flash_rect, "modulate:a", 0.0, 0.6)

func fade_to(a: float, dur: float) -> void:
	var tw = create_tween()
	tw.tween_property(fade_rect, "modulate:a", a, dur)

func refresh() -> void:
	if not main:
		return
	hp_bar.size.x = 216 * clampf(main.health / 100.0, 0, 1)
	hp_bar.color = Color(1, 0.84, 0) if main.god_mode else Color(0.9, 0.2, 0.2)
	var lvl = "LEVEL %d/10 — %s" % [main.wave, main.LEVELS[main.wave-1]] if main.wave >= 1 and main.wave <= 10 else ("ENDLESS — WAVE %d" % main.wave if main.wave > 10 else "GET READY")
	level_label.text = lvl + ("  •  GOD MODE" if main.god_mode else "")
	kills_label.text = "PUNKS DOWN: %d   CITY LOVE: %d%%   LIFETIME: %d" % [main.kills, int(main.city_love), main.lifetime_kills]
	if main.player:
		weapon_label.text = "WEAPON: " + main.player.WEAPONS[main.player.weapon]["n"]
		outfit_label.text = "OUTFIT: " + main.Outfits.OUTFITS[main.outfit]["n"]

func show_game() -> void:
	dead_panel.visible = false
	pause_panel.visible = false
	caption("")
	clear_hint()
	if touch_layer:
		touch_layer.visible = true
		for c in touch_layer.get_children():
			c.visible = true
	refresh()

func show_pause() -> void:
	pause_panel.visible = true
	if touch_layer:
		# only the pause button stays live over the pause panel
		for c in touch_layer.get_children():
			c.visible = (c == pause_btn)

func hide_pause() -> void:
	pause_panel.visible = false
	if touch_layer:
		for c in touch_layer.get_children():
			c.visible = true

func show_dead(kills: int, wave: int) -> void:
	dead_panel.get_node("DeadText").text = "SHE'S DOWN\n\n%d punks down, wave %d\n\nR — RIDE AGAIN" % [kills, wave]
	dead_panel.visible = true
	clear_hint()
	if touch_layer:
		touch_layer.visible = false

func _process(_delta: float) -> void:
	if main.state == main.S.RIDE:
		refresh()
