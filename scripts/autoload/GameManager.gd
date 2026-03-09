extends Node

enum GameState { MENU, PLAYING, PAUSED, DEAD, ESCAPED }

signal state_changed(new_state: GameState)
signal biome_changed(biome_name: String)
signal altitude_updated(altitude: float)
signal score_updated(score: int)
signal player_died
signal player_respawned
signal checkpoint_activated(pos: Vector2)
signal item_collected(item_type: String)
signal helicopter_reached

var current_state: GameState = GameState.MENU
var current_biome: String = "beach"
var max_altitude: float = 0.0
var current_altitude: float = 0.0
var current_distance: float = 0.0
var score: int = 0
var deaths: int = 0
var run_time: float = 0.0
var active_checkpoint: Vector2 = Vector2(200, 500)
var items_found: int = 0

const START_Y := 560.0
const BIOME_THRESHOLDS := {
	"beach": 0.0,
	"jungle": 10000.0,
	"icelands": 20000.0,
	"fire": 30000.0,
}
const TOTAL_DISTANCE := 40000.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input_map()

func _process(delta: float) -> void:
	if current_state == GameState.PLAYING:
		run_time += delta

func _setup_input_map() -> void:
	var actions := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"jump": [KEY_SPACE],
		"grab": [KEY_SHIFT],
		"use_item": [KEY_E],
		"cycle_item": [KEY_Q],
		"pause": [KEY_ESCAPE],
		"interact": [KEY_F],
	}
	for action_name in actions:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		for key in actions[action_name]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			var already := false
			for existing in InputMap.action_get_events(action_name):
				if existing is InputEventKey and existing.physical_keycode == key:
					already = true
					break
			if not already:
				InputMap.action_add_event(action_name, ev)

func set_state(new_state: GameState) -> void:
	current_state = new_state
	state_changed.emit(new_state)
	match new_state:
		GameState.PAUSED:
			get_tree().paused = true
		GameState.PLAYING:
			get_tree().paused = false
		GameState.DEAD:
			deaths += 1
			player_died.emit()
		GameState.ESCAPED:
			helicopter_reached.emit()

func update_progress(world_x: float, world_y: float) -> void:
	current_distance = maxf(world_x, 0.0)
	current_altitude = maxf(START_Y - world_y, 0.0)
	if current_altitude > max_altitude:
		max_altitude = current_altitude
		score = int(max_altitude)
		score_updated.emit(score)
	altitude_updated.emit(current_altitude)
	var new_biome := _get_biome_for_distance(current_distance)
	if new_biome != current_biome:
		current_biome = new_biome
		biome_changed.emit(new_biome)

func _get_biome_for_distance(d: float) -> String:
	if d >= BIOME_THRESHOLDS["fire"]:
		return "fire"
	if d >= BIOME_THRESHOLDS["icelands"]:
		return "icelands"
	if d >= BIOME_THRESHOLDS["jungle"]:
		return "jungle"
	return "beach"

func set_checkpoint(pos: Vector2) -> void:
	active_checkpoint = pos
	checkpoint_activated.emit(pos)

func collect_item(item_type: String) -> void:
	items_found += 1
	item_collected.emit(item_type)

func start_game() -> void:
	max_altitude = 0.0
	current_altitude = 0.0
	current_distance = 0.0
	score = 0
	deaths = 0
	run_time = 0.0
	items_found = 0
	current_biome = "beach"
	active_checkpoint = Vector2(200, 500)
	set_state(GameState.PLAYING)
	get_tree().paused = false
	var err := get_tree().change_scene_to_file("res://scenes/game/Game.tscn")
	if err != OK:
		push_error("Failed to load game scene: %s" % error_string(err))

func go_to_menu() -> void:
	SaveManager.record_run(max_altitude, run_time, deaths, items_found, false)
	set_state(GameState.MENU)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu/MainMenu.tscn")

func get_progress() -> float:
	return clampf(current_distance / TOTAL_DISTANCE, 0.0, 1.0)
