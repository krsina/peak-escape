extends Node

const SAVE_PATH := "user://peakclimb_save.json"

var data := {
	"best_altitude": 0.0,
	"best_time": 0.0,
	"total_deaths": 0,
	"total_escapes": 0,
	"items_found": 0,
	"sfx_volume": 0.4,
	"music_volume": 0.5,
}

func _ready() -> void:
	load_data()

func save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
	else:
		push_error("SaveManager: failed to open save file for writing: %s" % SAVE_PATH)

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("SaveManager: failed to open save file for reading: %s" % SAVE_PATH)
		return
	var json := JSON.new()
	var result := json.parse(file.get_as_text())
	if result != OK or not (json.data is Dictionary):
		push_error("SaveManager: invalid or corrupt save file")
		return
	for key in json.data:
		data[key] = json.data[key]

func record_run(altitude: float, time: float, deaths: int, items: int, escaped: bool) -> void:
	if altitude > data["best_altitude"]:
		data["best_altitude"] = altitude
	if escaped:
		data["total_escapes"] += 1
		if data["best_time"] <= 0.0 or time < data["best_time"]:
			data["best_time"] = time
	data["total_deaths"] += deaths
	data["items_found"] += items
	save_data()

func set_volume(sfx: float, music: float) -> void:
	data["sfx_volume"] = sfx
	data["music_volume"] = music
	save_data()
