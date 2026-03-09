extends StaticBody2D

var wall_size := Vector2(30, 120)
var wall_color := Color(0.55, 0.48, 0.35)
var revealed := false
var reveal_progress := 0.0

func setup(size: Vector2, color: Color) -> void:
	wall_size = size
	wall_color = color

	var shape := RectangleShape2D.new()
	shape.size = wall_size
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = wall_size * 0.5
	add_child(col)

	collision_layer = 1
	collision_mask = 0

	var detect := Area2D.new()
	detect.collision_layer = 0
	detect.collision_mask = 2
	var detect_shape := RectangleShape2D.new()
	detect_shape.size = Vector2(wall_size.x + 20, wall_size.y)
	var detect_col := CollisionShape2D.new()
	detect_col.shape = detect_shape
	detect_col.position = wall_size * 0.5
	detect.add_child(detect_col)
	detect.body_entered.connect(_on_player_touch)
	add_child(detect)

	set_meta("friction", 1.0)
	queue_redraw()

func _on_player_touch(body: Node2D) -> void:
	if body.is_in_group("player") and not revealed:
		_reveal()

func _reveal() -> void:
	revealed = true
	AudioManager.play_sfx("crumble")
	collision_layer = 0
	var tw := create_tween()
	tw.tween_property(self, "reveal_progress", 1.0, 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_finish_reveal)

func _finish_reveal() -> void:
	var particles := CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 12
	particles.lifetime = 0.5
	particles.explosiveness = 0.9
	particles.direction = Vector2(1, -0.5).normalized()
	particles.spread = 40.0
	particles.initial_velocity_min = 30.0
	particles.initial_velocity_max = 80.0
	particles.gravity = Vector2(0, 200)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = wall_color
	particles.global_position = global_position + wall_size * 0.5
	get_parent().add_child(particles)
	get_tree().create_timer(2.0).timeout.connect(particles.queue_free)

func _process(_delta: float) -> void:
	if revealed:
		queue_redraw()

func _draw() -> void:
	if revealed:
		var alpha := 1.0 - reveal_progress
		if alpha <= 0.01:
			return
		var c := wall_color
		c.a = alpha * 0.3
		draw_rect(Rect2(Vector2.ZERO, wall_size), c)
		return

	var r := RandomNumberGenerator.new()
	r.seed = hash(position)
	var jitter := minf(wall_size.x, wall_size.y) * 0.06
	var pts := PackedVector2Array()
	var num := 12
	for i in num:
		var t := float(i) / num
		var p: Vector2
		if t < 0.25:
			p = Vector2(lerpf(0, wall_size.x, t / 0.25), 0)
		elif t < 0.5:
			p = Vector2(wall_size.x, lerpf(0, wall_size.y, (t - 0.25) / 0.25))
		elif t < 0.75:
			p = Vector2(lerpf(wall_size.x, 0, (t - 0.5) / 0.25), wall_size.y)
		else:
			p = Vector2(0, lerpf(wall_size.y, 0, (t - 0.75) / 0.25))
		p.x += r.randf_range(-jitter, jitter)
		p.y += r.randf_range(-jitter, jitter)
		pts.append(p)
	draw_colored_polygon(pts, wall_color)
	draw_polyline(pts, wall_color.darkened(0.2), 1.5)
	draw_line(pts[0], pts[pts.size() - 1], wall_color.darkened(0.2), 1.5)

	for i in range(r.randi_range(2, 5)):
		var cx := r.randf_range(4, wall_size.x - 4)
		var cy := r.randf_range(4, wall_size.y - 4)
		draw_line(
			Vector2(cx, cy),
			Vector2(cx + r.randf_range(-8, 8), cy + r.randf_range(-4, 4)),
			wall_color.darkened(0.15), 1.0
		)
