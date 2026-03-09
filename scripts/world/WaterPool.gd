extends Area2D

var pool_size := Vector2(200, 60)
var pool_style := "water"
var wave_time := 0.0
var surface_color := Color(0.2, 0.5, 0.85, 0.6)
var deep_color := Color(0.1, 0.3, 0.65, 0.7)

func setup(size: Vector2, style: String = "water") -> void:
	pool_size = size
	pool_style = style
	match style:
		"water":
			surface_color = Color(0.2, 0.5, 0.85, 0.6)
			deep_color = Color(0.1, 0.3, 0.65, 0.7)
		"frozen":
			surface_color = Color(0.7, 0.85, 0.95, 0.8)
			deep_color = Color(0.55, 0.72, 0.88, 0.85)
		"steam":
			surface_color = Color(0.6, 0.25, 0.1, 0.5)
			deep_color = Color(0.5, 0.15, 0.05, 0.6)

	collision_layer = 0
	collision_mask = 2
	monitoring = true

	var shape := RectangleShape2D.new()
	shape.size = pool_size
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = pool_size * 0.5
	add_child(col)

	if pool_style == "frozen":
		var ice_body := StaticBody2D.new()
		ice_body.collision_layer = 1
		ice_body.collision_mask = 0
		ice_body.set_meta("friction", 0.05)
		ice_body.add_to_group("no_climb")
		var ice_shape := RectangleShape2D.new()
		ice_shape.size = Vector2(pool_size.x, 8)
		var ice_col := CollisionShape2D.new()
		ice_col.shape = ice_shape
		ice_col.position = Vector2(pool_size.x * 0.5, 4)
		ice_body.add_child(ice_col)
		add_child(ice_body)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	queue_redraw()

var _bodies_inside: Array[Node2D] = []

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_bodies_inside.append(body)
		AudioManager.play_sfx("water_enter")

func _on_body_exited(body: Node2D) -> void:
	_bodies_inside.erase(body)

func _physics_process(delta: float) -> void:
	for body in _bodies_inside:
		if not is_instance_valid(body):
			continue
		if body is CharacterBody2D:
			if pool_style == "steam":
				if body.has_method("take_damage"):
					body.take_damage(15.0 * delta)
			elif pool_style == "water":
				body.velocity.x *= (1.0 - 0.5 * delta)
				if body.has_node(".."):
					body.fall_start_speed = 0.0

func _process(delta: float) -> void:
	wave_time += delta
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, pool_size), deep_color)

	var wave_pts := PackedVector2Array()
	var steps := int(pool_size.x / 8)
	wave_pts.append(Vector2(0, 0))
	for i in range(steps + 1):
		var x := pool_size.x * float(i) / steps
		var y := sin(wave_time * 2.5 + x * 0.04) * 3.0
		wave_pts.append(Vector2(x, y))
	wave_pts.append(Vector2(pool_size.x, pool_size.y * 0.3))
	wave_pts.append(Vector2(0, pool_size.y * 0.3))
	if wave_pts.size() >= 3:
		draw_colored_polygon(wave_pts, surface_color)

	if pool_style == "steam":
		var r := RandomNumberGenerator.new()
		r.seed = hash(position) + int(wave_time * 2)
		for i in range(5):
			var bx := r.randf_range(10, pool_size.x - 10)
			var by := r.randf_range(pool_size.y * 0.3, pool_size.y * 0.8)
			var br := r.randf_range(3, 8)
			draw_circle(Vector2(bx, by), br, Color(0.8, 0.4, 0.1, 0.3))

	if pool_style == "water":
		for i in range(3):
			var lx := pool_size.x * float(i + 1) / 4
			var ly := pool_size.y * 0.4 + sin(wave_time * 1.5 + i) * 4
			draw_line(
				Vector2(lx - 15, ly), Vector2(lx + 15, ly),
				Color(0.5, 0.7, 0.9, 0.3), 1.0
			)

	if pool_style == "frozen":
		draw_rect(Rect2(0, 0, pool_size.x, 8), surface_color.lightened(0.2))
		var r := RandomNumberGenerator.new()
		r.seed = hash(position)
		for i in range(4):
			var sx := r.randf_range(10, pool_size.x - 10)
			draw_line(Vector2(sx, 1), Vector2(sx + r.randf_range(-12, 12), 7), Color(1, 1, 1, 0.3), 1.0)
