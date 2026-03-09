extends Area2D

var pool_size := Vector2(200, 50)
var lava_time := 0.0

const SURFACE_COLOR := Color(1.0, 0.55, 0.1, 0.85)
const DEEP_COLOR := Color(0.7, 0.15, 0.02, 0.9)
const GLOW_COLOR := Color(1.0, 0.4, 0.05, 0.3)
const DAMAGE_PER_SEC := 40.0
const KNOCKBACK_UP := -250.0

func setup(size: Vector2) -> void:
	pool_size = size
	collision_layer = 0
	collision_mask = 2
	monitoring = true

	var shape := RectangleShape2D.new()
	shape.size = pool_size
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = pool_size * 0.5
	add_child(col)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	queue_redraw()

var _bodies_inside: Array[Node2D] = []

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_bodies_inside.append(body)

func _on_body_exited(body: Node2D) -> void:
	_bodies_inside.erase(body)

func _physics_process(delta: float) -> void:
	for body in _bodies_inside:
		if not is_instance_valid(body):
			continue
		if body.has_method("take_damage"):
			body.take_damage(DAMAGE_PER_SEC * delta)
		if body is CharacterBody2D:
			body.velocity.y = minf(body.velocity.y, KNOCKBACK_UP)

func _process(delta: float) -> void:
	lava_time += delta
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, pool_size), DEEP_COLOR)

	var glow_rect := Rect2(-8, -12, pool_size.x + 16, pool_size.y + 16)
	var glow_c := GLOW_COLOR
	glow_c.a = 0.15 + sin(lava_time * 3.0) * 0.08
	draw_rect(glow_rect, glow_c)

	var wave_pts := PackedVector2Array()
	var steps := int(pool_size.x / 6)
	wave_pts.append(Vector2(0, 0))
	for i in range(steps + 1):
		var x := pool_size.x * float(i) / steps
		var y := sin(lava_time * 2.0 + x * 0.05) * 4.0 + cos(lava_time * 3.0 + x * 0.08) * 2.0
		wave_pts.append(Vector2(x, y))
	wave_pts.append(Vector2(pool_size.x, pool_size.y * 0.4))
	wave_pts.append(Vector2(0, pool_size.y * 0.4))
	if wave_pts.size() >= 3:
		draw_colored_polygon(wave_pts, SURFACE_COLOR)

	var r := RandomNumberGenerator.new()
	r.seed = hash(position) + int(lava_time * 3)
	for i in range(4):
		var bx := r.randf_range(8, pool_size.x - 8)
		var by := r.randf_range(pool_size.y * 0.2, pool_size.y * 0.7)
		var br := r.randf_range(2, 6)
		var ba := 0.4 + sin(lava_time * 4.0 + i * 1.5) * 0.2
		draw_circle(Vector2(bx, by), br, Color(1.0, 0.7, 0.2, ba))

	r.seed = hash(position)
	for i in range(3):
		var bx := r.randf_range(15, pool_size.x - 15)
		var cycle := fmod(lava_time * 0.5 + i * 0.7, 2.0)
		if cycle < 0.3:
			var by := lerpf(pool_size.y * 0.5, -8, cycle / 0.3)
			draw_circle(Vector2(bx, by), 4.0 - cycle * 8, Color(1.0, 0.8, 0.3, 0.6))
