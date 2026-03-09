extends Area2D

var wind_strength := 150.0
var wind_dir := 1.0
var anim_time := 0.0
var bodies_in_zone: Array[Node2D] = []
const ZONE_SIZE := Vector2(1200, 180)

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	if has_meta("wind_strength"):
		wind_strength = get_meta("wind_strength")
	wind_dir = [-1.0, 1.0].pick_random()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = ZONE_SIZE
	shape.shape = rect
	shape.position = ZONE_SIZE * 0.5
	add_child(shape)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	monitoring = true

func _physics_process(delta: float) -> void:
	anim_time += delta
	bodies_in_zone = bodies_in_zone.filter(func(b): return is_instance_valid(b))
	for body in bodies_in_zone:
		if body.has_method("apply_wind"):
			body.apply_wind(Vector2(wind_strength * wind_dir, 0), delta)
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("apply_wind"):
		bodies_in_zone.append(body)
		AudioManager.play_sfx("wind")

func _on_body_exited(body: Node2D) -> void:
	bodies_in_zone.erase(body)

func _draw() -> void:
	var alpha := 0.08 + absf(sin(anim_time * 1.5)) * 0.06
	draw_rect(Rect2(Vector2.ZERO, ZONE_SIZE), Color(0.8, 0.85, 0.9, alpha))
	for i in 8:
		var t := fmod(anim_time * 60 * (0.8 + i * 0.1) + i * 160, ZONE_SIZE.x + 100) - 50
		var y := 20.0 + i * (ZONE_SIZE.y - 40) / 8.0
		var arrow_x := t if wind_dir > 0 else ZONE_SIZE.x - t
		var tip := Vector2(arrow_x + 20 * wind_dir, y)
		var tail := Vector2(arrow_x - 30 * wind_dir, y)
		draw_line(tail, tip, Color(0.9, 0.92, 0.95, 0.25), 1.5)
		draw_line(tip, tip + Vector2(-8 * wind_dir, -4), Color(0.9, 0.92, 0.95, 0.2), 1.0)
		draw_line(tip, tip + Vector2(-8 * wind_dir, 4), Color(0.9, 0.92, 0.95, 0.2), 1.0)
