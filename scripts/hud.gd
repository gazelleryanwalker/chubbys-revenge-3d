extends CanvasLayer
## HUD: health bar, level line, floaters, crosshair, pause menu, death screen.

var main

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
	_build_pause()
	_build_dead()
	refresh()

func _build_pause() -> void:
	pause_panel = Control.new()
	pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(bg)
	var t = Label.new()
	t.text = "PAUSED\n\nP / ESC — RESUME\nR — RESTART"
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
	refresh()

func show_pause() -> void:
	pause_panel.visible = true

func hide_pause() -> void:
	pause_panel.visible = false

func show_dead(kills: int, wave: int) -> void:
	dead_panel.get_node("DeadText").text = "SHE'S DOWN\n\n%d punks down, wave %d\n\nR — RIDE AGAIN" % [kills, wave]
	dead_panel.visible = true
	clear_hint()

func _process(_delta: float) -> void:
	if main.state == main.S.RIDE:
		refresh()
