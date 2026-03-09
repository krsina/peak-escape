extends Control

var anim_time := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_build_ui()

func _process(delta: float) -> void:
	anim_time += delta

func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.size = Vector2(400, 380)
	panel.position = Vector2(-200, -190)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.08, 0.06, 0.95)
	sb.border_color = Color(1, 0.85, 0.4, 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 30
	vbox.offset_right = -30
	vbox.offset_top = 25
	vbox.offset_bottom = -25
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var escaped := GameManager.current_state == GameManager.GameState.ESCAPED
	var title := Label.new()
	title.text = "ESCAPED!" if escaped else "RUN COMPLETE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.4) if escaped else Color(0.8, 0.7, 0.6))
	vbox.add_child(title)

	_add_stat(vbox, "Altitude", "%d m" % int(GameManager.max_altitude / 10.0))
	_add_stat(vbox, "Time", _format_time(GameManager.run_time))
	_add_stat(vbox, "Deaths", str(GameManager.deaths))
	_add_stat(vbox, "Items Found", str(GameManager.items_found))
	_add_stat(vbox, "Progress", "%d%%" % int(GameManager.get_progress() * 100))

	if SaveManager.data.get("best_altitude", 0.0) > 0:
		var best := Label.new()
		best.text = "Personal Best: %dm" % int(SaveManager.data["best_altitude"] / 10)
		best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		best.add_theme_font_size_override("font_size", 12)
		best.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55, 0.6))
		vbox.add_child(best)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_box)

	var retry := _make_btn("Run Again", "_on_retry")
	btn_box.add_child(retry)
	var menu := _make_btn("Menu", "_on_menu")
	btn_box.add_child(menu)

func _add_stat(parent: VBoxContainer, label: String, value: String) -> void:
	var hbox := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.65, 0.6))
	hbox.add_child(lbl)
	var val := Label.new()
	val.text = value
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.add_theme_font_size_override("font_size", 15)
	val.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	hbox.add_child(val)
	parent.add_child(hbox)

func _format_time(t: float) -> String:
	var mins := int(t) / 60
	var secs := int(t) % 60
	return "%d:%02d" % [mins, secs]

func _make_btn(text: String, callback: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(140, 40)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.22, 0.2, 0.16, 0.85)
	sb.border_color = Color(0.7, 0.6, 0.4, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	btn.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.3, 0.26, 0.2, 0.9)
	hover.border_color = Color(1, 0.85, 0.5, 0.8)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	btn.add_theme_color_override("font_hover_color", Color(1, 0.9, 0.5))
	btn.pressed.connect(Callable(self, callback))
	return btn

func _on_retry() -> void:
	get_tree().paused = false
	AudioManager.play_sfx("menu_confirm")
	GameManager.start_game()

func _on_menu() -> void:
	get_tree().paused = false
	AudioManager.play_sfx("menu_confirm")
	GameManager.go_to_menu()
