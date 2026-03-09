extends Control

var panel: Panel
var built := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause"):
		_on_resume()
		get_viewport().set_input_as_handled()

func show_menu() -> void:
	visible = true
	if not built:
		_build_ui()
		built = true

func hide_menu() -> void:
	visible = false

func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.size = Vector2(280, 260)
	panel.position = Vector2(-140, -130)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.1, 0.08, 0.92)
	sb.border_color = Color(0.6, 0.5, 0.35, 0.6)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 30
	vbox.offset_right = -30
	vbox.offset_top = 20
	vbox.offset_bottom = -20
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	vbox.add_child(title)

	var resume_btn := _make_btn("Resume", "_on_resume")
	vbox.add_child(resume_btn)

	var restart_btn := _make_btn("Restart", "_on_restart")
	vbox.add_child(restart_btn)

	var menu_btn := _make_btn("Main Menu", "_on_menu")
	vbox.add_child(menu_btn)

func _make_btn(text: String, callback: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 38)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.22, 0.2, 0.16, 0.8)
	sb.border_color = Color(0.6, 0.5, 0.4, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.32, 0.28, 0.22, 0.9)
	hover.border_color = Color(1, 0.85, 0.5, 0.7)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	btn.add_theme_color_override("font_hover_color", Color(1, 0.9, 0.5))
	btn.pressed.connect(Callable(self, callback))
	return btn

func _on_resume() -> void:
	AudioManager.play_sfx("menu_select")
	GameManager.set_state(GameManager.GameState.PLAYING)
	hide_menu()

func _on_restart() -> void:
	AudioManager.play_sfx("menu_confirm")
	GameManager.set_state(GameManager.GameState.PLAYING)
	hide_menu()
	GameManager.start_game()

func _on_menu() -> void:
	AudioManager.play_sfx("menu_confirm")
	GameManager.go_to_menu()
