extends Control

var health_bar: ColorRect
var health_fill: ColorRect
var stamina_bar: ColorRect
var stamina_fill: ColorRect
var altitude_label: Label
var score_label: Label
var biome_label: Label
var item_container: HBoxContainer
var item_slots: Array[Panel] = []
var player_ref = null

var damage_flash: ColorRect
var death_overlay: ColorRect
var death_label: Label
var tutorial_label: Label
var tutorial_shown := false
var progress_bg: ColorRect
var progress_fill: ColorRect
var prev_health := 100.0

const BAR_W := 180.0
const BAR_H := 14.0
const HEALTH_COLOR := Color(0.85, 0.2, 0.15)
const HEALTH_BG := Color(0.3, 0.1, 0.08)
const STAMINA_COLOR := Color(0.2, 0.7, 0.9)
const STAMINA_BG := Color(0.08, 0.2, 0.3)
const STAMINA_LOW := Color(0.9, 0.4, 0.1)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_health_bar()
	_build_stamina_bar()
	_build_labels()
	_build_item_display()
	_build_effects()
	_build_progress_bar()
	_build_tutorial()
	GameManager.altitude_updated.connect(_on_altitude_updated)
	GameManager.score_updated.connect(_on_score_updated)
	GameManager.biome_changed.connect(_on_biome_changed)
	GameManager.player_died.connect(_on_player_died)
	GameManager.player_respawned.connect(_on_player_respawned)

func _process(_delta: float) -> void:
	if not player_ref or not is_instance_valid(player_ref):
		player_ref = _find_player()
		if not player_ref:
			return
	var hp: float = player_ref.health / player_ref.MAX_HEALTH
	health_fill.size.x = BAR_W * hp
	health_fill.color = HEALTH_COLOR if hp > 0.3 else Color(1, 0.3, 0.1, 0.8 + sin(Time.get_ticks_msec() * 0.01) * 0.2)

	if player_ref.health < prev_health - 0.5:
		_flash_damage()
	prev_health = player_ref.health

	var sp: float = player_ref.stamina / player_ref.MAX_STAMINA
	stamina_fill.size.x = BAR_W * sp
	stamina_fill.color = STAMINA_COLOR if sp > 0.25 else STAMINA_LOW

	var progress := GameManager.get_progress()
	progress_fill.size.x = 200.0 * progress
	progress_fill.position.x = 1030

	if not tutorial_shown and GameManager.current_distance > 400:
		_hide_tutorial()

	_update_items()

func _find_player() -> Node:
	var p := get_tree().get_first_node_in_group("player")
	if p:
		return p
	for n in get_tree().root.get_children():
		var found := _recursive_find(n)
		if found:
			return found
	return null

func _recursive_find(node: Node) -> Node:
	if node is CharacterBody2D and node.has_method("heal"):
		return node
	for child in node.get_children():
		var f := _recursive_find(child)
		if f:
			return f
	return null

func _build_health_bar() -> void:
	var container := Control.new()
	container.position = Vector2(20, 20)
	add_child(container)
	var label := Label.new()
	label.text = "HP"
	label.position = Vector2(0, -2)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1, 0.8, 0.7))
	container.add_child(label)
	health_bar = ColorRect.new()
	health_bar.color = HEALTH_BG
	health_bar.position = Vector2(28, 0)
	health_bar.size = Vector2(BAR_W, BAR_H)
	container.add_child(health_bar)
	health_fill = ColorRect.new()
	health_fill.color = HEALTH_COLOR
	health_fill.position = Vector2(28, 0)
	health_fill.size = Vector2(BAR_W, BAR_H)
	container.add_child(health_fill)

func _build_stamina_bar() -> void:
	var container := Control.new()
	container.position = Vector2(20, 40)
	add_child(container)
	var label := Label.new()
	label.text = "ST"
	label.position = Vector2(0, -2)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	container.add_child(label)
	stamina_bar = ColorRect.new()
	stamina_bar.color = STAMINA_BG
	stamina_bar.position = Vector2(28, 0)
	stamina_bar.size = Vector2(BAR_W, BAR_H)
	container.add_child(stamina_bar)
	stamina_fill = ColorRect.new()
	stamina_fill.color = STAMINA_COLOR
	stamina_fill.position = Vector2(28, 0)
	stamina_fill.size = Vector2(BAR_W, BAR_H)
	container.add_child(stamina_fill)

func _build_labels() -> void:
	altitude_label = Label.new()
	altitude_label.position = Vector2(20, 64)
	altitude_label.add_theme_font_size_override("font_size", 16)
	altitude_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	altitude_label.text = "0 m"
	add_child(altitude_label)

	score_label = Label.new()
	score_label.position = Vector2(20, 86)
	score_label.add_theme_font_size_override("font_size", 13)
	score_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5, 0.8))
	score_label.text = "Score: 0"
	add_child(score_label)

	biome_label = Label.new()
	biome_label.anchor_right = 1.0
	biome_label.position = Vector2(-20, 20)
	biome_label.size = Vector2(200, 30)
	biome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	biome_label.anchors_preset = Control.PRESET_TOP_RIGHT
	biome_label.add_theme_font_size_override("font_size", 14)
	biome_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	biome_label.text = "Beach"
	add_child(biome_label)

