extends Area2D

var spawn_pos := Vector2.ZERO
var rock_vel := Vector2.ZERO
var falling := false
var idle_timer := 0.0
var active := false
const FALL_SPEED := 350.0
const CYCLE_TIME := 4.5
const ACTIVATION_RANGE := 600.0
const DAMAGE := 25.0
const ROCK_SIZE := 14.0
const ROCK_COLOR := Color(0.5, 0.45, 0.4)
const WARN_COLOR := Color(1.0, 0.35, 0.1, 0.5)

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	spawn_pos = position
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = ROCK_SIZE
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	monitoring = true

func _physics_process(delta: float) -> void:
	if not active:
		_check_activation()
		queue_redraw()
		return

	if falling:
		rock_vel.y += 600.0 * delta
		position += rock_vel * delta
		if position.y > spawn_pos.y + 800:
			_reset()
	else:
		idle_timer += delta
		if idle_timer >= CYCLE_TIME:
			_start_fall()
	queue_redraw()

func _check_activation() -> void:
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if p.global_position.distance_to(spawn_pos) < ACTIVATION_RANGE:
			active = true
			idle_timer = 0.0
			return

func _start_fall() -> void:
	falling = true
	rock_vel = Vector2(0, FALL_SPEED * 0.2)

func _reset() -> void:
	position = spawn_pos
	falling = false
	idle_timer = 0.0
	rock_vel = Vector2.ZERO
	active = false

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage") and falling:
		body.take_damage(DAMAGE)

func _draw() -> void:
	if not active and not falling:
		draw_circle(Vector2(0, 0), ROCK_SIZE * 0.6, ROCK_COLOR.darkened(0.2))
		return

	if not falling:
		var warn_progress := clampf(idle_timer / CYCLE_TIME, 0, 1)
		if warn_progress > 0.6:
			var pulse := absf(sin(idle_timer * 8.0))
			draw_circle(Vector2(0, 0), ROCK_SIZE + 6, Color(WARN_COLOR.r, WARN_COLOR.g, WARN_COLOR.b, pulse * warn_progress * 0.5))
		draw_circle(Vector2(0, 0), ROCK_SIZE, ROCK_COLOR.darkened(0.1))
		var shake := sin(idle_timer * 20) * warn_progress * 2
		draw_circle(Vector2(shake, 0), ROCK_SIZE - 2, ROCK_COLOR)
	else:
		draw_circle(Vector2(0, 0), ROCK_SIZE, ROCK_COLOR)
		draw_circle(Vector2(0, 0), ROCK_SIZE - 3, ROCK_COLOR.lightened(0.1))
		draw_line(Vector2(-4, -3), Vector2(3, 5), ROCK_COLOR.darkened(0.2), 1.5)
		draw_line(Vector2(2, -5), Vector2(-3, 2), ROCK_COLOR.darkened(0.2), 1.0)
		for i in 4:
			var trail_y := (i + 1) * -10.0
			var trail_a := 0.3 - i * 0.06
			draw_circle(Vector2(randf_range(-3, 3), trail_y), 3.0 - i * 0.5, Color(0.6, 0.55, 0.5, trail_a))
