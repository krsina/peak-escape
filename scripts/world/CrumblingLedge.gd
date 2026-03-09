extends StaticBody2D

var ledge_color := Color(0.55, 0.48, 0.35)
var shake_time := 0.0
var standing_time := 0.0
var crumbling := false
var destroyed := false
var player_on_top := false
const CRUMBLE_DELAY := 1.2
const SHAKE_INTENSITY := 3.0
const SIZE := Vector2(90, 14)

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	if has_meta("color"):
		ledge_color = get_meta("color")

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	shape.shape = rect
	shape.position = SIZE * 0.5
	add_child(shape)

	var detect := Area2D.new()
	detect.collision_layer = 0
	detect.collision_mask = 2
	var area_shape := CollisionShape2D.new()
	var area_rect := RectangleShape2D.new()
	area_rect.size = Vector2(SIZE.x - 4, 12)
	area_shape.shape = area_rect
	area_shape.position = Vector2(SIZE.x * 0.5, -6)
	detect.add_child(area_shape)
	detect.body_entered.connect(_on_body_stepped)
	detect.body_exited.connect(_on_body_left)
	detect.monitoring = true
	add_child(detect)

	queue_redraw()

func _on_body_stepped(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_on_top = true

func _on_body_left(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_on_top = false

func _physics_process(delta: float) -> void:
	if destroyed:
		return
	if player_on_top:
		standing_time += delta
		if standing_time >= CRUMBLE_DELAY and not crumbling:
			_start_crumble()
	else:
		standing_time = maxf(standing_time - delta * 0.5, 0)
	if crumbling:
		shake_time += delta
	queue_redraw()

func _start_crumble() -> void:
	crumbling = true
	AudioManager.play_sfx("crumble")
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_callback(_destroy)

func _destroy() -> void:
	destroyed = true
	collision_layer = 0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)

func _make_rock_polygon(rect_min: Vector2, rect_size: Vector2, seed_val: int, num_points: int = 12) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var jitter := minf(rect_size.x, rect_size.y) * 0.14
	var pts := PackedVector2Array()
	var w := rect_size.x
	var h := rect_size.y
	for i in num_points:
		var t := float(i) / num_points
		var p: Vector2
		if t < 0.25:
			p = Vector2(lerpf(0, w, t / 0.25), 0)
		elif t < 0.5:
			p = Vector2(w, lerpf(0, h, (t - 0.25) / 0.25))
		elif t < 0.75:
			p = Vector2(lerpf(w, 0, (t - 0.5) / 0.25), h)
		else:
			p = Vector2(0, lerpf(h, 0, (t - 0.75) / 0.25))
		p.x += rng.randf_range(-jitter, jitter)
		p.y += rng.randf_range(-jitter, jitter)
		pts.append(rect_min + p)
	return pts

func _draw() -> void:
	if destroyed:
		return
	var offset := Vector2.ZERO
	if crumbling:
		offset = Vector2(sin(shake_time * 40) * SHAKE_INTENSITY, cos(shake_time * 35) * SHAKE_INTENSITY * 0.5)

	var rock_pts := _make_rock_polygon(offset, SIZE, hash(position), 12)
	draw_colored_polygon(rock_pts, ledge_color)
	draw_polyline(rock_pts, ledge_color.darkened(0.2), 1.5)
	draw_line(rock_pts[0], rock_pts[rock_pts.size() - 1], ledge_color.darkened(0.2), 1.5)

	var warn_progress := clampf(standing_time / CRUMBLE_DELAY, 0, 1)
	if warn_progress > 0:
		var warn_color := ledge_color.lerp(Color(0.8, 0.3, 0.1), warn_progress)
		var warn_rock := _make_rock_polygon(offset, Vector2(SIZE.x * warn_progress, 4), hash(position + Vector2(50, 0)), 6)
		draw_colored_polygon(warn_rock, warn_color)

	var crack_count := int(warn_progress * 6)
	var r := RandomNumberGenerator.new()
	r.seed = hash(position)
	for i in mini(crack_count, 6):
		var cx := r.randf_range(5, SIZE.x - 5) + offset.x
		var cy := r.randf_range(3, SIZE.y - 3) + offset.y
		draw_line(Vector2(cx, cy), Vector2(cx + r.randf_range(-8, 8), cy + r.randf_range(-4, 4)), ledge_color.darkened(0.4), 1.0)
