extends Control

var title_time := 0.0
var landscape_pts: Array[PackedVector2Array] = []

func _ready() -> void:
	_generate_landscape()
	_build_ui()
	GameManager.set_state(GameManager.GameState.MENU)

func _process(delta: float) -> void:
	title_time += delta
	queue_redraw()

func _generate_landscape() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 123
	for layer in 3:
		var pts := PackedVector2Array()
		var base_y := 480.0 - layer * 50
		pts.append(Vector2(0, 720))
		var step := 60
		for x in range(0, 1281, step):
			var h := rng.randf_range(40, 120) + layer * 30
			var y := base_y + sin(x * 0.004 + layer * 1.5) * h
			pts.append(Vector2(float(x), clampf(y, 200, 700)))
		pts.append(Vector2(1280, 720))
		pts.append(Vector2(0, 720))
		if pts.size() >= 3:
			landscape_pts.append(pts)

func _build_ui() -> void:
	var title := Label.new()
	title.text = "PEAK ESCAPE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = 40
	title.offset_top = 60
	title.offset_right = -40
	title.offset_bottom = 140
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	title.name = "Title"
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Climb to the helicopter"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.set_anchors_preset(Control.PRESET_TOP_WIDE)
	subtitle.offset_left = 40
	subtitle.offset_top = 130
	subtitle.offset_right = -40
	subtitle.offset_bottom = 165
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.75, 0.65))
	add_child(subtitle)

	var menu_panel := Panel.new()
	menu_panel.set_anchors_preset(Control.PRESET_CENTER)
	menu_panel.offset_left = -150
	menu_panel.offset_top = -90
	menu_panel.offset_right = 150
	menu_panel.offset_bottom = 110
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.07, 0.08, 0.72)
	panel_style.border_color = Color(0.85, 0.72, 0.45, 0.35)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	menu_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(menu_panel)

	var btn_container := VBoxContainer.new()
	btn_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn_container.offset_left = 26
	btn_container.offset_top = 22
	btn_container.offset_right = -26
	btn_container.offset_bottom = -22
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_container.add_theme_constant_override("separation", 12)
	menu_panel.add_child(btn_container)

	var play_btn := _make_button("Run", _on_play)
	btn_container.add_child(play_btn)

	var stats_label := Label.new()
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.65, 0.7))
	var sd: Dictionary = SaveManager.data
	if sd.get("best_altitude", 0.0) > 0:
		stats_label.text = "Best: %dm | Escapes: %d | Deaths: %d" % [int(sd["best_altitude"] / 10), sd.get("total_escapes", 0), sd.get("total_deaths", 0)]
	else:
		stats_label.text = "No runs yet"
	btn_container.add_child(stats_label)

	var quit_btn := _make_button("Quit", _on_quit)
	btn_container.add_child(quit_btn)

	var controls := Label.new()
	controls.text = "A/D: Move | Space: Jump | Shift: Grab Wall | E: Use Item | Q: Cycle Item"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	controls.offset_left = 20
	controls.offset_top = -45
	controls.offset_right = -20
	controls.offset_bottom = -15
	controls.add_theme_font_size_override("font_size", 11)
	controls.add_theme_color_override("font_color", Color(0.6, 0.6, 0.55, 0.6))
	add_child(controls)

func _make_button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(200, 44)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.18, 0.15, 0.8)
	sb.border_color = Color(0.8, 0.7, 0.5, 0.6)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.3, 0.25, 0.2, 0.9)
	hover.border_color = Color(1, 0.85, 0.5, 0.8)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := sb.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.15, 0.12, 0.1, 0.9)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	btn.add_theme_color_override("font_hover_color", Color(1, 0.9, 0.5))
	btn.focus_mode = Control.FOCUS_ALL
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.pressed.connect(callback)
	return btn

func _on_play() -> void:
	AudioManager.play_sfx("menu_confirm")
	GameManager.start_game()

func _on_quit() -> void:
	get_tree().quit()

func _draw_landscape_layer(pts: PackedVector2Array, color: Color) -> void:
	var n := pts.size()
	if n < 3:
		return
	var bottom_y := 720.0
	for j in n - 1:
		var a := pts[j]
		var b := pts[j + 1]
		if b.x <= a.x:
			continue
		var quad := PackedVector2Array([
			a, b,
			Vector2(b.x, bottom_y),
			Vector2(a.x, bottom_y),
		])
		draw_colored_polygon(quad, color)

func _draw() -> void:
	var vp := get_viewport_rect().size
	if vp.x <= 0 or vp.y <= 0:
		return

	var t_sky := Color(0.15, 0.08, 0.22)
	var b_sky := Color(0.40, 0.20, 0.12)
	for i in 20:
		var t := float(i) / 20
		draw_rect(Rect2(0, t * vp.y, vp.x, vp.y / 20 + 1), t_sky.lerp(b_sky, t))

	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 50:
		var sx := rng.randf() * vp.x
		var sy := rng.randf() * vp.y * 0.5
		var twinkle := absf(sin(title_time * (0.5 + rng.randf()) + i))
		draw_circle(Vector2(sx, sy), 1.0 + twinkle * 0.5, Color(1, 1, 0.9, twinkle * 0.7))

	var layer_colors := [
		Color(0.15, 0.22, 0.12, 0.5),
		Color(0.20, 0.15, 0.10, 0.6),
		Color(0.28, 0.20, 0.12, 0.7),
	]
	for i in landscape_pts.size():
		var pts: PackedVector2Array = landscape_pts[i]
		if pts.size() < 3:
			continue
		_draw_landscape_layer(pts, layer_colors[i])
