extends Area2D

var activated := false
var flame_time := 0.0
const FLAME_COLOR_A := Color(1.0, 0.6, 0.1)
const FLAME_COLOR_B := Color(1.0, 0.2, 0.05)
const SMOKE_COLOR := Color(0.4, 0.4, 0.4, 0.3)
const STONE_COLOR := Color(0.45, 0.42, 0.38)
const WOOD_COLOR := Color(0.5, 0.35, 0.18)

func _ready() -> void:
	collision_layer = 8
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 30.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	monitoring = true

func _process(delta: float) -> void:
	flame_time += delta
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("heal") and not activated:
		activated = true
		GameManager.set_checkpoint(global_position + Vector2(0, -4))
		body.heal(body.MAX_HEALTH)
		body.restore_stamina(body.MAX_STAMINA)
		AudioManager.play_sfx("checkpoint")

func _draw() -> void:
	draw_circle(Vector2(0, 2), 14, STONE_COLOR)
	for i in [-8, -3, 3, 8]:
		draw_line(Vector2(i, 0), Vector2(i * 0.6, -14), WOOD_COLOR, 2.0)

	if activated:
		for i in 5:
			var t := flame_time * 3.0 + i * 1.3
			var fx := sin(t) * 4.0
			var fy := -16.0 - absf(sin(t * 1.5)) * 10.0 - i * 3
			var r := 4.0 - i * 0.5
			var c: Color = FLAME_COLOR_A.lerp(FLAME_COLOR_B, float(i) / 5)
			draw_circle(Vector2(fx, fy), r, c)
		var smoke_y := -30.0 - sin(flame_time * 2.0) * 5.0
		draw_circle(Vector2(sin(flame_time) * 3, smoke_y), 3, SMOKE_COLOR)
	else:
		draw_circle(Vector2(0, -10), 3, Color(0.3, 0.3, 0.3, 0.5))

	if not activated:
		draw_string(ThemeDB.fallback_font, Vector2(-8, -36), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.5 + sin(flame_time * 2) * 0.3))
