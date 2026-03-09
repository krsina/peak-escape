extends Node2D

const BIOME_GRADIENTS := {
	"beach": [Color(0.45, 0.75, 0.95), Color(0.65, 0.85, 0.55)],
	"jungle": [Color(0.28, 0.45, 0.38), Color(0.12, 0.30, 0.15)],
	"icelands": [Color(0.72, 0.82, 0.92), Color(0.52, 0.62, 0.75)],
	"fire": [Color(0.32, 0.10, 0.06), Color(0.15, 0.04, 0.02)],
}

const HILL_COLORS := {
	"beach": [Color(0.35, 0.55, 0.30, 0.3), Color(0.30, 0.48, 0.25, 0.4)],
	"jungle": [Color(0.12, 0.30, 0.10, 0.5), Color(0.08, 0.22, 0.06, 0.6)],
	"icelands": [Color(0.55, 0.62, 0.70, 0.35), Color(0.45, 0.52, 0.62, 0.45)],
	"fire": [Color(0.22, 0.08, 0.04, 0.5), Color(0.18, 0.06, 0.02, 0.6)],
}

var current_top := Color(0.45, 0.75, 0.95)
var current_bot := Color(0.65, 0.85, 0.55)
var target_top := Color(0.45, 0.75, 0.95)
var target_bot := Color(0.65, 0.85, 0.55)
var hill_a := Color(0.35, 0.55, 0.30, 0.3)
var hill_b := Color(0.30, 0.48, 0.25, 0.4)
var cloud_offset := 0.0
var star_positions: Array[Vector2] = []

func _ready() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 42
	for i in 60:
		star_positions.append(Vector2(r.randf_range(0, 1280), r.randf_range(0, 720)))
	GameManager.biome_changed.connect(_on_biome_changed)
	_on_biome_changed(GameManager.current_biome)

func _process(delta: float) -> void:
	current_top = current_top.lerp(target_top, delta * 1.5)
	current_bot = current_bot.lerp(target_bot, delta * 1.5)
	cloud_offset += delta * 12.0
	queue_redraw()

func _on_biome_changed(biome: String) -> void:
	if biome in BIOME_GRADIENTS:
		var g: Array = BIOME_GRADIENTS[biome]
		target_top = g[0]
		target_bot = g[1]
	if biome in HILL_COLORS:
		var h: Array = HILL_COLORS[biome]
		hill_a = h[0]
		hill_b = h[1]

func _draw() -> void:
	var vp := get_viewport_rect().size
	var steps := 32
	for i in steps:
		var t := float(i) / steps
		var c := current_top.lerp(current_bot, t)
		var y := t * vp.y
		var h := vp.y / steps + 1
		draw_rect(Rect2(0, y, vp.x, h), c)

	if GameManager.current_biome in ["icelands", "fire"]:
		for sp in star_positions:
			var twinkle := absf(sin(cloud_offset * 0.3 + sp.x * 0.1))
			draw_circle(sp, 1.0 + twinkle * 0.5, Color(1, 1, 0.9, twinkle * 0.5))

	_draw_hill_layer(vp, 0.08, 0.04, hill_b, 60)
	_draw_hill_layer(vp, 0.15, 0.08, hill_a, 40)

	match GameManager.current_biome:
		"beach":
			_draw_clouds(vp)
		"jungle":
			_draw_clouds(vp)
			_draw_rain(vp)
		"icelands":
			_draw_snow(vp)
		"fire":
			_draw_embers(vp)

func _draw_hill_layer(vp: Vector2, parallax_x: float, parallax_y: float, color: Color, amplitude: float) -> void:
	var pts := PackedVector2Array()
	var scroll_x := GameManager.current_distance * parallax_x
	var scroll_y := GameManager.current_altitude * parallax_y
	pts.append(Vector2(0, vp.y))
	for x in range(0, int(vp.x) + 40, 40):
		var base_y := vp.y * 0.6 + scroll_y
		var noise_y := sin((x + scroll_x) * 0.004) * amplitude + cos((x + scroll_x) * 0.009) * amplitude * 0.5
		pts.append(Vector2(x, clampf(base_y + noise_y, 0, vp.y)))
	pts.append(Vector2(vp.x, vp.y))
	if pts.size() >= 3:
		draw_colored_polygon(pts, color)

func _draw_clouds(vp: Vector2) -> void:
	for i in 6:
		var cx := fmod(i * 240.0 + cloud_offset * (0.3 + i * 0.1), vp.x + 200) - 100
		var cy := 50.0 + i * 40.0 + sin(i * 1.7) * 25.0
		var r := 28.0 + i * 7.0
		draw_circle(Vector2(cx, cy), r, Color(1, 1, 1, 0.15))
		draw_circle(Vector2(cx + r * 0.6, cy - 4), r * 0.7, Color(1, 1, 1, 0.12))
		draw_circle(Vector2(cx - r * 0.4, cy + 3), r * 0.5, Color(1, 1, 1, 0.10))

func _draw_rain(vp: Vector2) -> void:
	var t := cloud_offset
	for i in 40:
		var rx := fmod(i * 37.0 + t * 30.0, vp.x)
		var ry := fmod(i * 23.0 + t * 120.0, vp.y)
		draw_line(Vector2(rx, ry), Vector2(rx - 2, ry + 8), Color(0.6, 0.7, 0.8, 0.25), 1.0)

func _draw_snow(vp: Vector2) -> void:
	var t := cloud_offset
	for i in 35:
		var sx := fmod(i * 47.0 + sin(t * 0.6 + i) * 40.0, vp.x)
		var sy := fmod(i * 31.0 + t * (18 + i * 1.5), vp.y)
		draw_circle(Vector2(sx, sy), 1.5, Color(1, 1, 1, 0.5))

func _draw_embers(vp: Vector2) -> void:
	var t := cloud_offset
	for i in 25:
		var ex := fmod(i * 71.0 + sin(t + i * 0.5) * 60.0, vp.x)
		var ey := fmod(vp.y - (i * 43.0 + t * (25 + i * 2.5)), vp.y)
		var glow := absf(sin(t * 2.0 + i))
		draw_circle(Vector2(ex, ey), 2.0, Color(1, 0.5, 0.1, glow * 0.5))
