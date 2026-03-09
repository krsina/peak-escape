extends Node2D

var player: CharacterBody2D
var hud: CanvasLayer
var pause_menu: Control
var bg_layer: CanvasLayer
var world_node: Node2D
var terrain_node: Node2D
var hazard_node: Node2D
var pickup_node: Node2D
var level_gen: Node2D

func _ready() -> void:
	_build_scene_tree()
	_generate_level()
	_place_player_on_surface()
	GameManager.player_respawned.connect(_on_player_respawned)
	GameManager.helicopter_reached.connect(_on_helicopter_reached)

func _build_scene_tree() -> void:
	bg_layer = CanvasLayer.new()
	bg_layer.layer = -10
	bg_layer.name = "BackgroundLayer"
	add_child(bg_layer)
	var bg := Node2D.new()
	bg.set_script(preload("res://scripts/effects/Background.gd"))
	bg.name = "Background"
	bg_layer.add_child(bg)

	world_node = Node2D.new()
	world_node.name = "World"
	add_child(world_node)
	terrain_node = Node2D.new()
	terrain_node.name = "Terrain"
	world_node.add_child(terrain_node)
	hazard_node = Node2D.new()
	hazard_node.name = "Hazards"
	world_node.add_child(hazard_node)
	pickup_node = Node2D.new()
	pickup_node.name = "Pickups"
	world_node.add_child(pickup_node)

	var player_scene := preload("res://scenes/player/Player.tscn")
	player = player_scene.instantiate()
	player.position = Vector2(80, 500)
	add_child(player)

	hud = CanvasLayer.new()
	hud.layer = 10
	hud.name = "HUDLayer"
	add_child(hud)
	var hud_ui := Control.new()
	hud_ui.set_script(preload("res://scripts/ui/HUD.gd"))
	hud_ui.name = "HUD"
	hud_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(hud_ui)

	pause_menu = Control.new()
	pause_menu.set_script(preload("res://scripts/ui/PauseMenu.gd"))
	pause_menu.name = "PauseMenu"
	pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.visible = false
	hud.add_child(pause_menu)

func _generate_level() -> void:
	level_gen = Node2D.new()
	level_gen.set_script(preload("res://scripts/world/LevelGenerator.gd"))
	add_child(level_gen)
	level_gen.generate(terrain_node, hazard_node, pickup_node)

func _place_player_on_surface() -> void:
	const SPAWN_X := 80.0
	const FEET_OFFSET := 20.0
	var surface_y: float = level_gen.get_surface_y_at(SPAWN_X)
	var spawn_y := surface_y - FEET_OFFSET
	player.position = Vector2(SPAWN_X, spawn_y)
	GameManager.active_checkpoint = Vector2(SPAWN_X, spawn_y)

func _process(_delta: float) -> void:
	_update_piton_lifetimes(_delta)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and GameManager.current_state == GameManager.GameState.PLAYING:
		GameManager.set_state(GameManager.GameState.PAUSED)
		pause_menu.show_menu()

func _on_player_respawned() -> void:
	if player:
		player.global_position = GameManager.active_checkpoint

func _on_helicopter_reached() -> void:
	SaveManager.record_run(
		GameManager.max_altitude,
		GameManager.run_time,
		GameManager.deaths,
		GameManager.items_found,
		true
	)
	await get_tree().create_timer(2.0).timeout
	_show_results()

func _show_results() -> void:
	var results := Control.new()
	results.set_script(preload("res://scripts/ui/ResultsScreen.gd"))
	results.name = "Results"
	results.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(results)

func _update_piton_lifetimes(delta: float) -> void:
	for child in terrain_node.get_children():
		if child.is_in_group("piton") and child.has_meta("lifetime"):
			var lt: float = child.get_meta("lifetime") - delta
			child.set_meta("lifetime", lt)
			if lt <= 0:
				child.queue_free()