func _build_item_display() -> void:
	item_container = HBoxContainer.new()
	item_container.position = Vector2(20, 110)
	item_container.add_theme_constant_override("separation", 6)
	add_child(item_container)
	for i in 3:
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(36, 36)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.15, 0.15, 0.2, 0.6)
		sb.border_color = Color(0.5, 0.5, 0.6, 0.4)
		sb.border_width_left = 1
		sb.border_width_right = 1
		sb.border_width_top = 1
		sb.border_width_bottom = 1
		sb.corner_radius_top_left = 4
		sb.corner_radius_top_right = 4
		sb.corner_radius_bottom_left = 4
		sb.corner_radius_bottom_right = 4
		slot.add_theme_stylebox_override("panel", sb)
		var lbl := Label.new()
		lbl.name = "ItemLabel"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.position = Vector2(0, 0)
		lbl.size = Vector2(36, 36)
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
		slot.add_child(lbl)
		item_container.add_child(slot)
		item_slots.append(slot)

func _update_items() -> void:
	if not player_ref or not is_instance_valid(player_ref):
		return
	for i in 3:
		var lbl: Label = item_slots[i].get_node("ItemLabel")
		if i < player_ref.inventory.size():
			var icon: String = _item_icon(player_ref.inventory[i])
			lbl.text = icon
			var sb: StyleBoxFlat = item_slots[i].get_theme_stylebox("panel").duplicate() as StyleBoxFlat
			sb.border_color = Color(1, 0.85, 0.3, 0.8) if i == player_ref.equipped_idx else Color(0.5, 0.5, 0.6, 0.4)
			item_slots[i].add_theme_stylebox_override("panel", sb)
		else:
			lbl.text = ""

func _item_icon(item_type: String) -> String:
	match item_type:
		"food": return "F"
		"bandage": return "B"
		"rope": return "R"
		"piton": return "P"
	return "?"

func _on_altitude_updated(alt: float) -> void:
	altitude_label.text = "%d m" % int(alt / 10.0)

func _on_score_updated(s: int) -> void:
	score_label.text = "Score: %d" % s

func _on_biome_changed(biome: String) -> void:
	biome_label.text = biome.capitalize()
	var tw := create_tween()
	tw.tween_property(biome_label, "modulate", Color(1, 1, 0.5), 0.3)
	tw.tween_property(biome_label, "modulate", Color.WHITE, 0.5)

func _build_effects() -> void:
	damage_flash = ColorRect.new()
	damage_flash.color = Color(0.9, 0.1, 0.05, 0)
	damage_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(damage_flash)

	death_overlay = ColorRect.new()
	death_overlay.color = Color(0, 0, 0, 0)
	death_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(death_overlay)

	death_label = Label.new()
	death_label.text = ""
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_label.set_anchors_preset(Control.PRESET_CENTER)
	death_label.size = Vector2(400, 60)
	death_label.position = Vector2(-200, -30)
	death_label.add_theme_font_size_override("font_size", 32)
	death_label.add_theme_color_override("font_color", Color(1, 0.3, 0.2))
	death_label.modulate.a = 0
	death_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(death_label)

func _build_progress_bar() -> void:
	var label := Label.new()
	label.text = "HELICOPTER"
	label.position = Vector2(1020, 692)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	add_child(label)

	progress_bg = ColorRect.new()
	progress_bg.color = Color(0.2, 0.18, 0.15, 0.4)
	progress_bg.position = Vector2(1030, 704)
	progress_bg.size = Vector2(200, 8)
	add_child(progress_bg)

	progress_fill = ColorRect.new()
	progress_fill.color = Color(1, 0.85, 0.3, 0.7)
	progress_fill.position = Vector2(1030, 704)
	progress_fill.size = Vector2(0, 8)
	add_child(progress_fill)

func _build_tutorial() -> void:
	tutorial_label = Label.new()
	tutorial_label.text = "A/D to move  |  SPACE to jump  |  SHIFT to grab walls  |  E to use items  |  Climb to the top!"
	tutorial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	tutorial_label.position = Vector2(-400, -60)
	tutorial_label.size = Vector2(800, 40)
	tutorial_label.add_theme_font_size_override("font_size", 14)
	tutorial_label.add_theme_color_override("font_color", Color(1, 0.95, 0.8, 0.8))
	tutorial_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tutorial_label)

func _hide_tutorial() -> void:
	tutorial_shown = true
	var tw := create_tween()
	tw.tween_property(tutorial_label, "modulate:a", 0.0, 1.5)

func _flash_damage() -> void:
	damage_flash.color = Color(0.9, 0.1, 0.05, 0.35)
	var tw := create_tween()
	tw.tween_property(damage_flash, "color:a", 0.0, 0.3)

func _on_player_died() -> void:
	death_overlay.color = Color(0, 0, 0, 0)
	death_label.text = "FALLEN"
	death_label.modulate.a = 0
	var tw := create_tween()
	tw.tween_property(death_overlay, "color:a", 0.6, 0.5)
	tw.parallel().tween_property(death_label, "modulate:a", 1.0, 0.4)

func _on_player_respawned() -> void:
	prev_health = 100.0
	var tw := create_tween()
	tw.tween_property(death_overlay, "color:a", 0.0, 0.4)
	tw.parallel().tween_property(death_label, "modulate:a", 0.0, 0.3)
